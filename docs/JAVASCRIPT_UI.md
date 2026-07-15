# JavaScript 声明式 JavaFX UI（hmcl-ui-v1）

HMCL Nex 的 JavaScript 插件固定运行在启动器管理的 Node.js v24.18.0 子进程中。Node.js 与 HMCL JVM 隔离，因此 JavaScript **不能直接调用** `Java.type()`、JavaFX 类或 HMCL Java 对象。

`hmcl-ui-v1` 允许 JavaScript 声明控件树，由 HMCL 在 JavaFX 线程创建真实控件。按钮事件会再次调用插件入口的 `onUiEvent` 事件。

## 消息格式

每条协议消息必须独占一行，并使用此前缀：

```text
HMCL_PLUGIN_MESSAGE:
```

示例发送函数：

```javascript
function send(message) {
    process.stdout.write('HMCL_PLUGIN_MESSAGE:' + JSON.stringify({
        protocol: 'hmcl-ui-v1',
        ...message
    }) + '\n');
}
```

普通日志可以写入标准输出；HMCL 只解析带前缀的协议行。

## 注册侧边栏页面

在 `onEnable` 生命周期中发送：

```javascript
send({
    sidebar: {
        title: 'My Plugin',
        page: {
            type: 'vbox',
            spacing: 16,
            children: [
                { type: 'title', text: 'My Plugin' },
                { type: 'textField', id: 'name', prompt: 'Name' },
                { type: 'button', text: 'Run', event: 'run', primary: true },
                { type: 'label', id: 'status', text: 'Ready', variant: 'secondary' }
            ]
        }
    }
});
```

## 支持的控件

| `type` | 主要属性 |
| --- | --- |
| `vbox` | `children`, `spacing`, `padding`, `alignment` |
| `hbox` | `children`, `spacing`, `padding`, `alignment` |
| `title` | `text`, `wrap` |
| `subtitle` | `text`, `wrap` |
| `label` | `text`, `wrap`, `variant` |
| `button` | `text`, `event`, `primary` |
| `textField` | `id`, `text`, `prompt` |
| `textArea` | `id`, `text`, `prompt`, `rows`, `wrap` |
| `checkBox` | `id`, `text`, `selected` |
| `separator` | 无 |
| `spacer` | `width`, `height` |

通用属性：

- `id`：用于读取输入值或定向更新控件，页面内必须唯一。
- `disabled`：禁用控件。
- `grow`：在父级 `vbox`/`hbox` 中占用剩余空间。
- `alignment`：JavaFX `Pos` 名称，例如 `CENTER_LEFT`、`TOP_CENTER`。
- `label.variant`：`normal`、`secondary`、`success`、`warning`、`error`。

为防止异常页面消耗过多资源，每页最多 500 个控件、最多嵌套 20 层。

## 处理按钮事件

按钮触发后，HMCL 使用同一个入口脚本运行：

```text
node main.js onUiEvent
```

环境变量：

- `HMCL_UI_EVENT_ID`：按钮的 `event` 值。
- `HMCL_UI_VALUES`：页面中所有有 `id` 的 `textField`、`textArea` 和 `checkBox` 当前值组成的 JSON 对象。

示例：

```javascript
if (event === 'onUiEvent') {
    const eventId = process.env.HMCL_UI_EVENT_ID;
    const values = JSON.parse(process.env.HMCL_UI_VALUES || '{}');

    if (eventId === 'run') {
        send({
            actions: [
                { type: 'setText', target: 'status', text: `Hello, ${values.name}` },
                {
                    type: 'dialog',
                    title: 'My Plugin',
                    message: 'Operation completed.',
                    level: 'success'
                }
            ]
        });
    }
}
```

事件在后台顺序执行，不会阻塞 JavaFX UI 线程。事件处理超时为 30 秒；等待响应时，触发事件的按钮会暂时禁用。

## 支持的响应动作

| `type` | 属性 | 效果 |
| --- | --- | --- |
| `setText` | `target`, `text` | 修改 Label、Button 或输入控件文本 |
| `setDisabled` | `target`, `disabled` | 修改目标控件禁用状态 |
| `dialog` | `title`, `message`, `level` | 显示 HMCL 原生对话框 |

`dialog.level` 支持 `info`、`success`、`warning`、`error`、`question`。

## 与 Java/Kotlin 插件的区别

- Java/Kotlin 插件运行在 HMCL JVM 中，可以直接实例化任意 JavaFX 控件并调用 HMCL API。
- JavaScript 插件运行在隔离的固定 Node.js 中，只能通过当前协议中明确支持的控件和动作访问 UI。
- 这种设计保证 Node.js 版本固定，并避免从 Node.js 线程直接操作 JavaFX UI。
