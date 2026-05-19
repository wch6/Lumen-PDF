# Lumen PDF

一个基于 Flutter 的现代 PDF 阅读器原型，视觉方向参考 UPDF：左侧工具栏、可覆盖式侧边面板、连续 PDF 阅读区、全文搜索、页面缩略图、目录跳转、本地笔记、文字高亮、阅读位置滑条、主题色设置、渲染分辨率设置、滚轮灵敏度设置和页面图片导出。

## 运行

```powershell
flutter pub get
flutter run -d windows
```

Web 调试：

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081
```

如果端口被占用，可以换端口：

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8082
```

## 打包 Windows APP

```powershell
flutter build windows --release
```

输出文件：

```text
build\windows\x64\runner\Release\pdf_reader.exe
```

Windows 桌面构建需要开启 Developer Mode，因为 `pdfrx`/Flutter 插件构建会使用符号链接。

## 程序结构

`lib/main.dart`  
程序入口。初始化 Flutter binding、初始化 `pdfrx` PDFium/WASM 运行环境，然后启动 `PdfReaderApp`。

`lib/src/app/pdf_reader_app.dart`  
应用壳。配置 Material 3、中文字体 fallback、基础颜色、tooltip 主题，并挂载 `ReaderHome`。

`lib/src/app/reader_home.dart`  
主状态协调器。负责打开 PDF、最近文件、笔记、高亮、全文搜索、搜索清除与缩略图回退、页码同步、缩放命令、夜间模式、主题设置、默认布局应用、Ctrl+Z/Ctrl+Y 高亮撤回重做、窄屏侧边栏覆盖逻辑。它只编排状态和回调，不直接绘制复杂 UI。
快捷键通过 `HardwareKeyboard` 注册全局处理器，只要应用窗口处于激活状态就能触发，不再依赖阅读区或某个控件先获得焦点；设置弹窗打开时会暂停全局快捷键，避免影响快捷键录入。

`lib/src/models/reader_models.dart`  
数据模型层。包含 `PdfSource`、`RecentDocument`、`PageNote`、`TextHighlight`、`HighlightRect`、`ReaderSettings`、`PageExportOptions`、`PanelMode`、`ReaderAccent`、`DefaultPageLayout`、`ResolutionMode`、`ExportImageFormat` 和本地存储 key。需要持久化的模型提供 JSON 编码/解码入口，便于 `SharedPreferencesAsync` 存储。

`lib/src/theme/app_colors.dart`  
主题 token。集中维护浅色/深色颜色、三套主题色（玫瑰红、暗夜紫、薄荷绿）、15 个高亮色、页面分割线色。`AppColors.setTheme` 是当前全局主题入口。

`lib/src/widgets/reader_rail.dart`  
左侧功能栏。左上角 PDF 图标负责资料库入口，其余按钮负责缩略图、目录、搜索、笔记和设置入口。窄屏下点击功能栏会打开覆盖式面板，再次点击当前入口会收起面板，不改变阅读区尺寸。

`lib/src/widgets/reader_panels.dart`  
左侧内容面板集合。包含资料库、页面缩略图、目录、搜索结果、笔记列表、最近文件卡片等。页面面板展示当前文件名和页数，并提供单页/双页缩略图切换；单页模式会收窄侧栏，让单个缩略图与双页模式中的单页宽度一致。缩略图底部左侧显示页码，右侧三点菜单提供快速导出和普通导出。

`lib/src/widgets/reader_toolbar.dart`  
顶部工具栏。只承载操作控件，不显示当前文件名。包含文件入口、本次会话已打开文件切换、搜索框、页码跳转、上一页/下一页、缩放、适合宽度、适合页面、高亮颜色选择、新建便签、夜间模式切换。宽屏和窄屏下，除打开文件按钮与会话标签切换按钮外，其余控件都会靠近窗口右侧；空间不足时横向滚动。

