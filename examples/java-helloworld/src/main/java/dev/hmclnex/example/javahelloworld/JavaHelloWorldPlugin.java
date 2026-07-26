package dev.hmclnex.example.javahelloworld;

import com.jfoenix.controls.JFXButton;
import javafx.beans.property.ReadOnlyObjectProperty;
import javafx.beans.property.ReadOnlyObjectWrapper;
import javafx.geometry.Insets;
import javafx.scene.control.Label;
import javafx.scene.layout.VBox;
import org.jackhuang.hmcl.plugin.Plugin;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.plugin.PluginManifest;
import org.jackhuang.hmcl.plugin.PluginPermission;
import org.jackhuang.hmcl.plugin.PluginPermissionException;
import org.jackhuang.hmcl.ui.Controllers;
import org.jackhuang.hmcl.ui.decorator.DecoratorPage;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;

public final class JavaHelloWorldPlugin implements Plugin {
    private PluginContext context;

    @Override
    public void onLoad(PluginContext context) {
        this.context = context;
        log("Loaded on HMCL " + context.getLauncherVersion());
    }

    @Override
    public void onEnable() {
        log("Enabled");
        if (!context.isPermissionGranted(PluginPermission.LAUNCHER_UI)) {
            log("Launcher UI permission denied; continuing without a sidebar page");
            return;
        }

        // Register a sidebar item in the launcher's plugin menu.
        // Clicking it navigates to this plugin's custom page.
        try {
            context.registerSidebarItem("Java HelloWorld", () -> runWithLauncherUi(context, () ->
                    Controllers.navigate(new HelloWorldPage(context))));
        } catch (PluginPermissionException exception) {
            // The user may revoke permission between the query and registration.
            log("Launcher UI permission changed; continuing without a sidebar page");
        }
    }

    @Override
    public void onDisable() {
        log("Disabled");
    }

    @Override
    public void onUnload() {
        log("Unloaded");
    }

    @Override
    public PluginManifest getManifest() {
        return context.getManifest();
    }

    private void log(String message) {
        try {
            Path log = context.getDataDirectory().resolve("java-helloworld.log");
            Files.writeString(log, LocalDateTime.now() + " " + message + System.lineSeparator(),
                    java.nio.file.StandardOpenOption.CREATE, java.nio.file.StandardOpenOption.APPEND);
        } catch (Exception ignored) {
        }
    }

    private static void runWithLauncherUi(PluginContext context, Runnable action) {
        try {
            context.requirePermission(PluginPermission.LAUNCHER_UI);
            action.run();
        } catch (PluginPermissionException exception) {
            System.err.println("[Java HelloWorld] Launcher UI permission denied: " + exception.getReason());
        }
    }

    public static final class HelloWorldPage extends VBox implements DecoratorPage {
        private final ReadOnlyObjectWrapper<State> state = new ReadOnlyObjectWrapper<>(State.fromTitle("Java Plugin Page"));
        private final PluginContext context;

        public HelloWorldPage(PluginContext context) {
            this.context = context;
            setPadding(new Insets(24));
            setSpacing(12);

            Label title = new Label("Java HelloWorld Page");
            title.setStyle("-fx-font-size: 24px; -fx-font-weight: bold;");

            Label info = new Label("Plugin directory: " + context.getPluginDirectory() + "\nHMCL data directory: " + context.getDataDirectory());
            info.setWrapText(true);

            JFXButton dialogButton = new JFXButton("Show launcher dialog");
            dialogButton.getStyleClass().add("jfx-button-raised");
            dialogButton.setOnAction(e -> runWithLauncherUi(context, () ->
                    Controllers.dialog("Hello from Java plugin page.", "Java Plugin")));

            JFXButton stageButton = new JFXButton("Modify window title");
            stageButton.setOnAction(e -> runWithLauncherUi(context, () ->
                    context.getPrimaryStage().setTitle("HMCL - Modified by Java Plugin")));

            JFXButton writeButton = new JFXButton("Write plugin data file");
            writeButton.setOnAction(e -> runWithLauncherUi(context, () -> {
                try {
                    Files.writeString(context.getDataDirectory().resolve("data.txt"), "Java plugin wrote this file.\n");
                    Controllers.dialog("data.txt written.", "Java Plugin");
                } catch (Exception ex) {
                    Controllers.dialog(ex.toString(), "Java Plugin Error");
                }
            }));

            getChildren().setAll(title, info, dialogButton, stageButton, writeButton);
        }

        @Override
        public ReadOnlyObjectProperty<State> stateProperty() {
            return state.getReadOnlyProperty();
        }
    }
}
