package dev.hmclce.sdk.examples;

import javafx.application.Platform;
import javafx.scene.control.Alert;
import org.jackhuang.hmcl.game.HMCLGameRepository;
import org.jackhuang.hmcl.plugin.PluginContext;
import org.jackhuang.hmcl.setting.GameDirectoryManager;
import org.jackhuang.hmcl.ui.Controllers;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;

public final class LauncherModificationExamples {
    private LauncherModificationExamples() {
    }

    public static void showDialog(String message) {
        Controllers.dialog(message, "Plugin SDK");
    }

    public static void showJavaFxAlert(PluginContext context) {
        Platform.runLater(() -> {
            Alert alert = new Alert(Alert.AlertType.INFORMATION);
            alert.initOwner(context.getPrimaryStage());
            alert.setTitle("Plugin SDK");
            alert.setHeaderText("JavaFX Alert");
            alert.setContentText("Plugins can create normal JavaFX UI.");
            alert.show();
        });
    }

    public static void changeWindowTitle(PluginContext context, String title) {
        Platform.runLater(() -> context.getPrimaryStage().setTitle(title));
    }

    public static String listGameInstances() {
        HMCLGameRepository repository = GameDirectoryManager.getSelectedRepository();
        return repository.getVersions().stream()
                .map(version -> version.getId())
                .collect(Collectors.joining("\n"));
    }

    public static void navigateToSettings() {
        Controllers.navigate(Controllers.getSettingsPage());
    }

    public static void navigateToDownloadPage() {
        Controllers.getDownloadPage().showGameDownloads();
        Controllers.navigate(Controllers.getDownloadPage());
    }

    public static void writePluginData(PluginContext context, String fileName, String content) throws Exception {
        Path target = context.getPluginDirectory().resolve(fileName);
        Files.createDirectories(target.getParent());
        Files.writeString(target, content);
    }

    public static String readPluginData(PluginContext context, String fileName) throws Exception {
        Path target = context.getPluginDirectory().resolve(fileName);
        return Files.exists(target) ? Files.readString(target) : "";
    }
}