`lib/src/widgets/reader_stage.dart`  
阅读区。封装 `PdfViewer.file`/`PdfViewer.data`，接入 PDF 链接点击、连续阅读布局、速度滚轮、鼠标悬停阅读位置滑条、文字选择高亮、笔记角标和搜索结果绘制。`ReaderSettings.effectiveResolution` 会参与 `PdfViewerParams.getPageRenderingScale`，用于控制页面渲染清晰度；滚轮灵敏度会同步调整页面图片内存缓存、水平/垂直预加载范围和滚轮惯性。

`lib/src/widgets/page_export_dialog.dart`  
普通页面导出窗口。允许临时选择图片分辨率、图片格式、命名格式和导出文件夹；默认值来自快速导出设置，但不会强制写回全局设置。

`lib/src/widgets/settings_dialog.dart`  
设置窗口。样式参考 UPDF 设置弹窗，当前提供主题色切换、默认页面布局、是否始终以该比例打开文档、夜间模式开关、阅读渲染分辨率、速度滚轮灵敏度、快速导出默认值和清除软件缓存。

`lib/src/pdf/pdf_viewer_behaviors.dart`  
PDF 阅读交互策略。包含连续页面布局算法和速度感知滚轮滚动代理。

`lib/src/services/file_saver.dart`  
条件导出的文件保存服务。Windows 等 `dart:io` 平台使用 `file_saver_io.dart` 直接写入已配置的导出文件夹；Web 等不支持直接写文件夹的平台使用 `file_saver_stub.dart`，并由 `file_picker.saveFile` 弹出保存窗口兜底。

## 核心算法

### 连续页面布局

`continuousPageLayout` 接收 `List<PdfPage>`，计算最大页面宽度作为文档布局宽度，然后按页面顺序纵向排列：

```text
x = (maxPageWidth - page.width) / 2
y = previousPageBottom + separator
separator = 1 PDF point
```

`PdfViewerParams.backgroundColor` 使用 `AppColors.pageSeparator`。页面间只露出 1 个布局单位的背景色，因此视觉上是黑色或白色细线，而不是大块留白。初始缩放使用 `coverZoom`，让 PDF 宽度尽量填满阅读区。

### 速度滚轮

`VelocityScrollInteractionDelegateProvider` 实现 `PdfViewerScrollInteractionDelegateProvider`。每次滚轮事件到达时：

```text
dt = now - lastWheelTime
velocity = delta.distance / dt
multiplier = 1 + clamp(velocity / velocityScale, 0, maxMultiplier - 1)
target += delta * multiplier
```

然后使用指数衰减插值平滑追赶目标：

```text
alpha = 1 - exp(-friction * frameDt)
current = current + (target - current) * alpha
```

因此慢滚时移动细腻，快速连续滚动时相同滚轮角度会产生更大的页面位移，更接近网页阅读时的惯性滚动感。

设置里的“速度滚轮灵敏度”会同时调整 `scrollByMouseWheel`、`velocityScale` 和 `maxVelocityMultiplier`。灵敏度越高，速度放大越早触发，快速滚动时跨过的页面越多；当前上限限制在 5 档，避免滚动距离超过缩略图列表那种大步滚动的体感。

### 渲染分辨率

`ReaderSettings.effectiveResolution` 将设置项转换为 DPI：

```text
默认设置 = 192 dpi
系统设置 = 192 dpi
```

阅读区通过 `PdfViewerParams.getPageRenderingScale` 将 DPI 转换为 PDF 渲染倍率：

```text
dpiScale = dpi / 72
renderScale = min(estimatedScale, dpiScale, previewCap, maxSafeScale)
```

`estimatedScale` 来自当前缩放；阅读预览默认以 192 dpi 为目标，并按文件体积和滚动状态设置上限。普通文档优先显示更清晰的预览，较大的扫描 PDF 会在滚动时降低一点预览倍率，避免明显增加首帧延迟；`maxSafeScale` 按页面最长边限制到约 3600 像素，避免超高 DPI 导致一次渲染占用过多内存。

