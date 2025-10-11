// Imports נחוצים ל-Kotlin DSL
import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // ה-Flutter Gradle Plugin חייב להיות אחרי Android ו-Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// קריאת גרסאות מתוך pubspec.yaml
val flutterVersionCode = project.findProperty("flutter.versionCode")?.toString()?.toInt() ?: 1
val flutterVersionName = project.findProperty("flutter.versionName")?.toString() ?: "1.0.0"

android {
    // שם חבילה סופי ויחיד
    namespace = "com.lottoluck.app"

    // דרישה עדכנית של Google Play - יעד API 35
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.lottoluck.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val props = Properties()
            val propsFile: File = rootProject.file("android/key.properties")
            if (propsFile.exists()) {
                props.load(FileInputStream(propsFile))
                val storePath = props["storeFile"] as String?
                if (storePath != null) {
                    storeFile = file(storePath)
                }
                storePassword = props["storePassword"] as String?
                keyAlias = props["keyAlias"] as String?
                keyPassword = props["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // ברירת מחדל
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}

dependencies {
    // SDK לפרסומות AdMob
    implementation("com.google.android.gms:play-services-ads:23.4.0")
    // תמיכה במולטי דקס
    implementation("androidx.multidex:multidex:2.0.1")
}
