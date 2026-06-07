# Lumen PDF

Lumen PDF 是一个 Windows-first 的 Flutter PDF 阅读器。它面向长时间阅读论文、手册、报告和扫描文档的工作流，重点放在本地阅读、全文搜索、页内导航、文字高亮、便签、选中文本翻译、pdf2zh 本地全文翻译和页面图片导出。

应用不是 PDF 编辑器，也不会改写用户原始 PDF 文件。最近文件、阅读位置、笔记、高亮、缩略图布局和导出默认值都保存在本地应用数据中。

## 功能概览

- 打开本地 PDF，支持拖入 Windows 窗口，恢复最近阅读页和视口位置。
- 使用 `pdfrx` 连续渲染 PDF，支持适合宽度、适合页面、缩放、PDF 内部链接和外部 URL。
- 左侧工具栏和可折叠侧栏提供资料库、缩略图、目录、搜索结果、笔记和翻译结果。
- 全文搜索支持结果列表、上下命中跳转和阅读区高亮。
- 文字选择右键菜单支持翻译、复制和高亮。
- 高亮按 PDF 页面坐标保存，支持再次选中局部取消，支持高亮评论。
- 独立便签可放置在页面坐标上，笔记列表支持跳转、编辑、删除和键盘浏览。
- 选中文本翻译支持无密钥服务 fallback、部分 API 服务、词典查询和英式/美式发音。
- 本地 pdf2zh 服务集成支持翻译、裁剪、对照和裁剪对照。
- 单页图片导出支持 PNG/JPG、DPI 元数据、快速导出默认值和临时导出选项。
- Windows 端提供自定义窗口控制、圆角无边框窗口、DPI 感知、窗口尺寸记忆和暗色标题栏同步。

## 技术栈

- Flutter 和 Material 3。
- `pdfrx` 用于 PDFium/WASM PDF 渲染、文本选择、搜索、链接和页面绘制回调。
- `sqlite3` 用于最近文件、文档位置、笔记和高亮数据。
- `image` 用于页面导出编码和 PNG/JPG DPI 元数据写入。
- `file_picker` 用于打开 PDF、选择目录和保存导出图片。
- `audioplayers` 用于词典发音播放。
- Windows runner 通过 `MethodChannel` 暴露窗口控制、拖入文件和 DPI 信息。

## 运行

```powershell
flutter pub get
flutter run -d windows
```

Web 调试可以使用：

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081
```

如果端口被占用，换一个端口即可：

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8082
```

## 验证

```powershell
flutter analyze
flutter test
```

当前测试覆盖：

- 基础空状态和高亮调色板。
- PDF 哈希与仓储按文件内容绑定注释。
- 设置迁移、快捷键默认值、系统 DPI 分辨率策略。
- 选中文本规范化和词典查询条件。
- PNG/JPG 页面导出 DPI 元数据。

## 打包 Windows

```powershell
flutter build windows --release
```

输出文件位于：

```text
build\windows\x64\runner\Release\lumen.exe
```

Windows 桌面构建通常需要开启 Developer Mode，因为 Flutter 插件构建可能使用符号链接。

## 本地数据

应用数据默认存放在：

```text
%LOCALAPPDATA%\LumenPDF
```

主要文件：

- `settings.json`：主题、窗口尺寸、缩略图布局、快捷键、导出和翻译设置。
- `software_cache.sqlite`：最近文件列表和最近阅读位置缓存。
- `file_data.sqlite`：按 PDF SHA-256 哈希保存的文档记录、阅读位置、便签和高亮。

清除软件缓存会移除设置和最近文件缓存。清除 PDF 文件数据会移除文档位置、便签和高亮。两者都不会删除用户磁盘上的 PDF 文件。

## 源码结构

```text
lib/main.dart
lib/src/app/
lib/src/assets/
lib/src/models/
lib/src/pdf/
lib/src/services/
lib/src/theme/
lib/src/widgets/
lib/src/window/
windows/runner/
test/
```

关键文件：

- `lib/main.dart`：初始化 Flutter binding 和 `pdfrx`，启动 `PdfReaderApp`。
- `lib/src/app/pdf_reader_app.dart`：Material 应用壳、字体 fallback、主题和 `ReaderHome` 注入。
- `lib/src/app/reader_home.dart`：主状态协调器。负责打开 PDF、搜索、页码、缩放、最近文件、笔记、高亮、翻译、导出、设置、窗口快捷键和侧栏状态。
- `lib/src/models/reader_models.dart`：核心模型。包括 `PdfSource`、`RecentDocument`、`ReaderPosition`、`PageNote`、`TextHighlight`、`ReaderSettings`、快捷键和导出选项。
- `lib/src/theme/app_colors.dart`：颜色 token。包含浅色、深色、三套主题色、高亮调色板、选择色和危险色。
- `lib/src/widgets/reader_toolbar.dart`：顶部工具栏、搜索框、页码、缩放、会话标签、高亮颜色菜单和窗口按钮。
- `lib/src/widgets/reader_rail.dart`：左侧功能栏和夜间模式入口。
- `lib/src/widgets/reader_panels.dart`：资料库、缩略图、目录、搜索、笔记和翻译侧栏。
- `lib/src/widgets/reader_stage.dart`：PDF 阅读舞台，封装 `PdfViewer` 参数、选择菜单、链接处理、页面叠加绘制和阅读位置滑条。
- `lib/src/widgets/settings_dialog.dart`：设置窗口。包含常规、快捷键、文档翻译和选中文本翻译设置。
- `lib/src/pdf/pdf_viewer_behaviors.dart`：连续页面布局和速度感知滚轮代理。
- `lib/src/services/reader_repository.dart`：读取和保存 PDF 状态的仓储入口。
- `lib/src/services/reader_database.dart`：SQLite schema、迁移和数据访问。
- `lib/src/services/app_data_paths.dart`：应用数据目录解析和旧数据迁移。
- `lib/src/services/translation_services.dart`：pdf2zh、本地服务请求、选中文本翻译、词典和发音。
- `lib/src/services/export_image_encoder.dart`：页面图片编码和 DPI 元数据处理。
- `lib/src/window/window_chrome_controller.dart`：Dart 侧 Windows 窗口 MethodChannel。
- `windows/runner/flutter_window.cpp`：原生窗口通道、拖入文件、DPI、窗口尺寸和标题栏主题。
- `windows/runner/win32_window.cpp`：无边框窗口、圆角、命中测试、最小尺寸和 DPI 处理。

