allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // The stub colors/dimens/style in android/stub_resources exist because
    // in_app_purchase_android's own AAR references resources that no
    // current Play Services / AndroidX Core release ships (see the XML
    // file's own comment for the full story). Its verifyReleaseResources
    // task checks THAT MODULE'S OWN resources — a stub living under
    // :app's res never reaches it, since :app depends on this library,
    // not the reverse. Confirmed via `withPlugin` (not afterEvaluate) so
    // this runs as soon as the subproject applies com.android.library,
    // regardless of evaluation order between this file and the
    // subproject's own build.gradle.
    if (name == "in_app_purchase_android") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                sourceSets.getByName("main").res.srcDir(
                    rootProject.file("stub_resources/in_app_purchase_android/res")
                )
            }
        }
    }

    // Force every plugin's own Android library module onto the same
    // compileSdk as :app. Plugin AARs (geocoding_android is the one that
    // surfaced this) ship their own build.gradle reading
    // flutter.compileSdkVersion directly — which resolves to a stale,
    // much-lower value on at least one build machine and trips AGP's
    // cross-module compileSdk consistency check, even though :app's own
    // build.gradle.kts already pins a newer literal. :app itself doesn't
    // need this — its compileSdk is already an explicit literal.
    //
    // Must be afterEvaluate, not withPlugin like the block above: a
    // withPlugin callback fires the instant the plugin is applied, which
    // is BEFORE the subproject's own build.gradle reaches its own
    // `compileSdk = flutter.compileSdkVersion` line further down that
    // same script — so that later assignment was winning and clobbering
    // this override. afterEvaluate runs once the whole subproject script
    // (including that later line) has already finished.
    pluginManager.withPlugin("com.android.library") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
            }
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
