# Business Manager - Setup Guide

## Running the App

### Using Command Line

**Default BAC flavor:**
```
flutter run -t lib/main.dart
```

**BAC flavor with arguments:**
```
flutter run --flavor bac --dart-define=FLAVOR=bac --dart-define=APP_NAME="BAC manager" --dart-define=COMPANY_NAME="Business Manager"
```

**Komusoft flavor:**
```
flutter run --flavor komusoft -t lib/main.dart --dart-define=FLAVOR=komusoft --dart-define=APP_NAME="Komusoft Solns" --dart-define=COMPANY_NAME="Komusoft Solutions Ltd" --dart-define=BOT_USERNAME=test.account123@qc.com --dart-define=BOT_PASSWORD=Ba@123456
```

### Using Android Studio

1. Go to **Run > Edit Configurations**
2. Click **+** and select **Flutter**
3. Configure as follows:

   **For BAC:**
   - Flavor: `bac`
   - Dart entry point: `lib/main.dart`
   - Build mode: `Debug` or `Release`
   - Additional run args: `--dart-define=FLAVOR=bac --dart-define=APP_NAME="BAC manager" --dart-define=COMPANY_NAME="Business Manager"`

   **For Komusoft:**
   - Flavor: `komusoft`
   - Dart entry point: `lib/main.dart`
   - Build mode: `Debug` or `Release`
   - Additional run args: `--dart-define=FLAVOR=komusoft --dart-define=APP_NAME="Komusoft Solns" --dart-define=COMPANY_NAME="Komusoft Solutions Ltd" --dart-define=BOT_USERNAME=test.account123@qc.com --dart-define=BOT_PASSWORD=Ba@123456`

4. Click **OK** and run from the device selector

---

## Building the App

### Debug APK
```
flutter build apk --debug --flavor bac --dart-define=FLAVOR=bac --dart-define=APP_NAME="BAC manager" --dart-define=COMPANY_NAME="Business Manager"
```

### Release APK
```
flutter build apk --release --flavor bac --dart-define=FLAVOR=bac --dart-define=APP_NAME="BAC manager" --dart-define=COMPANY_NAME="Business Manager"
```

Replace `--flavor bac` with `--flavor komusoft` and adjust the `--dart-define` values for other flavors.

---

## Adding a New Company Flavor

### 1. Update `android/app/build.gradle.kts`

Add a new flavor block (around lines 15-19):

```kotlin
create("newcompany") {
    dimension = "company"
    applicationId = "com.newcompany.businessmanager"
    resValue("string", "app_name", "New Company Name")
}
```

### 2. Create Android Resources

Create folder: `android/app/src/newcompany/res/values/`

Create file `strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">New Company Name</string>
</resources>
```

### 3. Create Asset Files

Create folder: `assets/flavors/newcompany/`

Add the following files:
- `logo.png`
- `app_icon.png`

Then run:
```
flutter pub run flutter_launcher_icons -f flutter_launcher_icons-flavor.yaml
```

### 4. Update `pubspec.yaml`

Add the new asset path:
```yaml
- assets/flavors/newcompany/
```

---

## Available Flavors

| Flavor | App Name | COMPANY_NAME |
|--------|----------|---------------|
| bac | BAC manager | Business Manager |
| komusoft | Komusoft Solns | Komusoft Solutions Ltd |
| (add new) | (custom) | (custom) |