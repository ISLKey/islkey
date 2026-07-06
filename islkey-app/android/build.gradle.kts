import com.android.build.api.dsl.CommonExtension

allprojects {
    repositories {
        google()
        mavenCentral()
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

    // Some plugins (e.g. nfc_manager) hardcode an old compileSdk (31) that is
    // lower than what their own AndroidX dependencies now require (34+). Force
    // every Android subproject to compile against a modern SDK so the build
    // succeeds. Registered here, BEFORE evaluationDependsOn below triggers
    // evaluation — moving it after throws "project already evaluated".
    afterEvaluate {
        val androidExt = extensions.findByType(CommonExtension::class.java)
        if (androidExt != null && (androidExt.compileSdk ?: 0) < 36) {
            androidExt.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
