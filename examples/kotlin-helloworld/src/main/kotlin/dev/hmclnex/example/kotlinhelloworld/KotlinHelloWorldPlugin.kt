package dev.hmclnex.example.kotlinhelloworld

import com.jfoenix.controls.JFXButton
import javafx.application.Platform
import javafx.beans.property.ReadOnlyObjectProperty
import javafx.beans.property.ReadOnlyObjectWrapper
import javafx.geometry.Insets
import javafx.scene.control.Label
import javafx.scene.layout.VBox
import org.jackhuang.hmcl.plugin.Plugin
import org.jackhuang.hmcl.plugin.PluginContext
import org.jackhuang.hmcl.plugin.PluginManifest
import org.jackhuang.hmcl.ui.Controllers
import org.jackhuang.hmcl.ui.decorator.DecoratorPage
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import java.time.LocalDateTime

class KotlinHelloWorldPlugin : Plugin {
    private lateinit var context: PluginContext

    override fun onLoad(context: PluginContext) {
        this.context = context
        log("Loaded on HMCL ${context.launcherVersion}")
    }

    override fun onEnable() {
        log("Enabled")
        // Register a sidebar item in the launcher's plugin menu.
        context.registerSidebarItem("Kotlin HelloWorld") {
            Controllers.navigate(HelloWorldPage(context))
        }
    }

    override fun onDisable() {
        log("Disabled")
    }

    override fun onUnload() {
        log("Unloaded")
    }

    override fun getManifest(): PluginManifest = context.manifest

    private fun log(message: String) {
        runCatching {
            Files.writeString(
                context.pluginDirectory.resolve("kotlin-helloworld.log"),
                "${LocalDateTime.now()} $message${System.lineSeparator()}",
                StandardOpenOption.CREATE,
                StandardOpenOption.APPEND
            )
        }
    }

    class HelloWorldPage(private val context: PluginContext) : VBox(), DecoratorPage {
        private val state = ReadOnlyObjectWrapper(DecoratorPage.State.fromTitle("Kotlin Plugin Page"))

        init {
            padding = Insets(24.0)
            spacing = 12.0

            val title = Label("Kotlin HelloWorld Page").apply {
                style = "-fx-font-size: 24px; -fx-font-weight: bold;"
            }
            val info = Label("Plugin directory: ${context.pluginDirectory}\nHMCL data directory: ${context.dataDirectory}").apply {
                isWrapText = true
            }
            val dialogButton = JFXButton("Show launcher dialog").apply {
                styleClass.add("jfx-button-raised")
                setOnAction { Controllers.dialog("Hello from Kotlin plugin page.", "Kotlin Plugin") }
            }
            val titleButton = JFXButton("Modify window title").apply {
                setOnAction { context.primaryStage.title = "HMCL - Modified by Kotlin Plugin" }
            }
            val writeButton = JFXButton("Write plugin data file").apply {
                setOnAction {
                    runCatching {
                        Files.writeString(context.pluginDirectory.resolve("data.txt"), "Kotlin plugin wrote this file.\n")
                        Controllers.dialog("data.txt written.", "Kotlin Plugin")
                    }.onFailure {
                        Controllers.dialog(it.toString(), "Kotlin Plugin Error")
                    }
                }
            }

            children.setAll(title, info, dialogButton, titleButton, writeButton)
        }

        override fun stateProperty(): ReadOnlyObjectProperty<DecoratorPage.State> = state.readOnlyProperty
    }
}