## 阅读流程

1. 用户通过工具栏、资料库或拖放打开 PDF。
2. `ReaderHome` 构造 `PdfSource`，交给 `ReaderRepository.openSource`。
3. `PdfHashService` 对文件或 bytes 计算 SHA-256。
4. `ReaderDatabase` 根据哈希读取文档位置、笔记和高亮，并更新最近文件。
5. `ReaderStage` 加载 `PdfViewer.file` 或 `PdfViewer.data`。
6. `onViewerReady` 创建 `PdfTextSearcher`，加载目录，恢复位置或应用默认页面布局。
7. 阅读过程中的页码、视口位置、缩略图锚点、笔记和高亮按需保存。

## 渲染与交互

连续页面布局由 `continuousPageLayout` 计算。它使用最大页面宽度作为文档宽度，页面居中纵向排列，页间只保留 1 个 PDF point 的分割线。

滚轮交互由 `VelocityScrollInteractionDelegateProvider` 处理。慢速滚动保持细腻，快速连续滚动根据速度放大位移，并用指数衰减追赶目标位置。

阅读渲染分辨率由 `ReaderSettings.effectiveResolutionForSystemResolution` 决定。默认设置为 96 DPI；系统设置会读取当前窗口 DPI，并限制在 96 到 600 DPI 之间。页面实际渲染倍率还会结合当前缩放、文件大小和页面最长边做安全上限。

## 注释语义

- 独立便签只删除自身。
- 高亮可拥有一个关联评论。
- 删除高亮评论会同时删除高亮和关联评论。
- 清空评论文本不等于删除高亮。
- 空的自动高亮评论不会在页面上绘制独立笔记角标，但高亮仍然显示。

## 快捷键

默认快捷键定义在 `kDefaultShortcutBindings`。用户可以在设置中改绑。

- `Ctrl+O`：打开 PDF。
- `Ctrl+F`：搜索。
- `Esc`：清除搜索或隐藏当前面板。
- `Ctrl+Tab`：打开本次会话文件菜单。
- `Ctrl+H`：选择高亮颜色。
- `Ctrl+L`：打开资料库。
- `Ctrl+T`：打开缩略图。
- `Shift+Tab`：切换缩略图单页/双页布局。
- `Ctrl+B`：打开目录。
- `Ctrl+N`：打开笔记。
- `Ctrl+Shift+N`：新建便签。
- `Ctrl+'`：打开设置。
- `Page Up` / `Page Down`：上一页/下一页。
- `Ctrl+W`：适合宽度。
- `Ctrl+P`：适合页面。
- `Ctrl+Shift+L`：切换日夜模式。

全局快捷键只在指针位于应用窗口内、当前路由激活、没有打开设置录入和文本输入未占用时响应。

## 翻译服务

选中文本翻译由 `SelectionTranslationService` 处理。它会先规范化选择文本，再按设置调用翻译服务；词典查询只对较短词组触发。

无密钥翻译默认 fallback 顺序包括必应、腾讯 TranSmart、火山网页翻译和 Google。百度、阿里、腾讯云需要在设置里配置密钥。词典支持海词、有道、必应、剑桥和 Free Dictionary API。发音按英式和美式去重展示。

pdf2zh 集成要求本地服务可访问，默认地址：

```text
http://localhost:8890
```

全文翻译结果会保存到原 PDF 同级目录下的 `<文件名>_pdf2zh` 文件夹。

## 页面导出

缩略图三点菜单提供快速导出和普通导出。

- 快速导出使用设置中的默认 DPI、格式、命名规则和导出文件夹。
- 普通导出会打开 `PageExportDialog`，允许临时调整参数。

命名模板支持：

- `{document}`：PDF 文件名，不含扩展名。
- `{page}`：页码。
- `{page2}`：两位页码。
- `{page3}`：三位页码。
- `{date}`：导出日期，格式为 `yyyyMMdd`。

Windows 不允许的文件名字符会被替换为 `_`。

## 设计原则

- 阅读画布优先，工具栏和侧栏服务阅读，不喧宾夺主。
- UI 文案使用简短中文动词，设置和确认框再承担较长说明。
- 控件保持熟悉：图标按钮、开关、滑块、下拉、色块和上下文菜单。
- 侧栏和弹窗保持紧凑，不把主阅读界面变成说明页。
- 破坏性操作必须明确说明会删除什么，并要求确认。

更多产品和设计约束见 `PRODUCT.md` 与 `DESIGN.md`。
