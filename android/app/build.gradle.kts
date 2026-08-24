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
    namespace = "com.compofelice.woodlandstrailguide"
    // Pinned above Flutter's own default (which resolved to 33 on at
    // least one build machine) — adding the geocoding package pulled in
    // a newer AndroidX dependency chain (exifinterface 1.4.1, then
    // navigationevent-android 1.0.2) that kept demanding one API level
    // higher each time 34 and then 35 were tried. Jumped straight to the
    // current latest (36) rather than chasing it one bump at a time.
    // Bumping targetSdk to match so the two stay consistent; minSdk is
    // untouched.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.compofelice.woodlandstrailguide"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
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

// NOTE: the play-services-base/basement version force that used to
// live here moved to the root android/build.gradle.kts's allprojects
// block — a fix scoped to just :app never reaches the
// :in_app_purchase_android subproject, which is where the resource
// conflict actually happens.
