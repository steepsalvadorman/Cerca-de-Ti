# Plan de mejora — Vacíos de lógica de aplicación y de negocio

Documento **operativo** para cerrar los vacíos de lógica que quedan abiertos en Cerca de Ti.
No reemplaza a [`plan-de-solucion-vacios.md`](./plan-de-solucion-vacios.md) (el catálogo histórico
`GAP-01…GAP-132`): lo **actualiza contra el código real** y lo convierte en trabajo ejecutable con
criterio de aceptación verificable.

- **Fecha de esta revisión:** 2026-09-19
- **Base:** lectura del código + **ejecución real** de las suites (Postgres 5432 disponible).
- **Método:** cada afirmación de este documento se comprobó leyendo `archivo:línea` o ejecutando un
  comando. Lo que no se pudo comprobar se marca explícitamente como *por verificar*.

## Evidencia de ejecución (esta revisión)

| Comando | Resultado |
|---|---|
| `flutter test` | ✅ **16/16 pasan** (`cerca_format_test`, `session_expiry_test`, `widget_test`) |
| `cd backend; cargo test --all-targets` | ❌ **125 pasan / 1 falla** (126 en total) → *exit 1* |
| `Test-NetConnection 127.0.0.1:5432` | ✅ alcanzable (Postgres local arriba) |

Distribución de la suite de backend en esta pasada (para poder comparar después):

| Target | Pasan |
|---|---|
| `src/` (unitarias, incl. `rate_limit` y `validation`) | 26 |
| `bidding_flow.rs` | 15 |
| `input_validation.rs` | 15 |
| `job_cancellation.rs` | 14 |
| `document_upload.rs` | 11 |
| `chat_tracking_http.rs` | 10 |
| `business_rules.rs` / `google_sign_in.rs` / `job_concurrency.rs` | 7 cada uno |
| `demo_seed_guard.rs` | 5 |
| `deploy_manifest.rs` | 3 |
| `job_lifecycle.rs` | 5 ✅ + **1 ❌** |

**El único fallo es un vacío de lógica de negocio real, no un test roto** (ver §2 · H-1):

```
---- paying_the_fee_activates_the_job_and_advancing_completes_it stdout ----
panicked at tests\job_lifecycle.rs:172:5:
assertion failed: after_payment.payment_done
test result: FAILED. 5 passed; 1 failed
```

> ⚠️ `tests.yml` es la puerta de `android-distribute.yml` y corre en cada push a `main`. Con este
> fallo, **la cadena de distribución está roja**: no sale APK y el gate de "no shipear sin tests
> verdes" está bloqueando legítimamente.

---

## 0. Resumen ejecutivo

El proyecto ya cerró la mayor parte de lo crítico del informe original: la licitación funciona
(`GAP-80`), el fee se cobra a través de un puerto `PaymentGateway` (`GAP-14`), hay concurrencia
optimista por versión (`GAP-07`), cancelación real (`GAP-19`), rate limiting (`GAP-118`), subida de
documentos verificada por *magic bytes* (`GAP-30/62/63`), guardas de arranque en producción
(`GAP-113`) y **125 pruebas de backend + 16 de Flutter**.

Lo que queda **no es "más cobertura"**: son **contradicciones internas del modelo** y **guardas que
existen pero no se activan**. Tres ejemplos verificados en esta revisión:

1. Un job *directo* o *project* nace con `fee_paid = true` y `payment_done = false`, y el endpoint
   de pago **no puede corregirlo** porque el dominio retorna temprano (§2 · H-1). **La suite lo
   detecta y hoy está roja.**
2. `APP_ENV=production` **no está declarado en `render.yaml`**, así que las guardas de producción
   (demo password sembrado, `PAYMENTS_MODE=fake`) **nunca se activan en el deploy real** (§2 · H-2).
3. El techo de dinero sigue siendo un `String` libre (`payment_method`) y el flag que dice si el
   pago se resolvió tiene **dos fuentes de verdad** (`fee_paid` / `payment_done`).

**Objetivo de este plan:** (a) devolver la suite a verde, (b) unificar los invariantes del agregado
`JobRequest` en un solo sitio, (c) cerrar los huecos de dinero/identidad, y (d) instalar los gates
que evitan que esto vuelva a pasar. Sin (d), el resto se re-abre.

