# Ingresar con Google

Todo el código está en su sitio. Lo que falta son credenciales, y esas
sólo se crean a mano en Google Cloud Console. Mientras no existan, la
app muestra el botón y el backend responde `503` — nada más se rompe.

## 1. Crear los clientes OAuth

En [Google Cloud Console](https://console.cloud.google.com) → un
proyecto para Cerca → **APIs & Services → Credentials**.

Antes de crear nada, completa **OAuth consent screen**: tipo *External*,
nombre de la app, correo de soporte, y la URL de la política de
privacidad. Se puede dejar en *Testing* mientras desarrollas (hasta 100
cuentas de prueba); pasar a *Production* no requiere revisión de Google
mientras sólo pidas los scopes básicos de perfil y correo.

Luego, **Create Credentials → OAuth client ID**, dos veces:

**a) Application type: Web.** No hay ninguna web; este cliente existe
porque es el que hace que Google emita un *ID token* dirigido a nuestro
backend. Su id es el que viaja en el claim `aud` y el que ambos lados
tienen que conocer. Sin redirect URIs.

**b) Application type: Android.**
- Package name: `com.salvador.cerca`
- SHA-1: el de la llave de debug **y**, en otra credencial, el de la
  llave de release. Son huellas distintas; si falta la de release, el
  ingreso funciona en tu máquina y falla en la Play Store.

Su id no se escribe en ninguna parte: Google lo asocia por package name
y huella.

Para obtener el SHA-1 de debug (PowerShell):

```powershell
keytool -list -v -alias androiddebugkey `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -keypass android
```

## 2. Configurar el backend

Acepta el/los id que pueden aparecer en `aud`, separados por coma. Es lo
que impide que un token emitido para otra app se reuse contra Cerca:

```
GOOGLE_CLIENT_IDS=<id-del-cliente-web>.apps.googleusercontent.com
```

En local va en `backend/.env`; en producción, en las variables de
entorno de Render.

## 3. Configurar la app

El mismo id del cliente **web**, en tiempo de compilación:

```powershell
flutter run -d emulator-5554 `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<id-del-cliente-web>.apps.googleusercontent.com
```

Para los builds de release, el mismo `--dart-define` en
`flutter build apk` / `appbundle`.

## Cómo se comporta

`POST /auth/google` recibe el ID token y, en este orden:

1. Si ya conocemos esa cuenta de Google, inicia sesión.
2. Si no, pero el correo (verificado por Google) ya existe por registro
   con contraseña, **vincula** la identidad a esa cuenta en vez de crear
   una duplicada. Esa cuenta conserva el rol que ya tenía.
3. Si no existe nadie, crea la cuenta — pero necesita saber el rol. La
   pantalla de registro lo manda desde su toggle; la de login no lo
   tiene, así que el backend responde `422` y la app abre una hoja
   preguntando *"¿Cómo usarás Cerca?"* antes de reintentar.

Una cuenta creada por Google no tiene contraseña: intentar
`POST /auth/login` con ese correo responde `409` diciendo que esa cuenta
ingresa con Google, en vez de un "credenciales inválidas" que mandaría a
la persona a buscar una contraseña que nunca puso.

## Pendiente para iOS

Falta crear el cliente OAuth de tipo iOS y pasarlo como
`--dart-define=GOOGLE_IOS_CLIENT_ID=...` (el código ya lo lee). Ojo con
la guideline 4.8 de App Store Review: una app que ofrece login social de
terceros tiene que ofrecer también una opción equivalente de privacidad,
que en la práctica significa *Sign in with Apple*.
