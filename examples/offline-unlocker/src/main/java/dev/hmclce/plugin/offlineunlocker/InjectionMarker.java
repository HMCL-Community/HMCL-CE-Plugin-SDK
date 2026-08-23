package dev.hmclce.plugin.offlineunlocker;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;

/**
 * Records that the mixin injection executed.
 *
 * <p>The mixin runs from the pre-main agent, before the plugin lifecycle starts,
 * so {@link org.jackhuang.hmcl.plugin.PluginContext} is not available yet and
 * {@code System.out} has not been rebound to the launcher's logging pipeline.
 * A println at that point is effectively invisible. Writing to a fixed path
 * keeps the injection verifiable.
 *
 * <p>Resolves against {@code hmcl.dir} so the marker lands inside whichever
 * profile is active, including isolated test profiles.
 */
final class InjectionMarker {
    private static final String PLUGIN_ID = "dev.hmclce.offlineunlocker";

    private InjectionMarker() {
    }

    static void record(String message) {
        try {
            String localHome = System.getProperty("hmcl.dir", System.getenv("HMCL_LOCAL_HOME"));
            Path base = localHome != null && !localHome.isBlank()
                    ? Path.of(localHome)
                    : Path.of(System.getProperty("user.dir"), ".hmcl");

            Path dir = base.resolve("plugin-data").resolve(PLUGIN_ID);
            Files.createDirectories(dir);

            Files.writeString(dir.resolve("injection.log"),
                    LocalDateTime.now() + " [mixin] " + message + System.lineSeparator(),
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (Exception ignored) {
            // Never let diagnostics break class initialisation of the target.
        }
    }
}