---

## 1. Estado verificado contra el código de hoy

### 1.1 ✅ Cerrado y con prueba (lo que ya no hay que tocar)

| Regla de negocio | Dónde vive | Prueba que la sostiene |
|---|---|---|
| La licitación es operable: el técnico puede abrir una subasta abierta | `job/application/mod.rs:66-99` (`JobAccess`) | `bidding_flow.rs` (15) |
| El postor no ve `client_id` ni `address` | `job/interfaces/http/dto.rs` (`OpenBidJobResponse`) | idem, sobre JSON crudo |
| Un técnico no verificado **no puede ofertar** (el badge significa algo) | `submit_offer.rs:52-54` | `an_unverified_technician_cannot_bid` |
| Solo el técnico asignado avanza el job; el cliente no | `advance_progress.rs:38-41` | `job_lifecycle.rs` |
| Cancelación real, con autor, motivo y estado terminal respetado | `cancel_job.rs` + migración `0012` + `routes.rs:18` | `job_cancellation.rs` (14) |
| Escrituras concurrentes: una gana, la otra recibe conflicto | `postgres_job_repository.rs:168-227` + `0013` | `job_concurrency.rs` (7) |
| Un documento solo "sube" si el objeto existe, pesa ≤10 MB y sus *magic bytes* coinciden | `upload_document.rs:198-251` | `document_upload.rs` (11) |
| Rate limiting por IP (credenciales y general) | `shared/rate_limit.rs`, `routes.rs:57,76` | 7 unitarias + `input_validation.rs` |
| Cuerpo máximo de 64 KiB + validación por campo | `routes.rs:33,73`, `shared/validation.rs` | `input_validation.rs` (15) |
| El pago ya no es un booleano: puerto `PaymentGateway`, captura registrada, idempotencia | `ports.rs`, `fake_payment_gateway.rs`, migración `0014` | `payment_simulation.rs` |
| Chat y tracking dependen de **participación + estado**, no de `fee_paid` | `job_participation.rs` | `chat_tracking_http.rs` (10) |
| Producción no arranca con el hash demo ni con `PAYMENTS_MODE=fake` | `main.rs:55-81` | `demo_seed_guard.rs` (5) |
| El rating del técnico se recalcula al calificar | `rate_job.rs:44-49` | `rating_a_job_updates_the_technicians_average` |
| Precios del seed en soles | `cerca_seed_data.dart:42-86` | `cerca_format_test.dart` |

**Conclusión:** el núcleo del dominio está en buen estado. Los vacíos que quedan (§1.2) son de
**coherencia interna**, **guardas no activadas** y **pertinencia del modelo**, no de arquitectura.

### 1.2 🔴 Abierto y verificado (los vacíos que quedan)

Formato: síntoma → evidencia → causa raíz → impacto.

#### H-1 · `fee_paid` y `payment_done` divergen, y la suite está roja — **Crítica**
- **Síntoma:** `cargo test` falla en `job_lifecycle.rs:172` (`assertion failed: after_payment.payment_done`).
- **Evidencia:** `fee_amount_for()` (`job_request.rs:45-50`) devuelve **`0` para `direct` y
  `project`**; `JobRequest::new` (`:107,111,113`) deja esos jobs en `Active`, con `fee_paid = true`
  y `payment_done = false`; `JobRequest::pay_fee` (`:142-148`) **retorna temprano** cuando
  `fee_paid` ya es `true`; y `PayFeeUseCase` (`pay_fee.rs:60-67`) usa esa ruta para el camino "ya
  pagado". Conclusión: `POST /jobs/{id}/pay` responde `Ok` pero `payment_done` **nunca se escribe**
  en un job gratuito, aunque el DTO (`dto.rs:22,50`) y el cliente (`job_request.dart:21`) lo
  exponen.
- **Causa raíz:** dos flags con solape semántico sin invariante que los ate, y la tarifa "gratis"
  modelada como *pago ya hecho* en vez de *no aplica cobro*.
- **Impacto:** doble fuente de verdad sobre el dinero; la UI puede habilitarse por `paymentDone` y
  discrepar del servidor; **CI rojo ⇒ no se publica APK**.

