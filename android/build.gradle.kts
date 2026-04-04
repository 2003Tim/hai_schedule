allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val sharedBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(sharedBuildDir)

subprojects {
    val rootDrive = rootProject.projectDir.toPath().root?.toString()
    val projectDrive = project.projectDir.toPath().root?.toString()
    val buildDir =
        if (
            rootDrive != null &&
            projectDrive != null &&
            rootDrive.equals(projectDrive, ignoreCase = true)
        ) {
            sharedBuildDir.dir(project.name)
        } else {
            project.layout.projectDirectory.dir("build")
        }
    project.layout.buildDirectory.value(buildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
