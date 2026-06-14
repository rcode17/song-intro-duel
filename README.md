# Song Intro Duel

MVP de juego para 2 jugadores: crear sala, unirse con código, escoger género, escuchar preview de Deezer y adivinar la canción.

## Stack
- Flutter
- Firebase Firestore
- Deezer public API previews de 30 segundos
- just_audio

## Antes de correr
1. Instala Flutter.
2. Crea un proyecto en Firebase.
3. Activa Cloud Firestore.
4. En la raíz del proyecto ejecuta:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
flutter pub get
flutter run -d chrome
```

`flutterfire configure` generará `lib/firebase_options.dart`.

## Deploy web a Firebase Hosting

```bash
npm install -g firebase-tools
firebase login
firebase init hosting
# public directory: build/web
# configure as single-page app: Yes
flutter build web
firebase deploy --only hosting
```

## Firestore rules de prueba
Ver `firestore.rules`. Son reglas para MVP, no producción.

## Pendientes para producción
- Login real o anónimo con Firebase Auth.
- Reglas de seguridad por usuario.
- Evitar que el cliente vea la respuesta correcta antes de responder.
- Backend propio o Cloud Functions para validar puntajes.
- Normalizar nombres de artistas/canciones.
