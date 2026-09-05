package dev.hmclce.example.javapatch;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;
import org.jackhuang.hmcl.plugin.PluginPatchInvocation;
import org.jackhuang.hmcl.plugin.PluginPatchResult;
import org.jetbrains.annotations.NotNullByDefault;
import org.jetbrains.annotations.Nullable;

import java.util.Objects;

/// Demonstrates an observational Java Patch callback that leaves the invocation unchanged.
@NotNullByDefault
public final class JavaPatchPlugin implements Plugin {
    /// Launcher context retained only for the required manifest compatibility method.
    private @Nullable PluginContext context;

    /// Receives the package context after the plugin is created.
    ///
    /// @param context immutable launcher-provided plugin context
    @Override
    public void onLoad(PluginContext context) {
        this.context = Objects.requireNonNull(context, "context");
    }

    /// Activates this stateless observational example.
    @Override
    public void onEnable() {
    }

    /// Deactivates this stateless observational example.
    @Override
    public void onDisable() {
    }

    /// Preserves the supplied invocation without retaining or changing it.
    ///
    /// @param invocation immutable Patch invocation
    /// @return the shared unchanged Patch result
    @Override
    public PluginPatchResult onPatch(PluginPatchInvocation invocation) {
        Objects.requireNonNull(invocation, "invocation");
        return PluginPatchResult.unchanged();
    }

    /// Returns the manifest supplied during plugin loading.
    ///
    /// @return plugin package manifest
    /// @throws NullPointerException if called before the launcher invokes {@link #onLoad(PluginContext)}
    @Override
    public PluginManifest getManifest() {
        return Objects.requireNonNull(context, "context").getManifest();
    }
}
