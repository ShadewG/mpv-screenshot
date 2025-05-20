-- mpv-clipboard-tools.lua
--
-- Copy screenshot to clipboard and various text information
--
-- Features:
-- - Copy screenshot to clipboard (Ctrl+Shift+f)
-- - Copy filename (Ctrl+f)
-- - Copy full path (Ctrl+p)
-- - Copy timestamp (Ctrl+t)
-- - Copy duration (Ctrl+d)
-- - Copy filename and timestamp (Ctrl+Shift+t)
-- - Insert screenshot and timestamp into Notion (Ctrl+Shift+n)

local msg = require 'mp.msg'
local utils = require 'mp.utils'

-- Platform detection
WINDOWS = 2
UNIX = 3

local function platform_type()
    local workdir = utils.to_string(mp.get_property_native("working-directory"))
    if string.find(workdir, "\\") then
        return WINDOWS
    else
        return UNIX
    end
end

local function command_exists(cmd)
    local pipe = io.popen("type " .. cmd .. " > /dev/null 2> /dev/null; printf \"$?\"", "r")
    exists = pipe:read() == "0"
    pipe:close()
    return exists
end

local function get_clipboard_cmd()
    if command_exists("xclip") then
        return "xclip -silent -in -selection clipboard"
    elseif command_exists("wl-copy") then
        return "wl-copy"
    elseif command_exists("pbcopy") then
        return "pbcopy"
    else
        msg.error("No supported clipboard command found")
        return false
    end
end

local function divmod(a, b)
    return a / b, a % b
end

-- Window title used for Notion; override with NOTION_WINDOW_TITLE env variable
local notion_window_title = os.getenv("NOTION_WINDOW_TITLE") or "Notion"

-- Paste clipboard contents into the active window (optionally activating a
-- specific window first). This sends an Enter key before Ctrl+V to ensure the
-- paste works even if no text field is focused.
local function paste_clipboard(window_name)
    local cmd
    if platform == WINDOWS then
        local script
        if window_name then
            script = string.format(
                "$ws=New-Object -ComObject WScript.Shell;" ..
                "$ws.AppActivate('%s');Start-Sleep -Milliseconds 100;" ..
                "$ws.SendKeys('{ENTER}');$ws.SendKeys('^v')",
                window_name
            )
        else
            script = "$ws=New-Object -ComObject WScript.Shell;" ..
                     "$ws.SendKeys('{ENTER}');$ws.SendKeys('^v')"
        end
        cmd = {"powershell", "-Command", script}
    elseif command_exists("xdotool") then
        if window_name then
            cmd = {"xdotool", "search", "--name", window_name,
                    "windowactivate", "--sync", "key", "Return", "ctrl+v"}
        else
            cmd = {"xdotool", "key", "Return", "ctrl+v"}
        end
    else
        msg.error("No supported paste command found")
        return false
    end

    mp.command_native({ name = "subprocess", args = cmd })
    return true
end

-- Get temporary directory for screenshot
local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"

-- Function to set text to clipboard
local function set_clipboard(text)
    if platform == WINDOWS then
        mp.commandv("run", "powershell", "set-clipboard", table.concat({'"', text, '"'}))
        return true
    elseif (platform == UNIX and clipboard_cmd) then
        local pipe = io.popen(clipboard_cmd, "w")
        pipe:write(text)
        pipe:close()
        return true
    else
        msg.error("Set_clipboard error")
        return false
    end
end

-- Function to format seconds into HH:MM:SS.mmm
function format_timestamp(seconds)
    if seconds == nil then return "N/A" end
    local minutes, remainder = divmod(seconds, 60)
    local hours, minutes = divmod(minutes, 60)
    local seconds = math.floor(remainder)
    local milliseconds = math.floor((remainder - seconds) * 1000)
    return string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
end

