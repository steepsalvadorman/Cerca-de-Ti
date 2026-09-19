# Plan de solución — Vacíos de lógica de negocio

Compañero de [`casos-de-prueba-logica-de-negocio.md`](./casos-de-prueba-logica-de-negocio.md).
Este documento convierte los vacíos identificados (`GAP-01` … `GAP-132`) en un plan ejecutable,
ordenado por **riesgo de negocio real**, no por dificultad técnica.

- **Base:** 303 reglas de negocio identificadas, 50 con prueba (17 % de cobertura).
- **Todo hallazgo cita `archivo:línea`.** Cada GAP se verificó leyendo el código.
- ⚠️ **Ningún hallazgo está confirmado por ejecución:** la suite de integración no corre en este
  entorno (`PoolTimedOut`, sin Postgres). Ver §5, Sprint 0.

---

## Estado de implementación

La **Ola 0**, la Ola 1 completa salvo el cobro real, y buena parte de la Ola 2 y 3 ya están
aplicadas y verificadas contra Postgres real. La suite pasó de **39 a 151 pruebas** (backend) y
de **4 a 16** (Flutter), con cero regresiones. `cargo test` termina en **exit 0**.

### ✅ Aplicado y verificado — Ola 0

| GAP | Qué se hizo | Verificación |
|---|---|---|
| **GAP-80** | `authorize_job_access` devuelve un `JobAccess` explícito (`OwningClient` / `AssignedTechnician` / `BiddableTechnician`) y admite al técnico registrado en una subasta abierta. Antes el 403 impedía abrir la solicitud y el formulario de oferta nunca se renderizaba | `tests/bidding_flow.rs` |
| **GAP-18** | El payload se estrecha según el acceso: `OpenBidJobResponse` sustituye a `JobRequestResponse` para el postor, y el feed usa el mismo tipo. `client_id` y `address` ya no se filtran | Idem, con asserts sobre el JSON crudo |
| **GAP-15** | `advance_progress` exige `TechnicianUser` y el caso de uso rechaza a cualquier otro actor. Se retiró el botón "Actualizar estado" de la pantalla de seguimiento | `a_client_cannot_advance_their_own_job` |
| **GAP-113** | Migración `0011` anula el hash de `password123`; el seed se movió a `seeds/demo.sql` (opt-in, contraseñas `NULL`) más un binario `seed`; guarda de arranque si `APP_ENV=production` | `tests/demo_seed_guard.rs` + smoke test HTTP |
| **GAP-112** | `GOOGLE_CLIENT_IDS` en `render.yaml`; prueba que compara lo que lee el código contra lo declarado | `tests/deploy_manifest.rs`, comprobado quitando la variable |
| **GAP-111** | Google ya no adopta en silencio una cuenta con contraseña propia (`LinkRequiresPassword`, 409). El test que codificaba el comportamiento vulnerable se reescribió | `google_does_not_adopt_an_account_that_has_its_own_password` |
| **GAP-30/62/63** | `head_object` + `read_prefix`; `confirm` verifica existencia, tamaño (≤10 MB) y **magic bytes** antes de cambiar estado | 4 pruebas, incluido el exploit de 6 peticiones |
| **GAP-118** | Argon2 fuera del runtime async + rate limiting en proceso, sin dependencias nuevas | `shared/rate_limit.rs` (7 unitarias) + `repeated_login_attempts_are_rate_limited` |
| **GAP-95** | Precios del seed a soles, alineados con la migración 0007; prueba que ata la etiqueta al desglose | `test/cerca_format_test.dart` |
| **GAP-96** | El progreso de documentos cuenta solo los 3 obligatorios | Idem |

### ✅ Aplicado y verificado — Ola 1, 2 y 3

| GAP | Qué se hizo | Verificación |
|---|---|---|
| **GAP-20/05** | **La puja está gateada por `is_verified`.** Un técnico sin verificar no puede ofertar (403 `TechnicianNotVerified`); leer la subasta sigue permitido, porque el gate va en la acción, no en la lectura | `an_unverified_technician_cannot_bid`, `an_unverified_technician_can_still_see_the_auction` |
| **GAP-19** | **Cancelación real.** `JobStatus::Cancelled` existía desde el principio y ningún caso de uso lo escribía. Ahora `POST /jobs/{id}/cancel`, con quién y por qué (migración `0012`), terminales rechazados y salida del feed | `tests/job_cancellation.rs` (14 pruebas) |
| **GAP-12** | El early-return de idempotencia de `pay_fee` corría **antes** del chequeo de estado, así que `POST /pay` sobre un job gratuito ya cancelado o completado respondía `Ok`. La cancelación lo hizo alcanzable; ahora el chequeo terminal va primero | `a_cancelled_free_job_cannot_be_paid`, `a_completed_free_job_cannot_be_paid`, `paying_a_live_free_job_twice_stays_harmless` |
| **GAP-07** | **Concurrencia optimista** (migración `0013`): columna `version` y el UPDATE condicionado a ella, así el segundo escritor no matchea filas y recibe `ConcurrentModification` (409) en vez de sobrescribir en silencio | `tests/job_concurrency.rs` (7 pruebas) |
| **GAP-02** | **Validación de entrada transversal**: `shared::validation`, `AppError::Validation` → 422 nombrando el campo, y `RequestBodyLimitLayer` de 64 KiB. Cubre registro/login, jobs, ofertas, chat, direcciones, métodos de pago y perfil de técnico | `tests/input_validation.rs` (15 pruebas) |
| **GAP-06** | Techo de precio en ofertas (`i32::MAX` ya no entra) y tope del ETA | `an_absurd_offer_price_is_rejected`, `an_overlong_eta_is_rejected` |
| **GAP-17** | Rating fuera de rango ahora es 422 nombrando el campo, no un error de transición | `an_out_of_range_rating_names_the_field` |
| **GAP-32** | Perfil de técnico validado: `coverage_km` en rango, catálogo canónico de oficios, días de la semana, al menos una categoría | `an_invalid_technician_profile_is_refused` |
| **GAP-64** | `original_filename` acotado a 255 caracteres | Incluido en la validación |
| **GAP-123** | `name` validado en la vía de contraseña (la de Google ya lo hacía) | `a_blank_name_is_refused_at_registration`, `an_accented_name_of_legal_length_is_accepted` |
| **GAP-43** | Un job inexistente en chat o tracking devolvía **403** en vez de 404: el cliente revisaba permisos cuando el problema era un enlace viejo. Variantes `JobNotFound` en ambos dominios | `tests/chat_tracking_http.rs` |
| **GAP-74** | **Chat y tracking no tenían ni una prueba HTTP.** Ahora cubren autorización, 401/403/404, ida y vuelta de un mensaje, y ubicación compartida y leída | `tests/chat_tracking_http.rs` (9 pruebas) |

### Bugs latentes que aparecieron al implementar

Tres cosas que no estaban en el informe y salieron al escribir las pruebas:

- **`save_job_request` nunca persistía `title` ni `address`.** Los escribía el INSERT y ningún
  UPDATE posterior los tocaba, así que cualquier futura edición se habría perdido en silencio.
  Corregido y cubierto por `job_concurrency.rs`.
- **El 403 de `/jobs/{id}/advance` para un cliente** llegaba como error de transición en lugar
  de una negativa clara; ahora el rol lo corta el extractor, antes del caso de uso.
- **`GET /jobs/{id}/messages` con un job inexistente** devolvía 403 en vez de 404 (sigue
  abierto como GAP-43).

### 🔜 Pendiente (siguiente iteración)

- **GAP-14 / GAP-126** — cobro real: puerto `PaymentGateway`, `payment_method` como enum,
  validación PCI, idempotency keys. Es el mayor bloqueante restante y el único de la Ola 1 que
  queda.
- **GAP-05 (segunda mitad)** — filtrar el feed por categoría y cobertura. El gate de
  verificación ya está; falta que el feed sea *pertinente*, lo que requiere una columna
  `category` en `job_requests` que hoy no existe.
- **GAP-09** — la matriz completa actor × endpoint. `bidding_flow.rs` y `job_cancellation.rs`
  cubren subasta y cancelación; faltan `pay`, `rate`, `choose` y chat/tracking.
- **GAP-38** — desacoplar el chat de `fee_paid` (decisión de producto pendiente, §7).
- **GAP-31** — estados `verified`/`rejected`, rol revisor, revocación de la verificación.
- **GAP-25/26/27** — refresh tokens, revocación, validación del secreto.
- **GAP-16** — recalcular el rating del técnico al calificar.
- Olas 3 y 4 restantes según lo descrito abajo.

---

## 0. Resumen ejecutivo

Cerca de Ti tiene un núcleo de dominio **mejor que el promedio** para su etapa: hay puertos y
adaptadores reales, errores tipados, migraciones con constraints, y la máquina de estados del
job ya fue auditada una vez (los tests `business_rules.rs` existen porque un audit previo
encontró un lifecycle "write-forward").

Lo que queda abierto no son detalles: son **agujeros en el modelo de negocio**, no en el código.

| # | Hallazgo | Riesgo |
|---|---|---|
| 1 | **La licitación no funciona en la app.** El técnico ve las solicitudes abiertas pero al abrir una recibe 403 y el formulario de oferta nunca aparece | Crítico — el flujo central está roto |
| 2 | **Cualquiera se verifica como técnico en 6 peticiones sin subir un byte** | Crítico — la insignia "Verificado" es falsificable |
| 3 | **Credenciales por defecto (`password123`) sembradas en todos los entornos, incluida producción** | Crítico — acceso inmediato |
| 4 | **El botón de Google está muerto en producción** (`GOOGLE_CLIENT_IDS` ausente de `render.yaml` → 503) | Crítico — no se puede entrar con Google |
| 5 | **Pre-hijack de cuenta**: el email no se verifica y Google vincula por email ⇒ la víctima hereda la cuenta del atacante | Crítico — toma de cuentas |
| 6 | **El cliente puede finalizar su propio trabajo y calificarse** | Crítico — invalida reseñas y el estado `completed` |
| 7 | **El pago de la comisión no cobra nada** (`pay_fee` solo escribe un booleano) | Crítico — el modelo de ingresos no existe |
| 8 | **Argon2 síncrono en handlers async + sin rate limiting** ⇒ un flood tumba la API entera | Crítico — DoS trivial |
| 9 | **`fee_paid` es la única puerta del chat y del tracking**, y el código se contradice a sí mismo | Crítico — ni el técnico elegido puede escribir antes de que el cliente pague |
| 10 | **Nada valida la entrada**: sin límites de tamaño, sin rangos, sin enums, sin cotas | Alto |
| 11 | **Concurrencia inexistente**: read-modify-write sin locks ni versiones | Alto |
| 12 | **No existe cancelación** aunque `cancelled` esté en el dominio y en el CHECK | Alto |
| 13 | **El frontend y el backend calculan el precio por separado** (y el seed está en pesos chilenos) | Alto |
| 14 | **Sin paginación, sin auditoría, sin pasarela, sin métricas** | Alto |

**Veredicto:** el sistema es un **prototipo funcional con un dominio de juguete en los bordes
monetarios, de confianza y de identidad**. Hay además **dos bugs que rompen el flujo principal
hoy** (`GAP-80` impide ofertar, `GAP-112` impide entrar con Google en producción) y **un
problema de seguridad explotable en producción** (`GAP-113`, credenciales sembradas). No se
puede lanzar a producción con dinero real hasta cerrar la ola 1 completa.

