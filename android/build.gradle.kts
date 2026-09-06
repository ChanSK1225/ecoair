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
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.test" &&
                requested.name == "runner" && requested.version == "1.2+") {
                // Flutter integration_test uses a dynamic version; keep builds reproducible.
                useVersion("1.3.0")
                because("Use the tested AndroidX runner without a dynamic Maven lookup")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
