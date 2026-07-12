# Design QA

- Source visual truth: `/var/folders/rh/8_cnyf3d7dx0_08ffwl_mbs80000gn/T/codex-clipboard-3bafd8c5-91d4-4e2f-89ed-f8291a81f358.png`
- Implementation screenshots: `/tmp/es-dashboard-preview/main.png`, `/tmp/es-dashboard-preview/icon.png`, `/tmp/es-dashboard-preview/history.png`, `/tmp/es-dashboard-preview/settings.png`
- Viewport: 430 × 470 points, light appearance
- State: Ready; Main, Icon, empty History, and Settings screens

## Full-view comparison evidence

The fixed outer frame, two rounded light-gray regions, left content/right navigation split, section dividers, blue resource metrics, Return to Ready control, and Quit row follow the supplied mock. The implementation uses native SF Symbols and the selected ES Status icon rather than the mock's emoji/text glyphs.

## Focused comparison evidence

Icon and Settings were captured separately because their controls are not visible in the Main reference. Icon retains all seven existing choices and the four-state preview in the fixed left region. Settings retains language, elapsed time, login launch, macOS notifications, version, and update controls without overflow. Empty History renders its title, retention rule, empty-state text, and disabled Clear button in the same fixed region.

## Findings and iteration history

- Initial P2: the first implementation was 650 points wide and visually looser than the 586-point source. Fixed by reducing the shell to 586 × 546 and reflowing Icon, language, and Advanced settings to a 430-point content column.
- Initial P2: the Icon navigation used a generic palette symbol. Fixed by using the user's currently selected ES Status icon.
- Initial P2: Quit lacked the source's keyboard shortcut label. Fixed by adding `⌘Q` to the right side of the Quit row.
- Follow-up P1: Main had excessive gaps, navigation cards visually merged, Settings lacked section hierarchy, and progress styling differed from resource metrics. Fixed by compacting the information stack, restoring five independent gray cards, adding Basic/Advanced headings and dividers, and applying the same 15-point medium blue style to elapsed/progress/remaining with blue completed blocks.
- Follow-up P1: the 546-point implementation still contained excess empty space and native `imageAbove` placed icons too far from their labels. Fixed by reducing the panel to 470 points and replacing navigation buttons with a dedicated control that centers a 28-point icon and label as one 52-point group.
- Follow-up P2: the left panel remained wider than required and the gap between R processes and Elapsed time was conspicuous. Fixed by validating the full 8-block `100%` progress string at 400 points, shrinking the outer frame to 556 points, and moving the elapsed/progress/remaining group 20 points upward.
- Follow-up P1: the requested 350-point panel and hover affordance were still missing. Fixed by setting the content panel to exactly 350 points, reducing navigation cards to 78 points, and adding active mouse tracking with a light-blue hover state. The full 8-block `100%` state was rendered without clipping.
- Follow-up P2: Icon lacked its section title and History vertically centered its whole variable-height panel, causing the title and Clear button to move. Fixed by adding a pinned Appearance header, giving History the full fixed content height, pinning its title/top metadata and Clear button, and moving only the records within the remaining middle region.
- Follow-up P1: the requested 300-point content panel, 430-point total frame, translucent surfaces, execution section, and persistent progress/ETA rows were missing. Fixed by applying those exact dimensions, using 70%-opaque background colors while keeping text opaque, adding R Execution Progress, and rendering progress/ETA placeholders when no live event exists.
- Follow-up P1: Icon still used a cramped side-by-side selector/preview layout and Settings repeated Language below Basic. Fixed by laying Appearance choices in two columns, adding a horizontal divider and 2×2 Status Preview below, renaming the Settings section to Language, and leaving only the three language buttons beneath it.
- Follow-up P2: language buttons needed a 1×2 spanning layout, Elapsed time was not persistent, resource/progress heading typography differed, and version was not visible below Settings. Fixed by using a full-width first language row, two half-width second-row buttons, persistent elapsed placeholder, matching 14-point headings, and a pinned navigation version label; language and Advanced tile backgrounds now use 70%-opaque surfaces.
- Follow-up P1: native ON switches rendered gray when the menu window was inactive and the Resource Usage title-to-first-value gap differed from Execution Progress. Fixed with a custom accent switch renderer and matching 2-point title/value spacing in both Main sections.
- Follow-up P1: the Open RStudio action clipped in the narrow navigation card, History lacked a boundary below its header, and Quit/branding occupied the wrong surfaces. Fixed by wrapping Open RStudio onto two lines, adding a pinned History divider, moving Quit into a dedicated Settings control, and pinning ES Status/version to opposite sides of Main's footer.
- Follow-up P2: Appearance was left-aligned, resource rows used 30-point spacing while execution rows used 24 points, and navigation cards retained excessive horizontal inset. Fixed by centering Appearance across the full 272-point header width, standardizing all value rows to 24-point spacing, and halving card side insets from 6 to 3 points.
- Follow-up P2: compacting the resource rows left an oversized gap before Execution Progress. Fixed by moving the complete execution block and its lower divider upward by 18 points while preserving the 24-point internal row rhythm and removing the latent detail/header overlap.
- Follow-up P1: Appearance centered the wrong element, navigation labels/icons/cards remained oversized, selected language lacked a persistent background, the section gap exceeded 10 points, Return to Ready had asymmetric divider spacing, and native NSSwitch chrome obscured the blue ON track. Fixed by centering only the two-column style controls, compacting navigation to 10-point labels and 22-point icons, adding selected-language accent fill, using an exact 10-point section gap and symmetric button dividers, and replacing NSSwitch drawing with a dedicated accent switch control.
- Follow-up P2: compact navigation content still sat visually high and the 470-point shell retained unnecessary vertical space. Fixed by centering each icon/label group from its measured combined height and reducing the shell to 440 points while preserving roughly 20 points below the final Status Preview row; Main and Settings were reflowed into the 412-point content panel without clipping.
- Follow-up P2: custom Advanced switches still snapped instantly between states. Fixed by moving track and knob rendering to Core Animation layers with synchronized 0.20-second ease-in-out position/color transitions that continue from the presentation state during rapid toggles.
- No remaining P0, P1, or P2 visual or interaction issues in the captured states.

## Required fidelity surfaces

- Typography: native macOS system typography with matched hierarchy and compact labels; no clipping except intentional truncation of the longest language button.
- Spacing/layout: fixed 430 × 470 frame, 300-point content region, 88-point navigation region, consistent 14-point outer inset and rounded panels.
- Colors/tokens: neutral light-gray panels, native separators, blue accent metrics and selected-page highlight.
- Image quality/assets: SF Symbols and the app's existing high-resolution generated status icons; no placeholder assets.
- Copy/content: Main, Icon, History, Open RStudio, Settings, resource labels, Return to Ready, Settings Quit App, history empty state, ES Status, and version are present.

## Interaction verification

- Main, Icon, History, and Settings buttons switch content in place without changing the outer size.
- Open RStudio remains an action and does not replace the current page.
- Icon selection, settings toggles, update control, History Clear, Return to Ready, and Quit retain their callbacks.

final result: passed
