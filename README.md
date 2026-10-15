# DinkyWinky

DinkyWinky is a personal fork of [Dinky](https://github.com/mikker/Dinky) with drag targets, accordion stacking and session restoration. The independent feature branches keep the upstream app identity for future pull requests. The `fork/dinkywinky` branch contains the combined build and its separate identity.

Build the local signed bundle with `IDENTITY='WinMuxX Local Code Signing' scripts/bundle.sh`. It produces `build/DinkyWinky.app`; the bundled CLI is `Contents/MacOS/dinkywinky`. The app uses `~/.config/dinkywinky/dinkywinky.toml`, `~/Library/Application Support/dinkywinky`, `~/Library/Logs/dinkywinky.log`, and its own temporary command socket. Its bundle identifier is `com.gfavaro.DinkyWinky`. The upstream automatic update feed is disabled for this build.

Dinky and DinkyWinky can both be installed. Quit one before running the other. Comparison builds use separate saved state; copying the initial config does not synchronize later changes. DinkyWinky needs its own Accessibility grant. Use the local bundle workflow for this fork; upstream release and VM scripts retain their original Dinky packaging and credentials.

---

<img src="docs/assets/icon.png" alt="dinky" width="128">

# dinky

> oh wow. you moved a rectangle.

A tiling window manager for macOS that leaves System Integrity Protection on.

```sh
brew install --cask mikker/tap/dinky
```

[Documentation](https://dinky.rodeo)

## Quick start

Open dinky and grant Accessibility when asked. Windows tile as they open.

- `dinky workspace 3`: Switch to workspace 3.
- `dinkywinky layout accordion`: Stack the focused container with peeking edges.
- `dinky doctor`: Check the config, the macOS settings dinky needs, and that no other tiler is running.

Learn more:

- [Configuration](https://dinky.rodeo/configuration/)
- [Commands](https://dinky.rodeo/commands/)

MIT licensed.
