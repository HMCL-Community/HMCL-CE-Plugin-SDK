/**
 * Hello World JavaScript Plugin for HMCL
 * 
 * This script demonstrates the basic structure of a JavaScript plugin.
 */

// Global variables to store plugin state
var pluginManifest;
var pluginContext;

/**
 * Called when the plugin is loaded
 */
function onLoad(context) {
    pluginContext = context;
    pluginManifest = context.getManifest();
    
    print("[HelloWorldJS] Plugin loaded!");
    print("[HelloWorldJS] Plugin Name: " + pluginManifest.getName());
    print("[HelloWorldJS] Plugin Version: " + pluginManifest.getVersion());
    print("[HelloWorldJS] HMCL Version: " + context.getLauncherVersion());
}

/**
 * Called when the plugin is enabled
 */
function onEnable() {
    print("[HelloWorldJS] Plugin enabled!");
    
    // Import JavaFX classes
    var Platform = Java.type("javafx.application.Platform");
    var Alert = Java.type("javafx.scene.control.Alert");
    var AlertType = Java.type("javafx.scene.control.Alert$AlertType");
    
    // Show a greeting dialog on the JavaFX thread
    Platform.runLater(function() {
        var alert = new Alert(AlertType.INFORMATION);
        alert.setTitle("Hello World JS");
        alert.setHeaderText("JavaScript Plugin Loaded Successfully");
        alert.setContentText(
            "Hello from " + pluginManifest.getName() + " v" + pluginManifest.getVersion() + "!\n\n" +
            "This is a JavaScript plugin running in HMCL.\n" +
            "Author: " + pluginManifest.getAuthor()
        );
        alert.initOwner(pluginContext.getPrimaryStage());
        alert.show();
    });
}

/**
 * Called when the plugin is disabled
 */
function onDisable() {
    print("[HelloWorldJS] Plugin disabled!");
}

/**
 * Called when the plugin is unloaded (optional)
 */
function onUnload() {
    print("[HelloWorldJS] Plugin unloaded!");
}
