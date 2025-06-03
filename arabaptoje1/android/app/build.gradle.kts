plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ Firebase için gerekli plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.arabaptoje1"

    // ✅ Firebase ve Google Maps için NDK 27 gerekli
    ndkVersion = "27.0.12077973"

    // ✅ Android 23 ve üstü gerekiyor (firebase_auth vs.)
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.arabaptoje1"
        minSdk = 23 // <-- burada düzeltme yapıldı
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
