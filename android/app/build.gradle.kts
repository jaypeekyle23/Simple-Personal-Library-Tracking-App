plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_library_tracker"
    
    // CHANGED: Bumped to 36 to satisfy the latest Flutter plugins
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ADDED: Enable desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_library_tracker"
        minSdk = flutter.minSdkVersion
        
        // CHANGED: Bumped to 36 to match compileSdk
        targetSdk = 36
        
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

dependencies {
    // UPDATED: Use 2.1.4 as requested by the error message
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}