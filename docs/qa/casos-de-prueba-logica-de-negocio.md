# Casos de prueba — Lógica de negocio (Cerca de Ti)

Auditoría de la lógica de negocio del backend Rust (`backend/src`) y del cliente Flutter
(`lib/`), con el catálogo de casos de prueba necesario para cubrirla.

- **Fecha:** 2026-02-19
- **Alcance:** reglas de negocio, invariantes, máquinas de estado, validaciones, autorización
  por rol y por propiedad, y contrato cliente/servidor.
- **Fuera de alcance:** pruebas de UI pixel-perfect, infraestructura (Postgres/S3 reales),
  rendimiento y carga.
- **Método:** lectura completa del código, en cuatro pasadas independientes por feature (auth,
  technician, chat/tracking, cliente Flutter) más la del núcleo de `job`.
  ⚠️ **La suite de integración no se pudo ejecutar** en este entorno (`PoolTimedOut`: no hay
  Postgres levantado), así que **ningún hallazgo está confirmado por ejecución**. Los repro son
  concretos y ejecutables en cuanto haya base de datos — ver §5 del plan de solución.

## Cómo leer este documento

Cada caso tiene un ID (`TC-<área>-<n>`), y una columna **Estado**:

| Estado | Significado |
|---|---|
| ✅ CUBIERTO | Ya existe una prueba que lo verifica (se cita el nombre). |
| ⚠️ PARCIAL | Existe una prueba cercana, pero no cubre el caso exacto. |
| ❌ FALTA | No existe ninguna prueba. |
| 🔴 BUG | El caso **falla hoy**: es un defecto, no solo un hueco de cobertura. |

Los IDs de defecto (`GAP-<n>`) se detallan en
[`plan-de-solucion-vacios.md`](./plan-de-solucion-vacios.md).

---

## 1. Inventario de la lógica de negocio

### 1.1 Backend — puertos y adaptadores (hexagonal)

| Capa | Módulo | Reglas que concentra |
|---|---|---|
| `auth` | `domain/value_objects.rs` | `Email::parse`, `Role::parse` |
| | `application/register_user.rs` | password ≥ 8, email único |
| | `application/sign_in_with_google.rs` | vincular identidad, `email_verified`, `RoleRequired` |
| | `infrastructure/jwt_token_service.rs` | HS256, `exp` a 7 días |
| | `infrastructure/google_identity_verifier.rs` | JWKS cache, `aud`, `iss`, TTL |
| | `interfaces/http/middleware.rs` | `CurrentUser` / `ClientUser` / `TechnicianUser` |
| `job` | `domain/job_request.rs` | **tarifario** (`fee_amount_for`), `pay_fee`, `advance_timeline`, `rate` |
| | `application/create_job.rs` | compatibilidad `job_kind` ↔ asignación |
| | `application/submit_offer.rs` | solo subasta abierta, precio > 0, ETA no vacío, un bid por técnico |
| | `application/choose_offer.rs` | propiedad, una sola elección, oferta del mismo job |
| | `application/pay_fee.rs` | propiedad, idempotencia |
| | `application/advance_progress.rs` | `authorize_job_access` |
| | `application/rate_job.rs` | propiedad, 1..5, única |
| | `application/mod.rs` | `authorize_job_access`, historial, inbox |
| `technician` | `domain/technician_document.rs` | `DOCUMENT_KEYS`, `MANDATORY_DOCUMENT_KEYS`, `DocStatus` |
| | `application/upload_document.rs` | content-type permitido, extensión derivada, verificación automática |
| | `application/save_profile.rs` | (sin validaciones) |
| | `infrastructure/s3_object_storage.rs` | firma de URLs, expiración |
| `client` | `application/*` | direcciones y métodos de pago |
| `chat` | `application/send_message.rs`, `application/mod.rs` | participantes, `fee_paid` |
| `tracking` | `application/update_location.rs` | técnico asignado, `fee_paid` |

### 1.2 Máquina de estados del job (la pieza central)

```
                    create_job
   direct/project ─────────────► ACTIVE  (fee_paid = true, step 0)
                                   │
                                   │ advance_timeline ×3
                                   ▼
                               COMPLETED ──► rate (1..5, una vez)

   create_job
   bidding ─────────► PENDING (fee_paid = false, step 0)
                        │  ▲
        submit_offer ───┘  │  (mientras pending y sin técnico)
                        │
      choose_offer ─────┘  (fija technician_profile_id + agreed_price)
                        │
      pay_fee ──────────► ACTIVE (fee_paid = true, step 0) ──► COMPLETED
                                                            (vía advance_timeline)

   CANCELLED: definido en el dominio y permitido por el CHECK de la BD,
              pero NINGÚN caso de uso escribe este estado.
```

**Transiciones legales:** `pending→active`, `active→completed`, `active→active` (step++).
**Transiciones prohibidas:** cualquier cosa desde `completed` o `cancelled`; `active→pending`;
re-elección de oferta; doble rating.

---

## 2. Casos de prueba — `job` (núcleo del negocio)

### 2.1 Tarifario y creación

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-JOB-001 | `direct` es gratis | `job_kind=direct`, `technician_profile_id=Some(1)` | `fee_amount=0`, `fee_paid=true`, `status=active` | ✅ `only_bidding_has_the_four_sol_fee` |
| TC-JOB-002 | `project` es gratis | `job_kind=project`, `tech_team_id=Some(1)` | `fee_amount=0`, `fee_paid=true`, `status=active` | ✅ `only_bidding_has_the_four_sol_fee` |
| TC-JOB-003 | `bidding` cuesta S/ 4 | `job_kind=bidding` | `fee_amount=4`, `fee_paid=false`, `status=pending` | ✅ `only_bidding_has_the_four_sol_fee` |
| TC-JOB-004 | `job_kind` inválido | `job_kind="freebie"` | `InvalidStatusTransition` → 400 | ✅ `creating_a_job_rejects_incompatible_provider_assignments` (parcial) |
| TC-JOB-005 | Asignaciones incompatibles | (`direct`,None), (`bidding`,Some), (`bidding`,team), (`project`,Some) | rechazado → 400 | ✅ `creating_a_job_rejects_incompatible_provider_assignments` |
| TC-JOB-006 | **`technician_profile_id` inexistente** | `direct` con id `999999` | 400/404 limpio, **no** FK 500 | ❌ FALTA 🔴 **GAP-01** |
| TC-JOB-007 | **`tech_team_id` inexistente** | `project` con id `999999` | 400/404 limpio | ❌ FALTA 🔴 **GAP-01** |
| TC-JOB-008 | `mobility_included` por defecto | omitido | `true` | ✅ `creating_a_job_computes_the_fee_server_side` |
| TC-JOB-009 | `mobility_included=false` persiste | `false` | `false` en BD | ⚠️ PARCIAL (se prueba el default) |
| TC-JOB-010 | `title`/`address` enormes | 1 MB de texto | rechazado o truncado | ❌ FALTA **GAP-02** |
| TC-JOB-011 | `fee_type` ≠ `job_kind` | — | imposible: se copia `job_kind` | ✅ por construcción |
| TC-JOB-012 | **`fee_amount_for` con `fee_type` desconocido** | `fee_type="banana"` | hoy devuelve `0` ⇒ **job gratis** | ❌ FALTA 🔴 **GAP-03** |

### 2.2 Subasta (bidding)

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-JOB-020 | Bid feliz | técnico con perfil, precio 80 | oferta creada, 201 | ✅ `choosing_an_offer_assigns_...` |
| TC-JOB-021 | Doble bid del mismo técnico | 2º POST | `OfferAlreadySubmitted` → 409 | ✅ `a_technician_cannot_bid_twice_on_the_same_job` |
| TC-JOB-022 | Bid sobre `direct` | job directo | `InvalidStatusTransition` → 400 | ✅ `offers_are_rejected_on_the_wrong_kind_of_job_and_at_impossible_prices` |
| TC-JOB-023 | Precio 0 / negativo | `price ∈ {0,-50}` | `InvalidOffer` → 400 | ✅ idem |
| TC-JOB-024 | ETA vacío / solo espacios | `"   "` | `InvalidOffer` → 400 | ✅ idem |
| TC-JOB-025 | Bid sin perfil de técnico | usuario rol technician sin `technician_profiles` | `Unauthorized` → 403 | ❌ FALTA **GAP-04** |
| TC-JOB-026 | Bid sobre job ya asignado | tras `choose_offer` | `InvalidStatusTransition` → 400 | ✅ `bidding_closes_once_the_job_has_its_technician` |
| TC-JOB-027 | Bid sobre job `active`/`completed` | tras `pay_fee` | 400 | ⚠️ PARCIAL (solo se cubre "ya asignado") |
| TC-JOB-028 | **Técnico NO verificado puede pujar** | `is_verified=false` | hoy **sí puede** | ❌ FALTA 🔴 **GAP-05** |
| TC-JOB-029 | **Técnico fuera de cobertura/categoría** | `categories=['jardineria']` pujando gasfitería | hoy **sí puede** | ❌ FALTA 🔴 **GAP-05** |
| TC-JOB-030 | Precio `i32::MAX` | `price=2147483647` | aceptado (sin techo superior) o rechazado por regla | ❌ FALTA **GAP-06** |
| TC-JOB-031 | ETA de 1 MB | `eta` gigante | rechazado | ❌ FALTA **GAP-02** |
| TC-JOB-032 | Bid sobre job inexistente | UUID aleatorio | `JobNotFound` → 404 | ❌ FALTA |
| TC-JOB-033 | Dos `submit_offer` concurrentes del mismo técnico | paralelo | exactamente 1 oferta (constraint 0009) | ❌ FALTA **GAP-07** |
| TC-JOB-034 | **Re-bid / actualizar oferta** | 2º POST con otro precio | hoy 409; decisión de producto pendiente | ❌ FALTA **GAP-08** |

