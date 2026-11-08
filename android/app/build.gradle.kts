plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lonyogang.lonyogang_heritage"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications + timezone transitive deps require
        // core library desugaring for java.time on < API 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lonyogang.lonyogang_heritage"
        // flutter_local_notifications needs API 21+; bump min above the
        // flutter default (which is 21 anyway) to keep that pinned.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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

dependencies {
    // Keeps java.time + ThreeTen-style APIs usable on API 21-25 where
    // the OS doesn't ship them. flutter_local_notifications transitively
    // demands this for scheduled notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
