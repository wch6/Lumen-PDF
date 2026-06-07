# Lumen PDF Product Context

register: product

## Product Purpose

Lumen PDF is a local-first Flutter PDF reader for Windows desktop reading, annotation, search, translation, and page export workflows. It is a productivity tool. The first screen is the reader itself: open file entry, document canvas, top toolbar, left rail, side panels, and reading controls.

The product should help users stay inside one focused reading surface for long sessions. It should remember useful local state, expose repeated actions near the document, and avoid changing original PDF files.

## Primary Users

- Researchers, students, engineers, and technical readers who spend long sessions in papers, manuals, reports, standards, and scanned documents.
- Bilingual readers who need quick selection translation, dictionary lookup, pronunciation, and local pdf2zh document translation.
- Users who prefer predictable local storage for recent files, reading position, notes, highlights, export defaults, and keyboard shortcuts.
- Windows desktop users who expect native file picking, drag and drop, window controls, DPI awareness, and stable performance on large documents.

## Core Jobs

- Open local PDFs quickly from the toolbar, recent list, session menu, or file drop.
- Restore the last useful page and viewport position for a document by file content hash.
- Read continuously with responsive zoom, fit-width and fit-page commands, smooth mouse-wheel behavior, and clear page rendering.
- Browse thumbnails, outlines, search results, notes, and translation output without losing the reading context.
- Search full text, move between hits, and align selected matches in the viewport.
- Highlight selected text, attach comments to highlights, create standalone page notes, edit notes inline, and jump between notes.
- Preserve annotation semantics: clearing note text differs from deleting a note; deleting a highlight comment removes the highlight and its attached note.
- Translate selected text, optionally show a dictionary entry and pronunciation audio, and keep the result close to the selected text workflow.
- Send local PDFs to a local pdf2zh service and save translated files beside the original document.
- Export individual pages as images with quick defaults or per-export options.
- Clear software cache and PDF file data deliberately, with explicit confirmation and no deletion of original PDF files.

## Product Principles

- Reading comes first. The PDF page, selection geometry, annotation placement, and navigation accuracy matter more than decorative UI.
- Local state must be legible. Users should understand what is cached, what is tied to a PDF hash, and what will be cleared.
- Controls should stay close to repeated workflows. Toolbars, rails, panels, context menus, and shortcuts should make frequent actions reachable without turning the app into a document manager.
- Advanced settings are allowed, but they must remain grouped by workflow and easy to scan.
- Keyboard support should work at the application-window level when the pointer is inside the app, while text fields, menus, and dialogs protect user input.
- Translation is an assistive layer, not a dependency for reading. Basic reading, notes, highlights, search, and export must remain local-first.
- The original PDF is read-only. Lumen PDF stores its own annotations and metadata separately.

## Current Product Surface

- Top toolbar: open PDF, current file, session file menu, zoom, fit commands, search, page stepping, highlight color menu, and custom window controls on Windows.
- Left rail: library, thumbnails, outline, search, notes, settings, and night mode entry.
- Side panels: recent files, thumbnails, outline tree, search results, notes list, and selection translation result.
- Reading stage: continuous PDF viewer, text selection context menu, highlight and note overlays, link handling, scroll thumb, empty state, and status messages.
- Settings dialog: general reading settings, shortcut bindings, document translation, selection translation, dictionary, pronunciation, export defaults, cache clearing, and file-data clearing.
- Windows runner: custom frame, resize handles, drag region, window size memory, DPI bridge, title bar theme sync, and dropped-file bridge.

## Data Model Expectations

- A `PdfSource` can come from a file path or memory bytes.
- File identity is the SHA-256 hash of PDF content, not only path.
- Recent files live in app cache; document positions, notes, and highlights live in file data.
- `ReaderSettings` owns theme accent, default layout, window memory, thumbnail layout, render resolution mode, scroll sensitivity, export defaults, translation settings, pronunciation settings, and shortcut bindings.
- `PageNote` stores page, text, optional page coordinates, optional `highlightId`, color, creation time, and update time.
- `TextHighlight` stores page, selected text, PDF-space rects, color, and creation time.

## Tone And Copy

- Use concise Chinese UI labels for end-user controls.
- Prefer direct verbs: 打开, 搜索, 保存, 清除, 删除, 翻译, 导出.
- Empty states may orient users, but the main reading surface should not contain long training copy.
- Tooltips can name commands and shortcuts. Settings can explain consequences.
- Destructive actions must name the data being removed and distinguish software cache, file data, recent entries, notes, highlights, and original PDF files.

## Non Goals

- Do not become a PDF editor that rewrites PDF content.
- Do not bury reading behind a landing page, marketing screen, or heavy document-management shell.
- Do not require network access for opening, reading, search, notes, highlights, reading position, or page export.
- Do not make cache, note, highlight, or file-data deletion easy to trigger accidentally.
- Do not turn every small action into a modal dialog when a panel, inline editor, menu, or tooltip is enough.
- Do not introduce ornamental UI that competes with the PDF page.

## Technical Shape

- Flutter app using Material 3.
- `pdfrx` handles PDF rendering, search, text selection, links, layout, and page paint callbacks.
- `ReaderHome` coordinates application state, repository calls, callbacks, global shortcuts, and window integration.
- `reader_*` widgets own major UI surfaces and should remain mostly presentational.
- `ReaderRepository` and `ReaderDatabase` persist recent files, document positions, notes, and highlights.
- `ReaderSettingsStore` persists settings as JSON under the app data directory.
- `translation_services.dart` owns local pdf2zh calls, selection translation, dictionary lookup, pronunciation audio extraction, and HTTP helpers.
- `export_image_encoder.dart` owns image encoding and DPI metadata.
- Windows native code owns custom window behavior and exposes it through `pdf_reader/window_chrome`.

## Success Criteria

- Opening a known PDF feels immediate and returns to the expected reading position.
- The document canvas remains the dominant surface at every supported window size.
- Text selection, highlight geometry, note selection, and jump behavior are reliable.
- Search, thumbnails, outlines, notes, and translation panels help navigation without forcing a layout reset.
- Settings changes are persisted predictably and do not break current reading context.
- Clearing local data is explicit, reversible only by user backups, and never deletes original PDFs.
- Analyzer and tests remain clean before committing.