### 2.3 Elección de oferta

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-JOB-040 | Elección feliz | `offer_id` válido | `technician_profile_id` y `agreed_price` grabados | ✅ `choosing_an_offer_assigns_the_technician_and_records_the_price` |
| TC-JOB-041 | Elegir dos veces | 2ª elección | `InvalidStatusTransition` → 400 | ✅ `an_offer_cannot_be_chosen_twice_or_after_the_job_started` |
| TC-JOB-042 | Elegir tras `pay_fee` | job activo | 400 | ✅ idem |
| TC-JOB-043 | **Otro cliente elige mi oferta** | `client_id` ajeno | `Unauthorized` → 403 | ❌ FALTA **GAP-09** |
| TC-JOB-044 | **Oferta de OTRO job** | `offer_id` de un job distinto | `InvalidStatusTransition` → 400 | ❌ FALTA **GAP-09** |
| TC-JOB-045 | `offer_id` inexistente | `999999` | `OfferNotFound` → 404 | ❌ FALTA |
| TC-JOB-046 | Job inexistente | UUID aleatorio | `JobNotFound` → 404 | ❌ FALTA |
| TC-JOB-047 | **Elegir en subasta con 0 ofertas** | `offer_id` inventado | 404 (se cumple por `find_offer_by_id`) | ⚠️ PARCIAL |
| TC-JOB-048 | **Dos elecciones concurrentes** | paralelo | una gana, la otra 400 | ❌ FALTA 🔴 **GAP-07** |

### 2.4 Pago de la comisión

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-JOB-050 | Pago activa el job | `pay` en `pending` | `fee_paid=true`, `status=active`, `step=0` | ✅ `paying_the_fee_activates_the_job_and_advancing_completes_it` |
| TC-JOB-051 | Pago idempotente | 2º `pay` | no-op, **no** resucita un job completado | ✅ `paying_twice_is_harmless_and_never_resurrects_a_finished_job` |
| TC-JOB-052 | Pago de job gratis | `direct` (ya `fee_paid`) | no-op, sigue `active` | ✅ `free_job_payment_retry_is_harmless` (unitario) |
| TC-JOB-053 | **Otro cliente paga mi job** | `client_id` ajeno | `Unauthorized` → 403 | ❌ FALTA **GAP-09** |
| TC-JOB-054 | **`payment_method` arbitrario** | `payment_method="banana"` | hoy **se acepta y persiste** | ❌ FALTA 🔴 **GAP-10** |
| TC-JOB-055 | **`payment_done` nunca pasa a `true`** | cualquier pago | sigue `false` para siempre | ❌ FALTA 🔴 **GAP-11** |
| TC-JOB-056 | **Pago en job `completed`/`cancelled` con `fee_paid=false`** | estado inconsistente | debería 400, pero el early-return no lo ve | ❌ FALTA **GAP-12** |
| TC-JOB-057 | **`pay_fee` no exige técnico asignado** | `bidding` sin `choose_offer` | hoy activa el job sin técnico | ❌ FALTA 🔴 **GAP-13** |
| TC-JOB-058 | Pago concurrente (doble tap) | paralelo | un solo efecto | ❌ FALTA **GAP-07** |
| TC-JOB-059 | **No hay pasarela real** | cualquier pago | dinero nunca cobrado de verdad | ❌ FALTA 🔴 **GAP-14** |

### 2.5 Avance de timeline y finalización

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-JOB-060 | Avance 0→1→2→3 | 3 llamadas | `step` 1,2,3; al 3 `status=completed` | ✅ `paying_the_fee_activates_the_job_and_advancing_completes_it` |
| TC-JOB-061 | Avance tras completar | 4ª llamada | `InvalidStatusTransition` → 400 | ✅ `timeline_cannot_advance_after_completion` (unitario) |
| TC-JOB-062 | Técnico ajeno no avanza | otro perfil | error | ✅ `a_technician_not_assigned_to_a_job_cannot_advance_it` |
| TC-JOB-063 | Avance sobre `pending` | job sin pagar | 400 | ❌ FALTA |
| TC-JOB-064 | **El CLIENTE puede avanzar y finalizar su propio job** | `POST /jobs/{id}/advance` con token de cliente | hoy **sí** (200) | ❌ FALTA 🔴 **GAP-15** |
| TC-JOB-065 | **El cliente puede auto-finalizar sin que el técnico llegue** | cliente avanza 3 veces | `completed` falso | ❌ FALTA 🔴 **GAP-15** |
| TC-JOB-066 | Salto de paso (no existe endpoint) | — | no aplica | n/a |
| TC-JOB-067 | **El cliente puede calificar un job que él mismo finalizó** | avance ×3 + `rate` | hoy 200 | ❌ FALTA 🔴 **GAP-15** |
| TC-JOB-068 | Avance concurrente ×2 desde `step=2` | paralelo | `step=3` una sola vez | ❌ FALTA **GAP-07** |

### 2.6 Calificación

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-JOB-070 | Rating válido 1..5 | `rating=5` | `rating=5`, `comment` grabado | ⚠️ PARCIAL (unitario `rating_rejects_boundaries_and_duplicate_submissions`) |
| TC-JOB-071 | Rating 0 y 6 | `{0,6}` | error | ✅ `rating_rejects_boundaries_and_duplicate_submissions` |
| TC-JOB-072 | Rating duplicado | 2º POST | error | ✅ idem |
| TC-JOB-073 | Rating en job no completado | `pending`/`active` | error | ❌ FALTA |
| TC-JOB-074 | **Otro cliente califica mi job** | `client_id` ajeno | 403 | ❌ FALTA **GAP-09** |
| TC-JOB-075 | **Nada actualiza el rating del técnico** | tras calificar | `technician_profiles.rating`/`reviews` sin cambio | ❌ FALTA 🔴 **GAP-16** |
| TC-JOB-076 | `comment` de 1 MB | texto gigante | rechazado | ❌ FALTA **GAP-02** |
| TC-JOB-077 | **Error equivocado para rating inválido** | `rating=9` | devuelve `InvalidStatusTransition` (400) en vez de un error de validación | ❌ FALTA **GAP-17** |
| TC-JOB-078 | **El rating no tiene efecto en el negocio** | — | no afecta orden, visibilidad ni subastas | ❌ FALTA 🔴 **GAP-16** |

### 2.7 Autorización sobre jobs y listados

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-JOB-080 | Cliente lee su job | dueño | 200 | ⚠️ PARCIAL |
| TC-JOB-081 | **Tercero lee un job ajeno** | UUID de otro | `Unauthorized` → 403 | ❌ FALTA **GAP-09** |
| TC-JOB-082 | Técnico asignado lee el job | asignado | 200 | ❌ FALTA |
| TC-JOB-083 | **Job inexistente en `GET /jobs/{id}`** | UUID aleatorio | 404 | ❌ FALTA |
| TC-JOB-084 | **Ofertas de un job ajeno** | otro cliente | 403 | ❌ FALTA **GAP-09** |
| TC-JOB-085 | **El feed `open_for_bid` filtra las ofertas propias** | técnico que ya pujó | el job no aparece | ❌ FALTA |
| TC-JOB-086 | **`open_for_bid` expone `client_id` y `address`** | cualquier técnico | filtra datos del cliente | ❌ FALTA 🔴 **GAP-18** |
| TC-JOB-087 | Historial del cliente ordenado desc | varios jobs | orden correcto | ❌ FALTA |
| TC-JOB-088 | **Historial incluye jobs `cancelled`** | con cancelación | aparece | ❌ FALTA (no hay cancelación, **GAP-19**) |
| TC-JOB-089 | Inbox del técnico sin perfil | rol technician, sin perfil | 403 | ✅ `the_right_role_is_not_rejected` (implícito) |

### 2.8 Cancelación (**funcionalidad ausente**)

| ID | Caso | Resultado esperado | Estado |
|---|---|---|---|
| TC-JOB-090 | Cliente cancela un `pending` | `cancelled`, comisión no cobrada | ❌ FALTA 🔴 **GAP-19** |
| TC-JOB-091 | Cliente cancela un `active` | política (reembolso/penalidad) | ❌ FALTA 🔴 **GAP-19** |
| TC-JOB-092 | Cancelar un job ya `completed` | 400 | ❌ FALTA 🔴 **GAP-19** |
| TC-JOB-093 | Técnico abandona el job | estado/reasignación | ❌ FALTA 🔴 **GAP-19** |
| TC-JOB-094 | Job sin técnico que responda (expirado) | auto-cancelar / republicar | ❌ FALTA **GAP-19** |

---

