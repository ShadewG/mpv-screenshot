-- preview.lua
-- Display every video frame when scrubbing.
-- Toggle with Ctrl+Shift+o (change in input.conf if needed).
-- Uses screenshot-to-file and overlay-add to show current frame.

local utils = require 'mp.utils'

local tmpdir = os.getenv('TMPDIR') or os.getenv('TEMP') or os.getenv('TMP') or '/tmp'
local tmpfile = utils.join_path(tmpdir, 'mpv_preview.png')
local preview_enabled = false
local overlay_id = 99

local function show_frame(_, pos)
    if not preview_enabled or not pos then return end
    mp.commandv('screenshot-to-file', tmpfile, 'video')
    mp.command_native({ name = 'overlay-add', id = overlay_id, x = 0, y = 0, file = tmpfile })
end

local function toggle_preview()
    preview_enabled = not preview_enabled
    if preview_enabled then
        mp.observe_property('time-pos', 'native', show_frame)
        mp.osd_message('Scrub preview ON')
    else
        mp.unobserve_property(show_frame)
        mp.command_native({ name = 'overlay-remove', id = overlay_id })
        mp.osd_message('Scrub preview OFF')
    end
end

mp.add_key_binding('Ctrl+Shift+o', 'toggle-scrub-preview', toggle_preview)
