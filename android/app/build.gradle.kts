plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.lottoluck"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.lottoluck"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // בראש הקובץ או לפני android { ... } הוסף:
val flutterVersionCode = project.findProperty("flutter.versionCode")?.toString()?.toInt() ?: 1
val flutterVersionName = project.findProperty("flutter.versionName")?.toString() ?: "1.0"

android {
    // ... שאר ההגדרות

    defaultConfig {
        applicationId = "com.yourcompany.lottoluck"   // עדכן לשם החבילה שלך
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // השתמש במשתנים שיצרנו
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }
}

    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
