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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    if (project.state.executed) {
        val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (androidExt != null && androidExt.namespace == null) {
            androidExt.namespace = project.group.toString()
        }
        // Force API 36 if already executed
        if (plugins.hasPlugin("com.android.library")) {
            configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
            }
        }
    } else {
        project.afterEvaluate {
            val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (androidExt != null && androidExt.namespace == null) {
                androidExt.namespace = project.group.toString()
            }
            // Force API 36 safely inside the existing evaluation
            if (plugins.hasPlugin("com.android.library")) {
                configure<com.android.build.gradle.LibraryExtension> {
                    compileSdk = 36
                }
            }
        }
    }
}