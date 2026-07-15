allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // in_app_purchase_android bundles a legacy "Sign in with Google"
    // button resource file (common_google_signin_btn_text_dark/light.xml)
    // that references color/dimen resources Google removed from newer
    // play-services-base/basement releases. Bumping google_mobile_ads to
    // 9.0.0 pulled in a newer, incompatible version of those libraries
    // via a different transitive path, so AAPT2 fails to link inside
    // the :in_app_purchase_android module itself — "resource
    // color/common_google_signin_btn_text_dark_disabled ... not found".
    // This MUST live in allprojects (not just :app's build.gradle) since
    // the failing verifyReleaseResources/mergeReleaseResources task
    // belongs to the in_app_purchase_android subproject, which has its
    // own configurations that a fix scoped to :app never touches.
    configurations.all {
        resolutionStrategy {
            force("com.google.android.gms:play-services-base:18.3.0")
            force("com.google.android.gms:play-services-basement:18.3.0")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
