# Business Manager - Setup Guide

## Running the App

### Using Command Line

**BAC flavor:**
```
flutter run --flavor bac -t lib/main.dart --dart-define=FLAVOR=bac --dart-define=APP_NAME="BAC manager" --dart-define=COMPANY_NAME="Business Manager"
```

**Other flavors:** Use the corresponding args from the Available Flavors table.

### Using Android Studio

1. Go to **Run > Edit Configurations**
2. Click **+** and select **Flutter**
3. Set:
   - Dart entry point: `lib/main.dart`
   - Build mode: **Debug** or **Release**
   - Flavor: (select from table below)
   - Additional run args: (see table below)
4. Click **OK** and run from the device selector

---

## Building the App

### Debug APK
```
flutter build apk --debug --flavor <flavor> --dart-define=FLAVOR=<flavor> --dart-define=APP_NAME="<app_name>" --dart-define=COMPANY_NAME="<company_name>" --dart-define=BOT_USERNAME=<bot_username> --dart-define=BOT_PASSWORD=<bot_password>
```

### Release APK
Same as above, replace `--debug` with `--release`.

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

Add files: `logo.png`, `app_icon.png`

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
|--------|----------|--------------|--------------|--------------|
| bac | BAC manager | Business Manager | 
| komusoft | Komusoft Solns | Komusoft Solutions Ltd |
| fitzone | Fitzone Gym | Fitzone Gym |
| mega | Standard Supermarket | Standard Supermarket |
| top_grade | Top Grade | Top Grade Genetics |