---

## 1. Clasificación de los vacíos

### Ola 0 — Rompe el flujo o expone el sistema HOY (arreglar esta semana)

| GAP | Título | Sev | Archivo clave |
|---|---|---|---|
| GAP-80 | **La licitación no funciona: el técnico recibe 403 al abrir una solicitud abierta** | 🔴 Crítico | `technician_jobs_screen.dart:46`; `technician_job_detail_screen.dart:80`; `job/application/mod.rs:37-50` |
| GAP-113 | **`password123` sembrado en todos los entornos, incluida producción** | 🔴 Crítico | `0002_cerca_features.sql:119-127`; `main.rs:38-41` |
| GAP-112 | **`GOOGLE_CLIENT_IDS` ausente de `render.yaml` ⇒ `/auth/google` = 503 en producción** | 🔴 Crítico | `render.yaml:28-54`; `main.rs:51-56` |
| GAP-111 | **Pre-hijack de cuenta vía vinculación por email de Google** | 🔴 Crítico | `sign_in_with_google.rs:73-78` |
| GAP-118 | **Argon2 síncrono + sin rate limiting ⇒ DoS trivial** | 🔴 Crítico | `login_user.rs:46-49`; `routes.rs:36` |
| GAP-62 | **La URL firmada no limita el tamaño: se puede subir 50 GB** | 🔴 Crítico | `s3_object_storage.rs:71-78,151` |
| GAP-63 | **El `Content-Type` no está en la firma: se declara imagen y se sube HTML** | 🔴 Crítico | `s3_object_storage.rs:71-78` |
| GAP-95 | **Costos de equipo del seed en pesos chilenos** (`S/ 1,265,000.00` frente a `S/ 5,110.00`) | 🔴 Crítico | `cerca_seed_data.dart:63,69,75` |
| GAP-30 | **Auto-verificación sin que exista el objeto en el bucket** | 🔴 Crítico | `upload_document.rs:113-132` |

### Ola 1 — Bloqueantes de producción

| GAP | Título | Sev |
|---|---|---|
| GAP-15 | El cliente puede avanzar y finalizar el job | 🔴 Crítico |
| GAP-14 | No hay pasarela de pago; `pay_fee` no cobra | 🔴 Crítico |
| GAP-38 | Chat/tracking bloqueados por `fee_paid` para el técnico elegido | 🔴 Crítico |
| GAP-19 | No existe cancelación ni expiración de subasta | 🔴 Crítico |
| GAP-20 | Auto-registro libre como `technician` | 🔴 Crítico |
| GAP-28 | Sin rate limiting en toda la API | 🔴 Crítico |
| GAP-114 | Cuentas split-brain en el flujo de Google (sin transacción) | 🟠 Alto |
| GAP-126 | Riesgo PCI: PAN/CVV en texto plano; `pay_fee` ignora los métodos guardados | 🟠 Alto |
| GAP-69 | El bucket privado es un requisito solo documentado | 🟠 Alto |
| GAP-65 | Confirmar y verificar no son atómicos ⇒ técnico atascado sin verificar | 🟠 Alto |
| GAP-66 | Confirmar no es idempotente; el invariante "verificado ⇒ docs subidos" es falso | 🟠 Alto |

### Ola 2 — Integridad y confianza

| GAP | Título | Sev |
|---|---|---|
| GAP-07 | Sin control de concurrencia (lost updates, doble asignación) | 🟠 Alto |
| GAP-05 | Técnicos no verificados / fuera de cobertura pueden pujar | 🟠 Alto |
| GAP-31 | Verificación automática, sin `rejected`, nunca revocada | 🟠 Alto |
| GAP-09 | Faltan pruebas de autorización por propiedad (varios endpoints) | 🟠 Alto |
| GAP-13 | `pay_fee` no exige técnico asignado | 🟠 Alto |
| GAP-16 | El rating no actualiza el rating del técnico | 🟠 Alto |
| GAP-44 | Sin validación de coordenadas (incl. NaN/∞ fuera de la API) | 🟠 Alto |
| GAP-51 | El precio del proyecto se calcula en el cliente | 🟠 Alto |
| GAP-55 | "S/ 4" hardcodeado en el frontend | 🟠 Alto |
| GAP-46 | Ubicación obsoleta se muestra como actual | 🟠 Alto |
| GAP-58 | Operaciones multi-tabla sin transacción | 🟠 Alto |
| GAP-25 | JWT no revocable por 7 días | 🟠 Alto |
| GAP-26 | Takeover de cuenta vía vinculación por email de Google | 🟠 Alto |
| GAP-50 | `formatShortDate` lanza con ISO inválido | 🟠 Alto |
| GAP-11 | `payment_done` nunca se escribe | 🟠 Alto |
| GAP-75 | Un job `project` (`tech_team_id`) no tiene canal de chat ni tracking | 🟡 Medio |
| GAP-74 | Chat y tracking sin una sola prueba HTTP | 🟠 Alto |
| GAP-77 | Guardado concurrente del perfil revierte la verificación | 🟠 Alto |
| GAP-96 | El progreso de documentos divide por 4 (incluye el opcional) | 🟠 Alto |
| GAP-97/98 | `AsyncLoading` sin valor previo y estado clavado tras un fallo | 🟠 Alto |
| GAP-99 | El perfil del proveedor depende del filtro de categoría del Home | 🟠 Alto |
| GAP-115 | El rol de `/me` y el del token pueden divergir | 🟡 Medio |
| GAP-116 | 422 sobrecargado ⇒ el selector de rol entra en bucle | 🟡 Medio |
| GAP-117 | Un 401 de `/auth/google` cierra la sesión de un usuario autenticado | 🟡 Medio |

### Ola 3 — Calidad, contrato y validación

Todo lo demás: `GAP-01/02/03/04/06/08/10/12/17/18/21/22/23/24/27/29/32/33/34/39/40/42/43/45/47/48/49/52/54/56/59/61`
más `GAP-64/67/68/70/72/73/76/78/79/94/100/101/102/103/104/105/106/107/108/109/110/119/120/121/122/123/124/125/127/128/129/130/131/132`.
Ver el catálogo para el detalle y la severidad de cada uno.

### Ola 4 — Escala y observabilidad

| GAP | Título | Sev |
|---|---|---|
| GAP-35 | Sin paginación en ningún listado | 🟢 Bajo |
| GAP-36 | Objetos huérfanos en el bucket | 🟢 Bajo |
| GAP-37 | No hay endpoint de lectura de documentos | 🟢 Bajo |
| GAP-42 | Chat sin paginación | 🟢 Bajo |
| GAP-56 | Sin cabeceras de seguridad | 🟢 Bajo |
| GAP-57 | Sin métricas ni auditoría de negocio | 🟢 Bajo |
| GAP-60 | Cobertura de pruebas del cliente Flutter | 🟢 Bajo |

*(`GAP-41` se descartó: no hay XSS en el cliente actual. `GAP-53` no aplica: no hay matemática
de distancias en el cliente.)*

---

## 1bis. Ola 0 — Detalle de lo que rompe hoy

### GAP-80 · La licitación no funciona en la app 🔴

**Evidencia.** `technician_jobs_screen.dart:46` hace `setJobId(job.id)` sobre un job de
`openForBid` y navega al detalle. `technician_job_detail_screen.dart:80` lee
`activeJobControllerProvider`, que llama `GET /jobs/{id}`
(`active_job_controller.dart:13-17`). El backend pasa por `authorize_job_access`
(`job/application/mod.rs:28-51`), que solo autoriza **al cliente dueño** o **al técnico ya
asignado**. En una subasta `technician_profile_id` es `NULL` y el llamador es un técnico
interesado ⇒ **`Unauthorized` → 403**.

Con `job == null` la pantalla muestra *"No se pudo cargar este trabajo."*
(`technician_job_detail_screen.dart:100-115`) y **la sección "Enviar oferta" de la línea 161
nunca se renderiza**.

**Consecuencia.** El técnico ve la lista de solicitudes abiertas, toca una, y no puede ofertar.
No hay ningún otro camino en la app para enviar una oferta (`POST /jobs/{id}/offers` está
expuesto, pero nada lo llama). **El modo licitación es inoperable de punta a punta.**

**Solución.** La raíz es que un solo DTO/endpoint sirve a dos audiencias con necesidades de
autorización distintas. Separarlas:
1. **Feed de licitación**: `GET /technician/jobs` ya devuelve `open_for_bid`. El técnico debe
   poder abrir el detalle **desde ahí**, sin un segundo fetch autorizado por propiedad.
2. Añadir un endpoint de lectura para postores:
   `GET /jobs/{id}/bid-detail` (o `GET /jobs/{id}` con una regla adicional: *un técnico puede
   leer un job en subasta `pending` y sin asignar*), devolviendo una **proyección sin PII del
   cliente** (`OpenBidJobSummary`: id, título, categoría, presupuesto referencial, `created_at`)
   — nunca `client_id` ni `address` (esto resuelve también GAP-18).
3. Alternativa más simple y sin endpoint nuevo: el detalle del técnico deja de usar
   `activeJobControllerProvider` y lee el job **de la lista que ya tiene en memoria**
   (`technicianJobsControllerProvider`), sin fetch por id.
4. Regla de autorización explícita y probada:
   ```
   leer un job  ← cliente dueño | técnico asignado | técnico con perfil (si bidding + pending + sin asignar)
   mutar un job ← cliente dueño (pay/rate/choose) | técnico asignado (advance/location)
   ```

**Pruebas.** TC-FLT-024, TC-JOB-081, TC-JOB-086 y un test HTTP
`an_eligible_technician_can_read_an_open_bidding_job_but_not_the_clients_address`.

---

### GAP-113 · `password123` en todos los entornos 🔴

**Evidencia.** `0002_cerca_features.sql:119-127` inserta 5 usuarios con el hash documentado como
`password123` (`:119`, y confirmado en `backend/README.md:15-17`), con
`ON CONFLICT (id) DO NOTHING`. `main.rs:38-41` ejecuta las migraciones **en cada arranque**.

**Consecuencia.** `POST /auth/login {"email":"client@cerca.com","password":"password123"}` devuelve
un token válido de 7 días en la base de datos de producción. Lo mismo para los 4 técnicos
sembrados, que además tienen perfiles verificados con ratings de 4.9 y aparecen en `/providers`.

**Solución.**
1. **Sacar el bloque de seed de la migración.** Las migraciones son esquema; los datos de demo
   son otra cosa. Moverlo a `backend/seeds/demo.sql`, ejecutado solo por
   `docker-compose` / un script manual, y **nunca** por `sqlx::migrate!`.
2. Migración `0011` que **borre o desactive** esas cuentas si existen (con guarda de entorno o
   comprobación de que siguen teniendo el hash original), y que fuerce rotación.
3. `main.rs`: además, comprobar `APP_ENV`; si es `production`, **abortar el arranque** si alguna
   fila conserva el hash por defecto. Un failsafe que no depende de que nadie recuerde hacerlo.
4. Documentar el usuario demo en `README.md` como "solo desarrollo local", no como credenciales.

**Pruebas.** Un test que verifique que `sqlx::migrate!` no deja ninguna fila en `users` cuando
parte de una base vacía, y otro que compruebe que el seed es explícito.

---

### GAP-112 · Google muerto en producción 🔴

