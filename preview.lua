-- preview.lua
-- Display every video frame when scrubbing.
-- Toggle with Ctrl+Shift+o (change in input.conf if needed).
-- Uses screenshot-to-file and overlay-add to show current frame.

local utils = require 'mp.utils'

local tmpdir = os.getenv('TMPDIR') or os.getenv('TEMP') or os.getenv('TMP') or '/tmp'
local tmpfile = utils.join_path(tmpdir, 'mpv_preview.png')
local preview_enabled = false
local overlay_id = 99

local overlay_scale = 0.25

local function show_frame(_, pos)
    if not preview_enabled or not pos then return end

    mp.commandv('screenshot-to-file', tmpfile, 'video')

    local w = mp.get_property_number('osd-width')
    local h = mp.get_property_number('osd-height')
    if not (w and h) then return end

    local ow = math.floor(w * overlay_scale)
    local oh = math.floor(h * overlay_scale)
    local ox = w - ow - 10
    local oy = h - oh - 10

    mp.command_native({
        name = 'overlay-add',
        id = overlay_id,
        file = tmpfile,
        x = ox,
        y = oy,
        width = ow,
        height = oh
    })
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
