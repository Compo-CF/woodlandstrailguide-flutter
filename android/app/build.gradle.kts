import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load the upload keystore password + path from android/key.properties.
// That file is git-ignored — never committed. If it's missing (e.g. on CI
// without the secret provisioned), we fall back to debug signing so the
// project still builds, just not with a Play-Store-uploadable signature.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.compofelice.woodlandstrailguide_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.compofelice.woodlandstrailguide_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.getProperty("storeFile") != null) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Use the release signing config if key.properties is present,
            // otherwise fall back to debug so local builds still work.
            signingConfig = if (keystoreProperties.getProperty("storeFile") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// in_app_purchase_android bundles a legacy "Sign in with Google" button
// resource file (common_google_signin_btn_text_dark/light.xml) that
// references color resources Google removed from newer
// play-services-base/basement releases. Bumping google_mobile_ads to
// 9.0.0 pulled in a newer, incompatible version of those libraries via
// a different transitive path, so AAPT2 fails to link — "resource
// color/common_google_signin_btn_text_dark_disabled ... not found".
// Forcing both to a version that still ships those resources resolves
// the conflict for every module in the dependency graph at once.
configurations.all {
    resolutionStrategy {
        force("com.google.android.gms:play-services-base:18.3.0")
        force("com.google.android.gms:play-services-basement:18.3.0")
    }
}
