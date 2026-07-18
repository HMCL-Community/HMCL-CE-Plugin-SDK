package dev.hmclnex.example.javamixin;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;

/// Demonstrates combining startup Mixin injection with the regular HMCL plugin lifecycle.
public final class JavaMixinPlugin implements Plugin {
    /// Context received when HMCL registers the lifecycle implementation.
    private PluginContext context;

    /// Stores the plugin context and reports whether the startup injection executed.
    ///
    /// @param context plugin context
    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
        System.out.println("[HMCL Mixin Example] lifecycle loaded; injected="
                + Boolean.getBoolean("hmcl.example.mixin.applied"));
    }

    /// Enables the lifecycle portion of the example.
    @Override
    public void onEnable() {
        System.out.println("[HMCL Mixin Example] enabled");
    }

    /// Disables the lifecycle portion of the example.
    @Override
    public void onDisable() {
        System.out.println("[HMCL Mixin Example] disabled");
    }

    /// Returns the authoritative package manifest.
    ///
    /// @return plugin manifest
    @Override
    public PluginManifest getManifest() {
        return context.getManifest();
    }
}
