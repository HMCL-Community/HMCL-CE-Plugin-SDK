// JavaScript plugins run in isolated Node.js processes. They cannot use
// Java.type(), JavaFX classes, or HMCL JVM objects directly.

const fs = require('fs');
const path = require('path');

function sendHmclMessage(message) {
    process.stdout.write('HMCL_PLUGIN_MESSAGE:' + JSON.stringify({
        protocol: 'hmcl-ui-v1',
        ...message
    }) + '\n');
}

function showDialog(message) {
    sendHmclMessage({
        actions: [{ type: 'dialog', title: 'Plugin SDK', message, level: 'info' }]
    });
}

function updateLabel(id, text) {
    sendHmclMessage({
        actions: [{ type: 'setText', target: id, text }]
    });
}

function writePluginData(fileName, content) {
    const dataDir = process.env.HMCL_PLUGIN_DATA_DIR;
    const target = path.join(dataDir, fileName);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content, 'utf8');
}

function readPluginData(fileName) {
    const target = path.join(process.env.HMCL_PLUGIN_DATA_DIR, fileName);
    return fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : '';
}