#### H-2 · `APP_ENV` no llega al deploy ⇒ las guardas de producción no existen — **Crítica**
- **Evidencia:** `render.yaml` menciona `APP_ENV` **solo en un comentario** (`:64`) y no lo declara
  como `envVar`; `main.rs:55` y `:64` condicionan las guardas a `config.is_production()`, que es
  `environment == "production"` (`config.rs:74-76`). `deploy_manifest.rs` valida
  `GOOGLE_CLIENT_IDS`, no `APP_ENV`.
- **Causa raíz:** una guarda condicionada a una variable que el manifiesto de despliegue no fija.
- **Impacto:** en el host real, `PAYMENTS_MODE=fake` (`render.yaml:65-66`) "cobra" sin cobrar y el
  chequeo de contraseñas demo queda inerte. Las guardas de `main.rs` solo se activarían si alguien
  define `APP_ENV` a mano en el dashboard — y ningún test lo cubre.

#### H-3 · El método de pago es un `String` libre y puede llevar un PAN — **Alta**
- **Evidencia:** `PayFeeInput.payment_method: String` (`pay_fee.rs:10`) llega del body sin
  validación de forma; `ClientPaymentMethod` (`client/domain/client_payment_method.rs:12-19`) solo
  copia `label`/`detail` y `AddPaymentMethodUseCase` (`add_payment_method.rs:21-25`) no valida
  nada; `PayFeeUseCase` **no comprueba que el método pertenezca al cliente**; y
  `client/interfaces/http/routes.rs:10-15` no expone `PUT` ni `DELETE`.
- **Impacto:** se puede pagar con un método inventado y el servidor lo acepta; `detail` es texto
  libre apto para almacenar PAN/CVV ⇒ riesgo PCI (`GAP-126`).

#### H-4 · El feed de subastas no filtra por oficio, categoría ni cobertura — **Alta**
- **Evidencia:** `find_open_bidding_jobs` (`postgres_job_repository.rs:317-329`) filtra solo
  `job_kind='bidding' AND status='pending' AND technician_profile_id IS NULL`, más el `NOT IN` de
  las ofertas propias. Nada de `categories`, `coverage_km` ni distancia.
- **Causa raíz:** `job_requests` no tiene columna de categoría: la pertinencia **no es expresable**
  sin cambio de esquema.
- **Impacto:** todo técnico ve todas las subastas; el "feed pertinente" es una promesa sin modelo
  de datos que la sostenga (`GAP-05`, segunda mitad).

#### H-5 · El rating 5.0 está fabricado en dos sitios — **Alta**
- **Evidencia:** `technician_profiles.rating` es `NOT NULL DEFAULT 5.0` (`0002:8`) y
  `save_profile` inserta `rating: 5.0` con `reviews: 0`
  (`technician/application/save_profile.rs:55-56`); **además**,
  `recalculate_rating_from_jobs` hace `SET rating = COALESCE(stats.avg_rating, 5.0)`
  (`postgres_technician_repository.rs:319`), de modo que un técnico sin reseñas **vuelve** a 5.0.
- **Impacto:** la primera impresión del ranking es una mentira sistemática: todos 5.0 con 0 reseñas.

#### H-6 · La posición del técnico es fija y el mapa del cliente la ignora — **Alta**
- **Evidencia:** al crear perfil se escriben `pin_top: 0.45`, `pin_left: 0.35` y
  `distance: "0.5 km"` (`save_profile.rs:57-60`) — idénticos para todos; el cliente **no usa esos
  campos** y resuelve coordenadas por `id`, con respaldo al centro de Lima
  (`home_screen.dart:699,706,747-749,760`).
- **Impacto:** un técnico nuevo aparece en Lima; `coverage_km`, `distance` y los pines no
  significan nada (`GAP-44/46/92/107`).

#### H-7 · La tarifa sigue hardcodeada en el cliente y su valor es un placeholder — **Alta**
- **Evidencia:** `'S/ 4'` literal en `bidding_screen.dart:142` y `job_rating_screen.dart:111`;
  la tarifa del servidor está declarada como placeholder (`job_request.rs:42-50`) y el texto de
  esas dos pantallas **no interpola `feeAmount`**.
- **Impacto:** cambiar el precio obliga a tocar dos pantallas; si divergen, la app miente sobre lo
  que cobra (la clase de bug que ya ocurrió con `GAP-51/55`).

