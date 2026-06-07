# Lumen PDF Design Context

## Design Register

Product UI. Design serves repeated reading, annotation, translation, and export work. The interface should feel calm, precise, and native to a serious desktop tool. Familiarity is a feature here: users should trust the controls and stop noticing the shell while they read.

Physical scene: a researcher or engineer is reading a dense PDF on a Windows laptop or external monitor for an hour or more, switching between the document, notes, search results, and translation output under normal office light or late-night desk light. This supports a restrained neutral system with optional night mode, compact controls, and no decorative surfaces.

## Visual Direction

- Reference family: modern desktop PDF tools such as UPDF, plus task-focused product interfaces that keep navigation predictable.
- The PDF page is the primary visual asset. UI chrome frames the document but should not compete with it.
- The app shell uses a top toolbar, narrow left rail, optional side panel, and expanded reading stage.
- Use operational polish: compact spacing, clear hover states, stable hit targets, legible icons, and consistent row rhythms.
- Avoid marketing composition, hero sections, ornamental backgrounds, gradient decoration, glass effects, and large empty promotional copy.

## Color Strategy

Strategy: restrained product palette. Tinted neutrals carry most of the interface; the current accent is reserved for selected state, primary action, focus, and a few active indicators.

Source of truth: `lib/src/theme/app_colors.dart`.

Light mode:

- Ink `0xFF202124`
- Subtle `0xFF666A70`
- Muted `0xFF8A8D93`
- Canvas `0xFFF4F4F4`
- Surface `0xFFFBFBFA`
- Panel `0xFFEFEFEF`
- Rail `0xFFE8E8E8`
- Line `0xFFDADCE0`
- Toolbar item `0xFFF0F0F0`

Dark mode:

- Ink `0xFFF2F2F2`
- Subtle `0xFFC6C6C6`
- Muted `0xFF9A9A9A`
- Canvas `0xFF202020`
- Surface `0xFF242424`
- Panel `0xFF2B2B2B`
- Rail `0xFF242424`
- Line `0xFF3A3A3A`
- Toolbar item `0xFF303030`

Accent choices:

- Rose: default warm red family.
- Purple: focused violet family.
- Green: calm mint family.

Rules:

- Use `AppColors.accent`, `accentSoft`, and `accentLine` instead of hard-coded accent values.
- Use `AppColors.danger` for destructive actions.
- Use `AppColors.selection` for text selection and note focus.
- Use `AppColors.highlightPalette` for highlighter swatches and annotation colors.
- Preserve translucent highlight alpha so PDF text remains legible.
- Do not let one saturated hue dominate the shell. Neutrals should carry the product.

## Typography

- App font: `Microsoft YaHei UI`.
- Fallbacks: `Microsoft YaHei`, `SimHei`, `Segoe UI`, `Arial`.
- Use compact product hierarchy. Panel titles, active labels, page numbers, shortcut badges, and toolbar pills can be bold.
- Use small readable labels for Chinese UI, especially in the toolbar and settings rows.
- Avoid hero-scale type inside the app shell.
- Prose in dialogs and settings should stay concise, with comfortable line height and a practical width.

## Layout

- Main structure: top toolbar, left rail, optional side panel, expanded reading stage.
- The reading stage must remain visually dominant and should not be placed inside a decorative card.
- The left rail is compact and icon-led. The current panel entry should be obvious.
- Side panels may use cards for repeated items such as recent files, search results, notes, and thumbnails, but avoid nested cards.
- Settings should use sections, rows, dividers, switches, sliders, dropdowns, and compact text fields rather than stacks of decorative cards.
- Narrow layouts should collapse panels over the reading stage without resizing the PDF viewport unless required.
- Fixed-format UI elements such as toolbar buttons, rail buttons, thumbnails, note markers, and window controls need stable dimensions.
- Text in buttons, badges, panels, and dialogs must not overflow. Prefer ellipsis for paths and selected-text previews.

## Components

