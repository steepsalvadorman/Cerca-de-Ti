# Despliegue pendiente

Estado: pendiente hasta disponer de una nueva cuota o proveedor para alojar el backend.

## Arquitectura prevista

```text
Flutter (Android/iOS)
        |
        v
Backend Rust (proveedor pendiente)
        |-- Supabase Postgres
        `-- Supabase Storage
```

Supabase alojará la base de datos PostgreSQL y los documentos privados. El
backend Rust seguirá controlando autenticación, roles, solicitudes, ofertas,
licitaciones y autorizaciones. La aplicación móvil no debe conectarse
directamente a PostgreSQL ni contener credenciales de Supabase.

Firebase App Distribution fue retirado del workflow. GitHub Actions compila el
APK y lo publica como un artefacto descargable durante 30 días.

## Situación actual

- El proyecto eliminado de Render debe reemplazarse por otro alojamiento.
- Railway se deja pendiente porque terminó la cuota gratuita.
- El backend ya incluye `Dockerfile` y ejecuta las migraciones SQL al iniciar.
- El workflow Android ya no necesita `FIREBASE_APP_ID` ni credenciales de Firebase.
- `API_BASE_URL` admite una variable pública de GitHub Actions.
- No hay credenciales reales guardadas en este documento ni deben agregarse.

## Pasos para retomar

1. Elegir dónde ejecutar el contenedor Rust: Railway con nueva cuota, Fly.io,
   Google Cloud Run, Koyeb, un VPS u otro proveedor compatible con Docker.
2. Crear o recuperar el proyecto de Supabase.
3. Cambiar cualquier contraseña de base de datos que haya sido compartida en
   mensajes, capturas o registros.
4. En Supabase, abrir **Connect → Session pooler** y copiar la conexión del
   puerto `5432`. Evitar Transaction pooler (`6543`) porque no admite prepared
   statements.
5. Configurar en el proveedor del backend:

   ```text
   DATABASE_URL=<cadena Session pooler de Supabase con SSL>
   JWT_SECRET=<cadena aleatoria larga y privada>
   RUST_LOG=backend=info,tower_http=warn
   GOOGLE_CLIENT_IDS=<ids permitidos, cuando se active Google Sign-In>
   S3_ENDPOINT=<endpoint S3 de Supabase Storage>
   S3_REGION=<región del proyecto>
   S3_ACCESS_KEY_ID=<clave S3>
   S3_SECRET_ACCESS_KEY=<secreto S3>
   S3_BUCKET=<bucket privado>
   ```

6. Desplegar y comprobar que `https://<backend>/health` responda correctamente.
7. En GitHub, crear la variable de repositorio `API_BASE_URL` con la URL HTTPS
   pública del backend.
8. Ejecutar manualmente **Build Android APK** y descargar el artefacto generado.
9. Probar registro, inicio de sesión, perfil, dirección, solicitud directa,
   licitación de S/4, documentos y cierre de sesión desde un dispositivo real.

## Migración de datos

Al apuntar `DATABASE_URL` a una base vacía, el backend crea el esquema y los
datos semilla automáticamente. Esto no copia usuarios, solicitudes ni ofertas
de una base anterior. Si se quieren conservar, primero se debe realizar un
respaldo con `pg_dump` y restaurarlo en Supabase antes de iniciar el backend.

## Distribución temporal

Mientras no se use Google Play Internal Testing, los APK se descargan desde:

```text
GitHub → Actions → Build Android APK → Artifacts → cerca-android-<número>
```

Para iOS será necesario configurar firma de Apple y utilizar TestFlight; un APK
de Android no puede instalarse en iPhone.