-- Function to copy image to clipboard
function copy_image_to_clipboard(image_path)
    local success = false
    
    if platform == WINDOWS then
        -- Use PowerShell to copy image to clipboard
        local ps_script_path = utils.join_path(temp_dir, "mpv_img_clipboard.ps1")
        local ps_file = io.open(ps_script_path, "w")
        ps_file:write([[
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    $imagePath = "]] .. image_path:gsub("\\", "\\\\") .. [["
    
    if (Test-Path $imagePath) {
        $image = [System.Drawing.Image]::FromFile($imagePath)
        [System.Windows.Forms.Clipboard]::SetImage($image)
        $image.Dispose()
        exit 0
    } else {
        Write-Error "File not found: $imagePath"
        exit 1
    }
} catch {
    Write-Error $_.Exception.Message
    exit 2
}
]])
        ps_file:close()
        
        -- Execute the PowerShell script
        local cmd = string.format('powershell -ExecutionPolicy Bypass -File "%s"', ps_script_path)
        msg.info("Running image clipboard command: " .. cmd)
        
        local result = os.execute(cmd)
        success = (result == 0 or result == true)
        
        -- Clean up the script
        os.remove(ps_script_path)
    elseif platform == UNIX then
        if clipboard_cmd then
            if string.find(clipboard_cmd, "xclip") then
                os.execute(string.format("xclip -selection clipboard -t image/png -i '%s'", image_path))
            elseif string.find(clipboard_cmd, "wl-copy") then
                os.execute(string.format("wl-copy < '%s'", image_path))
            elseif string.find(clipboard_cmd, "pbcopy") then
                os.execute(string.format("osascript -e 'set the clipboard to (read (POSIX file \"%s\") as JPEG picture)'", image_path))
            end
            success = true
        end
    end
    
    return success
end

-- Copy screenshot to clipboard
function take_screenshot_to_clipboard()
    -- Create a temporary file for the screenshot
    local temp_screenshot = utils.join_path(temp_dir, "mpv_screenshot_" .. os.time() .. ".png")
    msg.info("Saving screenshot to: " .. temp_screenshot)
    
    -- Take a screenshot directly to our temp file
    mp.commandv("screenshot-to-file", temp_screenshot, "video")
    
    -- Short delay to ensure the file is written
    mp.add_timeout(0.2, function()
        -- Check if the screenshot was saved
        local file = io.open(temp_screenshot, "r")
        if not file then
            mp.osd_message("Failed to save screenshot to temporary file.", 3)
            msg.error("Failed to save screenshot to: " .. temp_screenshot)
            return
        end
        file:close()
        msg.info("Screenshot saved successfully to: " .. temp_screenshot)
        
        -- Copy the image to clipboard
        local success = copy_image_to_clipboard(temp_screenshot)
        
        if success then
            mp.osd_message("Screenshot copied to clipboard!", 3)
            msg.info("Screenshot copied to clipboard")
        else
            mp.osd_message("Failed to copy screenshot to clipboard.", 3)
            msg.error("Failed to copy screenshot to clipboard")
        end
        
        -- Clean up the temporary screenshot file
        os.remove(temp_screenshot)
        msg.info("Cleaned up temporary file")
    end)
end

-- Copy Time
function copy_time()
    local time_pos = mp.get_property_number("time-pos")
    local formatted = format_timestamp(time_pos)
    
    if set_clipboard(formatted) then
        mp.osd_message(string.format("Time Copied to Clipboard: %s", formatted))
    else
        mp.osd_message("Failed to copy time to clipboard")
    end
end

-- Copy Filename with Extension
function copy_filename()
    local filename = string.format("%s", mp.get_property_osd("filename"))
    local extension = string.match(filename, "%.(%w+)$")

    local succ_message = "Filename Copied to Clipboard"
    local fail_message = "Failed to copy filename to clipboard"

    -- If filename doesn't have an extension then it is a URL.
    if not extension then
        filename = mp.get_property_osd("path")

        succ_message = "URL Copied to Clipboard"
        fail_message = "Failed to copy URL to clipboard"
    end

    if set_clipboard(filename) then
        mp.osd_message(string.format("%s: %s", succ_message, filename))
    else
        mp.osd_message(string.format("%s", fail_message))
    end
end