## 3. Casos de prueba — `auth`

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-AUTH-001 | Registro feliz de cliente | email/nombre/pass/rol | 201 + token | ⚠️ PARCIAL |
| TC-AUTH-002 | **Auto-registro como `technician`** | `role=technician` | hoy **permitido sin verificación** | ❌ FALTA 🔴 **GAP-20** |
| TC-AUTH-003 | **Auto-registro como `admin`/otro** | `role=admin` | `InvalidRole` → 400 | ✅ por `Role::parse` |
| TC-AUTH-004 | Password de 7 caracteres | `"1234567"` | `WeakPassword` → 400 | ❌ FALTA |
| TC-AUTH-005 | Password de 8 caracteres | `"12345678"` | aceptado (límite exacto) | ❌ FALTA |
| TC-AUTH-006 | **Password de 8 bytes pero < 8 caracteres** | `"contraseña"`-style multibyte | `.len()` es bytes ⇒ pasa | ❌ FALTA 🔴 **GAP-21** |
| TC-AUTH-007 | Email inválido | `"a@b"`, `"@x.com"`, `"x@"`, `"ab"` | `InvalidEmail` → 400 | ⚠️ PARCIAL |
| TC-AUTH-008 | **Email con mayúsculas** | `"ANA@TEST.LOCAL"` | se normaliza a minúsculas | ⚠️ PARCIAL (código sí, test no) |
| TC-AUTH-009 | **Email duplicado con distinto case** | `"ana@x.com"` vs `"ANA@X.COM"` | 409 `EmailAlreadyExists` | ❌ FALTA |
| TC-AUTH-010 | **Email con espacios** | `"  ana@x.com  "` | se recorta | ⚠️ PARCIAL |
| TC-AUTH-011 | **Email Unicode homográfico** | `"аnа@x.com"` (cirílico) | colisión de identidad | ❌ FALTA 🔴 **GAP-22** |
| TC-AUTH-012 | **Nombre vacío / gigante** | `name=""`, 1 MB | sin validación | ❌ FALTA **GAP-02** |
| TC-AUTH-013 | **Carrera en email único** | 2 registros concurrentes | 1 debe dar 409, hoy 500 | ❌ FALTA 🔴 **GAP-23** |
| TC-AUTH-014 | Login feliz | credenciales válidas | 200 + token | ⚠️ PARCIAL |
| TC-AUTH-015 | Login con password malo | — | `InvalidCredentials` → 401 | ❌ FALTA |
| TC-AUTH-016 | **Login con email inexistente** | — | 401 y **mismo tiempo de respuesta** (anti-enumeración) | ❌ FALTA **GAP-24** |
| TC-AUTH-017 | **Login de cuenta solo-Google con password** | `password_hash IS NULL` | `PasswordLoginUnavailable` → 409 | ❌ FALTA |
| TC-AUTH-018 | **`/me` devuelve el usuario** | token válido | 200 con role | ⚠️ PARCIAL |
| TC-AUTH-019 | Token sin `Bearer` | `Authorization: token` | 401 | ❌ FALTA |
| TC-AUTH-020 | Token expirado | `exp` pasado | 401 | ❌ FALTA |
| TC-AUTH-021 | Token firmado con otro secreto | HS256 ajeno | 401 | ❌ FALTA |
| TC-AUTH-022 | Token con `alg=none` / RS256 | — | 401 (HS256 obligatorio) | ❌ FALTA |
| TC-AUTH-023 | **Token de usuario borrado** | `sub` inexistente | hoy **sigue siendo válido** 7 días | ❌ FALTA 🔴 **GAP-25** |
| TC-AUTH-024 | **Token tras cambio de rol** | rol en BD ≠ rol en token | sigue el del token | ❌ FALTA 🔴 **GAP-25** |
| TC-AUTH-025 | **No hay logout ni revocación** | — | imposible invalidar | ❌ FALTA 🔴 **GAP-25** |
| TC-AUTH-026 | **Google: `email_verified=false`** | token de Google | `ProviderEmailUnverified` → 403 | ❌ FALTA |
| TC-AUTH-027 | **Google: sin claim `email`** | — | 403 (mismo camino) | ❌ FALTA |
| TC-AUTH-028 | **Google: `aud` de otra app** | token de otro proyecto | `InvalidProviderToken` → 401 | ❌ FALTA |
| TC-AUTH-029 | **Google: `iss` inválido** | — | 401 | ❌ FALTA |
| TC-AUTH-030 | **Google: `kid` desconocido → refetch** | rotación de claves | refetch y éxito | ❌ FALTA |
| TC-AUTH-031 | **Google: flood de `kid` falsos** | muchos tokens | refetch limitado a 1/min | ❌ FALTA |
| TC-AUTH-032 | Google: primera vez sin `role` | `role=None` | `RoleRequired` → 422 | ❌ FALTA |
| TC-AUTH-033 | Google: misma cuenta 2ª vez | mismo `sub` | 200, **no** crea duplicado | ❌ FALTA |
| TC-AUTH-034 | Google: email ya registrado con password | — | vincula identidad, no duplica | ❌ FALTA |
| TC-AUTH-035 | **Google: mismo email, `sub` distinto** | — | vinculación por email | ❌ FALTA |
| TC-AUTH-036 | **Google: takeover de cuenta pre-registrada** | atacante registra `victima@gmail.com` con password; víctima entra con Google | la víctima **hereda** la cuenta del atacante | ❌ FALTA 🔴 **GAP-26** |
| TC-AUTH-037 | **Google: sin nombre** | `name=None` | usa la parte local del email | ❌ FALTA |
| TC-AUTH-038 | **Google: no configurado** | `GOOGLE_CLIENT_IDS` vacío | 503 | ❌ FALTA |
| TC-AUTH-039 | **JWT_SECRET débil** | `"change-me..."` | debe fallar al arrancar, hoy no | ❌ FALTA 🔴 **GAP-27** |
| TC-AUTH-040 | **Sin rate limiting en login** | 10.000 intentos | bloqueo/backoff | ❌ FALTA 🔴 **GAP-28** |
| TC-AUTH-041 | **Timing attack en comparación** | — | Argon2 verify de tiempo constante | ⚠️ PARCIAL (Argon2 lo hace) |
| TC-AUTH-042 | Rol en ruta incorrecta | cliente en `/technician/*` | 403 | ✅ `a_client_cannot_reach_technician_only_routes` |
| TC-AUTH-043 | Rutas anónimas | sin token | 401 (no 403) | ✅ `protected_routes_still_reject_anonymous_callers` |
| TC-AUTH-044 | `/providers` público | sin token | 200 | ✅ `the_providers_listing_stays_public` |
| TC-AUTH-045 | **Email con múltiples `@`** | `"a@b.c@d"` | debe rechazarse; hoy **se acepta** | ❌ FALTA 🔴 **GAP-121** |
| TC-AUTH-046 | **Email con dominio vacío** | `"a@b."`, `"a@.com"`, `"a@."` | debe rechazarse; hoy se acepta | ❌ FALTA 🔴 **GAP-121** |
| TC-AUTH-047 | **Email con espacio o salto de línea** | `"a b@c.com"`, `"a\n@b.com"` | debe rechazarse; hoy se acepta | ❌ FALTA 🔴 **GAP-121** |
| TC-AUTH-048 | **Email con NUL embebido** | `"a\u0000@b.com"` | 400; hoy **500** (Postgres rechaza `0x00`) | ❌ FALTA 🔴 **GAP-121** |
| TC-AUTH-049 | **Email de 2 MB** | cadena enorme | debe rechazarse | ❌ FALTA **GAP-121** |
| TC-AUTH-050 | **Nombre vacío o solo espacios** | `""`, `"   "` | debe rechazarse; hoy se acepta | ❌ FALTA **GAP-123** |
| TC-AUTH-051 | **Fila heredada con email inválido** | `email='admin@localhost'` | `/login` y `/me` deben dar 401; hoy **400** | ❌ FALTA **GAP-130** |
| TC-AUTH-052 | **Cuerpo faltante o mal tipado** | `{"email":"a@b.com"}` | debe devolver `{"error":…}` JSON, no texto plano | ❌ FALTA **GAP-129** |
| TC-AUTH-053 | **`Authorization: bearer x` (minúscula)** | — | 401 (documentar) | ❌ FALTA **GAP-129** |
| TC-AUTH-054 | **Token con `alg=none` o RS256** | — | 401 | ❌ FALTA |
| TC-AUTH-055 | **Token con `exp` hace 30 s** | dentro del leeway de 60 s | aceptado (fijar el comportamiento) | ❌ FALTA |
| TC-AUTH-056 | **Fila de `users` insertada a mano con mayúsculas** | `Ana@Example.com` | no debe crear una segunda cuenta | ❌ FALTA 🔴 **GAP-120** |
| TC-AUTH-057 | **Carga: 200 logins concurrentes** | `/health` debe seguir respondiendo | p95 < 200 ms | ❌ FALTA 🔴 **GAP-118** |
| TC-AUTH-058 | **100 tokens con `kid` desconocido** | — | ≤ 1 fetch a JWKS por ventana | ❌ FALTA **GAP-124** |
| TC-AUTH-059 | **Fallo de `link_identity` tras `insert`** | — | sin sesión, sin usuario huérfano | ❌ FALTA 🔴 **GAP-114** |
| TC-AUTH-060 | **Dos sign-ins concurrentes con el mismo `sub`** | — | exactamente 1 usuario y 1 link | ❌ FALTA 🔴 **GAP-114** |
| TC-AUTH-061 | **Registro con contraseña de 6 caracteres multibyte** | `"áéíóúñ"` | debe rechazarse; hoy **pasa** | ❌ FALTA 🔴 **GAP-122** |
| TC-AUTH-062 | **La migración no deja usuarios demo** | base vacía + `migrate!` | tabla `users` vacía | ❌ FALTA 🔴 **GAP-113** |
| TC-AUTH-063 | **`GOOGLE_CLIENT_IDS` está en `render.yaml`** | comparar `AppConfig::from_env` | toda variable debe estar declarada | ❌ FALTA 🔴 **GAP-112** |

---

