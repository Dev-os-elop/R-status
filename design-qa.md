# Design QA — Right-side Settings Menu

## Evidence

- Source reference: `/var/folders/rh/8_cnyf3d7dx0_08ffwl_mbs80000gn/T/TemporaryItems/NSIRD_screencaptureui_2ppdht/Screenshot.png`
- Implementation capture: `/tmp/rstatus-settings-submenu-switches.png`
- Viewport: 3840 × 2486 desktop capture; the open Settings menu is fully visible and legible.
- State: RStudio Status Settings submenu open.

The source is a structural reference rather than a pixel-identical target. The implementation intentionally uses a native macOS menu instead of copying the gray dashboard card, while retaining the requested right-side grouping and direct controls.

## Surface comparison

| Surface | Result |
| --- | --- |
| Typography | Native San Francisco menu typography is consistent with macOS menu conventions. |
| Spacing and layout | Settings opens to the right of the existing menu. Basic, Appearance, and Advanced are separated into compact groups with native separators. |
| Colors and tokens | Native menu vibrancy is preserved. Icon previews use stable state colors: blue running, green complete, red fail, and orange interrupted. |
| Image quality and assets | All seven menu-bar themes are rendered programmatically at menu-bar resolution. The Cat Silhouette bundle icon remains sharp at standard `.icns` sizes. |
| Copy and content | Language, seven icon choices, elapsed-time visibility, and launch-at-login controls match the requested settings scope. |

## Interaction QA

- Language opens a nested System Language / 한국어 / English selector.
- Cat Outline, Cat Silhouette, Status Pulse, Progress Blocks, Signal Orbit, Window Check, and Layered S display live previews and persist the selected theme.
- Show Elapsed Time in Menu Bar uses a native `NSSwitch` and updates the status item immediately.
- Launch at Login uses a native `NSSwitch` backed by `SMAppService`.
- Selecting language or appearance rebuilds the menu without opening a separate app window.

## Comparison history

- P2: The first implementation used menu checkmarks for Advanced options, which did not match the supplied switch reference.
- Fix: Added a purpose-built native menu item view containing `NSSwitch` controls.
- Evidence: `/tmp/rstatus-settings-submenu-switches.png` shows both Advanced settings as switches in the right-side panel.

final result: passed

## Cat icon extension

- Source reference: `/var/folders/rh/8_cnyf3d7dx0_08ffwl_mbs80000gn/T/TemporaryItems/NSIRD_screencaptureui_U6auwu/Screenshot.png`
- Implementation contact sheet: `/tmp/RStatus-cat-states.png`
- Bundle icon preview: `/tmp/RStatus-cat.png`
- Verified states: idle gray circles, running blue play eyes, complete green check eyes, interrupted amber pause eyes, and fail red X eyes.
- Verified styles: Cat Outline and Cat Silhouette share the same geometry and remain recognizable at a rendered 19 px preview.
- Intentional simplification: no mouth, nose, whiskers, body, tail, or external state badge; status information lives entirely in eye color and shape.

final result: passed
