package dev.hmclnex.plugin.offlineunlocker;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;

public final class OfflineUnlockerPlugin implements Plugin {
    private PluginContext context;

    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
        log("Plugin loaded on HMCL " + context.getLauncherVersion());
        log("Mixin will unlock offline account restrictions during static initialization");
    }

    @Override
    public void onEnable() {
        log("Plugin enabled");
    }

    @Override
    public void onDisable() {
        log("Plugin disabled");
    }

    @Override
    public void onUnload() {
        log("Plugin unloaded");
    }

    @Override
    public PluginManifest getManifest() {
        return context.getManifest();
    }

    private void log(String message) {
        try {
            Path logFile = context.getDataDirectory().resolve("offline-unlocker.log");
            String entry = LocalDateTime.now() + " [OfflineUnlocker] " + message + System.lineSeparator();
            Files.writeString(logFile, entry,
                    java.nio.file.StandardOpenOption.CREATE,
                    java.nio.file.StandardOpenOption.APPEND);
        } catch (Exception ignored) {
        }
    }
}