## 4. Casos de prueba — `technician` (perfil y documentos)

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-TECH-001 | Solicitar URL de subida | `cedula` + `image/jpeg` | `pending`, `storage_key` con UUID | ✅ `requesting_a_slot_stages_the_document_as_pending` |
| TC-TECH-002 | Confirmar marca `uploaded` | tras solicitar | `uploaded`, `uploaded_at` | ✅ `confirming_marks_the_document_uploaded` |
| TC-TECH-003 | Confirmar sin solicitar | directo | `DocumentNotFound` → 404 | ✅ `a_document_cannot_be_confirmed_without_an_upload` |
| TC-TECH-004 | Clave desconocida | `"pasaporte"` | `InvalidDocumentKey` → 400 | ✅ `unknown_document_keys_and_file_types_are_rejected` |
| TC-TECH-005 | Content-type no permitido | `application/x-msdownload` | `InvalidContentType` → 400 | ✅ idem |
| TC-TECH-006 | Verificación completa | 3 obligatorios | `is_verified=true` | ✅ `a_technician_is_verified_once_every_mandatory_document_lands` |
| TC-TECH-007 | Verificación incompleta | 2 de 3 | `is_verified=false` | ✅ idem |
| TC-TECH-008 | `seguro` opcional | solo 3 obligatorios | verificado igual | ✅ idem |
| TC-TECH-009 | Re-subida vuelve a `pending` | 2º upload | `pending`, `uploaded_at=NULL` | ✅ `re_uploading_a_document_sends_it_back_to_pending` |
| TC-TECH-010 | Extensión derivada del content-type | pdf→`.pdf`, png→`.png` | correcta | ⚠️ PARCIAL (pdf cubierto) |
| TC-TECH-011 | **Content-type en mayúsculas / con `; charset`** | `"IMAGE/JPEG"`, `"image/jpeg; charset=utf-8"` | rechazado (permitido solo exacto) — decidir | ❌ FALTA **GAP-29** |
| TC-TECH-012 | **Confirmar sin que los bytes existan en el bucket** | solicitar URL, **no** subir, confirmar | hoy **verifica igual** | ❌ FALTA 🔴 **GAP-30** |
| TC-TECH-013 | **Auto-verificación sin revisión humana** | subir 3 archivos basura | `is_verified=true` | ❌ FALTA 🔴 **GAP-30** |
| TC-TECH-014 | **No existe estado `rejected`** | — | el CHECK solo permite `uploaded`/`pending` | ❌ FALTA 🔴 **GAP-31** |
| TC-TECH-015 | **La verificación nunca se revoca** | re-subir tras verificado | sigue `is_verified=true` | ❌ FALTA 🔴 **GAP-31** |
| TC-TECH-016 | **`InvalidDocumentStatus` nunca se usa** | — | error muerto en el dominio | ❌ FALTA **GAP-31** |
| TC-TECH-017 | **`original_filename` con path traversal** | `"../../etc/passwd"` | no afecta la clave del objeto | ⚠️ PARCIAL (la clave usa UUID) |
| TC-TECH-018 | **`coverage_km` negativo / cero** | `-5`, `0` | sin validación | ❌ FALTA 🔴 **GAP-32** |
| TC-TECH-019 | **`oficio` vacío o gigante** | `""`, 1 MB | sin validación | ❌ FALTA **GAP-32** |
| TC-TECH-020 | **`categories` arbitrarias o vacías** | `["xyz"]`, `[]` | sin validación | ❌ FALTA 🔴 **GAP-32** |
| TC-TECH-021 | **`available_days` con valores inválidos** | `["lunes"]`, `[""]` | sin validación | ❌ FALTA **GAP-32** |
| TC-TECH-022 | **`price_label` libre** | `"gratis"` | sin validación (es texto de marketing) | ❌ FALTA |
| TC-TECH-023 | **Guardar perfil borra `is_verified`** | guardar con `is_verified=false` en memoria | debe preservar el verificado | ⚠️ PARCIAL (el flujo actual lo preserva, pero es frágil) **GAP-33** |
| TC-TECH-024 | **Sin validación de rango de `pin_top`/`pin_left`** | `-1`, `99` | sin validación | ❌ FALTA **GAP-32** |
| TC-TECH-025 | Bucket no configurado | `S3_*` vacío | 503 en uploads, resto OK | ❌ FALTA |
| TC-TECH-026 | `/providers` filtra por categoría | `?category=gasfiteria` | solo coincidentes | ❌ FALTA |
| TC-TECH-027 | **`/providers` público expone `user_id`** | sin token | fuga de UUID | ❌ FALTA **GAP-34** |
| TC-TECH-028 | **`/providers` sin paginación** | 10.000 técnicos | respuesta enorme | ❌ FALTA **GAP-35** |
| TC-TECH-029 | Técnico sin perfil guarda perfil | rol ok | crea perfil | ⚠️ PARCIAL |
| TC-TECH-030 | **Objeto huérfano en el bucket** | subir y nunca confirmar | basura acumulada | ❌ FALTA **GAP-36** |
| TC-TECH-031 | **Fila sin objeto (o al revés)** | desincronización | sin reconciliación | ❌ FALTA **GAP-36** |
| TC-TECH-032 | URL firmada expira | esperar el TTL | PUT rechazado | ❌ FALTA |
| TC-TECH-033 | **Lectura de documentos del técnico** | ¿hay `presign_get`? | `presign_get` existe pero **nadie lo llama** | ❌ FALTA 🔴 **GAP-37** |
| TC-TECH-034 | **Subir 50 GB con la URL firmada** | declarar `image/jpeg`, PUT gigante | debe rechazarse; hoy **se acepta** | ❌ FALTA 🔴 **GAP-62** |
| TC-TECH-035 | **Declarar `image/jpeg` y subir HTML** | PUT con `text/html` | el tipo real debe registrarse/rechazarse | ❌ FALTA 🔴 **GAP-63** |
| TC-TECH-036 | **Magic bytes vs content-type declarado** | PNG declarado `image/jpeg` | rechazo | ❌ FALTA **GAP-63** |
| TC-TECH-037 | **`original_filename` con `../../etc/passwd`** | nombre malicioso | saneado a basename | ⚠️ PARCIAL (no afecta la clave, sí se persiste) **GAP-64** |
| TC-TECH-038 | **`original_filename` con NUL / 5 MB** | `"a\0.jpg"` | rechazado/acotado | ❌ FALTA **GAP-64** |
| TC-TECH-039 | **Fallo de `save_profile` tras confirmar** | confirm OK, verify falla | estado parcial; el técnico queda sin verificar para siempre | ❌ FALTA 🔴 **GAP-65** |
| TC-TECH-040 | **Confirmar dos veces** | 2º confirm | `uploaded_at` se reescribe | ❌ FALTA **GAP-66** |
| TC-TECH-041 | **Fila con status futuro (`'verified'`)** | insertar directo | `GET /technician/documents` da 500 | ❌ FALTA **GAP-67** |
| TC-TECH-042 | **`S3_ENDPOINT` con esquema en mayúsculas** | `"HTTPS://acct.r2..."` | host mal parseado, URLs firmadas rotas | ❌ FALTA **GAP-68** |
| TC-TECH-043 | **Bucket público** | ACL público | cédulas expuestas; solo hay un comentario que lo pide | ❌ FALTA **GAP-69** |
| TC-TECH-044 | **Borrar cuenta deja los objetos** | borrar usuario | filas en cascada, objetos permanecen | ❌ FALTA **GAP-70** |
| TC-TECH-045 | **Perfil nuevo aparece con 5.0 estrellas** | crear perfil | rating fabricado con 0 reseñas | ❌ FALTA 🔴 **GAP-71** |
| TC-TECH-046 | **Todos los perfiles nuevos comparten pin** | crear 2 perfiles | mismo `pin_top`/`pin_left`/`distance` | ❌ FALTA **GAP-71** |
| TC-TECH-047 | **`/providers` muestra no verificados** | perfil sin docs | aparece junto a los verificados | ❌ FALTA **GAP-25b** |
| TC-TECH-048 | **Filtro `?category=Gasfiteria`** | mayúscula | devuelve vacío (case-sensitive) | ❌ FALTA **GAP-72** |
| TC-TECH-049 | **`document_key` no tiene CHECK en BD** | INSERT directo con `'pasaporte'` | se acepta | ❌ FALTA **GAP-73** |
| TC-TECH-050 | **Guardado concurrente inicial del perfil** | 2 `POST /technician/profile` en paralelo | el `is_verified` obsoleto no debe pisar | ❌ FALTA 🔴 **GAP-77** |
| TC-TECH-051 | **`is_verified` no coincide con los documentos** | verificado + 1 doc `pending` | invariante "verificado ⇒ 3 obligatorios subidos" | ❌ FALTA 🔴 **GAP-66** |
| TC-TECH-052 | **10 000 `POST /upload-url`** | sin cooldown | límite | ❌ FALTA **GAP-78** |
| TC-TECH-053 | **Contenido no revisable verifica** | 3 archivos de 1 byte | no debe verificar sin revisión | ❌ FALTA 🔴 **GAP-30** |
| TC-TECH-054 | **Sin `verified_at`/`verified_by`/`rejection_reason`** | decisión de KYC | no hay auditoría posible | ❌ FALTA **GAP-67** |
| TC-TECH-055 | **Certificado de antecedentes sin expiración** | doc de hace 3 años | re-verificación | ❌ FALTA **GAP-79** |

---