#### H-8 · Sesiones de 7 días sin refresh ni revocación — **Alta**
- **Evidencia:** `jwt_token_service.rs:16,35-36`: HS256, `exp = now + 7 días`, sin `jti` ni lista
  de revocación; no hay endpoint de refresh.
- **Impacto:** un token robado —o el de una cuenta comprometida— sigue siendo válido hasta una
  semana; no existe "cerrar todas las sesiones" (`GAP-25`).

#### H-9 · La verificación de técnicos es automática, no auditable y tiene carrera — **Alta**
- **Evidencia:** `refresh_verification` (`upload_document.rs:255-271`) marca `is_verified = true`
  en cuanto los 3 documentos obligatorios están `Uploaded`; no hay estado `rejected`, rol revisor
  ni revocación. `save_profile` es un UPSERT que reescribe `is_verified` con el valor **leído**
  (`postgres_technician_repository.rs:165-173`) y `technician_profiles` **no tiene columna
  `version`**: "leer perfil (false) → confirmar documento (true) → guardar perfil (false)" pierde la
  verificación sin conflicto (`GAP-31/65/66/77`).
- **Impacto:** verificar es trivial y des-verificar es invisible; el badge sigue siendo un dato
  autodeclarado por el propio interesado.

#### H-10 · No hay paginación en ningún listado — **Media**
- **Evidencia:** `find_client_history` (`:279-296`), `find_assigned_jobs` (`:298-315`) y
  `find_open_bidding_jobs` (`:317-337`) hacen `SELECT … ORDER BY created_at DESC` sin `LIMIT`; el
  chat devuelve el hilo completo (`GAP-35/42`).
- **Impacto:** payloads que crecen sin techo; pantallas de inicio que se degradan con el tiempo.

#### H-11 · Sin cabeceras de seguridad, sin métricas de negocio, sin auditoría — **Media**
- **Evidencia:** `routes.rs:59-77` solo añade `TraceLayer`, CORS, límite de cuerpo y rate limit: no
  hay HSTS, `X-Content-Type-Options` ni `Referrer-Policy`; no existe tabla ni log de auditoría para
  `pay`/`choose`/`cancel`/`rate` (`GAP-56/57`).

#### H-12 · El cliente puede quedar clavado, o mostrar el pago como hecho sin serlo — **Alta**
- **Evidencia:** `active_job_controller.dart:26-56` asigna `state = const AsyncLoading()` **antes**
  del `await` y **fuera** de `AsyncValue.guard` en `payFee`, `rate` y `chooseOffer`: si la petición
  falla, el provider queda en `AsyncLoading` indefinidamente y la UI cae a sus respaldos. Además el
  acceso a `/tracking` depende del estado local de navegación, no del job
  (`app_router.dart:39-50,193-196` no consulta `fee_paid` ni `status`), así que un deep link entra
  con `fee_paid == false` (`GAP-97/98/106`).
- **Impacto:** estados de UI que no corresponden a la verdad del servidor; el usuario no sabe si pagó.

#### H-13 · No hay prueba de contrato cliente ⇄ servidor — **Media** 
- **Evidencia:** el mismo payload está definido dos veces —`job/interfaces/http/dto.rs` y
  `lib/features/job_request/domain/job_request.dart` (+ `*.g.dart`)— y nada compara ambas
  definiciones (`GAP-59`). H-1 es la demostración: el campo existe en los dos lados y su semántica
  no coincide.
- **Impacto:** cada divergencia de contrato se descubre en producción, no en CI.

---

## 2. Plan de mejora por olas

Cada ola se puede entregar y verificar por separado. El orden no es por dificultad: es por **riesgo
de negocio**. Cada ítem lleva *dónde*, *qué hacer* y **cómo se sabe que quedó cerrado**.

### Ola A — Estabilizar y no mentir (esta semana)

Objetivo: CI verde, deploy con guardas reales, y ni un peso ni un byte de tarjeta sin control.

#### A1 · Unificar el estado del pago (H-1) 🔴 — *desbloquea todo lo demás*
**Dónde:** `job/domain/job_request.rs`, `job/application/pay_fee.rs`, `job/interfaces/http/dto.rs`,
migración nueva `0015`.