-- Copy Full Filename Path
function copy_full_path()
    local full_path = ""
    if platform == WINDOWS then
        full_path = string.format("%s\\%s", mp.get_property_osd("working-directory"), mp.get_property_osd("path"))
    else
        full_path = string.format("%s/%s", mp.get_property_osd("working-directory"), mp.get_property_osd("path"))
    end

    if set_clipboard(full_path) then
        mp.osd_message(string.format("Full Filename Path Copied to Clipboard: %s", full_path))
    else
        mp.osd_message("Failed to copy full filename path to clipboard")
    end
end

-- Copy Current Video Duration
function copy_duration()
    local duration = string.format("%s", mp.get_property_osd("duration"))

    if set_clipboard(duration) then
        mp.osd_message(string.format("Video Duration Copied to Clipboard: %s", duration))
    else
        mp.osd_message("Failed to copy video duration to clipboard")
    end
end

-- Copy filename and timestamp
function copy_info()
    local filename = mp.get_property("filename")
    local time_pos = mp.get_property_number("time-pos")
    local formatted = format_timestamp(time_pos)
    local info = string.format("File: %s\nTimestamp: %s", filename, formatted)
    
    if set_clipboard(info) then
        mp.osd_message(string.format("Info Copied to Clipboard:\n%s", info))
    else
        mp.osd_message("Failed to copy info to clipboard")
    end
end

-- Take a screenshot and paste it along with info into the active window (e.g. Notion)
function insert_into_notion()
    local temp_screenshot = utils.join_path(temp_dir, "mpv_screenshot_" .. os.time() .. ".png")
    mp.commandv("screenshot-to-file", temp_screenshot, "video")

    mp.add_timeout(0.2, function()
        local file = io.open(temp_screenshot, "r")
        if not file then
            mp.osd_message("Failed to save screenshot", 3)
            return
        end
        file:close()

        if copy_image_to_clipboard(temp_screenshot) then
            paste_clipboard(notion_window_title)
        else
            mp.osd_message("Failed to copy screenshot to clipboard", 3)
        end

        os.remove(temp_screenshot)

        mp.add_timeout(0.1, function()
            local filename = mp.get_property("filename")
            local path = mp.get_property("path")
            local full_path
            if platform == WINDOWS then
                full_path = mp.get_property("working-directory") .. "\\" .. path
            else
                full_path = mp.get_property("working-directory") .. "/" .. path
            end
            local time_pos = mp.get_property_number("time-pos")
            local formatted = format_timestamp(time_pos)
            local info = string.format("Timestamp: %s\nFile: %s\nPath: %s", formatted, filename, full_path)
            if set_clipboard(info) then
                paste_clipboard(notion_window_title)
                mp.osd_message("Inserted screenshot and info", 3)
            else
                mp.osd_message("Failed to copy info to clipboard", 3)
            end
        end)
    end)
end

-- Initialize platform detection
platform = platform_type()
if platform == UNIX then
    clipboard_cmd = get_clipboard_cmd()
end

-- Key-Bindings
mp.add_key_binding("Ctrl+t", "copy-time", copy_time)
mp.add_key_binding("Ctrl+f", "copy-filename", copy_filename)
mp.add_key_binding("Ctrl+p", "copy-full-path", copy_full_path)
mp.add_key_binding("Ctrl+d", "copy-duration", copy_duration)
mp.add_key_binding("Ctrl+Shift+t", "copy-info", copy_info)
mp.add_key_binding("Ctrl+Shift+f", "screenshot-to-clipboard", take_screenshot_to_clipboard)
mp.add_key_binding("Ctrl+Shift+n", "insert-into-notion", insert_into_notion)

-- Register script messages for binding in input.conf
mp.register_script_message("screenshot-to-clipboard-message", take_screenshot_to_clipboard)
mp.register_script_message("copy-time-message", copy_time)
mp.register_script_message("copy-filename-message", copy_filename)
mp.register_script_message("copy-full-path-message", copy_full_path)
mp.register_script_message("copy-duration-message", copy_duration)
mp.register_script_message("copy-info-message", copy_info)
mp.register_script_message("insert-into-notion-message", insert_into_notion)

msg.info("Clipboard tools script loaded with platform type: " .. platform)