## 5. Casos de prueba — `chat` y `tracking`

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-CHAT-001 | Cliente envía mensaje en job `direct` | job gratuito | 201 | ✅ `direct_chat_is_available_without_a_platform_payment` |
| TC-CHAT-002 | Cliente lee el hilo | — | 1 mensaje | ✅ idem |
| TC-CHAT-003 | **Mensaje en `bidding` sin pagar** | `fee_paid=false` | `FeeNotPaid` → 402 | ❌ FALTA |
| TC-CHAT-004 | **Mensaje tras pagar** | `fee_paid=true` | 201 | ❌ FALTA |
| TC-CHAT-005 | **El técnico asignado escribe antes del pago** | `bidding` elegido, sin pagar | hoy **402** | ❌ FALTA 🔴 **GAP-38** |
| TC-CHAT-006 | **Técnico no asignado escribe** | tercero | 403 | ❌ FALTA |
| TC-CHAT-007 | **Un participante de subasta escribe al cliente** | técnico que pujó, no elegido | 403 | ❌ FALTA **GAP-39** |
| TC-CHAT-008 | **Cliente ajeno lee el hilo** | otro cliente | 403 | ❌ FALTA |
| TC-CHAT-009 | **Mensaje vacío / solo espacios** | `""`, `"   "` | debe rechazarse | ❌ FALTA 🔴 **GAP-40** |
| TC-CHAT-010 | **Mensaje de 1 MB** | texto gigante | debe rechazarse | ❌ FALTA 🔴 **GAP-40** |
| TC-CHAT-011 | **Mensaje con unicode/emoji/RTL** | `"👷‍♂️"`, `"\u202E"` | se guarda y devuelve íntegro | ❌ FALTA |
| TC-CHAT-012 | **Mensaje con HTML/script** | `<script>…</script>` | almacenado tal cual; la app debe escapar | ❌ FALTA **GAP-41** |
| TC-CHAT-013 | **Orden y paginación** | 500 mensajes | orden por `created_at ASC`, con paginación | ❌ FALTA 🔴 **GAP-42** |
| TC-CHAT-014 | **Job inexistente** | UUID aleatorio | 403 (hoy) — debería ser 404 | ❌ FALTA **GAP-43** |
| TC-CHAT-015 | **Suplantación de rol** | `sender_role` viene del JWT | imposible; documentado | ✅ por diseño (`dto.rs`) |
| TC-CHAT-016 | **Sin rate limiting de mensajes** | flood | límite | ❌ FALTA **GAP-28** |
| TC-CHAT-017 | **Escritura/lectura vía router real (HTTP)** | `oneshot` sobre `/jobs/{id}/messages` | 401 sin token, 200 dueño, 403 tercero | ❌ FALTA 🔴 **GAP-74** |
| TC-CHAT-018 | **Job con `tech_team_id` (proyecto) no tiene canal** | equipo asignado intenta chatear | 403 (hoy); decidir el modelo | ❌ FALTA **GAP-75** |
| TC-CHAT-019 | **Reordenamiento con `created_at` idéntico** | 2 mensajes mismo timestamp | orden debe ser determinista | ❌ FALTA **GAP-76** |
| TC-CHAT-020 | **Timestamp lo pone la app, no la BD** | reloj desviado | orden incorrecto | ❌ FALTA **GAP-76** |
| TC-TRK-001 | Tracking en job `direct` sin pago | job gratuito | 200 | ✅ `direct_tracking_is_available_without_a_platform_payment` |
| TC-TRK-002 | Cliente lee la ubicación | — | `-12.05, -77.04` | ✅ idem |
| TC-TRK-003 | **Técnico no asignado publica** | tercero | 403 | ❌ FALTA |
| TC-TRK-004 | **Tercero lee la ubicación** | ajeno | 403 | ❌ FALTA |
| TC-TRK-005 | **Latitud/longitud fuera de rango** | `lat=999`, `lng=-500` | debe rechazarse | ❌ FALTA 🔴 **GAP-44** |
| TC-TRK-006 | **NaN / Infinity** | `"NaN"`, `"Infinity"` | debe rechazarse (hoy puede persistir) | ❌ FALTA 🔴 **GAP-44** |
| TC-TRK-007 | **(0,0)** | coordenada nula | tratar como "sin GPS" | ❌ FALTA **GAP-44** |
| TC-TRK-008 | **Solo se guarda la última posición** | PK = `job_request_id` | no hay historial | ❌ FALTA **GAP-45** |
| TC-TRK-009 | **Ubicación obsoleta** | sin updates por horas | se muestra como actual | ❌ FALTA 🔴 **GAP-46** |
| TC-TRK-010 | **Tracking en `bidding` sin pagar** | `fee_paid=false` | 402 | ❌ FALTA |
| TC-TRK-011 | **Tracking tras completar** | job `completed` | debería detenerse | ❌ FALTA **GAP-47** |
| TC-TRK-012 | **Retención / privacidad de ubicación** | — | política de borrado | ❌ FALTA **GAP-45** |
| TC-TRK-013 | **Sin verificación de "técnico en movimiento"** | misma coordenada 1000 veces | sin control de spam | ❌ FALTA **GAP-28** |
| TC-TRK-014 | **Chat/tracking escribibles tras `completed`** | completar el job y seguir publicando | debe cerrarse | ❌ FALTA 🔴 **GAP-74** |
| TC-TRK-015 | **Fila con `NaN` escrita fuera de la API** | `INSERT ... 'NaN'` | `GET` devuelve `null` y rompe el parseo en Dart | ❌ FALTA **GAP-44** |
| TC-TRK-016 | **Sin ruta HTTP probada en el router real** | `oneshot` sobre `/jobs/{id}/location` | 401/403/200 según actor | ❌ FALTA 🔴 **GAP-74** |

---

## 6. Casos de prueba — `client` (direcciones y pagos)

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-CLI-001 | Listar direcciones | — | solo las propias | ⚠️ PARCIAL |
| TC-CLI-002 | Agregar dirección | `{label, detail}` | 201, ligada al `client_id` del token | ⚠️ PARCIAL |
| TC-CLI-003 | **`label`/`detail` vacíos** | `""` | debe rechazarse | ❌ FALTA **GAP-02** |
| TC-CLI-004 | **`detail` de 1 MB** | — | debe rechazarse | ❌ FALTA **GAP-02** |
| TC-CLI-005 | **Direcciones de otro cliente** | token ajeno | nunca visibles | ❌ FALTA **GAP-09** |
| TC-CLI-006 | Métodos de pago propios | — | solo los propios | ⚠️ PARCIAL |
| TC-CLI-007 | **Borrar/editar dirección** | PUT/DELETE | no existen endpoints | ❌ FALTA **GAP-48** |
| TC-CLI-008 | **Sin límite de direcciones** | 10.000 | límite por cuenta | ❌ FALTA **GAP-35** |
| TC-CLI-009 | **Datos de tarjeta en texto plano** | `detail="Visa 4111…"` | riesgo PII/PCI | ❌ FALTA 🔴 **GAP-49** |
| TC-CLI-010 | `POST /client/profile` | — | marca `profile_saved` | ⚠️ PARCIAL |
| TC-CLI-011 | **PAN completo en `detail`** | `"4111111111111111 exp 08/28 cvv 123"` | debe rechazarse; hoy **se guarda** | ❌ FALTA 🔴 **GAP-126** |
| TC-CLI-012 | **Pagar con un método no guardado** | `payment_method="inventado"` | debe rechazarse; hoy se acepta | ❌ FALTA 🔴 **GAP-126** |
| TC-CLI-013 | **Borrar una tarjeta comprometida** | `DELETE /client/payment-methods/{id}` | hoy **405** | ❌ FALTA **GAP-127** |
| TC-CLI-014 | **Sin `client_profiles` row** | `GET /client/profile` | hoy `{"profile_saved":false}`, indistinguible de "no guardado" | ❌ FALTA **GAP-127** |
| TC-CLI-015 | **Orden inestable de listas** | 500 direcciones, 2 llamadas | sin `ORDER BY` ⇒ orden arbitrario | ❌ FALTA **GAP-128** |
| TC-CLI-016 | **Token de cliente con rol cambiado en BD** | escribir una dirección | no debería poder | ❌ FALTA **GAP-131** |
| TC-CLI-017 | **`POST /client/profile` responde 200 vacío** | — | el único éxito no-JSON | ❌ FALTA **GAP-132** |

---

## 7. Casos de prueba — Cliente Flutter (contrato y cálculos)

