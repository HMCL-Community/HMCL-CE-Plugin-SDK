plugins {
    java
}

repositories {
    mavenCentral()
    maven("https://repo.spongepowered.org/repository/maven-public/")
}

val auraLauncherJar = System.getenv("HMCL_JAR")
    ?.takeIf(String::isNotBlank)
    ?.let(::file)
    ?.takeIf { it.isFile }
    ?: error("Set HMCL_JAR to an Aura Launcher Next JAR")

dependencies {
    compileOnly(files(auraLauncherJar))
    compileOnly("org.spongepowered:mixin:0.8.7")
    annotationProcessor("org.spongepowered:mixin:0.8.7:processor")
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
    options.compilerArgs.addAll(listOf("-proc:none"))
}

tasks.withType<AbstractArchiveTask>().configureEach {
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}

tasks.jar {
    archiveBaseName.set("java-mixin-example")
}

tasks.register<Zip>("packageNpl") {
    dependsOn(tasks.jar)
    archiveFileName.set("dev.hmclce.example.java.mixin-v1.0.0.npl")
    destinationDirectory.set(layout.buildDirectory.dir("npl"))
    from("plugin.json")
    into("libs") {
        from(tasks.jar)
    }
}
