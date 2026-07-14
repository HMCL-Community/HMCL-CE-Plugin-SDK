// JavaScript plugin snippets for HMCL Nex.
// These snippets assume `pluginContext` is available from onLoad(context).

function showDialog(message) {
    var Controllers = Java.type('org.jackhuang.hmcl.ui.Controllers');
    Controllers.dialog(message, 'Plugin SDK');
}

function showJavaFxAlert() {
    var Platform = Java.type('javafx.application.Platform');
    var Alert = Java.type('javafx.scene.control.Alert');
    var AlertType = Java.type('javafx.scene.control.Alert$AlertType');
    Platform.runLater(function () {
        var alert = new Alert(AlertType.INFORMATION);
        alert.initOwner(pluginContext.getPrimaryStage());
        alert.setTitle('Plugin SDK');
        alert.setHeaderText('JavaFX Alert');
        alert.setContentText('Plugins can create normal JavaFX UI.');
        alert.show();
    });
}

function changeWindowTitle(title) {
    var Platform = Java.type('javafx.application.Platform');
    Platform.runLater(function () {
        pluginContext.getPrimaryStage().setTitle(title);
    });
}

function listGameInstances() {
    var GameDirectoryManager = Java.type('org.jackhuang.hmcl.setting.GameDirectoryManager');
    var repository = GameDirectoryManager.getSelectedRepository();
    var versions = repository.getVersions();
    var result = [];
    for (var i = 0; i < versions.size(); i++) {
        result.push(versions.get(i).getId());
    }
    return result.join('\n');
}

function navigateToSettings() {
    var Controllers = Java.type('org.jackhuang.hmcl.ui.Controllers');
    Controllers.navigate(Controllers.getSettingsPage());
}

function navigateToDownloadPage() {
    var Controllers = Java.type('org.jackhuang.hmcl.ui.Controllers');
    Controllers.getDownloadPage().showGameDownloads();
    Controllers.navigate(Controllers.getDownloadPage());
}

function writePluginData(fileName, content) {
    var Files = Java.type('java.nio.file.Files');
    var target = pluginContext.getPluginDirectory().resolve(fileName);
    Files.createDirectories(target.getParent());
    Files.writeString(target, content);
}

function readPluginData(fileName) {
    var Files = Java.type('java.nio.file.Files');
    var target = pluginContext.getPluginDirectory().resolve(fileName);
    return Files.exists(target) ? Files.readString(target) : '';
}
