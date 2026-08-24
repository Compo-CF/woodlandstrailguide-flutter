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

    // NOTE: do NOT try to override a plugin subproject's compileSdk from
    // here. A plugin whose own build.gradle hardcodes `compileSdk N`
    // (geocoding_android 3.3.1 did, with N=33) cannot be overridden from
    // the root: withPlugin fires before that line runs, and afterEvaluate
    // is rejected outright ("It is too late to set compileSdk. It has
    // already been read to configure this project."). The fix for that
    // class of problem is to upgrade the offending package — see the
    // geocoding constraint in pubspec.yaml.
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