**Qué hacer**
1. Decidir el significado y escribirlo en el código: `fee_paid` = *"el cobro de Cerca quedó
   resuelto"*; `payment_done` = *"hubo una transacción"*. Un job gratuito es `fee_paid = true` y
   `payment_done = false`, y **eso es correcto**, no un defecto.
2. Corregir la expectativa del test para que exprese la regla anterior
   (`job_lifecycle.rs:172`: para `direct`, `payment_done` es `false`; el caso con transacción se
   verifica en un job `bidding`).
3. Añadir la prueba que hoy falta: **un job de subasta, tras `pay`, tiene ambos flags en `true` y
   `status = active`** (el test actual solo lo comprueba en `direct`).
4. Documentar el invariante en la migración `0015` y, si se quiere hacer imposible la divergencia,
   añadir el `CHECK` correspondiente.

**Criterio de aceptación:** `cargo test --all-targets` → **exit 0**, y existe una prueba que ata
cada combinación de `fee_amount`/`fee_paid`/`payment_done`/`status` a una fila esperada.

#### A2 · Activar las guardas de producción (H-2) 🔴
**Dónde:** `render.yaml`, `backend/tests/deploy_manifest.rs`.

**Qué hacer**
1. Declarar `APP_ENV` como `envVar` en `render.yaml` con `value: production`.
2. Cambiar `PAYMENTS_MODE` para que **no** pueda ser `fake` en producción: dejarlo `sync: false` o
   eliminarlo, para que el arranque falle ruidosamente en vez de simular cobros.
3. Extender `deploy_manifest.rs` para que compruebe, además de `GOOGLE_CLIENT_IDS`, que **cada
   variable que el código lee para una decisión de seguridad está declarada en el manifiesto**
   (`APP_ENV`, `PAYMENTS_MODE`, `S3_*`). El test debe fallar si alguien añade una guarda sin
   declararla.

**Criterio de aceptación:** `deploy_manifest.rs` falla si se quita `APP_ENV` de `render.yaml`; el
deploy deja de arrancar con `PAYMENTS_MODE=fake` (guardas efectivas).

#### A3 · Endurecer el pago (H-3) 🟠
**Dónde:** `job/application/pay_fee.rs`, `job/application/ports.rs`,
`client/application/add_payment_method.rs`, `client/interfaces/http/{routes,handlers}.rs`,
migración nueva.

**Qué hacer**
1. `payment_method` pasa de `String` a **enum cerrado** (`Card`, `Yape`, `Plin`, `Cash`…) y se
   valida con `shared::validation::one_of`, igual que el resto de enums del proyecto.
2. `PayFeeUseCase` recibe el `payment_method_id` del cliente y **verifica que pertenece a quien
   paga** (hoy no lo comprueba en absoluto).
3. `client_payment_methods.detail` deja de admitir PAN: o se elimina la columna a favor de
   `brand`/`last4`/`exp`, o se valida explícitamente que no contiene 13–19 dígitos seguidos y un
   CVV. **Ninguna ruta debe persistir un PAN.**
4. Añadir `DELETE /client/payment-methods/{id}` (y `PUT` si el producto lo necesita) con
   autorización por propiedad; hoy el cliente no puede borrar una tarjeta comprometida.

**Criterio de aceptación:** pruebas que verifiquen (a) `payment_method` inválido ⇒ 422 nombrando el
campo; (b) método de **otro** cliente ⇒ 403; (c) `detail` con PAN ⇒ rechazado; (d) `DELETE` borra
solo el propio.

#### A4 · Quitar la tarifa hardcodeada del cliente (H-7) 🟠
**Dónde:** `bidding_screen.dart:142`, `job_rating_screen.dart:111`, `cerca_format.dart`.

**Qué hacer:** interpolar `job.feeAmount` con `formatSoles` en los dos textos; si `feeAmount == 0`,
mostrar un texto que no mencione un cobro inexistente. Añadir prueba en
`test/cerca_format_test.dart` que ate la etiqueta al monto.

**Criterio de aceptación:** `grep "S/ 4" lib/` sin resultados; prueba que verifica que cambiar
`feeAmount` cambia el texto mostrado.

#### A5 · Reparar el estado del cliente Flutter (H-12) 🟠
**Dónde:** `lib/features/job_request/application/active_job_controller.dart`,
`lib/core/router/app_router.dart`.