| ID | Caso | Entrada | Resultado esperado | Estado |
|---|---|---|---|---|
| TC-FLT-001 | Formato de soles | `1234` | `"S/ 1,234.00"` | ❌ FALTA |
| TC-FLT-002 | **Soles negativos** | `-5` | `"S/ -5.00"` (¿o error?) | ❌ FALTA |
| TC-FLT-003 | **`i32::MAX`** | `2147483647` | `"S/ 2,147,483,647.00"` | ❌ FALTA |
| TC-FLT-004 | **Cero y valores < 1000** | `0`, `7` | `"S/ 0.00"`, `"S/ 7.00"` | ❌ FALTA |
| TC-FLT-005 | **Formato de fecha ISO inválido** | `"no-es-fecha"` | hoy **lanza excepción** | ❌ FALTA 🔴 **GAP-50** |
| TC-FLT-006 | Fecha cambia de día por zona horaria | `"2026-01-02T00:30:00Z"` | usa hora local | ❌ FALTA |
| TC-FLT-007 | **Precio de proyecto calculado en el cliente** | `labor+materials+mobility` | debe venir del backend | ❌ FALTA 🔴 **GAP-51** |
| TC-FLT-008 | **`agreedPriceLabel` con `providersPage=null`** | — | `"Por confirmar"` | ❌ FALTA |
| TC-FLT-009 | **`agreedPrice` nulo en bidding** | — | `"Por confirmar"` | ❌ FALTA |
| TC-FLT-010 | **Equipo no encontrado** | `techTeamId` ausente | `"Por confirmar"` | ❌ FALTA |
| TC-FLT-011 | **Sesión: 401 cierra sesión** | 401 autenticado | token borrado | ✅ `a 401 on an authenticated request ends the session` |
| TC-FLT-012 | **Sesión: backend caído no cierra** | 503 y luego 200 | reintenta, conserva token | ✅ `an unreachable backend at startup keeps the session instead of logging out` |
| TC-FLT-013 | **Sesión: 401 sin token no cierra** | login fallido | conserva | ✅ `a 401 without a token attached does not end the session` |
| TC-FLT-014 | **403 no debe cerrar sesión** | 403 | conserva sesión | ❌ FALTA |
| TC-FLT-015 | **Token expira a mitad de flujo** | 401 en `pay` | UI manejable | ❌ FALTA |
| TC-FLT-016 | **Timeout / offline** | sin red | mensaje claro | ❌ FALTA |
| TC-FLT-017 | **Doble tap en "Pagar"** | 2 POST | una sola petición efectiva | ❌ FALTA **GAP-07** |
| TC-FLT-018 | **Polling pisa estado más nuevo** | respuesta vieja llega tarde | no retrocede | ❌ FALTA **GAP-52** |
| TC-FLT-019 | **División por cero en distancias** | distancia 0 | sin `Infinity`/`NaN` | ❌ FALTA **GAP-53** |
| TC-FLT-020 | **Datos semilla como fallback** | API caída | ¿muestra datos falsos como reales? | ❌ FALTA 🔴 **GAP-54** |
| TC-FLT-021 | **Tarifa mostrada ≠ tarifa del backend** | S/ 4 hardcodeado | debe venir del campo `fee_amount` | ❌ FALTA 🔴 **GAP-55** |
| TC-FLT-022 | **Rol del token ≠ rol de la app** | cambio de rol | manejo | ❌ FALTA |
| TC-FLT-023 | Widget smoke test | — | arranca | ✅ `widget_test.dart` |
| TC-FLT-024 | **El técnico abre una solicitud abierta y oferta** | tocar una tarjeta de `openForBid` | debe mostrar el formulario de oferta | ❌ FALTA 🔴 **GAP-80** |
| TC-FLT-025 | **Doble tap en "Actualizar estado"** | 2 taps rápidos | un solo avance | ❌ FALTA 🔴 **GAP-81** |
| TC-FLT-026 | **Falló el POST de pago: ¿el estado se recupera?** | `pay` devuelve 500 | debe salir de "cargando" | ❌ FALTA 🔴 **GAP-82** |
| TC-FLT-027 | **El monto no parpadea durante el pago** | `payFee` en vuelo | no debe caer al valor local | ❌ FALTA 🔴 **GAP-82** |
| TC-FLT-028 | **Progreso de documentos: 3 obligatorios de 3** | subir los 3 | no debe mostrar 3/4 | ❌ FALTA 🔴 **GAP-83** |
| TC-FLT-029 | **Perfil de técnico visible con filtro de categoría activo** | chip "Gasfitería" + técnico de electricidad | debe cargar el perfil | ❌ FALTA **GAP-84** |
| TC-FLT-030 | **`firstWhere` con categoría de proyecto** | `piscinas` en el selector | no debe lanzar `StateError` | ❌ FALTA **GAP-85** |
| TC-FLT-031 | **Arranque con `/me` caído permanentemente** | 3 reintentos fallidos | no debe quedar en splash | ❌ FALTA **GAP-86** |
| TC-FLT-032 | **Historial vacío vs error** | fallo de red | debe distinguirse | ❌ FALTA **GAP-87** |
| TC-FLT-033 | **Polling 4xx: ¿cuántos reintentos?** | 402/403 persistente | no debe martillar | ❌ FALTA **GAP-88** |
| TC-FLT-034 | **JSON con tipo inesperado** | `"fee_amount": "4"` | error controlado, no `TypeError` | ❌ FALTA **GAP-89** |
| TC-FLT-035 | **Precio de oferta "1.500" / > i32** | entrada local | validación clara | ❌ FALTA **GAP-90** |
| TC-FLT-036 | **Deep link a `/tracking` con `fee_paid=false`** | sin pasar por pago | debe redirigir a pago | ❌ FALTA **GAP-91** |
| TC-FLT-037 | **Pin de técnico nuevo en el mapa** | recién registrado | posición real, no centro de Lima | ❌ FALTA **GAP-92** |
| TC-FLT-038 | **"Ver todos" borra el filtro de categoría** | desde la hoja | no debe alterar el filtro | ❌ FALTA **GAP-93** |

---

## 8. Casos transversales

| ID | Caso | Resultado esperado | Estado |
|---|---|---|---|
| TC-X-001 | **Sin rate limiting en ninguna ruta** | límites por IP/usuario | ❌ FALTA 🔴 **GAP-28** |
| TC-X-002 | **Sin cabeceras de seguridad / HTTPS forzado** | HSTS, etc. | ❌ FALTA **GAP-56** |
| TC-X-003 | **Sin observabilidad de negocio** | métricas de pagos, subastas | ❌ FALTA **GAP-57** |
| TC-X-004 | **Sin auditoría de acciones críticas** | log de quién pagó/elegió | ❌ FALTA **GAP-57** |
| TC-X-005 | **Sin idempotency keys en POSTs** | clave de idempotencia | ❌ FALTA **GAP-07** |
| TC-X-006 | **Sin control de concurrencia optimista** | `version`/`updated_at` | ❌ FALTA 🔴 **GAP-07** |
| TC-X-007 | **Transacciones incompletas** | operaciones multi-tabla atómicas | ❌ FALTA **GAP-58** |
| TC-X-008 | **Sin paginación en ningún listado** | límites | ❌ FALTA **GAP-35** |
| TC-X-009 | **Sin pruebas de contrato cliente↔servidor** | esquemas compartidos | ❌ FALTA **GAP-59** |
| TC-X-010 | **Sin pruebas del cliente Flutter** | 5 archivos, 1 de lógica | ❌ FALTA **GAP-60** |
| TC-X-011 | Errores 500 filtran mensajes internos | mensaje genérico | ✅ `shared/error.rs` |
| TC-X-012 | 401 vs 403 correctos | distinguidos | ✅ `role_authorization.rs` |
| TC-X-013 | CORS con lista vacía | rechaza navegadores | ✅ por diseño |
| TC-X-014 | **Sin límite de tamaño de body** | request de 100 MB | ❌ FALTA **GAP-02** |
| TC-X-015 | **Migraciones idempotentes** | re-ejecutar | ⚠️ PARCIAL (0009 no es idempotente) **GAP-61** |

---

## 9. Gaps descubiertos en las pasadas por feature (GAP-62 … GAP-132)

Las secciones 2–7 se redactaron con una primera lectura; después se auditó en profundidad cada
feature por separado. Estos son los vacíos **nuevos** que aparecieron, numerados a continuación
para no invalidar las referencias `GAP-01…GAP-61` ya usadas arriba.

### 9.1 Subida de documentos: la frontera de confianza (lo más grave del informe)

| GAP | Vacío | Sev | Evidencia |
|---|---|---|---|
| **GAP-62** | **La URL firmada no limita el tamaño.** `presign_put` firma solo `host` con `UNSIGNED-PAYLOAD`, sin `content-length-range`; el tope de 10 MB es **solo del cliente** | 🔴 Crítico | `s3_object_storage.rs:71-78,141,151`; `tech_docs_controller.dart:26` |
| **GAP-63** | **El `Content-Type` no está en la firma y no se comprueba el contenido.** Se declara `image/jpeg` y se sube HTML; no hay sniffing de magic bytes | 🔴 Crítico | `s3_object_storage.rs:71-78` (comentario explícito en `:72-76`) |
| **GAP-64** | `original_filename` se persiste sin sanear (traversal, NUL, longitud) | 🟡 Medio | `technician/interfaces/http/dto.rs:107`; `postgres_technician_repository.rs:274` |
| **GAP-65** | Confirmar y verificar no son atómicos: si `save_profile` falla, el técnico queda **sin verificar para siempre** y nada re-escanea | 🟠 Alto | `upload_document.rs:127-131` |
| **GAP-66** | **Confirmar no es idempotente** (reescribe `uploaded_at`) y la re-subida deja `is_verified=true` con el doc en `pending`: el invariante "verificado ⇒ 3 obligatorios subidos" ya es falso | 🟠 Alto | `postgres_technician_repository.rs:270-275,297` |
| **GAP-67** | **Estado desconocido en BD ⇒ 500.** El `parse` estricto de `DocStatus` convierte una fila futura (`'verified'`) en error del servidor. Y no hay `verified_at`/`verified_by`/`rejection_reason`: **cero auditoría de KYC** | 🟡 Medio | `technician_document.rs:19-25`; `postgres_technician_repository.rs:248-249` |
| **GAP-68** | `split_endpoint` es sensible a mayúsculas: `"HTTPS://host"` no se recorta y el host queda malformado | 🟢 Bajo | `s3_object_storage.rs:103-114` |
| **GAP-69** | El bucket privado es un **requisito solo documentado**: ningún código fija ni comprueba ACLs | 🟠 Alto | `config.rs:54-57`; `.env.example:17-19` |
| **GAP-70** | Sin `delete_object`: borrar la cuenta deja los documentos de identidad en el bucket | 🟡 Medio | `technician/application/ports.rs:10-17` |
| **GAP-77** | **Guardado concurrente inicial revierte la verificación.** El upsert escribe `is_verified = EXCLUDED.is_verified` desde un valor leído antes | 🟠 Alto | `postgres_technician_repository.rs:163-173`; `save_profile.rs:30,38-46` |
| **GAP-78** | `start_document_upload` sin throttle ni cooldown: 10 000 slots = 10 000 objetos huérfanos | 🟡 Medio | `postgres_technician_repository.rs:255-287` |
| **GAP-79** | Sin expiración ni re-verificación: un certificado de antecedentes de hace 3 años sigue valiendo | 🟡 Medio | `technician_document.rs:46-57` |

### 9.2 Marketplace: `is_verified` no es una puerta

