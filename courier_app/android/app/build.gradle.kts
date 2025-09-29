plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.courier.delivery_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.courier.delivery_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion  // Set minimum SDK to 21 for better compatibility
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }
    signingConfigs{
        create("release") {
            storeFile = file(findProperty("APP_UPLOAD_STORE_FILE") as String)
            storePassword = findProperty("APP_UPLOAD_STORE_PASSWORD") as String
            keyAlias = findProperty("APP_UPLOAD_KEY_ALIAS") as String
            keyPassword = findProperty("APP_UPLOAD_KEY_PASSWORD") as String
        }
        create("develop") {
            storeFile = file(findProperty("APP_UPLOAD_STORE_FILE") as String)
            storePassword = findProperty("APP_UPLOAD_STORE_PASSWORD") as String
            keyAlias = findProperty("APP_UPLOAD_KEY_ALIAS") as String
            keyPassword = findProperty("APP_UPLOAD_KEY_PASSWORD") as String
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("develop")
            }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