### PDF 链接

阅读区启用 `PdfLinkHandlerParams`：

- `link.dest != null`：调用 `PdfViewerController.goToDest` 在 PDF 内跳转。
- `link.url != null`：调用 `url_launcher.launchUrl` 用系统浏览器打开外部链接。
- `enableAutoLinkDetection = true`：让 `pdfrx` 尝试识别文本中的 URL。

### 高亮切换

右键菜单“高亮”会读取 `PdfTextSelectionDelegate.getSelectedTextRanges()`，把文本范围转换为 PDF 页面坐标矩形。再次高亮时使用几何差集逻辑：

```text
已有高亮 = 已有高亮 - 当前选择区域
新增高亮 = 当前选择区域 - 原有高亮
结果 = 新增高亮 + 保留下来的已有高亮
```

因此选区中已经高亮的部分会被取消，未高亮的部分会使用当前高亮颜色新增。高亮状态使用快照栈支持 `Ctrl+Z` 撤回和 `Ctrl+Y` 重做。

### 阅读位置滑条

阅读区使用 `PdfViewerScrollThumb` 作为悬停式位置指示器。`ReaderStage` 监听鼠标进入/离开阅读区，只有鼠标位于阅读区时才把滑条加入 `viewerOverlayBuilder`。滑条读取 `PdfViewerController.visibleRect` 和 `documentSize`，所以滚轮滚动、页码跳转、拖动视图都会同步当前位置。

### 窄屏侧边栏

当窗口宽度小于 `1040px`，内容面板默认折叠，仅保留左侧图标栏。点击图标栏后，`ReaderPanel` 以 `Stack + Positioned.fill` 覆盖在阅读区上层，点击阅读区空白处关闭。因为阅读区自身尺寸没有变化，PDF 不会因侧栏打开而重新缩放。

在 Windows 桌面端，`windows/runner/win32_window.cpp` 通过 `WM_GETMINMAXINFO` 设置 960×640 的最小窗口尺寸，保证窄屏状态下顶部工具按钮仍能完整显示。

### 会话标签切换

`ReaderHome` 使用 `SessionDocumentTab` 保存本次启动后打开过的 PDF，不写入持久化存储。打开或切换文件时会把对应项移动到列表前部并记录当前页；顶部 `OpenTabsButton` 只展示这组会话标签。每个标签项的 tooltip 显示完整文件路径，最大宽度限制为当前窗口宽度的一半，路径过长时自动换行。

### 清除缓存

设置窗口“清除软件缓存”会先弹出确认框。确认后调用 `SharedPreferencesAsync.clear()` 清除本软件保存在本地的设置、最近文件、笔记和高亮缓存，并重置当前界面中的设置、最近文件、笔记与高亮状态。该操作不会删除用户电脑上的 PDF 文件。

### 页面图片导出

缩略图三点菜单支持两种导出：

- 快速导出：使用设置页里的分辨率、图片格式、命名格式和导出文件夹。若文件夹可直接写入，则无额外弹窗；若未设置文件夹或平台不支持直接写文件夹，则弹出系统保存窗口。
- 普通导出：先打开 `PageExportDialog`，可以临时修改分辨率、格式、命名格式和导出文件夹，默认值继承快速导出设置。

导出核心流程：

```text
page = document.pages[pageNumber - 1].ensureLoaded()
scale = resolution / 72
PdfPage.render(width, height, backgroundColor: white)
BGRA8888 pixels -> image.Image.fromBytes(order: bgra)
PNG/JPG encoder -> Uint8List
saveBytesToFolder 或 FilePicker.saveFile
```

命名格式支持 `{document}`、`{page}`、`{page2}`、`{page3}`、`{date}`，最终文件名会清理 Windows 不允许的字符。

### 性能策略

