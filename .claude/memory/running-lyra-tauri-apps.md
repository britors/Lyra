---
name: running-lyra-tauri-apps
description: "How to launch Lyra's Tauri GUI apps (welcome, upgrade) from this sandbox, and why screenshots are impossible"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6ab30ef8-e2a5-4b3c-977c-dd39e345d3f0
  modified: 2026-08-19T17:48:37.686Z
---

The Bash sandbox reaches the user's Wayland socket but NOT XWayland or the
screenshot portal. Consequences when launching Lyra's Tauri apps:

- Launch WITHOUT `GDK_BACKEND=x11`. With it, GTK cannot open the X display and
  the process exits 0 with an empty log, looking like a silent crash.
  Working form: `setsid env WEBKIT_DISABLE_COMPOSITING_MODE=1 ./binary &`
- `xdotool` is not installed and `import -window` fails: there is no way to
  capture or verify the window from here. Visual confirmation is the user's.
- Binary paths do not match the app directory: welcome builds to
  `welcome/src-tauri/target/debug/lyra-welcome`, but the upgrade UI builds to
  `upgrade/target/debug/lyra-upgrade-ui` (crate name `lyra-upgrade-ui`).
- The upgrade UI takes `LYRA_UPGRADE_LAYOUT_PREVIEW=1` to show its layout
  without starting a real upgrade operation.
- `pkill -f` on these paths kills the invoking shell too (its own command line
  matches). Use `pkill -x lyra-welcome` / `pkill -x lyra-upgrade-ui`.
