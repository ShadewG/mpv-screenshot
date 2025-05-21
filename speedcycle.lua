-- speedcycle.lua
-- Cycle through playback speeds with key presses.
-- Increase speed with Ctrl+Shift+l, decrease with Ctrl+Shift+k.
-- Speeds: 2x, 4x, 8x, 10x, 15x, 20x. Defaults to normal speed.

local speeds = {2, 4, 8, 10, 15, 20}
local index = 0 -- 0 means normal speed (1x)

local function apply_speed()
    if index == 0 then
        mp.set_property_number('speed', 1)
    else
        mp.set_property_number('speed', speeds[index])
    end
    local spd = mp.get_property('speed')
    mp.osd_message(('Speed: %sx'):format(spd))
end

local function speed_up()
    if index < #speeds then
        index = index + 1
        apply_speed()
    else
        mp.osd_message('Speed: ' .. speeds[#speeds] .. 'x')
    end
end

local function speed_down()
    if index > 0 then
        index = index - 1
        apply_speed()
    else
        mp.osd_message('Speed: 1x')
    end
end

mp.add_key_binding('Ctrl+Shift+l', 'speed-up-cycle', speed_up)
mp.add_key_binding('Ctrl+Shift+k', 'speed-down-cycle', speed_down)
