plugins {
    java
    id("org.openjfx.javafxplugin") version "0.1.0"
}

repositories {
    mavenCentral()
}

val hmclJar = System.getenv("HMCL_JAR")?.let(::file)
    ?: fileTree("../../../../HMCL-CE/HMCL/build/libs") { include("HMCL-*.jar") }
        .files.maxByOrNull { it.lastModified() }
    ?: error("Build HMCL first or set HMCL_JAR")

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

tasks.withType<AbstractArchiveTask>().configureEach {
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}

tasks.jar {
    archiveBaseName.set("java-helloworld")
}

tasks.register<Zip>("packageNpl") {
    dependsOn(tasks.jar)
    archiveFileName.set("dev.hmclce.example.java.helloworld-v1.0.0.npl")
    destinationDirectory.set(layout.buildDirectory.dir("npl"))
    from("plugin.json")
    into("libs") {
        from(tasks.jar)
    }
}
