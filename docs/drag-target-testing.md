---
layout: default
title: Testing accordion and drag targets
---

# Testing accordion and drag targets

Enable `[drag] drop-targets = true`. Drag a tiled window onto another window and release over Accordion, Left, Right, Above, Below or Swap. Check tile, fixed and scrolling layouts. Escape must cancel without changing the tree. Edge resizing must retain manual proportions.

Accordion groups show peeking edges and no tab strip. Changing `[accordion] padding` changes those edges; automatic orientation follows the longer side unless explicitly chosen. Hovering a peeking edge respects `accordion-edges`. Splitting beside a group uses its whole allocation; dropping on Accordion joins it. Fixed drops keep reserved cells and scrolling drops preserve manual column widths.

Restart DinkyWinky after changing order and proportions. Saved groups must return as accordion, including snapshots written by the former tab build. Existing `layout tabs` commands select accordion as a compatibility alias. The layout menu and `list-windows` output must use accordion names.

Check that ordinary application-native tabs still follow their existing replacement handling. No DinkyWinky tab panel or tab-title cache should remain. Use disposable windows for close and replacement checks.
