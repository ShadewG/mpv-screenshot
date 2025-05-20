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

## screenshot.lua

`screenshot.lua` adds clipboard helpers. The **Ctrl+Shift+n** binding now
captures the current frame and timestamp information to the clipboard so
you can paste them manually into any application.
