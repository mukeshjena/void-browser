import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.voidbrowser.void_browser"
    compileSdk = flutter.compileSdkVersion
    // NDK r28+ required for 16 KB page size support (Android 15+ / targetSdk 35)
    // Flutter manages NDK version, but we ensure it's compatible
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.voidbrowser.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 5
        versionName = "1.1.1"
        multiDexEnabled = true
        
        // Enable vector drawables to reduce APK size
        vectorDrawables.useSupportLibrary = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Enable code shrinking and obfuscation
            isMinifyEnabled = true
            // Enable resource shrinking
            isShrinkResources = true
            // Use ProGuard rules
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
    
    // Support for 16 KB memory page sizes (required for Android 15+ / targetSdk 35)
    // AGP 8.5.1+ automatically handles 16 KB alignment for native libraries
    // useLegacyPackaging = false ensures proper 16 KB page size support
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
    
    // Ensure proper alignment for 16 KB page sizes
    // AGP 8.5.1+ automatically aligns uncompressed shared libraries to 16 KB boundaries
    bundle {
        language {
            enableSplit = true
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // AndroidX Core for FileProvider
    implementation("androidx.core:core:1.12.0")
}
