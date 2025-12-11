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
    ndkVersion = "29.0.14206865"

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
        targetSdk = 36
        versionCode = 7
        versionName = "1.1.3"
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
    // useLegacyPackaging = false ensures native libraries are stored uncompressed
    // and aligned to 16 KB boundaries, which is required for 16 KB page size support
    packaging {
        jniLibs {
            useLegacyPackaging = false
            // Ensure native libraries are uncompressed and 16 KB aligned
            // AGP 8.5.1+ automatically aligns uncompressed .so files to 16 KB
        }
        // Ensure resources are properly aligned
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
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
    
    lint {
        // Don't abort build on lint errors - treat as warnings
        abortOnError = false
        // Check all issues but don't fail the build
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // AndroidX Core for FileProvider and edge-to-edge support
    implementation("androidx.core:core:1.13.1")
    // AndroidX Activity for edge-to-edge support (Android 15+)
    implementation("androidx.activity:activity:1.9.2")
}
