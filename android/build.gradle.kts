import org.gradle.kotlin.dsl.support.serviceOf

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
// maplibre_gl targets Java 21, but ~/.gradle pins the Gradle JVM to 17 for older projects.
// Compile Java with the newer JDK listed in gradle.properties;
// the app must read maplibre classes too. Nothing global changes.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        javaCompiler.set(
            serviceOf<JavaToolchainService>().compilerFor { languageVersion.set(JavaLanguageVersion.of(25)) },
        )
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