**Qué hacer**
1. Envolver **todas** las mutaciones en `AsyncValue.guard` y **no** pisar el valor previo con
   `AsyncLoading` (usar `AsyncLoading` de valor: `state = AsyncLoading<JobRequest?>().copyWithPrevious(state)`,
   o conservar el job mientras se envía).
2. Añadir al `redirect` de `app_router.dart` una comprobación **contra el job**, no contra la
   navegación: `/tracking` y `/chat` solo si el job existe y `status` lo permite.
3. Pruebas de widget/unitarias: un POST que falla deja el provider en `AsyncError` (no en
   `AsyncLoading`); un deep link a `/tracking` con `feePaid == false` redirige al pago.

**Criterio de aceptación:** `flutter test` cubre los dos casos anteriores; ningún provider queda en
`AsyncLoading` tras un fallo.

---

### Ola B — Integridad del modelo (siguiente iteración)

Objetivo: que el modelo diga la verdad sobre quién es quién y cuánto cuesta qué.

#### B1 · Veracidad del rating (H-5) 🟠
**Dónde:** `technician/application/save_profile.rs:55-56`,
`postgres_technician_repository.rs:319`, migración nueva.
**Qué hacer:** dejar de fabricar `5.0`. Modelar "sin reseñas" como `rating NULL` / `reviews = 0`,
hacer que `recalculate_rating_from_jobs` **no** aplique un valor por defecto (`AVG` sin filas ⇒
`NULL`) y que la UI muestre "Nuevo" o "Sin reseñas" en vez de cinco estrellas.
**Criterio de aceptación:** prueba que crea un técnico, no lo califica, y comprueba que el rating
almacenado **no** es 5.0; y que tras una reseña de 3 el promedio es exactamente 3.0.

#### B2 · Pertinencia del feed (H-4) 🟠
**Dónde:** migración (`job_requests.category`), `create_job.rs`, `postgres_job_repository.rs:317-329`,
`get_technician_jobs.rs`.
**Qué hacer:**
1. Añadir `category` al job (derivada de la selección del cliente) y **definir el catálogo canónico
   de categorías en un solo sitio**, hoy duplicado entre `technician_document.rs`, el frontend y el
   `TEXT[]` de la tabla.
2. Filtrar el feed por las `categories` del técnico y (cuando haya geo real) por `coverage_km`.
3. Coherencia oficio↔categoría en `save_profile`: hoy se aceptan categorías que no corresponden al
   oficio declarado.

**Criterio de aceptación:** un técnico de gasfitería **no** ve subastas de electricidad; prueba que
lo verifica con dos perfiles de oficios distintos.

#### B3 · Ubicación real (H-6) 🟠
**Dónde:** `save_profile.rs:57-60`, `technician_profiles`, `home_screen.dart:699-760`,
`tracking/application/update_location.rs`.
**Qué hacer:** sustituir `pin_top`/`pin_left`/`distance` (maquetación y texto de *display*) por
`latitude`/`longitude` reales; calcular `distance` en el servidor a partir de la ubicación del
cliente; validar el rango geográfico de las coordenadas de tracking (hoy se aceptan `NaN`/`∞`).
**Criterio de aceptación:** un técnico nuevo aparece donde realmente está, no en Lima; coordenadas
fuera de rango ⇒ 422.

#### B4 · Verificación auditable (H-9) 🟠
**Dónde:** `upload_document.rs:255-271`, `technician_profiles`, rol revisor.
**Qué hacer:**
1. Separar *subido* de *verificado*: estados `pending` / `approved` / `rejected` y rol revisor.
2. Sacar `is_verified` del UPDATE de `save_profile`, para que el dueño **no** pueda reescribirlo
   (esto además cierra la carrera descrita en H-9).
3. Añadir `version` a `technician_profiles` (o reutilizar el patrón de la migración `0013`) para que
   un guardado concurrente reporte conflicto en vez de perder la verificación.
4. Revocación con motivo y auditoría.

**Criterio de aceptación:** guardar el perfil **no** puede cambiar `is_verified`; un documento
rechazado impide ofertar; la prueba de carrera (guardar perfil mientras se confirma un documento) no
pierde la verificación.