| GAP | Vacío | Sev | Evidencia |
|---|---|---|---|
| **GAP-80** | **El feed y el detalle son incoherentes: el técnico no puede ofertar desde la app.** `/technician/jobs` devuelve `open_for_bid`, el usuario toca la tarjeta, y el detalle hace `GET /jobs/{id}` → `authorize_job_access` rechaza porque `technician_profile_id` es `NULL` en una subasta → **403**, `job == null`, y el formulario "Enviar oferta" nunca se renderiza | 🔴 Crítico | `technician_jobs_screen.dart:46`; `technician_job_detail_screen.dart:80,100-115,161-173`; `job/application/mod.rs:37-50` |
| **GAP-72** | El filtro `?category=` es exacto y sensible a mayúsculas: `Gasfiteria` → lista vacía | 🟢 Bajo | `postgres_technician_repository.rs:200` |
| **GAP-73** | `technician_documents.document_key`/`content_type` sin CHECK: solo se validan en la app | 🟡 Medio | `0002:24`; `0008:10-14` |

### 9.3 Otros vacíos de backend

| GAP | Vacío | Sev | Evidencia |
|---|---|---|---|
| **GAP-74** | **Chat y tracking no tienen ni una prueba HTTP.** `role_authorization.rs` no toca `/jobs/{id}/messages` ni `/jobs/{id}/location` (sus listas están en `:110-141`) y `business_rules.rs` solo cubre jobs gratuitos (donde `fee_paid` nace `true`) | 🟠 Alto | `role_authorization.rs:110-141`; `business_rules.rs:124-162` |
| **GAP-75** | Un job `project` (`tech_team_id`) **no tiene canal**: el equipo asignado no puede chatear ni compartir ubicación (la comparación es contra `technician_profile_id`, siempre `NULL` en proyectos) | 🟡 Medio | `send_message.rs:54`; `update_location.rs:48` |
| **GAP-76** | Orden de mensajes no determinista: `ORDER BY created_at` sin desempate, y el timestamp lo genera la **app**, no la BD | 🟡 Medio | `postgres_chat_repository.rs:64`; `chat/domain/message.rs:22` |
| **GAP-94** | `choose_offer` sobre un job ya activo por pago responde **402 en vez de 400** (el gate de tarifa se evalúa antes que el de estado) | 🟡 Medio | `choose_offer.rs:34-39`; `error.rs:133-136` |

### 9.4 Cliente Flutter

| GAP | Vacío | Sev | Evidencia |
|---|---|---|---|
| **GAP-95** | **Costos de equipo en pesos chilenos.** El seed conserva `laborCost: 780000` (CLP) mientras la migración 0007 los reescribió a `3150` (soles) y el `priceLabel` dice "Desde $850.000": el mismo equipo mostraría **"S/ 1,265,000.00"** frente a los "S/ 5,110.00" reales | 🔴 Crítico | `cerca_seed_data.dart:63,69,75`; `0007_peru_currency_seed_data.sql:13-15` |
| **GAP-96** | El progreso de documentos divide por **4** (incluye `seguro`, que es opcional) mientras el backend exige 3: los técnicos se quedan "atascados en 3 de 4" — exactamente el bug que el propio `doc_requirement.dart:14-21` dice haber arreglado | 🟠 Alto | `cerca_controller.dart:119-123`; `technician_document.rs:36`; `doc_requirement.dart:14-21` |
| **GAP-97** | `state = const AsyncLoading()` sin valor previo: durante el POST el job es `null` y la UI cae a sus fallbacks (el monto salta al "S/ 4" local) — contradice el comentario de `app_fee_screen.dart:51-53` | 🟠 Alto | `active_job_controller.dart:28,43,51`; `app_fee_screen.dart:54,136` |
| **GAP-98** | El `await` de las mutaciones está **fuera** de `AsyncValue.guard`: si el POST falla, el provider queda en `AsyncLoading` **para siempre** | 🟠 Alto | `active_job_controller.dart:28-31,43-46,51-54` |
| **GAP-99** | El perfil del proveedor se busca en la página de `/providers` **filtrada por la categoría activa del Home**: si no coincide, "No se pudo cargar este perfil" | 🟠 Alto | `providers_controller.dart:34`; `technician_profile_screen.dart:50-102` |
| **GAP-100** | `firstWhere` sin `orElse` y el selector no incluye las categorías de proyecto: elegir "piscinas" en el Home y abrir el selector lanza `StateError` | 🟡 Medio | `mode_chooser_screen.dart:49,122`; `cerca_seed_data.dart:28-33` |
| **GAP-101** | `await ref.read(authControllerProvider.future)` en el splash **sin `try/catch`**: con `/me` fallando de forma persistente la app se queda colgada en el splash | 🟡 Medio | `auth_controller.dart:44-59`; `splash_screen.dart:47,56-60` |
| **GAP-102** | El historial trata el error como vacío (`?? const []`): muestra "Aún no tienes solicitudes anteriores." ante un fallo de red | 🟡 Medio | `client_account_screen.dart:116-122,251-258` |
| **GAP-103** | El rethrow en 4xx de `pollWithBackoff` **queda anulado**: Riverpod 3 reintenta cualquier error no-`Error` 10 veces con backoff, así que la app sigue martillando con 402/403 | 🟡 Medio | `polling.dart:34-36` (y su comentario en `:16-21`) |
| **GAP-104** | Los casts `as num).toInt()` y los `required` no nullables lanzan `TypeError`, que **no** es `DioException` y por tanto no lo mapea `apiExceptionOf` | 🟡 Medio | `job_request.g.dart:16-23`; `api_client.dart:92-95` |
| **GAP-105** | Precio de oferta sin formato local ni cota `i32`: `"1.500"` falla con mensaje genérico y un valor > 2³¹ se rechaza en el servidor con un 400 opaco | 🟡 Medio | `technician_job_detail_screen.dart:39-44`; `job/dto.rs:110` |
| **GAP-106** | El pago depende del **estado local de navegación**, no del job: un deep link a `/tracking` con `feePaid == false` entra igual y deja la pantalla en "Esperando la ubicación del técnico…" (el poll corta en el 402) | 🟡 Medio | `cerca_controller.dart:60-61`; `bidding_screen.dart:36-38`; `polling.dart:36` |
| **GAP-107** | Lat/lng de los pines **hardcodeadas por id** con fallback al centro de Lima: un técnico nuevo aparece en Lima y se ignoran los `pin_top`/`pin_left` del backend | 🟡 Medio | `home_screen.dart:703-713,745-750`; `save_profile.rs:59` |
| **GAP-108** | "Ver todos" limpia `selectedCategoryProvider`, descartando el filtro que el usuario eligió a propósito | 🟡 Medio | `home_screen.dart:358`; `providers_controller.dart:34` |
| **GAP-109** | `forceLogout` no es atómico (varios 401 simultáneos) y llama a `signOut()` de Google y al almacenamiento durante la expiración | 🟢 Bajo | `api_client.dart:55-65`; `auth_controller.dart:119-139` |
| **GAP-110** | Datos inventados mostrados como reales: ETA "Puede llegar hoy a las 17:00", una cita textual fabricada y "Foto adjunta del problema" sin permitir adjuntar; y `createJob` no envía `address` ni descripción, así que el seguimiento muestra "Sin dirección" | 🟢 Bajo | `direct_quote_screen.dart:123,167,179` y `:32-36` |

### 9.5 Reclasificaciones

Dos hallazgos de la primera pasada quedaron mejor calibrados tras la segunda lectura:

- **GAP-53** (división por cero en distancias del cliente): **no aplica**. No hay matemática de
  distancia ni ETA en el cliente — `distance` es un `String` del servidor y se muestra tal cual
  (`home_screen.dart:898`). El problema real es que **no existe geodata** (ver GAP-107 y GAP-44).
- **GAP-41** (XSS por contenido sin sanear): **descartado en el cliente actual**. El servidor
  guarda texto plano y Flutter usa `Text`, no `Html`/`WebView`. Se mantiene como riesgo latente
  solo si se añade un panel web de revisión (relevante para GAP-31).
- **GAP-39** (técnicos que pujaron no pueden chatear): **confirmado como comportamiento
  existente**, no un bug: `chat/application/mod.rs:41` solo autoriza si
  `job.technician_profile_id` es `Some` y coincide. Es una **decisión de producto** pendiente
  (ver §7 del plan), no un defecto de implementación.

---

### 9.6 Autenticación, cuentas y despliegue

