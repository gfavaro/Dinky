---
layout: default
title: Testing session restoration
---

# Testing session restoration

Use disposable windows for close and replacement checks. Record the starting Space and frame of each test window before enabling Dinky.

| Action | Expected result |
|---|---|
| Start enabled, then disable | Original reachable frames and surviving original Spaces return. The active Space stays unchanged. |
| Quit, then restart | The managed window order, layout and split ratios return before tiling. |
| Change a split size, then restart | The saved proportions return with the current display bounds. |
| Visit an inactive Space after restart | Its surviving windows use the saved layout. |
| Move or resize a floating window, then restart | Its saved frame fits the current monitor. |
| Move a window to another Space while disabled | Startup respects the changed Space. |
| Fail a restore, then change that window's frame or Space | A later explicit recovery leaves it where it is. Repeat after relaunching. |
| Fail a restore without moving the window | The next explicit recovery tries its original destination again. |
| Receive a late successful write | Recovery confirms success before checking for a position change. |
| Delete an original Space | Undo keeps its window on the current Space and fits its original frame to the available monitor. |
| Delete a managed Space | Startup can use its existing configured workspace binding; it does not create a Space solely for restoration. |
| Disconnect a display or hide/minimize a window | Inaccessible restoration remains pending. Revisit or show the window and retry explicitly. |
| Close a window or replace its application process | Stale saved entries do not control the replacement window. |
| Start disabled before granting Accessibility | New origins and layouts remain untouched until enabled. |
| Keep one application unresponsive | Responsive apps report results independently. Unconfirmed windows remain pending. |
| Repeat quit/restart and explicit recovery | Completed records disappear; pending state remains bounded by live window identities. |

The recovery file is `~/Library/Application Support/dinky/journal.json`. The managed layout is in `session.json` beside it. Preserve copies when reporting a failure; they contain window identifiers and layout data. Automated tests use injected frame reads and writes and do not close user windows.
