import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    kotlin("jvm") version "2.3.0"
    id("org.openjfx.javafxplugin") version "0.1.0"
}

repositories {
    mavenCentral()
}

val hmclJar = file(System.getenv("HMCL_JAR") ?: "../../../HMCL/HMCL/build/libs/HMCL-3.17.SNAPSHOT.jar")

dependencies {
    compileOnly(files(hmclJar))
}

javafx {
    version = "17.0.16"
    modules("javafx.controls")
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
}

tasks.jar {
    archiveBaseName.set("kotlin-helloworld")
}

tasks.register<Zip>("packageNpl") {
    dependsOn(tasks.jar)
    archiveFileName.set("dev.hmclnex.example.kotlin.helloworld-v1.0.0.npl")
    destinationDirectory.set(layout.buildDirectory.dir("npl"))
    from("plugin.json")
    into("libs") {
        from(tasks.jar)
        from(configurations.runtimeClasspath.map { files ->
            files.filter { it.name.startsWith("kotlin-stdlib") }
        })
    }
}
