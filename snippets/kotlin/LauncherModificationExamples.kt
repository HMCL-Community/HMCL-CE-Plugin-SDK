package dev.hmclce.sdk.examples

import javafx.application.Platform
import javafx.scene.control.Alert
import org.jackhuang.hmcl.plugin.PluginContext
import org.jackhuang.hmcl.setting.GameDirectoryManager
import org.jackhuang.hmcl.ui.Controllers
import java.nio.file.Files

object LauncherModificationExamples {
    fun showDialog(message: String) {
        Controllers.dialog(message, "Plugin SDK")
    }

    fun showJavaFxAlert(context: PluginContext) {
        Platform.runLater {
            Alert(Alert.AlertType.INFORMATION).apply {
                initOwner(context.primaryStage)
                title = "Plugin SDK"
                headerText = "JavaFX Alert"
                contentText = "Plugins can create normal JavaFX UI."
                show()
            }
        }
    }

    fun changeWindowTitle(context: PluginContext, title: String) {
        Platform.runLater { context.primaryStage.title = title }
    }

    fun listGameInstances(): String {
        val repository = GameDirectoryManager.getSelectedRepository()
        return repository.versions.joinToString("\n") { it.id }
    }

    fun navigateToSettings() {
        Controllers.navigate(Controllers.getSettingsPage())
    }

    fun navigateToDownloadPage() {
        Controllers.getDownloadPage().showGameDownloads()
        Controllers.navigate(Controllers.getDownloadPage())
    }

    fun writePluginData(context: PluginContext, fileName: String, content: String) {
        val target = context.pluginDirectory.resolve(fileName)
        Files.createDirectories(target.parent)
        Files.writeString(target, content)
    }

    fun readPluginData(context: PluginContext, fileName: String): String {
        val target = context.pluginDirectory.resolve(fileName)
        return if (Files.exists(target)) Files.readString(target) else ""
    }
}
