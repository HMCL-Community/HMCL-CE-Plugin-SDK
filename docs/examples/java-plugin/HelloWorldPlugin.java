package com.example.hello;

import javafx.application.Platform;
import javafx.scene.control.Alert;
import javafx.scene.control.Alert.AlertType;
import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;

/**
 * A simple example plugin that shows a greeting message.
 */
public class HelloWorldPlugin implements Plugin {
    
    private PluginManifest manifest;
    private PluginContext context;
    
    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
        this.manifest = context.getManifest();
        
        System.out.println("[HelloWorld] Plugin loaded!");
        System.out.println("[HelloWorld] HMCL Version: " + context.getLauncherVersion());
    }
    
    @Override
    public void onEnable() {
        System.out.println("[HelloWorld] Plugin enabled!");
        
        // Show a greeting dialog on the JavaFX thread
        Platform.runLater(() -> {
            Alert alert = new Alert(AlertType.INFORMATION);
            alert.setTitle("Hello World");
            alert.setHeaderText("Plugin Loaded Successfully");
            alert.setContentText(
                "Hello from " + manifest.getName() + " v" + manifest.getVersion() + "!\n\n" +
                "This is a simple example plugin for HMCL.\n" +
                "Author: " + manifest.getAuthor()
            );
            alert.initOwner(context.getPrimaryStage());
            alert.show();
        });
    }
    
    @Override
    public void onDisable() {
        System.out.println("[HelloWorld] Plugin disabled!");
    }
    
    @Override
    public void onUnload() {
        System.out.println("[HelloWorld] Plugin unloaded!");
    }
    
    @Override
    public PluginManifest getManifest() {
        return manifest;
    }
}
