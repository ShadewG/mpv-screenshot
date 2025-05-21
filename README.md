# mpv-screenshot

Utility scripts for mpv.

## preview.lua

`preview.lua` shows every video frame while you scrub through the
timeline. It listens for `time-pos` property changes and overlays the
current frame so no frames are missed.

### Key binding

* **Ctrl+Shift+o** – Toggle scrub preview on or off. Bind it to another
  key in `input.conf` if desired.

### Usage

Copy `preview.lua` into your `~/.config/mpv/scripts/` directory and
restart mpv. Toggle preview with the key binding above, then scrub using
the mouse or arrow keys to see each frame appear in an overlay.

## speedcycle.lua

`speedcycle.lua` lets you cycle through preset playback speeds using simple keybinds.

### Key bindings

* **l** – Increase speed through 2x, 4x, 8x, 10x, 15x and 20x.
* **k** – Step back down toward normal speed.

### Usage

Copy `speedcycle.lua` into your `~/.config/mpv/scripts/` directory. Use the keys above to quickly change playback speed in steps.