- PDF 渲染由 `pdfrx 2.3.4` 驱动，底层使用更新后的 PDFium；Flutter 负责 GPU 合成与界面绘制。
- `PdfViewerSizeDelegateProviderLegacy` 接管缩放边界和初始 `coverZoom`，避免继续依赖 2.3.x 中已弃用的 `minScale/maxScale/calculateInitialZoom` 顶层参数。
- `maxImageBytesCachedOnMemory` 按滚轮灵敏度提升到约 608-992 MB，提高连续阅读和高分辨率屏幕下的缓存命中。
- `verticalCacheExtent` 和 `horizontalCacheExtent` 根据滚轮灵敏度动态扩大，默认灵敏度下会预取约 6.9 个视口高度的上下内容，并为放大后的横向平移保留更多缓存。
- `pageImageCachingDelay` 和 `partialImageLoadingDelay` 在静止时降到 0，滚动中只保留很短的延迟，优先让当前页与邻近页尽快进入清晰渲染队列。
- 页面阴影被移除，减少每页复合绘制开销。

## 主要接口

`ReaderHome`

- `_pickPdf()`：调用 `file_picker` 选择 PDF。
- `_openSource(PdfSource source, {int initialPage = 1})`：载入文件来源并重置阅读状态。
- `_runSearch(String query)`：启动 `PdfTextSearcher` 全文搜索，并在进入搜索面板后执行适合宽度。
- `_clearSearchAndReturnToPages()`：由默认 `Esc` 快捷键触发，清空搜索、重置命中绘制、回到缩略图侧边栏并执行适合宽度。
- `_addNote()`：按当前页创建本地便签。
- `_addHighlightFromSelection(List<PdfPageTextRange> ranges)`：将文本选择范围转换为页面矩形，并按几何差集更新高亮。
- `_undoHighlight()` / `_redoHighlight()`：基于高亮快照栈执行撤回和重做。
- `_quickExportPage(int pageNumber)`：使用快速导出默认值导出缩略图对应页面。
- `_exportPage(int pageNumber)`：打开普通导出窗口并按用户选择导出页面。
- `_renderPageImageBytes(...)`：把指定 PDF 页渲染为 PNG/JPG 字节。
- `_showSettings()`：打开设置窗口。
- `_openSessionTab(SessionDocumentTab tab)`：从顶部会话标签切换到本次已打开过的文件。
- `_clearSoftwareCache()`：清除本应用本地缓存并重置相关运行状态。

`ReaderStage`

- `source`：当前 PDF 来源，支持本机路径或内存 bytes。
- `controller`：外部传入的 `PdfViewerController`。
- `textSearcher`：搜索器，用于绘制搜索命中。
- `notes` / `highlights`：页面叠加数据。
- `onAddHighlight`：右键菜单“高亮”的回调。
- `showScrollThumb`：控制阅读位置滑条是否显示。
- `passwordProvider`：受保护 PDF 的密码弹窗入口。
- `settings`：阅读设置，当前用于渲染分辨率和速度滚轮灵敏度。

`ReaderSettings`

- `accent`：主题色，支持 `rose`、`purple`、`green`。
- `defaultPageLayout`：默认页面布局，支持 `fitWidth` 和 `fitPage`。
- `alwaysOpenWithDefaultLayout`：是否总是用默认页面布局打开文档。
- `resolutionMode`：阅读渲染 DPI 设置，当前支持默认设置与系统设置。
- `scrollSensitivity`：速度滚轮灵敏度，取值 1 到 5。
- `quickExportResolution` / `quickExportFormat` / `quickExportNamePattern` / `quickExportFolder`：快速导出的默认参数。
- `toJson()` / `tryDecode()`：设置持久化接口。

## 参考取舍

- SumatraPDF：快速启动、阅读优先、界面轻量。
- KOReader：目录、阅读状态、页内导航要可靠。
- Mozilla pdf.js：搜索、文本层和链接识别是阅读器核心能力。
- GrapheneOS PdfViewer：打开文件流程保持简单，权限面尽量小。
- `pdfrx`：Flutter 侧使用 PDFium 做跨平台渲染，适合桌面、移动和 Web。