#### B5 · Sesiones revocables (H-8) 
**Dónde:** `jwt_token_service.rs`, `auth/interfaces/http/routes.rs`, migración.
**Qué hacer:** access token corto (p. ej. 30 min) + refresh token persistido y revocable con `jti`;
`POST /auth/refresh` y `POST /auth/logout` que revoca; invalidar todas las sesiones al cambiar la
contraseña.
**Criterio de aceptación:** un token revocado ⇒ 401 inmediato; pruebas de refresh y de revocación.

#### B6 · Paginación (H-10) 
**Dónde:** `postgres_job_repository.rs:279-337`, chat, `technician/application/get_technicians.rs`.
**Qué hacer:** paginación por cursor (`?limit=&cursor=`) en historial, jobs asignados, subastas
abiertas, `/providers` y mensajes; `limit` con techo explícito validado en el borde.
**Criterio de aceptación:** respuestas acotadas con cualquier volumen de datos; prueba de que el
cursor avanza sin duplicar ni perder filas.

---

### Ola C — Contrato, observabilidad y proceso (evita las recaídas)

#### C1 · Prueba de contrato cliente ⇄ servidor (H-13) 
**Dónde:** `backend/tests/` (JSON dorado) + `test/` (parseo del mismo literal).
**Qué hacer:** congelar el JSON que el servidor produce para cada payload público y hacer que un
test de Dart parsee **ese mismo literal**. Es la mitigación estructural contra H-1, `GAP-51` y
`GAP-55`: barata y viable hoy.
**Criterio de aceptación:** cambiar un campo del DTO del servidor rompe un test de Dart.

#### C2 · Cabeceras de seguridad y auditoría (H-11) 
**Dónde:** `routes.rs:59-77`, migración de auditoría.
**Qué hacer:** HSTS, `X-Content-Type-Options` y `Referrer-Policy`; registro de auditoría para `pay`,
`choose`, `cancel` y `rate` con actor, job, resultado y timestamp.
**Criterio de aceptación:** las cabeceras aparecen en toda respuesta; toda operación de dinero deja
rastro consultable.

#### C3 · Convertir `clippy` en bloqueante 
**Dónde:** `.github/workflows/tests.yml` (hoy `continue-on-error: true`, con ~16 avisos).
**Qué hacer:** limpiar los avisos y pasar a `-D warnings`, para que el linter deje de ser decorativo.
**Criterio de aceptación:** un `clippy` con avisos rompe la build.

#### C4 · Matriz actor × endpoint completa 
**Dónde:** `backend/tests/ownership_authorization.rs` y `role_authorization.rs` (existentes).
**Qué hacer:** completar lo que falta (`pay`, `rate`, `choose`, chat y tracking) para todos los
actores posibles: cliente ajeno, técnico no asignado, técnico no verificado, usuario sin perfil y
anónimo. `bidding_flow.rs` y `job_cancellation.rs` ya cubren subasta y cancelación.
**Criterio de aceptación:** cada endpoint mutador tiene al menos una prueba de rechazo por identidad
y otra por propiedad.

---

## 3. Orden de ejecución y esfuerzo

| # | Ítem | Hallazgo | Sev | Esfuerzo |
|---|---|---|---|---|
| 1 | Unificar el estado del pago + CI verde | H-1 | Crítica | S |
| 2 | `APP_ENV` en el manifiesto + test de guardas | H-2 | Crítica | S |
| 3 | Enum de método de pago, propiedad, no PAN, `DELETE` | H-3 | Alta | M |
| 4 | Tarifa interpolada en el cliente | H-7 | Alta | S |
| 5 | `AsyncValue.guard` + guarda de ruta por job | H-12 | Alta | S |
| 6 | Rating sin fabricar | H-5 | Alta | S |
| 7 | Verificación auditable + carrera del perfil | H-9 | Alta | M |
| 8 | Categoría del job + feed pertinente | H-4 | Alta | M |
| 9 | Geo real + validación de coordenadas | H-6 | Alta | M |
| 10 | Refresh y revocación de sesión | H-8 | Alta | M |
| 11 | Paginación por cursor | H-10 | Media | M |
| 12 | Prueba de contrato | H-13 | Media | S |
| 13 | Auditoría + cabeceras de seguridad | H-11 | Media | S |
| 14 | `clippy` bloqueante | — | Media | S |
| 15 | Matriz actor × endpoint | — | Media | M |

