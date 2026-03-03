plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.anime.darling"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.anime.darling"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

// Add this block at the very bottom:
dependencies {
    val media3Version = "1.5.1" // Newest stable version for Media3/ExoPlayer

    // Core ExoPlayer functionality
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    
    // Standard UI components (PlayerView, etc.)
    implementation("androidx.media3:media3-ui:$media3Version")
    
    // Support for HLS (needed for most anime streams)
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    
    // OkHttp extension to handle custom headers/Referers
    implementation("androidx.media3:media3-datasource-okhttp:$media3Version")

    // General AndroidX core for Kotlin compatibility
    implementation("androidx.core:core-ktx:1.12.0")
}
