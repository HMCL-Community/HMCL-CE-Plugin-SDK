package dev.hmclce.example.javalaunchhook;

import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginDataObject;
import org.jackhuang.hmcl.plugin.PluginDataValue;
import org.jackhuang.hmcl.plugin.PluginHookEvent;
import org.jackhuang.hmcl.plugin.PluginHookPoint;
import org.jackhuang.hmcl.plugin.PluginHookResult;
import org.jackhuang.hmcl.plugin.PluginManifest;

import java.util.ArrayList;
import java.util.List;

public final class JavaLaunchHookPlugin implements Plugin {
    private PluginContext context;

    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
        System.out.println("[Java Launch Hook] Loaded on HMCL " + context.getLauncherVersion());
    }

    @Override
    public void onEnable() {
        System.out.println("[Java Launch Hook] Enabled");
    }

    @Override
    public void onDisable() {
        System.out.println("[Java Launch Hook] Disabled");
    }

    @Override
    public void onUnload() {
        System.out.println("[Java Launch Hook] Unloaded");
    }

    @Override
    public PluginHookResult onHook(PluginHookEvent event) {
        if (event.point() != PluginHookPoint.BEFORE_GAME_LAUNCH) {
            return PluginHookResult.unchanged();
        }

        PluginDataObject data = event.data();
        PluginDataObject plan = data.requireObject("plan");
        PluginDataObject command = plan.requireObject("command");
        if (!"structured-java".equals(command.requireString("mode"))) {
            return PluginHookResult.unchanged();
        }

        List<PluginDataValue> jvmArguments = new ArrayList<>(command.requireArray("jvmArguments"));
        jvmArguments.add(PluginDataValue.string("-Dhmcl.example.launch-hook=true"));
        PluginDataObject updatedCommand = command.with(
                "jvmArguments", PluginDataValue.array(jvmArguments));
        PluginDataObject updatedPlan = plan.with(
                "command", PluginDataValue.object(updatedCommand));
        return PluginHookResult.replace(data.with(
                "plan", PluginDataValue.object(updatedPlan)));
    }

    @Override
    public PluginManifest getManifest() {
        return context.getManifest();
    }
}
