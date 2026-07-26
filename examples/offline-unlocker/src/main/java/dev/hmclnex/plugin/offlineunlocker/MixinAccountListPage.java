package dev.hmclnex.plugin.offlineunlocker;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import javafx.beans.property.BooleanProperty;

@Mixin(targets = "org.jackhuang.hmcl.ui.account.AccountListPage", remap = false)
public class MixinAccountListPage {
    @Shadow(remap = false)
    private static BooleanProperty RESTRICTED;

    @Inject(method = "<clinit>", at = @At("TAIL"), remap = false)
    private static void onStaticInit(CallbackInfo ci) {
        // Force unlock offline accounts by setting RESTRICTED to false
        if (RESTRICTED != null) {
            RESTRICTED.set(false);
            // Injection runs from the pre-main agent, before HMCL rebinds System.out
            // to its logging pipeline, so a println here does not reach the launcher
            // log. Write to a file instead so the injection stays observable.
            InjectionMarker.record("RESTRICTED set to false");
        }
    }
}
