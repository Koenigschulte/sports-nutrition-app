# Flutter Setup

## 1. Flutter installieren
https://docs.flutter.dev/get-started/install/windows/mobile

## 2. Projekt initialisieren (einmalig, nach Flutter-Installation)
```
cd Sports_Nutrition_App
flutter create app --org com.koeschu --project-name sports_nutrition_app
```
Danach pubspec.yaml aus diesem Ordner übernehmen.

## 3. Dependencies installieren
```
cd app
flutter pub get
```

## 4. Code generieren (Retrofit + JSON)
```
dart run build_runner build
```

## 5. App starten
```
# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d android
```
