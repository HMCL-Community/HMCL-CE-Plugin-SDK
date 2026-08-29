plugins {
    java
}

repositories {
    mavenCentral()
}

val auraLauncherJar = System.getenv("HMCL_JAR")
    ?.takeIf(String::isNotBlank)
    ?.let(::file)
    ?.takeIf { it.isFile }
    ?: error("Set HMCL_JAR to an Aura Launcher Next JAR")

dependencies {
    compileOnly(files(auraLauncherJar))
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
}

tasks.withType<AbstractArchiveTask>().configureEach {
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}

tasks.jar {
    archiveBaseName.set("java-launch-hook")
}

tasks.register<Zip>("packageNpl") {
    dependsOn(tasks.jar)
    archiveFileName.set("dev.hmclce.example.java.launch-hook-v1.0.0.npl")
    destinationDirectory.set(layout.buildDirectory.dir("npl"))
    from("plugin.json")
    into("libs") {
        from(tasks.jar)
    }
}
