plugins {
    java
}

repositories {
    mavenCentral()
    maven("https://repo.spongepowered.org/repository/maven-public/")
}

val hmclJar = System.getenv("HMCL_JAR")?.let(::file)
    ?: fileTree("../../../HMCL-CE/HMCL/build/libs") { include("HMCL-*.jar") }
        .files.maxByOrNull { it.lastModified() }
    ?: error("Build HMCL first or set HMCL_JAR")

dependencies {
    compileOnly(files(hmclJar))
    compileOnly("org.spongepowered:mixin:0.8.7")
    annotationProcessor("org.spongepowered:mixin:0.8.7:processor")
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
    options.compilerArgs.addAll(listOf("-proc:none"))
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
