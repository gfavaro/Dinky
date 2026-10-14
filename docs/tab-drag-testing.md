---
layout: default
title: Testing tabs and drag targets
description: Automated checks and manual cases for tab groups and drag targets.
permalink: /tab-drag-testing/
---

# Testing tabs and drag targets

Run the package checks with `swift test`. To run only the AppKit checks, use
`swift test --filter DinkyAppTests`.

The app tests use offscreen panels and stub close callbacks. They do not close
application windows, move user windows, switch Spaces, or install an event tap.
They cover tab selection, reorder, detach, cancellation, title clipping,
close-button targeting, title-event coalescing, title caching, compact shell rendering,
and panel cleanup. The fallback tab
style can be exercised on macOS 27 as well as the native tab role.

The pure layout tests cover directional drops in dwindle, fixed, and scrolling
layouts, tab selection, group borders, native tab replacement, saved ratios,
legacy names, stale intents, and repeated tree edits.

## Manual checks

Use disposable windows from at least two applications. Enable the targets:

```toml
[drag]
drop-targets = true
```

| Case | Expected result |
|---|---|
| Drag a window over each of the six targets | Release applies the selected target once. |
| Drag over a target, then press Escape | The tree stays unchanged and the overlay closes. |
| Resize a window by its edge | The layout keeps the new size; no drop target appears. |
| Select a tab | Its window comes to the front without moving the other members. |
| Drag a tab horizontally | The order changes and saved tile ratios stay with their windows. |
| Pull a tab out of the strip | A drag label follows the pointer; release applies the chosen target. |
| Pull a tab out, then return to the strip | The gesture stays a detach until release or Escape. |
| Hover a long title | The close button has its own slot and the title stays inside its tab. |
| Close an unsaved document through its tab | Its application handles the save prompt. |
| Switch from tabs to tiles and back | The group keeps its orientation and saved ratios. |
| Switch native Spaces or enter Mission Control during a drag | The drag cancels; panels do not remain on the previous Space. |
| Hide an app, minimize a member, or switch an application's native tabs | Window membership follows Dinky's existing visibility and replacement handling. |
| Disconnect and reconnect a display | Panels follow the current layout and stay on their assigned native Space. |
| Disable and enable Dinky | Panels close while disabled and rebuild when enabled. |
| Switch tabs and Spaces repeatedly, then finish a drag | Hidden full-size border and preview windows are released. Tab selection reuses the current group border. |
| Turn off drop targets | Dragging over another tile swaps the windows; other drops return to the existing allocation. |

Check light and dark appearances, borders on and off, and narrow tab strips.
Run the native window checks on macOS 15 or 26 before merge; forcing the fallback
style on macOS 27 verifies the control path but does not test the older OS.

Check a narrow group with ten windows. The selected tab must stay visible. Use the arrows and trackpad to scroll, then select and close a test window. Check that the action applies to the tab under the pointer. In a wide group, click the blank area after the tabs; selection must stay unchanged. Drag between tabs and check that the insertion marker stays above the strip.