- Use Material icons already present in the project.
- Icon-only controls need tooltips, ideally with shortcut hints through `ShortcutTooltip`.
- Use icon buttons for commands, color swatches for highlight color, switches for binary settings, sliders or number fields for numeric settings, dropdowns for bounded choices, and context menus for action sets.
- Use `showThemedContextMenu` for app menus when possible.
- Dialogs should align with `SettingsDialog`, `PageExportDialog`, and `_NoteEditorCard`: clear title, compact body, visible close or cancel affordance, and distinct action row.
- Destructive actions should use text or outlined affordances with danger color. Avoid filled primary styling for destructive confirmation unless the action is already inside a confirmation dialog and the label is explicit.
- The right-top close icon in small note editors is the cancel affordance. Do not duplicate it with a second bottom cancel action unless the surface lacks a close control.

## Interaction Rules

- Global shortcuts work when the pointer is inside the app window, the route is active, and no dialog or menu is capturing input.
- Text inputs protect editing. For note editors, Enter saves and Ctrl+Enter inserts a newline.
- Search focus should select existing query text for quick replacement.
- `Esc` clears active search results first, then hides the active panel.
- Opening side panels on compact width should overlay the document and close when the user taps outside the panel.
- Opening search or a full-width panel may refit the document, but compact overlays should avoid forcing PDF relayout.
- Clicking a note selects it, scrolls the page to the relevant geometry, and opens the notes panel when useful.
- Moving a note should update coordinates only on commit, with transient dragging allowed by the reading stage.

## Annotation Semantics

- Standalone note deletion removes only that note.
- Highlight-note deletion removes both the highlight and its attached note.
- Clearing note text is not the same as deleting a highlight.
- Empty automatic highlight notes should not draw standalone note markers over the PDF.
- Highlight comments should inherit the highlight color.
- Selection outlines should be visible but subtle, using dashed selection treatment rather than heavy decoration.

## Motion

- Motion exists to communicate state: panel reveal, menu appearance, dialog entrance, note focus, page navigation, and window minimize or resize feedback.
- Most UI transitions should sit around 150 to 250 ms.
- PDF navigation durations should remain short, roughly 90 to 160 ms where the current code already uses that range.
- Use ease-out curves. Do not animate layout in a way that makes controls drift under the cursor.
- Avoid decorative page-load choreography.

## Accessibility And Ergonomics

- Every icon-only control needs a tooltip.
- Hit targets must remain stable in the toolbar, rail, note markers, thumbnail grid, and window controls.
- Keyboard shortcuts should be discoverable in tooltips and configurable in settings.
- Text contrast must remain solid in dark mode, on panels, and over translucent highlights.
- File paths, selected text previews, dictionary output, and error summaries should wrap or truncate predictably.
- Destructive confirmations need explicit object names and consequences.

## Empty And Error States

- Empty reading stage: invite opening a PDF with one clear action.
- Empty library: show recent-file absence and provide the open action.
- Empty search: distinguish no query, searching, and no matches.
- Empty notes: invite creating a note without implying notes are required.
- Translation errors: show compact service failure summaries, not raw long HTML or stack traces.
- pdf2zh unavailable: say the local service was not detected and keep the current PDF usable.

## Anti Patterns

- No marketing heroes, ornamental gradients, blurred glass panels, decorative blobs, or illustration systems in the app shell.
- No nested cards.
- No colored side-stripe borders on cards, rows, alerts, or list items.
- No gradient text.
- No modal dialog as the first answer for minor actions.
- No custom-looking controls that obscure standard behavior.
- No heavy saturated color on inactive states.
- No explanatory training text in the main reading canvas.

## Implementation Notes

- Keep colors centralized in `AppColors`.
- Keep major surfaces in the existing `reader_*` widgets.
- Prefer presentational widget changes in `reader_toolbar.dart`, `reader_rail.dart`, `reader_panels.dart`, and `reader_stage.dart`; keep orchestration in `ReaderHome`.
- Preserve `ReaderToolbarMetrics` as the source for toolbar height, compact breakpoint, and minimum window size.
- Use the existing themed context menu, shortcut tooltip, window resize frame, and transition frame helpers instead of adding one-off UI systems.
- When changing rendering or PDF interaction, verify with `flutter analyze`, `flutter test`, and a manual Windows run when the change touches native window code or `pdfrx` parameters.
