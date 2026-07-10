# Design QA — Right-side Settings Menu

## Evidence

- Source reference: `/var/folders/rh/8_cnyf3d7dx0_08ffwl_mbs80000gn/T/TemporaryItems/NSIRD_screencaptureui_2ppdht/Screenshot.png`
- Implementation capture: `/tmp/rstatus-settings-submenu-switches.png`
- Viewport: 3840 × 2486 desktop capture; the open Settings menu is fully visible and legible.
- State: ES Status Settings submenu open.

The source is a structural reference rather than a pixel-identical target. The implementation intentionally uses a native macOS menu instead of copying the gray dashboard card, while retaining the requested right-side grouping and direct controls.

## Surface comparison

| Surface | Result |
| --- | --- |
| Typography | Native San Francisco menu typography is consistent with macOS menu conventions. |
| Spacing and layout | Settings opens to the right of the existing menu. Basic, Appearance, and Advanced are separated into compact groups with native separators. |
| Colors and tokens | Native menu vibrancy is preserved. Icon previews use stable state colors: blue running, green complete, red fail, and orange interrupted. |
| Image quality and assets | All seven menu-bar themes are rendered programmatically at menu-bar resolution. The Cat Original bundle icon remains sharp at standard `.icns` sizes. |
| Copy and content | Language, seven icon choices, elapsed-time visibility, and launch-at-login controls match the requested settings scope. |

## Interaction QA

- Language opens a nested System Language / 한국어 / English selector.
- Cat Original, Cat Silhouette, Status Pulse, Progress Blocks, Signal Orbit, Window Check, and Layered S display live previews and persist the selected theme.
- Appearance selections affect the menu-bar status glyph only; the app and notification identity remains the white Cat Original icon.
- The bundle icon is registered as `CatOriginal.icns`, and updates replace the entire bundle so stale icon files cannot survive installation.
- Notification Center receives a new app identity at `io.github.ljwook92.esstatus`; legacy appearance preferences migrate automatically.
- Show Elapsed Time in Menu Bar uses a native `NSSwitch` and updates the status item immediately.
- Launch at Login uses a native `NSSwitch` backed by `SMAppService`.
- Selecting language or appearance rebuilds the menu without opening a separate app window.

## Comparison history

- P2: The first implementation used menu checkmarks for Advanced options, which did not match the supplied switch reference.
- Fix: Added a purpose-built native menu item view containing `NSSwitch` controls.
- Evidence: `/tmp/rstatus-settings-submenu-switches.png` shows both Advanced settings as switches in the right-side panel.

final result: passed

## Cat icon extension

- Source visual truth: `/var/folders/rh/8_cnyf3d7dx0_08ffwl_mbs80000gn/T/TemporaryItems/NSIRD_screencaptureui_GlwgHQ/Screenshot.png`
- Implementation screenshot: `/tmp/RStatus-cat-states.png`
- Menu-with-text preview: `/tmp/RStatus-menu-complete-v054.png` at 260 × 38.
- Bundle icon preview: `/tmp/RStatus-cat-original-v053.png`
- Combined comparison evidence: `/tmp/RStatus-cat-qa-comparison.png`
- Comparison viewport: 1840 × 720, source and implementation shown in the same frame.
- State: Cat Original idle, running, complete, interrupted, and fail; Cat Silhouette retained as the secondary option.
- Focused comparison: not required because the combined frame includes enlarged 24 px renders and native 24 px previews for every state.

**Findings**

- No actionable P0/P1/P2 differences remain. Cat Original preserves the source's white face, pink ears and nose, short whiskers, gray forehead mark, state-colored outline, expression changes, and external status glyphs.
- Fonts and typography: labels are QA-only and do not ship in the icon asset; native menu typography remains unchanged.
- Spacing and layout rhythm: face-to-glyph proportions remain readable at 24 px without changing status-item height.
- Colors and visual tokens: graphite idle, cobalt running, emerald complete, amber interrupted, and red fail match the selected visual target.
- Image quality and asset fidelity: the bundle icon uses the same Cat Original face and blue ring treatment; standard `.icns` sizes were regenerated.
- Copy and content: Appearance names the selected design Cat Original and keeps Cat Silhouette as a separate option.

**Comparison history**

- P1 in v0.5.1: Cat Silhouette was incorrectly made the official default despite the selected white-cat design.
- Fix: restored the selected design as Cat Original, changed the default and bundle icon, and retained Cat Silhouette only as an optional theme.
- Post-fix evidence: `/tmp/RStatus-cat-qa-comparison.png`.
- P3 in v0.5.2: the Cat Original face had slightly more internal padding than requested.
- Fix: enlarged the menu-bar face by approximately 8% and reduced cat app-icon insets while preserving status-glyph spacing.
- P2 in v0.5.3: active-state icons dropped to 19 px beside text and the face rectangle was taller than it was wide.
- Fix: use 24 px for every menu-bar state, reduce cat image padding to 3%, and change the Cat Original menu face to a wider 0.76:0.72 proportion.
- Post-fix evidence: `/tmp/RStatus-menu-complete-v054.png` and `/tmp/RStatus-cat-states.png`.

final result: passed
