package dev.hmclce.example.javamixin.mixin;

import org.jackhuang.hmcl.Launcher;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/// Adds a harmless startup marker before `Launcher.main` executes.
@Mixin(Launcher.class)
public abstract class LauncherMixin {
    /// Prevents construction of the Mixin utility class.
    private LauncherMixin() {
    }

    /// Records that startup bytecode injection ran before the normal launcher entry point.
    ///
    /// @param args launcher arguments
    /// @param callback callback metadata supplied by Mixin
    @Inject(method = "main", at = @At("HEAD"))
    private static void hmclCe$markMixinApplied(String[] args, CallbackInfo callback) {
        System.setProperty("hmcl.example.mixin.applied", "true");
        System.out.println("[HMCL Mixin Example] Launcher.main injection applied");
    }
}