**Evidencia.** `render.yaml:28-54` declara `DATABASE_URL`, `JWT_SECRET` (generado), `RUST_LOG`,
`CORS_ALLOWED_ORIGINS` y los cinco `S3_*`. **No hay `GOOGLE_CLIENT_IDS`.** Entonces
`config.rs:44-49` devuelve un `Vec` vacío, y `main.rs:51-53` instala
`UnconfiguredIdentityVerifier`, por lo que `verify_google_id_token` siempre devuelve
`ProviderUnavailable` → **503** (`google_identity_verifier.rs:170-175`, `shared/error.rs:78-81`).

**Consecuencia.** El botón "Continuar con Google" (presente en login y registro) falla siempre en
el despliegue declarado. Es la única vía de entrada sin contraseña.

**Solución.** Añadir la variable a `render.yaml` con `sync: false` (se rellena en el panel):
```yaml
- key: GOOGLE_CLIENT_IDS
  sync: false
```
Y un test de humo del despliegue que compruebe que cada variable leída por `AppConfig::from_env`
está declarada en `render.yaml`. La lista de variables está en un solo sitio (`config.rs:27-51`),
así que el test es trivial: parsear `render.yaml`, extraer las claves y compararlas contra
`GOOGLE_CLIENT_IDS`, `S3_*` y `CORS_ALLOWED_ORIGINS`.

---

### GAP-111 · Pre-hijack de cuenta 🔴

**Evidencia.** `sign_in_with_google.rs:73-78`:
```rust
// 2. Same person, signed up with a password earlier.
if let Some(user) = self.repository.find_by_email(&email).await? {
    self.repository.link_identity(IdentityProvider::Google, &identity.subject, user.id).await?;
    return self.session_for(user, false);
}
```
La vinculación se decide **solo por el email** de Google (verificado por Google, correcto) contra
cualquier cuenta local existente. **No existe verificación del email en el registro con
contraseña**: no hay columna `email_verified` en ninguna migración, ni token de verificación, ni
endpoint de confirmación. `register_user.rs:37-60` devuelve sesión utilizable de inmediato.

**Consecuencia.** Un atacante registra `victima@gmail.com` con una contraseña que elige. La
víctima legítima entra con Google y su identidad se vincula **a la cuenta del atacante**. Ambos
tienen acceso; el atacante conserva su contraseña y su token. Todo lo que la víctima haga después
(crear jobs, guardar direcciones, chatear) es legible por el atacante.

**Solución.** Que la propiedad del email sea **precondición** de la vinculación:
1. Añadir `users.email_verified BOOLEAN NOT NULL DEFAULT FALSE`.
2. En `sign_in_with_google.rs`, **no vincular en silencio**:
   - si la cuenta local tiene `email_verified = true` → vincular (la propiedad ya se probó);
   - si la cuenta local se creó con contraseña y no está verificada → devolver un error distinto,
     `AuthError::LinkRequiresVerification` → 409, y pedir que el usuario confirme la contraseña
     en la misma petición antes de vincular.
3. Regla a escribir y documentar: *una identidad nueva nunca hereda una cuenta que tiene
   credencial propia sin una prueba de posesión.*
4. Alternativa más simple y también defendible: no auto-vincular nunca; crear siempre la cuenta
   del proveedor y ofrecer un flujo explícito de "vincular cuentas" desde ajustes.
5. Implementar de paso la verificación de email (GAP-125) — es el requisito previo de (2) en el
   caso "cuenta local verificada".

**Pruebas.** TC-AUTH-036 y TC-040 del catálogo del subagente, más
`google_sign_in_does_not_silently_claim_a_password_account`.

---

### GAP-118 · DoS por Argon2 síncrono sin rate limiting 🔴

**Evidencia.**
- `argon2_password_hasher.rs:11-22` — Argon2id con parámetros por defecto de la crate
  (≈19 MiB, `t=2`), **síncrono**.
- `register_user.rs:49` y `login_user.rs:46-49` lo llaman **directamente desde funciones
  `async`**, sin `spawn_blocking`: cada hash ocupa un worker de Tokio durante decenas de ms.
- `routes.rs:36-47` — solo `TraceLayer` y `CorsLayer`. No hay limitador, y `Cargo.toml` no
  incluye ninguna crate de rate limiting.
- `login_user.rs:32-36` — si el email no existe **no se hashea nada**, así que además de ser un
  oráculo de tiempo (GAP-119), el atacante puede elegir el camino más caro a voluntad.

**Consecuencia.** Unos cientos de `POST /auth/login` concurrentes con una contraseña incorrecta
contra `client@cerca.com` ocupan todos los workers de Tokio, que es compartido: `/health`, y todas
las demás rutas, dejan de responder. Con 1 vCPU de plan gratuito en Render, basta un script.

**Solución.**
1. **Rate limiting en capas** (`tower_governor` o equivalente):
   | Ruta | Límite |
   |---|---|
   | `/auth/login`, `/auth/register`, `/auth/google` | 5–10 / min por IP **y** por email, con backoff progresivo |
   | `/jobs/{id}/location` | 12 / min por job |
   | escrituras (`POST`) | 60 / min por usuario |
   | `/providers` | 60 / min por IP |
2. **Sacar el hashing del runtime async**: `tokio::task::spawn_blocking` alrededor de
   `hasher.hash` y `hasher.verify`, o un pool acotado dedicado. Sin esto, el rate limiting solo
   reduce el daño.
3. **Respuesta de tiempo constante**: hashear contra un hash señuelo cuando el email no existe,
   para eliminar el oráculo de tiempo (GAP-119).
4. Añadir bloqueo progresivo por cuenta tras N fallos, y devolver `429` con `Retry-After`.

**Pruebas.** TC-AUTH-040, TC-034 del catálogo del subagente (`/health` sigue respondiendo bajo
carga) y TC-X-001.

---

### GAP-62 + GAP-63 · La frontera de subida no está firmada 🔴

**Evidencia.** `s3_object_storage.rs:56-78`:
```rust
fn presign(&self, method: &str, key: &str) -> String { /* … */ }

fn presign_put(&self, key: &str, _content_type: &str) -> Result<String, TechnicianError> {
    // `content_type` is deliberately not part of the signature: …
    Ok(self.presign("PUT", key))
}
```
Y `presign_url` (`:136-152`) fija `X-Amz-SignedHeaders=host` y `UNSIGNED-PAYLOAD`.

Es decir: **la URL firmada solo garantiza el método y la ruta**. No incluye
`content-length-range`, ni `Content-Type`, ni `Content-MD5`, ni un checksum del payload.

**Consecuencia.**
1. Pedir la URL para `image/jpeg` y subir **50 GB**: el bucket lo acepta. El tope de 10 MB es
   solo del cliente (`tech_docs_controller.dart:26`).
2. Pedir la URL para `image/jpeg` y subir **HTML o un ejecutable**: el objeto se guarda y la
   columna `content_type` dice `image/jpeg`. Cualquier UI de revisión futura que sirva el objeto
   inline es XSS almacenado.

