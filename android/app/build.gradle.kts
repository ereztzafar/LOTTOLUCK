plugins {
    id("com.android.application")
    id("kotlin-android")
    // ה‑Flutter Gradle Plugin חייב להיות אחרי Android ו‑Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// קריאת גרסאות מתוך pubspec.yaml
val flutterVersionCode = project.findProperty("flutter.versionCode")?.toString()?.toInt() ?: 1
val flutterVersionName = project.findProperty("flutter.versionName")?.toString() ?: "1.0.0"

android {
    // שם חבילה סופי ויחיד
    namespace = "com.lottoluck.app"

    // לפי דרישת Google Play – יש לכוון ל־API 35 לפחות
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.lottoluck.app"
        minSdk = flutter.minSdkVersion
        // עמידה בדרישה שעד 31 באוגוסט 2025 כל האפליקציות יטרגטו API 35 לפחות:contentReference[oaicite:0]{index=0}.
        targetSdk = 35
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    signingConfigs {
        // קונפיגורציית חתימה עבור ריליס; קורא נתוני סיסמה ומפתח מתוך key.properties
        create("release") {
            val props = java.util.Properties()
            val propsFile = rootProject.file("android/key.properties")
            if (propsFile.exists()) {
                props.load(java.io.FileInputStream(propsFile))
                storeFile = props["storeFile"]?.let { file(it as String) }
                storePassword = props["storePassword"] as String?
                keyAlias = props["keyAlias"] as String?
                keyPassword = props["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("release") {
            // שימוש בחתימה אמיתית ובכיווץ משאבים (לשיפור ביצועים והקטנת גודל)
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // השארת ברירת מחדל
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
    // SDK לפרסומות (AdMob) – תואם ל‑API 35
    implementation("com.google.android.gms:play-services-ads:23.4.0")
    // תמיכה במולטי‑דקס במידת הצורך
    implementation("androidx.multidex:multidex:2.0.1")
}