**Regla de secuencia:** nada de la Ola B empieza antes de que A1 y A2 estén cerrados. Sin A1 la
suite está roja y no hay red de seguridad; sin A2 las demás guardas de producción son decorativas.

---

## 4. Definición de "vacío cerrado"

Un vacío está cerrado **solo** si cumple las cuatro condiciones:

1. **Regla explícita** — la regla vive en el dominio o en el esquema (un `CHECK`, un enum, un método
   del agregado), no implícita en un `if` de un handler.
2. **Punto único** — existe un solo sitio que la decide. Si hay dos, uno es una copia y hay que
   borrarlo (H-1, H-5 y H-7 son los tres ejemplos de este plan).
3. **Prueba en rojo→verde** — hay una prueba que **falla** con el comportamiento anterior. Se valida
   revirtiendo el arreglo: si el test sigue verde, el test no prueba nada.
4. **Verificación por ejecución** — `cargo test --all-targets` verde **y** `flutter test` verde,
   ejecutados en la misma pasada que el cambio.

---

## 5. Decisiones de producto pendientes

| Tema | Decisión que falta |
|---|---|
| Tarifas (H-1/H-7) | `fee_amount_for` es un placeholder explícito (`job_request.rs:42-44`): fijar los montos reales para Perú antes de cobrar |
| Chat | ¿El chat debe seguir abierto con el job `pending`, sin técnico elegido? Hoy sí (`job_participation.rs:45-51`) |
| Confirmación del cliente | El técnico cierra el trabajo y **nadie** lo confirma desde el lado del cliente: decidir si hace falta un paso de aceptación |
| Cobertura geográfica | `coverage_km` no se puede aplicar de verdad hasta que H-6 tenga coordenadas reales |
| Revocación (H-8) | ¿Sesión única por dispositivo o multisesión con revocación individual? |

---

## 6. Trazabilidad con el informe original

Este documento **actualiza el estado** de `plan-de-solucion-vacios.md`, no su catálogo. Los GAP que
siguen abiertos y su hallazgo equivalente:

| GAP original | Hallazgo aquí |
|---|---|
| `GAP-11` (`payment_done` nunca se escribe) | **H-1** |
| `GAP-112/113` (guardas inertes en el deploy) | **H-2** |
| `GAP-14/126` (método de pago libre, PAN) | **H-3** |
| `GAP-05` (feed no pertinente) | **H-4** |
| `GAP-71` (`rating 5.0` fabricado) | **H-5** |
| `GAP-44/46/92/107` (pines y coordenadas) | **H-6** |
| `GAP-51/55` (precio calculado en el cliente) | **H-7** |
| `GAP-25` (JWT no revocable) | **H-8** |
| `GAP-31/65/66/77` (verificación) | **H-9** |
| `GAP-35/42` (paginación) | **H-10** |
| `GAP-56/57` (cabeceras, métricas) | **H-11** |
| `GAP-97/98/106` (estado del cliente) | **H-12** |
| `GAP-59` (contrato) | **H-13** |

**Ya cerrados, fuera de las olas:** `GAP-80/18/15/19/20/28/30/62/63/95/96/111/112/118` y
`GAP-01/02/06/17/32/43/64/74/123` (véase §1.1).

### Corrección de documentación detectada

`plan-de-solucion-vacios.md` se contradice en dos puntos que conviene arreglar en la misma pasada:
- Afirma que `GAP-43` está resuelto (`:49`) y, doce líneas después, que "sigue abierto" (`:61-62`).
- Sus encabezados de ola siguen describiendo como pendientes cosas ya implementadas (p. ej. la
  concurrencia en `GAP-07` o la cancelación en `GAP-19`), mientras su tabla de estado las marca
  aplicadas.

---

## 7. Cómo se verifica este plan

Al cerrar cada ítem, la pasada de verificación es siempre la misma:

```powershell
# Backend (requiere Postgres en 5432)
cd backend; cargo test --all-targets

# Cliente
flutter test
flutter analyze
```

Un ítem del plan **no** se marca como cerrado si alguna de las dos suites no está en verde, aunque
el cambio "ya funcione a mano". Los números de partida de esta revisión son **125 pasan / 1 falla**
en backend y **16/16** en Flutter: el objetivo de la Ola A es volver a **126/126 y 16/16**.