El comentario del código justifica la omisión de `Content-Type` ("cualquier sufijo charset
convierte la subida en un 403 opaco"). Es un problema real, pero la solución no es quitar la
protección: es **normalizar el valor antes de firmar** y firmar el valor normalizado.

**Solución.**
1. Añadir `head_object(key) -> Option<ObjectMeta { size, etag, content_type }>` al puerto
   `ObjectStorage` (`technician/application/ports.rs:10-17`) e implementar el `HEAD` SigV4.
2. **`ConfirmDocumentUploadUseCase` debe verificar el objeto antes de confirmar**:
   ```rust
   let meta = self.storage.head_object(&doc.storage_key).await?
       .ok_or(TechnicianError::DocumentNotFound)?;
   if meta.size == 0 || meta.size > MAX_DOCUMENT_BYTES { return Err(/* 400 */); }
   if meta.content_type != doc.content_type { return Err(TechnicianError::DocumentContentMismatch); }
   ```
   Esto cierra también **GAP-30** (auto-verificación sin bytes): hoy `confirm` solo comprueba que
   exista una fila con `storage_key IS NOT NULL`, que la escribió el propio `start_document_upload`.
3. **Firmar la restricción de tamaño**: añadir `content-length-range` a la URL prefirmada
   (POST policy) o, si el proveedor no lo soporta, validar el tamaño con el `HEAD` del punto 2 y
   borrar el objeto si excede.
4. **Normalizar y firmar el `Content-Type`**: aceptar `image/jpeg; charset=…` y `IMAGE/JPEG` en la
   validación, normalizar a `image/jpeg`, y firmar ese valor exacto.
5. **Validar magic bytes** en el `HEAD` o descargando los primeros bytes: JPEG `FF D8 FF`,
   PNG `89 50 4E 47`, WebP `RIFF….WEBP`, PDF `%PDF-`. Rechazar discrepancias con 400.
6. Registrar el tamaño real en `technician_documents.byte_size` (migración).

**Pruebas.** TC-TECH-012, 013, 034, 035, 036. El `FakeStorage` de `document_upload.rs:22-32`
debe crecer con `head_object` para poder automatizarlas sin bucket.

---

### GAP-95 · El seed está en pesos chilenos 🔴

**Evidencia.** `lib/features/cerca/application/cerca_seed_data.dart:63,69,75` conserva
`laborCost: 780000`, `materialsCost: 420000`, `mobilityCost: 65000` — los valores **CLP** previos
a la migración `0007_peru_currency_seed_data.sql:13-15`, que los reescribió en soles a
`3150 / 1700 / 260`. El `priceLabel` del mismo objeto sigue diciendo `'Desde $850.000'`
(`:38-84` conserva además `$15.000`, `$32.000`).

**Consecuencia.** Para un mismo equipo, el flujo real (datos del backend) muestra
**"S/ 5,110.00"** y el flujo con datos semilla mostraría **"S/ 1,265,000.00"**, con una
incoherencia interna de escala entre el total y el precio publicado. Un factor de ~250× es
suficiente para que un cliente crea que el precio es absurdo, o peor, acepte un total erróneo.

**Solución.**
1. Borrar o regenerar `cerca_seed_data.dart` con valores en soles, alineados con la migración 0007.
2. **Quitar los precios del cliente por completo**: el total del proyecto debe venir del servidor
   (ver `GAP-51`). Un dato de negocio duplicado en el cliente es exactamente lo que produjo esto.
3. Auditar dónde se usa el seed como fallback y asegurarse de que **nunca** se presenta como un
   precio real (`GAP-54`). Un `priceLabel` sin datos del servidor debe ser un estado vacío, no
   un número inventado.
4. Añadir una prueba de contrato que falle si un literal monetario aparece en `lib/` fuera de un
   formateador.

**Pruebas.** TC-FLT-007, 020, 021.

---

### GAP-30 · Verificación falsificable 🔴

**Evidencia.**
- `technician/application/upload_document.rs:113-132` — `confirm` solo llama a
  `confirm_document_upload` y luego a `refresh_verification`.
- `technician/infrastructure/postgres_technician_repository.rs:296-304` — la única condición es
  `storage_key IS NOT NULL`, y esa columna la escribió `start_document_upload` (`:266`)
  **antes** de que existan bytes. El comentario de `:294-295` afirma que esto es
  "un-fakeable": **no lo es**.
- `upload_document.rs:139-149` — la verificación es automática y **solo suma**: si hay 3 filas
  `uploaded`, `is_verified = true`. No hay revisión humana ni estado `rejected`
  (`technician_document.rs:6-9`, `0002:25`).

**Consecuencia.** Seis peticiones (`upload-url` + `confirm`, por `cedula`, `antecedentes` y
`especialidad`) **sin subir un solo byte** otorgan `is_verified = true`. Esa insignia se muestra
en el feed de ofertas (`JobOfferResponse.verified`) y en el perfil.

**Solución.** El `head_object` de GAP-62/63 cierra el caso "no subí nada". Además:
1. **Separar "subido" de "verificado"**: subir ⇒ `uploaded`/`pending_review`; `is_verified` solo
   lo pone un **revisor** (rol `Admin`, que hoy no existe: `value_objects.rs:40-43`).
2. `refresh_verification` pasa a `recompute_verification` y debe poder **quitar** `is_verified`,
   no solo ponerlo (ver `GAP-31`).
3. Migración con los estados reales: `CHECK (status IN ('pending','uploaded','verified','rejected'))`,
   más `reviewed_by`, `reviewed_at`, `rejection_reason`, `byte_size`.
4. Endpoint de revisión `POST /admin/documents/{id}/review`, y `presign_get` (hoy **código muerto**,
   `ports.rs:16`) para que el revisor pueda ver la evidencia.

**Pruebas.** TC-TECH-012, 013, 014, 015, 053.

---

## 2. Ola 1 — Detalle de los bloqueantes

### GAP-15 · El cliente puede avanzar y finalizar su propio trabajo 🔴

**Evidencia.**
- `backend/src/features/job/application/mod.rs:33` — `authorize_job_access` acepta al cliente:
  `if job.client_id == caller_id { return Ok(()); }`
- `backend/src/features/job/interfaces/http/handlers.rs:74-83` — `advance_progress` toma
  `CurrentUser` (no `TechnicianUser`), así que cualquier rol pasa.
- `lib/features/tracking/presentation/screens/tracking_screen.dart:32-46,53` — la pantalla de
  seguimiento **del cliente** tiene un botón que llama `advance()`.

**Consecuencia.** Un cliente abre el seguimiento y pulsa tres veces: el job pasa a `completed`
sin que el técnico haya salido de casa. Acto seguido puede calificar (`rate` solo exige
`status == completed` y ser el dueño). La reseña es autogenerada.

**Solución.**
1. `AdvanceProgressUseCase` debe exigir que el llamador sea **el técnico asignado**, no el cliente.
   Introducir un parámetro/rol explícito y comparar contra `technician_profile_id`:
   ```rust
   // advance_progress.rs
   let profile = self.technician_repo.find_profile_by_user_id(caller_id).await?
       .ok_or(JobError::Unauthorized)?;
   if job.technician_profile_id != Some(profile.id) {
       return Err(JobError::Unauthorized);
   }
   ```
2. El handler pasa a tomar `TechnicianUser`.
3. `authorize_job_access` se mantiene para las rutas de **lectura**; para escritura se necesitan
   dos funciones: `authorize_client_owns(&job, caller)` y `authorize_assigned_technician(...)`.
4. Retirar el botón de `tracking_screen.dart` (ese botón es el cliente; el avance vive en
   `technician_job_detail_screen.dart`).
5. Regla de negocio a decidir y documentar: **¿el cliente puede confirmar la finalización?**
   Si sí (recomendado: doble confirmación), entonces `completed` requiere *ambas* partes y el
   estado necesita un paso intermedio (`awaiting_client_confirmation`).

**Pruebas.** TC-JOB-064, 065, 067 + nuevo test de regresión
`a_client_cannot_advance_or_complete_a_job`.

---

### GAP-14 · El pago de la comisión no cobra nada 🔴

**Evidencia.** `backend/src/features/job/application/pay_fee.rs:21-36` — el "pago" es
`job.payment_method = Some(input.payment_method); job.pay_fee()?; save_job_request()`. No hay
llamada a ninguna pasarela, ni webhook, ni `payment_done = true`. `payment_method` llega como
string libre desde `PayFeeRequest` (`job/interfaces/http/dto.rs:67`).

**Consecuencia.** El único ingreso del modelo de negocio (`fee_amount_for("bidding") == 4`) es
un booleano local. Cualquiera se autoconcede "pagado".

**Solución.**
1. Definir un puerto nuevo `PaymentGateway` en `job/application/ports.rs`:
   ```rust
   #[async_trait]
   pub trait PaymentGateway: Send + Sync {
       async fn authorize(&self, amount_soles: i32, method: PaymentMethod, idem_key: Uuid)
           -> Result<PaymentAuthorization, PaymentError>;
   }
   ```
2. `PayFeeUseCase` orquesta: valida `PaymentMethod` (enum, no `String`) → **exige que el método
   pertenezca al cliente** (`client_payment_methods.id`, hoy ignorado: GAP-126) → llama al gateway
   → solo si `authorize` devuelve `Captured` escribe `fee_paid = true` y `payment_done = true`,
   guardando `gateway_reference`.
3. Migración `0011_payments.sql`: `payment_method` a enum/CHECK, `payment_done NOT NULL`, nueva
   tabla `job_payments (job_request_id, gateway, reference, amount, status, idempotency_key UNIQUE, created_at)`.
4. Idempotencia real: `idempotency_key` única — resuelve también GAP-07/GAP-58 para el pago.
5. Modo degradado para el piloto: mantener un adaptador `FakePaymentGateway` que solo se active
   con `PAYMENTS_MODE=fake`, y que **registre un warning** en cada cobro simulado. Que sea
   imposible activarlo por accidente en producción (validar contra `APP_ENV=production`).

**Pruebas.** TC-JOB-051, 054, 055, 058, 059, TC-56 del catálogo del subagente de auth.

---

### GAP-38 · `fee_paid` es la única puerta del chat y del tracking 🔴

**Evidencia.**
- `chat/application/send_message.rs:63` — `if !job.fee_paid { return Err(ChatError::FeeNotPaid) }`
- `chat/application/mod.rs:60` — idéntico para leer
- `tracking/application/update_location.rs:54` — idéntico para publicar ubicación
- `backend/tests/business_rules.rs:120-141` — los tests solo cubren jobs **gratuitos**, donde
  `fee_paid` es `true` desde `JobRequest::new` (`job_request.rs:98`). El caso real está sin probar.

**Consecuencia.** En un job `bidding`, cuando el cliente elige al técnico, `fee_paid` sigue en
`false` (solo lo pone `pay_fee`). El técnico elegido ve el job como suyo, puede avanzar el
timeline, pero **no puede escribirle al cliente ni compartir ubicación** hasta que el cliente
pague. Y el propio código dice lo contrario en `business_rules.rs:120`: *"Direct contact is free
at launch. Chat and location must be available immediately without a fake payment step."*

**Hay una contradicción de modelo de negocio sin resolver.** El comentario dice que el contacto
es gratis; el código lo bloquea.

**Solución (recomendada).** Desacoplar "participar en la conversación" de "pagó la comisión":
1. Quitar el chequeo `fee_paid` de `send_message` y de `GetMessagesUseCase`. El contacto directo
   es el producto: cobrarlo dos veces (comisión + bloqueo) es incoherente.
2. Mantener el gate por **participación** — y escribirlo **una sola vez**: hoy la misma lógica
   está duplicada en cuatro sitios (`chat/application/mod.rs:38-56`, `send_message.rs:42-59`,
   `tracking/application/mod.rs:38-56`, `update_location.rs:48-50`). Debe ser una función
   compartida, como ya lo es `job::application::authorize_job_access`.
3. Añadir la dimensión que **falta por completo**: el **estado del job**. Hoy el chat y el
   tracking siguen abiertos en un job `completed` o `cancelled` (`GAP-74`): escribir debería
   requerir `pending`/`active`, leer podría permitir `completed` con una ventana de gracia, y
   `cancelled` debería cerrar.
4. En tracking, reemplazar el gate de tarifa por uno de **estado**: solo se publica ubicación si
   `status == Active`, y se corta al `completed` (resuelve también GAP-47).
5. Si el negocio decide lo contrario (el contacto *sí* se vende), entonces hay que **cobrar antes
   de asignar**, no después: `choose_offer` debe exigir `fee_paid`, y el flujo del cliente pasa a
   ser elegir → pagar → contactar. Cualquiera de las dos es defendible; la actual no lo es.
6. Un job `project` (`tech_team_id`) **no tiene canal en absoluto** (`GAP-75`): la comparación es
   contra `technician_profile_id`, que es `NULL` en proyectos. Hay que decidir quién es el
   participante del lado del equipo y modelarlo.

**Pruebas.** TC-CHAT-003 a 006, TC-CHAT-018, TC-TRK-010, TC-TRK-014.

---

### GAP-19 · No existe cancelación ni expiración 🔴

**Evidencia.**
- `job/domain/job_request.rs:13,22,31` — `JobStatus::Cancelled` existe y se parsea.
- `migrations/0002_cerca_features.sql:77` — el CHECK permite `'cancelled'`.
- **Ningún caso de uso escribe `Cancelled`.** Grep de `cancel` en `backend/src`: cero resultados
  fuera de la definición del enum.

**Consecuencia.** Un cliente que crea una subasta y no le responden no puede cerrarla. Un cliente
que ya no quiere el trabajo del técnico no puede cancelarlo. Un técnico asignado que abandona
deja el job colgado en `active` para siempre. No hay deshacer.

**Solución.**
1. Caso de uso `CancelJobUseCase` con política explícita por estado y actor:
   | Actor | `pending` | `active` | `completed` |
   |---|---|---|---|
   | cliente | sí, libre | sí, con regla de penalidad/reembolso | no |
   | técnico asignado | n/a | sí, deja constancia (abandono) | no |
2. `JobRequest::cancel(&mut self, by: Actor) -> Result<(), JobError>`, con `cancelled_at`,
   `cancelled_by`, `cancellation_reason` en una migración nueva.
3. Endpoint `POST /jobs/{id}/cancel` con `CurrentUser` + verificación de propiedad.
4. **Expiración de subasta**: `expires_at` en `job_requests` para `bidding`, y un job
   `pending` vencido se cancela (job programado o cálculo perezoso al leer). Sin esto, el feed
   `open_for_bid` crece con subastas muertas para siempre.
5. Regla de reembolso: necesita GAP-14 resuelto primero (hoy no hay nada que reembolsar).

**Pruebas.** TC-JOB-090 a 094.

---

### GAP-20 · Auto-registro libre como `technician` 🔴

**Evidencia.** `auth/application/register_user.rs:39` — `Role::parse(&input.role)` acepta
`"technician"` sin ninguna verificación. `Role` (`auth/domain/value_objects.rs:40-43`) es
exactamente `{Client, Technician}`.

**Consecuencia.** Cualquiera se registra como técnico. Y como `submit_offer` solo exige que
exista una fila en `technician_profiles` (`job/application/submit_offer.rs:28-32`), ese recién
llegado **puede pujar de inmediato**, sin documentos, sin verificación y sin cobertura. Combinado
con GAP-30, el flujo de confianza completo es atravesable en minutos.

**Solución.**
1. Decisión de producto: o el técnico se registra igual que el cliente y **la puja queda gated
   por verificación** (recomendado — es menos fricción y GAP-05 lo cubre), o el registro de
   técnico pasa por invitación/aprobación.
2. En cualquier caso, **el gate duro debe estar en la acción de negocio, no en el registro**:
   ```rust
   // submit_offer.rs — después de obtener el profile
   if !profile.is_verified {
       return Err(JobError::TechnicianNotVerified);
   }
   ```
   Un error de dominio nuevo con su mapeo a 403 en `shared/error.rs`.
3. Documentar en `docs/` la regla: "un técnico no verificado no aparece en el feed ni puede pujar".

**Pruebas.** TC-AUTH-002, TC-JOB-028.

---

### GAP-28 · Sin rate limiting 🔴

**Evidencia.** `backend/src/routes.rs:36-47` — solo `TraceLayer` y `CorsLayer`. Grep de
`rate_limit` en `backend/src`: cero resultados.

**Consecuencia.** `POST /auth/register` y `/auth/login` ejecutan Argon2 (deliberadamente caro:
`m=19456, t=2`): un atacante tumba el servidor con unos cientos de requests concurrentes.
`/auth/google` con `kid` falsos fuerza fetches a Google (parcialmente mitigado por
`JWKS_MIN_REFRESH_INTERVAL`, `google_identity_verifier.rs:25`). El chat y el tracking no tienen
límite de frecuencia.

**Solución.** Añadir `tower_governor` (o `axum` + `tower::limit`) con capas diferenciadas:
| Ruta | Límite sugerido |
|---|---|
| `/auth/login`, `/auth/register`, `/auth/google` | 5–10 / min por IP, con backoff progresivo |
| escritura (`POST/PATCH`) | 60 / min por usuario |
| tracking (`POST /location`) | 12 / min por job (ya es 1 cada 10 s desde el cliente) |
| chat | 30 / min por usuario |
| `/providers` | 60 / min por IP |

Además, cerrar la carrera del email único (GAP-23) mapeando la violación de constraint a 409.

**Pruebas.** TC-AUTH-040, TC-CHAT-016, TC-TRK-013, TC-X-001.

---

## 3. Ola 2 — Detalle de los hallazgos altos

### GAP-07 · Concurrencia inexistente 🟠

**Evidencia.** Todos los casos de uso siguen el patrón `find → mutar → save` sin lock ni versión:
`choose_offer.rs:22,54`, `pay_fee.rs:22,34`, `advance_progress.rs:20,29`,
`rate_job.rs:23,34`. `save_job_request` (`postgres_job_repository.rs:156-187`) hace un `UPDATE`
incondicional por `id`.

**Escenarios que se rompen.**
1. Dos `choose_offer` concurrentes sobre ofertas distintas: ambos leen `pending`/sin técnico,
   ambos escriben — gana el último, y **el primer técnico cree que tiene el trabajo**.
2. Cliente pulsa "Pagar" dos veces: dos `pay_fee` concurrentes ⇒ doble cobro cuando exista
   pasarela (GAP-14).
3. `advance_timeline` desde `step=2` dos veces en paralelo ⇒ ambas leen 2, ambas escriben 3;
   se pierde un avance (o con lógica distinta, se salta un estado).

**Solución.**
1. **Bloqueo por fila**: cambiar la lectura a `SELECT ... FOR UPDATE` dentro de una transacción.
   Añadir al puerto `JobRepository`:
   ```rust
   async fn find_job_request_for_update(&self, id: Uuid, tx: &mut Transaction<'_, Postgres>)
       -> Result<Option<JobRequest>, JobError>;
   ```
2. **Versión optimista** como alternativa más simple y suficiente para este volumen: columna
   `version INT NOT NULL DEFAULT 0`, y `UPDATE ... WHERE id = $1 AND version = $n`; si
   `rows_affected() == 0` ⇒ `JobError::ConcurrentModification`.
3. **Constraints como red de seguridad** (el patrón ya usado en 0009): para "como máximo una
   oferta elegida" añadir
   `CREATE UNIQUE INDEX ... ON job_requests (id) WHERE technician_profile_id IS NOT NULL AND status = 'pending'`
   no aplica; en su lugar, exigir en el `UPDATE` de `choose_offer` la condición
   `AND technician_profile_id IS NULL AND status = 'pending'` y comprobar `rows_affected`.
4. **Idempotency keys** en todos los `POST` mutadores no idempotentes (`/pay`, `/offers/choose`,
   `/advance`, `/rate`). Tabla `idempotency_keys (key, user_id, endpoint, response_hash, created_at)`.
   El frontend ya necesita esto: el doble tap está sin proteger (`active_job_controller.dart:25-31`
   no tiene guarda, a diferencia de `tracking_screen.dart:33`).

**Pruebas.** TC-JOB-033, 048, 058, 068, TC-FLT-017, TC-X-005, TC-X-006.

---

### GAP-05 · Puja sin verificación ni cobertura 🟠

**Evidencia.** `job/application/submit_offer.rs:27-53` — las condiciones son: existe perfil,
`price > 0`, `eta` no vacío, `job_kind == "bidding"`, `status == Pending`,
`technician_profile_id.is_none()`. **Nada sobre `is_verified`, `categories`, `coverage_km` ni
`available_days`.** Y `find_open_bidding_jobs` (`postgres_job_repository.rs:277-297`) no filtra
por categoría: todo técnico ve todas las subastas.

**Solución.**
1. Inyectar `TechnicianRepository` (ya está) y aplicar en `submit_offer`:
   ```rust
   if !profile.is_verified { return Err(JobError::TechnicianNotVerified); }
   if !profile.categories.contains(&job.category) { return Err(JobError::OutOfScope); }
   ```
2. **Filtrar el feed**, que es lo que realmente importa para la experiencia: `find_open_bidding_jobs`
   debe cruzar `job_requests.category` con `technician_profiles.categories` y ordenar por
   distancia. Hoy `job_requests` **no tiene columna `category`** — hay que añadirla (migración),
   derivarla de `job_kind` + la selección del cliente, y definir el catálogo canónico de
   categorías en un solo sitio (hoy está duplicado entre `technician_document.rs`, el frontend
   `cerca_seed_data.dart` y la tabla `categories TEXT[]`).
3. `coverage_km` y `available_days` requieren geolocalización real del cliente y del trabajo: hoy
   `distance` es un **string de display** (`'0.5 km'`) y `pin_top`/`pin_left` son **fracciones
   0..1 de layout**, no coordenadas (`0002_cerca_features.sql:10,12,13`). Esto es el GAP-53/GAP-44
   en su raíz: **no hay coordenadas reales en el modelo**. Añadir `lat`/`lng` a
   `technician_profiles`, `client_addresses` y `job_requests`.

**Pruebas.** TC-JOB-028, 029, 085.

---

### GAP-31 · Verificación sin revisión, sin rechazo, sin revocación 🟠

**Evidencia.**
- `0002_cerca_features.sql:25` — `CHECK (status IN ('uploaded', 'pending'))`. **No existe
  `rejected`.**
- `technician/domain/technician_document.rs:6-9` — el enum solo tiene `Uploaded` y `Pending`.
- `technician/domain/errors.rs` declara `InvalidDocumentStatus(_)` — **código muerto**, nunca
  se construye.
- `upload_document.rs:145-149` — `if all_mandatory_uploaded && !profile.is_verified { verified = true }`.
  Nunca hay un camino a `false`.

**Consecuencia.** No existe "revisión". Una cédula ilegible o un PDF de 3 bytes otorgan la
insignia. Y una vez otorgada, **no se puede quitar** aunque el técnico reemplace el documento:
re-subir lo devuelve a `pending` (`postgres_technician_repository.rs:270-275`) pero
`refresh_verification` solo se ejecuta al *confirmar*, así que el técnico queda marcado como
verificado con un documento en estado `pending`.

**Solución.**
1. Migración: `CHECK (status IN ('pending','uploaded','verified','rejected'))`, más
   `reviewed_by UUID`, `reviewed_at TIMESTAMPTZ`, `rejection_reason TEXT`.
2. Separar los dos conceptos en el dominio:
   - `DocStatus`: `Pending` | `Uploaded` | `Verified` | `Rejected` (subida por el técnico/revisor).
   - `TechnicianProfile.verification`: `Unverified` | `InReview` | `Verified` | `Suspended`,
     derivado de los documentos pero **explicitado**, no inferido.
3. `refresh_verification` pasa a ser `recompute_verification`, que puede poner **y quitar**
   `is_verified`, y que se ejecuta también al *iniciar* una re-subida (no solo al confirmar).
   Alternativa mejor: `is_verified` deja de ser una columna escribible por el flujo de uploads y
   pasa a ser un campo mantenido solo por el caso de uso de revisión.
4. Endpoint de administración `POST /admin/documents/{id}/review` con rol nuevo `admin`
   (hoy `Role` solo tiene dos valores, `value_objects.rs:40-43`).

**Pruebas.** TC-TECH-013 a 016, 023.

---

### GAP-09 · Autorización por propiedad sin pruebas 🟠

**Evidencia.** Las verificaciones **existen** en el código (bien), pero **no hay un solo test**
que las ejerza:
- `choose_offer.rs:27-29` — `if job.client_id != input.client_id { Unauthorized }`
- `pay_fee.rs:27-29` — idéntico
- `rate_job.rs:28-30` — idéntico
- `job/application/mod.rs:28-51` — `authorize_job_access` para lectura

`role_authorization.rs` cubre **rol**, y su propio comentario lo dice (líneas 3-6). Los tests de
`job_lifecycle.rs` y `business_rules.rs` siempre usan al dueño legítimo. **Nadie prueba el caso
negativo.**

**Solución.** Es la brecha de mayor retorno por esfuerzo del informe: escribir un archivo
`backend/tests/ownership_authorization.rs` con una matriz actor × endpoint y un helper que
devuelva el status HTTP. Cubre TC-JOB-043, 044, 053, 074, 081, 084 y TC-CLI-005, TC-CHAT-008.

```rust
// Matriz objetivo (actor × acción) — cada celda debe ser 403
//                     | get job | offers | choose | pay | rate | advance | messages | location
// tercero (client)    |   403   |  403   |  403   | 403 | 403  |   403   |   403    |   403
// técnico ajeno       |   403   |  403   |   n/a   | n/a | n/a  |   403   |   403    |   403
// técnico no asignado |   403   |  403   |   n/a   | n/a | n/a  |   403   |   403    |   403
```

Un bug de autorización que no se prueba es un bug de autorización que vuelve en el próximo refactor.
De hecho ya pasó una vez: `job/application/mod.rs:26` documenta que `Get`/`GetJobOffers`/
`AdvanceProgress` *"previously had no authorization check at all"*.

---

### GAP-13, GAP-11, GAP-12, GAP-03 · La máquina de estados del job tiene huecos 🟠

**GAP-13** — `pay_fee` no verifica que haya técnico asignado:
`pay_fee.rs:21-36` solo comprueba propiedad y `status == Pending`. Un job `bidding` **sin
`choose_offer`** se puede activar y completar con `technician_profile_id = NULL`. Luego
`find_open_bidding_jobs` lo excluye (status ya no es `pending`) pero nadie lo trabaja.

**GAP-11** — `payment_done` es un campo muerto: `JobRequest::new` lo pone en `false`
(`job_request.rs:100`), `save_job_request` lo escribe (`postgres_job_repository.rs:164,178`) y
**ningún caso de uso lo cambia a `true`**. Aparece en la respuesta HTTP
(`job/interfaces/http/dto.rs:20`) así que la app podría estar mostrando un estado falso.

**GAP-12** — el early-return de idempotencia (`job_request.rs:120-122`) ocurre **antes** del
chequeo de estado, así que un job con `fee_paid = true` en estado inválido pasa silenciosamente.
Hoy es inalcanzable por el flujo normal, pero es una bomba de relojería en cuanto se añada
cancelación (GAP-19).

**GAP-03** — `fee_amount_for` (`job_request.rs:45-50`) tiene `_ => 0`, es decir **cualquier
`fee_type` desconocido convierte el job en gratuito**. El CHECK de la BD lo protege hoy, pero
la función es la fuente de verdad de precios: debe ser `Result` o `unreachable!()`.

**Solución — un solo cambio coherente.** Introducir un tipo `JobKind` real (enum) en vez de
`String`, con un `match` exhaustivo que haga imposibles estos cuatro casos a la vez:

```rust
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum JobKind { Direct, Bidding, Project }

impl JobKind {
    pub fn fee_amount(self) -> i32 { match self { Self::Bidding => 4, _ => 0 } }
    pub fn parse(raw: &str) -> Result<Self, JobError> { /* … */ }
    pub fn requires_assignment(self) -> bool { matches!(self, Self::Direct) }
}
```

Migrar `job_kind: String` → `JobKind` en `JobRequest`, `CreateJobInput` y los DTOs. Un `match`
exhaustivo sobre un enum convierte GAP-03, GAP-04 y GAP-13 en errores de compilación en vez de
errores de runtime. Es el refactor de mayor valor estructural del plan.

**Pruebas.** TC-JOB-012, 055, 056, 057.

---

### GAP-16 · El rating no tiene consecuencia 🟠

**Evidencia.** `rate_job.rs:32` graba `job_requests.rating` y `comment`.
**Nada más.** `technician_profiles.rating` y `reviews` (`0002_cerca_features.sql:8-9`) nunca se
recalculan desde el flujo de negocio: solo el seed data los pone. Y el frontend los **muestra
como si fueran reales** (`technician_profile_screen.dart`, `JobOfferResponse.rating`).

**Consecuencia.** Un técnico con 1 estrella sigue mostrando 4.9. La calificación es decorativa.

**Solución.**
1. Al calificar, recalcular en la misma transacción:
   ```sql
   UPDATE technician_profiles
   SET rating = (SELECT AVG(rating) FROM job_requests
                 WHERE technician_profile_id = $1 AND rating IS NOT NULL),
       reviews = (SELECT COUNT(*) FROM job_requests
                  WHERE technician_profile_id = $1 AND rating IS NOT NULL)
   WHERE id = $1;
   ```
2. Decidir la política de redondeo y de "sin reseñas" (`rating` por defecto 5.0 para un técnico
   nuevo es engañoso: debería ser `NULL` y mostrarse como "Nuevo").
3. Definir qué hace el rating: ¿desempata en el feed? ¿bloquea a técnicos bajo 3.0? Sin una
   consecuencia, el incentivo no existe. Y bloquear exige la lógica de suspensión de GAP-31.

**Pruebas.** TC-JOB-075, 078.

---

### GAP-44, GAP-45, GAP-46 · El tracking no es tracking 🟠

**Evidencia.**
- `tracking/domain/location.rs:12-21` — `TechnicianLocation::new` acepta cualquier `f64`. **Sin
  validación de rango, sin rechazo de `NaN`/`Infinity`.**
- `0002_cerca_features.sql:109` — `job_request_id UUID PRIMARY KEY`: **una fila por job**, no hay
  historial (confirmado también por el comentario en `0009_offer_constraints_and_indexes.sql:75`).
- `tracking/interfaces/http/dto.rs:26-29` — `latitude: f64` deserializa `NaN` vía JSON no
  estándar; el frontend (`tracking_screen.dart`) pinta lo que llegue.
- No hay campo de expiración: `updated_at` existe pero nada lo compara contra `now()`.

**Solución.**
1. Value object validado en el dominio:
   ```rust
   impl TechnicianLocation {
       pub fn new(job: Uuid, lat: f64, lng: f64) -> Result<Self, TrackingError> {
           if !lat.is_finite() || !lng.is_finite() { return Err(TrackingError::InvalidCoordinates); }
           if !(-90.0..=90.0).contains(&lat) || !(-180.0..=180.0).contains(&lng) {
               return Err(TrackingError::InvalidCoordinates);
           }
           if lat == 0.0 && lng == 0.0 { return Err(TrackingError::InvalidCoordinates); }
           Ok(/* … */)
       }
   }
   ```
   Con `CHECK (latitude BETWEEN -90 AND 90)` y `CHECK (latitude <> 0 OR longitude <> 0)` en la BD,
   siguiendo el patrón de defensa en profundidad de la migración 0009.
2. Si se quiere historial: cambiar el PK a `(job_request_id, recorded_at)` con una tabla
   `tracking_location_history` y **política de retención explícita** (borrar a los N días de
   completar el job). Hoy los datos de ubicación de un técnico se guardan indefinidamente sin
   base de consentimiento ni borrado — es un problema legal, no solo técnico.
3. Frescura: en el DTO y en el cliente, marcar como obsoleta (o no mostrar) una ubicación con
   `updated_at` mayor a ~2 minutos.

**Pruebas.** TC-TRK-005 a 009, 012.

---

### GAP-25, GAP-26, GAP-27 · Sesiones y vinculación de identidades 🟠

**GAP-25** — `jwt_token_service.rs:34-45`: el token es `{sub, role, exp}` firmado HS256, 7 días,
**sin `iat`, sin `jti`, sin revocación**. No hay endpoint de logout. Un usuario borrado o con rol
cambiado sigue operando con su token viejo (el rol viaja en el token, `middleware.rs:43`).

**GAP-26** — `sign_in_with_google.rs:73-78`: si el email de Google (verificado por Google)
coincide con una cuenta que ya existe con contraseña, la identidad **se vincula automáticamente**.
Un atacante que registre con contraseña `victima@gmail.com` (que no controla) crea una cuenta; la
víctima legítima entra con Google y hereda la cuenta del atacante — incluidos sus jobs.

**GAP-27** — `config.rs:31-32`: `JWT_SECRET` solo se exige presente; `change-me-to-a-long-random-string`
pasa el arranque. `.env.example:2` lo sugiere literalmente.

**Solución.**
1. **Refresh tokens con rotación + access tokens cortos** (15 min). Tabla `refresh_tokens`
   (`jti UNIQUE`, `user_id`, `expires_at`, `revoked_at`, `replaced_by`), y `POST /auth/logout`
   que revoca. Añadir `jti` y `iat` al access token.
2. **Endurecer la vinculación**: solo auto-vincular si la cuenta existente **no tiene contraseña**
   (es decir, ya nació de un proveedor). Si tiene contraseña, exigir que el usuario la confirme
   antes de vincular, o enviar un correo de confirmación. Regla: *una identidad nueva nunca
   hereda silenciosamente una cuenta con credencial propia*.
3. **Validar el secreto al arrancar**: en `AppConfig::from_env`, rechazar secretos < 32 bytes o
   que contengan `change-me`, y fallar el arranque salvo `APP_ENV=development`.
4. Añadir un rol `Admin` (`value_objects.rs:40-43`) — hoy no existe, y sin él no hay revisión de
   documentos (GAP-31) ni operación posible.

**Pruebas.** TC-AUTH-023 a 027, 036, 039.

---

### GAP-51, GAP-55, GAP-54 · El frontend y el backend calculan lo mismo por separado 🟠

**Evidencia.**
- `lib/features/job_request/presentation/agreed_price_label.dart:15-21` y
  `lib/features/job_request/presentation/screens/project_quote_screen.dart:80-81` y
  `lib/features/cerca/application/cerca_controller.dart:140-146`: el total del proyecto
  (`laborCost + materialsCost + mobilityCost`) **se calcula en tres lugares del cliente**. El
  backend guarda `mobility_included` (`0005_job_pricing.sql`) pero **nunca guarda ni devuelve el
  total**. Cualquier cambio de precio de un equipo altera jobs históricos ya acordados.
- `job_rating_screen.dart:111`, `bidding_screen.dart:142`, `cerca_seed_data.dart:116`: **"S/ 4"
  hardcodeado en tres lugares**. El backend tiene `fee_amount`
  (`job_request.rs:45-50`) y la app **sí** lo deserializa (`job_request.g.dart:18`) y lo usa en
  `app_fee_screen.dart:54` — pero solo con fallback a un valor local: `?? fee.amount`.
- `cerca_seed_data.dart:63-75` conserva los **precios en pesos chilenos** (`laborCost: 780000`)
  que la migración 0007 corrigió a soles (`3150`). Si el fallback de datos semilla se activa,
  la app muestra precios ~250× mayores.

**Solución.**
1. El backend devuelve el precio acordado **resuelto**, no los insumos para calcularlo:
   añadir `agreed_price` también para `project` (hoy es `NULL` por decisión explícita de
   `0006_job_agreed_price.sql`), calculado en el servidor al crear el job y congelado en la fila.
2. Eliminar el cálculo de precio del cliente: `agreed_price_label` solo lee `job.agreedPrice`.
3. Sustituir todos los literales `"S/ 4"` por interpolación de `feeAmount`.
4. Borrar o regenerar `cerca_seed_data.dart` con valores en soles, y **auditar dónde se usa como
   fallback**: mostrar datos de demo como si fueran reales es peor que mostrar un error.
5. Añadir una prueba de contrato (GAP-59): un test que compare los campos que el cliente
   deserializa contra el JSON real del servidor. Con `freezed` + `json_serializable` ya hay
   esquema; una prueba dorada en `backend/tests/` que fije el JSON de `JobRequestResponse` lo
   convierte en contrato verificable.

**Pruebas.** TC-FLT-007, 020, 021.

---

### GAP-50 · `formatShortDate` lanza con entrada inválida 🟠

**Evidencia.** `lib/features/cerca/application/cerca_format.dart:23-26`:
```dart
final date = DateTime.parse(isoTimestamp).toLocal();
return '${date.day} ${_shortMonths[date.month - 1]}';
```
`DateTime.parse` lanza `FormatException` con ISO inválido o vacío. El `created_at` viene de
`j.created_at.to_rfc3339()` (`dto.rs:51`), que es válido — pero cualquier dato cacheado,
un campo nulo del backend, o un cambio de formato rompe el renderizado con una excepción no
capturada.

**Solución.** Devolver un valor seguro (`'—'` o `'Fecha desconocida'`) en vez de lanzar, y
añadir pruebas unitarias. `formatSoles` (`cerca_format.dart:5-14`) está bien resuelto y sirve de
modelo: es puro y no lanza.

**Pruebas.** TC-FLT-005, 006.

---

### GAP-02, GAP-40, GAP-32, GAP-06 · No hay validación de entrada en ningún sitio 🟡→🟠

**Evidencia.** Ningún campo de texto tiene límite. Ninguna estructura `Deserialize` usa
`#[serde(deny_unknown_fields)]` ni validadores. Y no hay `RequestBodyLimitLayer` en
`routes.rs:36`. Ejemplos concretos: `CreateJobRequest.title/address` (`dto.rs:61-62`),
`SendMessageRequest.text` (`chat/interfaces/http/dto.rs:34`), `SubmitOfferRequest.eta`
(`dto.rs:111`), `RateJobRequest.comment` (`dto.rs:74`), `add_address.label/detail`
(`client/.../dto.rs`), y `SaveTechnicianProfileInput` completo (`save_profile.rs:7-14`), donde
`coverage_km`, `available_days`, `categories` y `pin_top`/`pin_left` entran **sin una sola
comprobación**.

**Consecuencia.** Un `POST /jobs` con 100 MB de `title` agota memoria. Un `coverage_km = -5`
o `categories = []` corrompe el feed. Un mensaje vacío llena el chat de ruido.

**Solución.**
1. **Una capa de validación transversal**, no chequeos dispersos: usar `validator` (derive) sobre
   los DTOs, o un extractor `ValidatedJson<T>` que corra las reglas antes del handler. Reglas:
   | Campo | Regla |
   |---|---|
   | `title`, `label` | 1..=120 |
   | `address`, `detail` | 1..=300 |
   | `comment` | 0..=1000 |
   | `text` (chat) | 1..=2000, no solo espacios |
   | `eta` | 1..=60 |
   | `name` | 1..=120 |
   | `oficio` | 1..=80 |
   | `coverage_km` | 1..=500 |
   | `pin_top`/`pin_left` | 0.0..=1.0 (y renombrar: son layout, no coordenadas) |
   | `available_days` | subconjunto de `['lun',…,'dom']`, no vacío |
   | `categories` | subconjunto del catálogo canónico, no vacío |
   | `price` | 1..=1_000_000 soles |
2. `tower_http::limit::RequestBodyLimitLayer::new(64 * 1024)` global, con un límite propio para
   los endpoints de documentos (que son URLs, no bytes).
3. `deny_unknown_fields` en los DTOs de entrada: hoy un typo (`{"job_kid":"direct"}`) se ignora
   silenciosamente, lo que hace que los bugs del cliente parezcan bugs del servidor.
4. Errores de validación **tipados y por campo**: `AppError::Validation(Vec<FieldError>)` → 422
   con el campo y el motivo. Hoy todo cae en `InvalidStatusTransition` → 400 con un mensaje
   genérico (GAP-17).

**Pruebas.** TC-JOB-010, 031, 076, TC-AUTH-012, TC-TECH-018 a 024, TC-CHAT-009, 010, TC-CLI-003, 004, TC-X-014.

---

### GAP-01, GAP-23, GAP-61 · Errores de base de datos que se convierten en 500 🟡

**GAP-01** — `CreateJobUseCase` (`create_job.rs:25-57`) nunca comprueba que
`technician_profile_id` o `tech_team_id` existan. El INSERT falla por FK
(`postgres_job_repository.rs:131` → `JobError::Repository`) → mapeado a
`INTERNAL_SERVER_ERROR` (`shared/error.rs:124-127`). El cliente recibe un 500 por un 400/404.

**GAP-23** — `register_user.rs:45-52`: `find_by_email` y luego `insert`. Dos registros
concurrentes con el mismo email ⇒ uno viola `users_email_key` ⇒ 500 en vez de 409.

**GAP-61** — `0009_offer_constraints_and_indexes.sql:27-33` hace `ALTER TABLE ... ADD CONSTRAINT`
sin `IF NOT EXISTS` (que Postgres no soporta para constraints), así que re-ejecutar la migración
falla. `sqlx::migrate!` no re-ejecuta migraciones aplicadas, pero un entorno recreado a mano sí.

**Solución.**
1. **Enrutar los errores de SQL por código**: en los adaptadores Postgres, inspeccionar
   `sqlx::Error::Database(db_err)` y mapear:
   | SQLSTATE | Constraint | Error de dominio | HTTP |
   |---|---|---|---|
   | `23505` | `users_email_key` | `AuthError::EmailAlreadyExists` | 409 |
   | `23505` | `job_offers_one_bid_per_technician` | `JobError::OfferAlreadySubmitted` | 409 |
   | `23503` | cualquier FK | `*Error::NotFound` | 404 |
   | `23514` | cualquier CHECK | `*Error::InvalidInput` | 400 |
   Esto convierte la capa de persistencia en la red de seguridad que la migración 0009 quiso ser.
2. **Validar antes de insertar** en `create_job`: cargar el perfil/equipo y devolver 404 con
   mensaje claro. Defensa en profundidad: ambos.
3. **Migración idempotente**: envolver los `ALTER TABLE` de 0009 en `DO $$ BEGIN ... EXCEPTION
   WHEN duplicate_object THEN NULL; END $$;` y hacer lo mismo en 0006/0008/0010 (0003, 0005, 0008
   ya usan `IF NOT EXISTS`).
4. `JobError::Repository(String)` colapsa toda la información del error en un `String` — eso es
   lo que hace imposible mapear. Cambiar a `Repository(#[source] sqlx::Error)` o añadir una
   variante tipada.

**Pruebas.** TC-JOB-006, 007, TC-AUTH-013, TC-X-015.

---

### GAP-34, GAP-18, GAP-43, GAP-49 · Fugas de información 🟡

**GAP-34** — `/providers` es **público** (`role_authorization.rs:178-182` lo afirma
explícitamente) y devuelve `TechnicianProfile`, que incluye `user_id`. Con ese UUID, cualquiera
correlaciona identidades entre endpoints.

**GAP-18** — `find_open_bidding_jobs` devuelve `JobRequest` completo
(`postgres_job_repository.rs:277-297`), y `TechnicianJobsResponse` lo serializa con
`JobRequestResponse` (`dto.rs:120-123`), que incluye **`client_id` y `address`**
(`dto.rs:10,25`). Un técnico que ni ha pujado ve la dirección del cliente.

**GAP-43** — `SendMessageUseCase` (`send_message.rs:39`) devuelve `ChatError::Unauthorized`
cuando el job **no existe**: 403 en vez de 404, lo que filtra si un UUID existe.

**GAP-49** — `client_payment_methods.detail` es `TEXT` (`0002_cerca_features.sql:67`) y el seed
guarda `'Visa · vence 08/28'`. Si algún día se guarda un PAN, es PCI no conforme. Y no hay
cifrado ni borrado al eliminar la cuenta (que tampoco existe).

**Solución.**
1. **DTOs de proyección**: nunca serializar la entidad de dominio como respuesta pública. Crear
   `PublicTechnicianProfile` (sin `user_id`) para `/providers`, y `OpenBidJobSummary` (sin
   `client_id`, sin `address`, con categoría, título y presupuesto referencial) para `open_for_bid`.
2. **404 vs 403 coherente**: evaluar existencia primero; si no existe ⇒ 404; si existe pero no
   autorizado ⇒ 403. `GetJobRequestUseCase` ya lo hace bien (`mod.rs:64-68`) — replicar el patrón
   en chat y tracking.
3. **Nunca almacenar datos de tarjeta**: guardar solo un token de pasarela. Con GAP-14 resuelto,
   `client_payment_methods` debe pasar a `(provider, token, brand, last4, exp)` y el `detail`
   descriptivo derivarse, no persistirse.

**Pruebas.** TC-TECH-027, TC-JOB-086, TC-CHAT-014, TC-CLI-009.

---

## 4. Ola 4 — Escala y operación

| GAP | Acción | Esfuerzo |
|---|---|---|
| GAP-35 | Paginación cursor-based (`?limit=&cursor=`) en `open_for_bid`, `client/history`, `providers`, `messages` | S |
| GAP-42 | Igual para `chat_messages` (hoy devuelve el hilo entero) | S |
| GAP-36 | Job de reconciliación: listar objetos del bucket sin fila y filas `pending` > 24 h; borrar/alertar | M |
| GAP-37 | Endpoint de lectura con `presign_get` para el revisor (necesario para GAP-31) | S |
| GAP-53 | Validar el divisor antes de calcular distancia; hoy `distance` es un string y `pin_*` es layout | S |
| GAP-56 | HSTS, `X-Content-Type-Options`, `Referrer-Policy`; TLS solo en el proxy | S |
| GAP-57 | Métricas de negocio: jobs creados, tasa de puja, conversión de pago, jobs completados, cancelados. Log de auditoría para `pay`/`choose`/`cancel`/`review` | M |
| GAP-60 | Elevar la cobertura del cliente: `cerca_format`, `agreed_price_label`, `pollWithBackoff`, `LocationSharingController` (tienen lógica pura y son testeables sin UI) | M |

**GAP-59 (pruebas de contrato)** merece un párrafo propio: es la única mitigación estructural
contra la clase de bug que representan GAP-51/GAP-55. Con `freezed`/`json_serializable` en el
cliente y `serde` en el servidor, hay **dos definiciones independientes del mismo contrato** y
nada las compara. Opciones, en orden de coste:
1. Pruebas doradas del JSON del servidor en `backend/tests/` + un test de parseo en Dart con el
   mismo JSON literal. Barato, ya viable.
2. Generar los modelos Dart desde el OpenAPI del servidor (`utoipa` + `openapi-generator`).
   Correcto, más trabajo.
3. Cliente HTTP tipado compartido. Correcto, mayor reescritura.

Recomendado: (1) ahora, (2) cuando el contrato se estabilice.

---

## 5. Plan de ejecución

### Sprint 0 — Semana de contención (solo Ola 0)

Objetivo: que el producto **funcione** y que el sistema **no esté expuesto**. Son cambios
pequeños y localizados, pero cada uno es un bloqueante real.

1. **GAP-80** — el técnico puede ofertar. Sin esto la licitación no existe.
2. **GAP-113** — sacar el seed de `0002` a un script explícito, migración que limpia las cuentas
   por defecto, y failsafe de arranque en producción.
3. **GAP-112** — `GOOGLE_CLIENT_IDS` en `render.yaml` + test de humo de variables de entorno.
4. **GAP-111** — no auto-vincular por email sin prueba de posesión.
5. **GAP-118** — rate limiting en `/auth/*` + `spawn_blocking` para Argon2.
6. **GAP-62/63** — `head_object` + verificación del objeto en `confirm`; normalizar y firmar el
   `Content-Type`; validar magic bytes y tamaño.
7. **GAP-95** — borrar los precios en CLP del seed.
8. **GAP-30** — separar "subido" de "verificado" (requiere rol `Admin`; ver Sprint 2).

**Salida:** el flujo principal funciona, no hay credenciales conocidas, no hay auto-verificación,
y la API resiste un flood básico.

### Sprint 1 — Red de seguridad + cerrar el dinero

1. `backend/tests/ownership_authorization.rs` — la matriz actor × endpoint (GAP-09). **Es el
   mayor retorno por hora de todo el informe.**
2. `backend/tests/auth_http.rs` y `backend/tests/client_account.rs` — hoy **ningún test HTTP llama
   a `/auth/register`, `/auth/login` ni `/auth/google`**, y no hay una sola prueba de los casos de
   uso de `client` (GAP-132 en adelante). Un `tests/chat_tracking_http.rs` para GAP-74.
3. **GAP-15** — el cliente no puede avanzar/finalizar.
4. **GAP-38** — quitar el gate `fee_paid` del chat; unificar la autorización (hoy duplicada en
   cuatro sitios) y añadir el estado del job al gate.
5. **GAP-20 + GAP-05** — gate de verificación en `submit_offer`, filtrado del feed y coherencia
   oficio↔categoría.
6. **GAP-14** — puerto `PaymentGateway` con adaptador fake explícito, bloqueado en producción.
7. **GAP-126** — no almacenar PAN/CVV; `pay_fee` exige un método de pago del propio cliente.
8. **GAP-19** — cancelación y expiración de subasta.

**Salida:** el modelo de negocio es coherente y no trivialmente falsificable, y hay red de
pruebas sobre autorización y autenticación.

### Sprint 2 — Integridad

**GAP-07** (versiones optimistas + `rows_affected` + idempotency keys),
**GAP-13/11/12/03** (enum `JobKind` y un `match` exhaustivo),
**GAP-16** (recalcular rating del técnico), **GAP-31** (estados de revisión, rol `Admin`),
**GAP-44/45/46** (coordenadas reales, validación, retención),
**GAP-25/26/27** (refresh tokens, vinculación segura, validar secreto),
**GAP-114** (transacción en create+link), **GAP-115/116/117** (rol en el token, código de error en
el sobre, no cerrar sesión en el 401 de Google), **GAP-65/66/67/77** (atomicidad y estados de la
verificación), **GAP-119 a 125** (email, contraseña, nombre, single-flight de JWKS, verificación
de email).

### Sprint 3 — Contrato y borde

**GAP-02** (validación transversal + límite de body), **GAP-01/23/61** (mapeo de SQLSTATE +
migraciones idempotentes), **GAP-51/55/54** (precio en el servidor, quitar literales),
**GAP-34/18/43/49** (DTOs de proyección, 404 vs 403), **GAP-50**, **GAP-96 a 110** (robustez del
cliente: `AsyncLoading` con previous, `AsyncValue.guard`, perfil sin filtro, arranque, historial,
parseo tolerante, deep link a pago, pines reales).

### Sprint 4 — Escala

Paginación, reconciliación de objetos, métricas, auditoría, cabeceras de seguridad.

---

## 6. Pruebas concretas a escribir (priorizadas)

Las de mayor valor, en orden. Todas son ejecutables con la infraestructura actual
(`#[sqlx::test]` + `app_router` + `oneshot`).

| # | Prueba | Cubre |
|---|---|---|
| 1 | `an_eligible_technician_can_open_an_open_bidding_job` | **GAP-80** |
| 2 | `the_seed_migration_leaves_no_users_behind` | **GAP-113** |
| 3 | `every_env_var_read_by_config_is_declared_in_render_yaml` | **GAP-112** |
| 4 | `google_sign_in_does_not_silently_claim_a_password_account` | **GAP-111**, GAP-26 |
| 5 | `login_is_rate_limited_and_does_not_stall_health` | **GAP-118**, GAP-28 |
| 6 | `a_document_cannot_be_confirmed_if_the_object_was_never_uploaded` | **GAP-30**, GAP-62 |
| 7 | `an_oversized_or_mistyped_document_upload_is_rejected` | **GAP-62**, GAP-63 |
| 8 | `an_unrelated_client_cannot_pay_rate_or_choose_on_someone_elses_job` | GAP-09 |
| 9 | `a_client_cannot_advance_or_complete_a_job` | GAP-15 |
| 10 | `a_bidding_job_cannot_be_paid_before_a_technician_is_chosen` | GAP-13 |
| 11 | `an_unverified_technician_cannot_bid` | GAP-05, GAP-20 |
| 12 | `the_chosen_technician_can_message_the_client_before_the_fee_is_paid` | GAP-38 |
| 13 | `concurrent_offer_selections_assign_exactly_one_technician` | GAP-07 |
| 14 | `an_unknown_technician_profile_id_is_a_404_not_a_500` | GAP-01 |
| 15 | `a_duplicate_email_race_answers_409` | GAP-23 |
| 16 | `invalid_coordinates_are_rejected` (incl. NaN, ±∞, 0,0, 91, -181) | GAP-44 |
| 17 | `re_uploading_a_document_clears_verification` | GAP-31, GAP-66 |
| 18 | `rating_a_job_updates_the_technicians_average` | GAP-16 |
| 19 | `empty_and_oversized_text_fields_are_rejected` | GAP-02, GAP-40 |
| 20 | `chat_is_read_only_after_the_job_completes` | GAP-74 |
| 21 | `the_open_bid_feed_never_leaks_the_clients_address` | GAP-18 |
| 22 | `a_cancelled_job_cannot_be_paid_advanced_or_rated` | GAP-19 |
| 23 | `an_expired_or_revoked_token_is_rejected` | GAP-25 |
| 24 | `concurrent_google_sign_ins_create_exactly_one_account` | GAP-114 |
| 25 | `a_payment_method_cannot_store_a_full_card_number` | GAP-126 |
| 26 | `formatShortDate_never_throws` | GAP-50 |
| 27 | `project_price_comes_from_the_server` | GAP-51, GAP-95 |
| 28 | `an_invalid_fee_type_is_impossible_by_construction` | GAP-03 |

Las 28 usan los patrones que ya existen en el repositorio (`Ctx` en `business_rules.rs`,
`status_of` en `role_authorization.rs`): no hace falta infraestructura nueva, salvo dos
**seams de test** que hoy faltan:

- `GoogleIdentityVerifier` **no es testeable sin red**: `GOOGLE_CERTS_URL` es una `const` y el
  `reqwest::Client` se construye dentro de `new` (`google_identity_verifier.rs:14,59`). Hay que
  inyectar el fetcher de JWKS para poder probar `aud`/`iss`/`kid`/rotación (TC-46 a TC-48).
- `FakeStorage` (`document_upload.rs:22-32`) debe crecer con `head_object` y `delete_object` para
  poder imponer los nuevos invariantes sin bucket.

Además, tres notas operativas:
1. **La suite de integración no corre hoy**: los tests abortan con `PoolTimedOut` porque no hay
   Postgres levantado. Hay que dejarla verde en CI antes de que sirva como red de seguridad —
   `backend/docker-compose.yml` ya declara el servicio.
2. Los helpers (`create_user`, `create_technician_profile`) están **copiados en los 4 archivos de
   test**; extraerlos a `backend/tests/common/mod.rs` antes de añadir más.
3. Las pruebas que documentan comportamiento **incorrecto** deben ir marcadas `#[ignore]` con el
   GAP en el nombre, para que el arreglo las des-ignore y quede claro qué se estaba tolerando.

---

## 7. Decisiones de producto pendientes (bloquean diseño)

Estos puntos **no se pueden resolver en código**: requieren una decisión explícita, porque cada
opción implica un modelo distinto.

| # | Pregunta | Por qué bloquea | GAP |
|---|---|---|---|
| 1 | ¿El contacto con el técnico es gratis o se vende? | `business_rules.rs:120` dice gratis; `send_message.rs:63` lo bloquea | GAP-38 |
| 2 | ¿El cliente confirma la finalización, o solo el técnico? | Define si hace falta un estado intermedio | GAP-15 |
| 3 | ¿Cómo se cobra la comisión de S/ 4? ¿Qué pasarela? | Sin esto, `pay_fee` es un booleano | GAP-14 |
| 4 | ¿"Verificado" significa "subió documentos" o "un humano los revisó"? | Define si hace falta rol admin y cola de revisión | GAP-30, GAP-31 |
| 5 | ¿Se puede cancelar un job `active`? ¿Con penalidad? | Define el modelo de reembolso | GAP-19 |
| 6 | ¿Qué pasa si nadie puja una subasta? ¿Expira? ¿Se republica? | Define la expiración | GAP-19 |
| 7 | ¿El rating tiene consecuencias (suspensión, orden)? | Sin consecuencia, el incentivo no existe | GAP-16 |
| 8 | ¿Las tarifas 2990/4990 CLP → S/ 4 son definitivas? | `job_request.rs:42-44` marca la conversión como placeholder | — |
| 9 | ¿Se permite que un técnico actualice su oferta? | `0009:19-23` sugiere que sí ("keep the most recent bid"), el código lo prohíbe | GAP-08 |
| 10 | ¿Cuánto tiempo se retiene la ubicación de un técnico? | Requisito legal, no técnico | GAP-45 |
| 11 | ¿Un técnico puede chatear con el cliente **mientras puja** (antes de ser elegido)? | Hoy no (`chat/application/mod.rs:41`); decide si la subasta es a ciegas | GAP-39 |
| 12 | ¿El registro de técnico requiere aprobación previa, o basta con gatear la puja? | Cambia el onboarding y el modelo de confianza | GAP-20 |
| 13 | ¿Se exige verificación de email para registrarse con contraseña? | Es el requisito previo para cerrar el pre-hijack de forma limpia | GAP-111, GAP-125 |
| 14 | ¿Los jobs `project` tienen chat con el equipo? ¿Quién es el participante? | Hoy es estructuralmente imposible | GAP-75 |
| 15 | ¿Quién es el "dueño" del dato de ubicación y por cuánto se borra? | Consentimiento y retención | GAP-45, GAP-69 |

---

## 8. Lo que ya está bien (no tocar)

Para que el plan no se lea como una demolición:

- **La arquitectura hexagonal es real, no decorativa.** Los puertos (`JobRepository`,
  `TechnicianRepository`, `ObjectStorage`, `IdentityVerifier`, `TokenService`) permiten testear
  los casos de uso contra Postgres efímero y falsificar S3 — eso es lo que hace que este informe
  sea posible.
- **La máquina de estados del job fue auditada antes y el arreglo quedó bien hecho.**
  `business_rules.rs` documenta el *por qué* de cada regla ("otherwise one technician can flood
  the client's bidding screen"), no solo el qué. Ese estándar de comentario es infrecuente.
- **Defensa en profundidad en la subasta.** `0009_offer_constraints_and_indexes.sql` replica en
  la BD las reglas de `submit_offer.rs`, y lo dice explícitamente: *"so a missed check in a use
  case cannot corrupt the data"*. Es el patrón correcto; el plan lo extiende al resto.
- **Manejo de errores tipado y bien mapeado.** `shared/error.rs` es la única capa que conoce los
  status codes, y distingue 401 de 403 de 402 de 422 con justificación escrita. El 402 del fee es
  una decisión de diseño defendible, no un accidente.
- **El cliente Flutter maneja la sesión con criterio.** `session_expiry_test.dart` prueba que un
  503 no cierra la sesión y que un 401 sin token tampoco: son los dos casos que la mayoría de
  apps se saltan.
- **`pollWithBackoff`** (`lib/core/network/polling.dart`) distingue errores transitorios de
  definitivos con backoff creciente y un techo. Está mejor pensado que la media y tiene un
  comentario que explica el bug que lo motivó.

**Conclusión.** El problema no es la calidad del código: es que **el modelo de negocio se
detuvo a medio construir**. Existen las transiciones de estado pero no la cancelación; existe el
`fee_amount` pero no el cobro; existe `is_verified` pero no la verificación; existe `cancelled`
pero nadie cancela; existe el feed de subastas pero el técnico no puede abrir una. Cerrar la ola 0
hace que el producto **funcione**; cerrar las olas 1 y 2 lo convierte en un producto operable.

Un último dato que conviene tener presente: **el 100 % de los hallazgos de este informe salió de
leer el código, no de ejecutarlo**, porque la suite de integración no corre en este entorno
(`PoolTimedOut`: no hay Postgres levantado). Eso significa que hay dos tareas previas a cualquier
otra: **dejar la suite verde en CI** y **escribir los tests de los bordes que hoy nadie prueba**.
Sin esas dos cosas, cada refactor de este plan vuelve a introducir los mismos huecos — que es
exactamente lo que ya pasó una vez, como documenta `job/application/mod.rs:26`.