| GAP | Vacío | Sev | Evidencia |
|---|---|---|---|
| **GAP-111** | **Pre-hijack de cuenta.** No existe verificación de email para cuentas con contraseña, y `sign_in_with_google` vincula la identidad al email existente sin prueba de propiedad: un atacante registra el email de la víctima, y cuando la víctima entra con Google **hereda la cuenta del atacante**, que conserva su contraseña y su acceso | 🔴 Crítico | `sign_in_with_google.rs:73-78`; `register_user.rs:37-60` (no hay verificación); `0001_create_users.sql` (no hay columna `email_verified`) |
| **GAP-112** | **El botón de Google está muerto en producción.** `render.yaml` declara `DATABASE_URL`, `JWT_SECRET`, `RUST_LOG`, `CORS_*` y los `S3_*`, pero **omite `GOOGLE_CLIENT_IDS`** ⇒ `main.rs:51-53` instala `UnconfiguredIdentityVerifier` ⇒ **toda** llamada a `/auth/google` responde 503 | 🔴 Crítico | `render.yaml:28-54`; `main.rs:51-56`; `google_identity_verifier.rs:170-175` |
| **GAP-113** | **Credenciales por defecto sembradas en todos los entornos.** La migración `0002` inserta 5 cuentas con el hash de `password123` y `ON CONFLICT (id) DO NOTHING`, y las migraciones corren en **cada arranque**: `client@cerca.com` / `password123` da un token válido de 7 días en producción | 🔴 Crítico | `0002_cerca_features.sql:119-127`; `main.rs:38-41` |
| **GAP-114** | **Cuentas "split-brain".** `insert` + `link_identity` no son transaccionales y el link es `ON CONFLICT DO NOTHING`: dos sign-ins concurrentes con el mismo `sub` crean **dos usuarios** y descartan un link en silencio, devolviendo sesión para una cuenta sin identidad; con el mismo email, en cambio, da 500 | 🟠 Alto | `sign_in_with_google.rs:92-98`; `postgres_user_repository.rs:119-121` |
| **GAP-115** | **El rol de `/me` y el del token pueden divergir.** El token lleva `role` y es la única fuente de autorización (`middleware.rs:43`), mientras `/me` devuelve el rol de la BD (`auth/dto.rs:48`): tras cambiar el rol, la app enruta al UI nuevo y todas sus llamadas dan 403 hasta por 7 días | 🟡 Medio | `jwt_token_service.rs:9-38`; `middleware.rs:43`; `get_current_user.rs` |
| **GAP-116** | **422 sobrecargado.** El cliente decide "falta el rol" con `statusCode == 422`, así que **cualquier** rechazo de JSON de axum (texto plano) abre el selector cliente/técnico y el reintento nunca puede tener éxito | 🟡 Medio | `lib/core/network/api_exception.dart:16`; `google_sign_in_button.dart:46-53`; `shared/error.rs:75` |
| **GAP-117** | **Un 401 de `/auth/google` cierra la sesión de un usuario ya autenticado** (un ID token inválido devuelve 401 y el interceptor cierra sesión ante cualquier 401 con token adjunto) | 🟡 Medio | `api_client.dart:54-57`; `shared/error.rs:65-66` |
| **GAP-118** | **Argon2 síncrono dentro de handlers async** + sin rate limiting: cada intento de login ocupa un worker de tokio durante todo el hash (19 MiB, t=2) ⇒ un flood no autenticado bloquea la API entera | 🔴 Crítico | `register_user.rs:49`; `login_user.rs:46-49`; `argon2_password_hasher.rs:11-22` |
| **GAP-119** | **Enumeración de cuentas.** `PasswordLoginUnavailable` (409) nombra el tipo de cuenta, y el tiempo de respuesta distingue email conocido de desconocido (no se hashea nada si el email no existe) | 🟡 Medio | `login_user.rs:32-44`; `shared/error.rs:71` |
| **GAP-120** | **La unicidad de email es case-sensitive en la BD** mientras la app normaliza a minúsculas: una fila escrita fuera de la app (`Ana@Example.com`) es invisible a `find_by_email` ⇒ segunda cuenta para la misma persona. No hay índice `UNIQUE (lower(email))` ni `citext` | 🟡 Medio | `0001_create_users.sql:3`; `value_objects.rs:22`; `postgres_user_repository.rs:70-72` |
| **GAP-121** | **`Email::parse` acepta direcciones malformadas** (`a@b.c@d`, `a@b.`, `a@.com`, `a b@c.com`, `a\n@b.com`, sin tope de longitud): el invariante "cualquier `Email` en alcance está bien formado" (`value_objects.rs:5-7`) es falso. Con NUL embebido el INSERT falla ⇒ **500** | 🟡 Medio | `value_objects.rs:11-23` |
| **GAP-122** | **La regla de contraseña es por bytes**: `"áéíóúñ"` son 6 caracteres y 12 bytes ⇒ **pasa**. Sin tope máximo, sin complejidad | 🟡 Medio | `register_user.rs:41-43` |
| **GAP-123** | `name` sin validar en la vía de contraseña (`""`, `"   "`, 2 MB), mientras la vía de Google lo recorta y descarta vacíos | 🟡 Medio | `register_user.rs:50`; `sign_in_with_google.rs:84-90` |
| **GAP-124** | **JWKS sin single-flight**: N peticiones concurrentes con un `kid` desconocido disparan N llamadas salientes a Google (amplificación no autenticada). Un `RwLock` envenenado desactiva el caché para siempre | 🟡 Medio | `google_identity_verifier.rs:94-96,121-134` |
| **GAP-125** | Sin verificación de email, sin reset/cambio de contraseña, y una cuenta solo-Google **nunca** puede tener login con contraseña (`password_hash` queda `NULL`) | 🟡 Medio | `login_user.rs:41-44`; no existen endpoints |
| **GAP-126** | **Riesgo PCI**: `client_payment_methods.detail` es texto libre sin validar (se puede guardar un PAN/CVV completo en claro) y `PayFeeUseCase` acepta cualquier string de `payment_method` ignorando los métodos guardados | 🟠 Alto | `client/infrastructure/postgres_client_repository.rs`; `add_payment_method.rs:21-25`; `job/application/pay_fee.rs:31` |
| **GAP-127** | Sin `PATCH`/`DELETE` para direcciones ni métodos de pago: un cliente no puede quitar una tarjeta comprometida. `AddressNotFound`/`PaymentMethodNotFound`/`ClientNotFound` son variantes muertas | 🟡 Medio | `client/interfaces/http/routes.rs:10-15`; `client/domain/errors.rs:5-9` |
| **GAP-128** | Direcciones y métodos de pago sin validación (vacíos, solo espacios, 2 MB), sin paginación y **sin `ORDER BY`** (orden inestable entre llamadas) | 🟡 Medio | `add_address.rs:21-25`; `postgres_client_repository.rs:61,88` |
| **GAP-129** | Los mensajes de rechazo del middleware/extractor son **texto plano**, no el sobre `{"error": …}` que el cliente sabe parsear (y sin `WWW-Authenticate`); `Bearer` es sensible a mayúsculas | 🟢 Bajo | `middleware.rs:23,32,36,41`; `api_client.dart:74-88` |
| **GAP-130** | Una fila heredada cuya `email` no pasa `Email::parse` (p. ej. `admin@localhost`) hace que `/auth/login` y `/me` respondan **400** en vez de 401 | 🟢 Bajo | `postgres_user_repository.rs:29`; `login_user.rs:30` |
| **GAP-131** | Las tablas de cliente solo tienen `REFERENCES users(id)`, sin constraint de rol: un token de cliente obsoleto (ver GAP-115) sigue escribiendo filas de cliente | 🟢 Bajo | `0002_cerca_features.sql:57,65` |
| **GAP-132** | `POST /client/profile` responde **200 con cuerpo vacío** (el único éxito no-JSON) | 🟢 Bajo | `client/interfaces/http/handlers.rs:25` |

**Nota sobre el alcance de las pruebas existentes.** `google_sign_in.rs` cubre bien los tres pasos
del flujo de Google, y `role_authorization.rs` el 401 vs 403 — pero **ningún test HTTP llama a
`/auth/register`, `/auth/login` ni `/auth/google`**, y no existe una sola prueba de
`RegisterUserUseCase`, `LoginUserUseCase`, `Email::parse`, `Role::parse`, `JwtTokenService::verify`
ni de ningún caso de uso de `client`. Son ~44 reglas sin red.

---

## 10. Resumen de cobertura

Cifras verificadas contando las filas de las tablas anteriores:

| Área | Casos | ✅ Cubiertos | ⚠️ Parciales | ❌ Faltantes | 🔴 Bugs |
|---|---:|---:|---:|---:|---:|
| `job` | 79 | 25 | 5 | 29 | 20 |
| `auth` | 63 | 4 | 7 | 31 | 21 |
| `technician` | 55 | 9 | 5 | 27 | 14 |
| `chat` | 20 | 3 | 0 | 12 | 5 |
| `tracking` | 16 | 2 | 0 | 9 | 5 |
| `client` | 17 | 0 | 4 | 10 | 3 |
| Flutter | 38 | 4 | 0 | 25 | 9 |
| Transversal | 15 | 3 | 1 | 9 | 2 |
| **Total** | **303** | **50 (17 %)** | **22** | **152** | **79** |

*(Las columnas se solapan: un caso puede estar ✅ y a la vez citar un GAP; 🔴 cuenta los que
marcan un defecto.)*

**Lectura.** Hay 50 pruebas para 303 reglas de negocio identificadas: **una de cada seis**. La
cobertura fuerte está en la máquina de estados del job y en el flujo de documentos. Los huecos
grandes son **cancelación, concurrencia, cobro real, identidad, validación de entrada y todo el
contrato con el cliente Flutter**.

**Cuatro hallazgos concentran la mayor parte del riesgo:**

1. **La licitación no funciona en la app** (`GAP-80`): el técnico ve las solicitudes abiertas,
   toca una, recibe 403 y el formulario de oferta nunca aparece. El modo licitación es inoperable.
2. **La verificación de técnicos es falsificable en 6 peticiones** sin subir un byte
   (`GAP-30` + `GAP-62` + `GAP-63`).
3. **Credenciales por defecto en producción** (`GAP-113`, `password123` sembrado en cada arranque)
   y **el botón de Google muerto en el despliegue declarado** (`GAP-112`).
4. **El cliente puede finalizar y calificar su propio trabajo** (`GAP-15`), y la calificación no
   tiene ninguna consecuencia (`GAP-16`).

**Dos advertencias sobre el propio informe.** Ningún hallazgo está confirmado por ejecución — la
suite de integración no corre en este entorno (`PoolTimedOut`). Y hay áreas donde **la cobertura
es cero, no baja**: `role_authorization.rs` no toca las rutas de chat ni de tracking, ningún test
HTTP llama a `/auth/register`, `/auth/login` o `/auth/google`, y no existe una sola prueba de
`RegisterUserUseCase`, `LoginUserUseCase`, `Email::parse`, `Role::parse`, `JwtTokenService::verify`
ni de los casos de uso de `client`.

Los vacíos priorizados y cómo cerrarlos están en
[`plan-de-solucion-vacios.md`](./plan-de-solucion-vacios.md).
