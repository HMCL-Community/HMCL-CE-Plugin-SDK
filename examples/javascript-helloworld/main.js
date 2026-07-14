var pluginContext = null;
var pluginManifest = null;

function onLoad(context) {
    pluginContext = context;
    pluginManifest = context.getManifest();
    log('Loaded on HMCL ' + context.getLauncherVersion());
}

function onEnable() {
    var Platform = Java.type('javafx.application.Platform');
    var Controllers = Java.type('org.jackhuang.hmcl.ui.Controllers');
    Platform.runLater(function () {
        Controllers.navigate(createPage());
    });
}

function onDisable() {
    log('Disabled');
}

function onUnload() {
    log('Unloaded');
}

function createPage() {
    var VBox = Java.type('javafx.scene.layout.VBox');
    var Insets = Java.type('javafx.geometry.Insets');
    var Label = Java.type('javafx.scene.control.Label');
    var JFXButton = Java.type('com.jfoenix.controls.JFXButton');
    var Controllers = Java.type('org.jackhuang.hmcl.ui.Controllers');
    var DecoratorPage = Java.type('org.jackhuang.hmcl.ui.decorator.DecoratorPage');
    var ReadOnlyObjectWrapper = Java.type('javafx.beans.property.ReadOnlyObjectWrapper');
    var Files = Java.type('java.nio.file.Files');

    var page = new (Java.extend(VBox, DecoratorPage))({
        stateProperty: function () {
            return this.state.getReadOnlyProperty();
        }
    });

    page.state = new ReadOnlyObjectWrapper(DecoratorPage.State.fromTitle('JavaScript Plugin Page'));
    page.setPadding(new Insets(24));
    page.setSpacing(12);

    var title = new Label('JavaScript HelloWorld Page');
    title.setStyle('-fx-font-size: 24px; -fx-font-weight: bold;');

    var info = new Label('Plugin directory: ' + pluginContext.getPluginDirectory() + '\nHMCL data directory: ' + pluginContext.getDataDirectory());
    info.setWrapText(true);

    var dialogButton = new JFXButton('Show launcher dialog');
    dialogButton.getStyleClass().add('jfx-button-raised');
    dialogButton.setOnAction(function () {
        Controllers.dialog('Hello from JavaScript plugin page.', 'JavaScript Plugin');
    });

    var titleButton = new JFXButton('Modify window title');
    titleButton.setOnAction(function () {
        pluginContext.getPrimaryStage().setTitle('HMCL - Modified by JavaScript Plugin');
    });

    var writeButton = new JFXButton('Write plugin data file');
    writeButton.setOnAction(function () {
        try {
            Files.writeString(pluginContext.getPluginDirectory().resolve('data.txt'), 'JavaScript plugin wrote this file.\n');
            Controllers.dialog('data.txt written.', 'JavaScript Plugin');
        } catch (e) {
            Controllers.dialog(String(e), 'JavaScript Plugin Error');
        }
    });

    page.getChildren().setAll(title, info, dialogButton, titleButton, writeButton);
    return page;
}

function log(message) {
    try {
        var Files = Java.type('java.nio.file.Files');
        var StandardOpenOption = Java.type('java.nio.file.StandardOpenOption');
        var LocalDateTime = Java.type('java.time.LocalDateTime');
        Files.writeString(
            pluginContext.getPluginDirectory().resolve('javascript-helloworld.log'),
            LocalDateTime.now() + ' ' + message + java.lang.System.lineSeparator(),
            StandardOpenOption.CREATE,
            StandardOpenOption.APPEND
        );
    } catch (e) {
    }
}
