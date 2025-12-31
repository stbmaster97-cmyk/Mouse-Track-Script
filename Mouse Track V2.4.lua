local obs = obslua
local ffi = require("ffi")

ffi.cdef([[
    typedef struct { long x; long y; } POINT;
    typedef struct { long left; long top; long right; long bottom; } RECT;
    typedef struct { unsigned long cbSize; RECT rcMonitor; RECT rcWork; unsigned long dwFlags; } MONITORINFO;
    typedef int (__stdcall *MONITORENUMPROC)(void*, void*, RECT*, long);
    int GetCursorPos(POINT* lpPoint);
    int GetMonitorInfoA(void* hMonitor, MONITORINFO* lpmi);
    int EnumDisplayMonitors(void* hdc, RECT* lprcClip, MONITORENUMPROC lpfnEnum, long dwData);
]])

local pt = ffi.new("POINT")
local monitors = {}
local tracker_profiles = {} 
local timer_active = false
local tracking_enabled = true
local zoom_active = false
local is_closing = false 
local center_on_stop = false
local split_hotkeys = false
local auto_disable_time = 0
local move_threshold = 10
local MAX_SOURCES = 10
local last_mouse_x, last_mouse_y = 0, 0
local idle_time = 0 

local hotkey_toggle_id = obs.OBS_INVALID_HOTKEY_ID
local hotkey_disable_id = obs.OBS_INVALID_HOTKEY_ID
local hotkey_reset_id = obs.OBS_INVALID_HOTKEY_ID
local hotkey_zoom_id = obs.OBS_INVALID_HOTKEY_ID

local function clamp(val, min, max) return math.max(min, math.min(max, val)) end

local function get_center_pos(profile)
    local src_w = obs.obs_source_get_base_width(profile.source)
    local src_h = obs.obs_source_get_base_height(profile.source)
    if src_w == 0 or src_h == 0 then return 0, 0 end
    local current_zoom = zoom_active and profile.zoom or 1.0
    local crop_w = math.floor(profile.width / current_zoom)
    local crop_h = math.floor(profile.height / current_zoom)
    return (src_w - crop_w) / 2, (src_h - crop_h) / 2
end

function toggle_tracking(pressed)
    if not pressed then return end
    if split_hotkeys then
        tracking_enabled = true
        is_closing = false
    else
        if is_closing or not tracking_enabled then
            tracking_enabled = true
            is_closing = false
        else
            if center_on_stop then is_closing = true else tracking_enabled = false end
        end
    end
end

function toggle_zoom(pressed)
    if not pressed then return end
    zoom_active = not zoom_active
end

function disable_tracking(pressed)
    if not pressed or not tracking_enabled then return end
    if center_on_stop then is_closing = true else tracking_enabled = false end
end

function reset_to_center(pressed)
    if not pressed then return end
    for _, profile in ipairs(tracker_profiles) do
        local cx, cy = get_center_pos(profile)
        profile.cur_x, profile.cur_y = cx, cy
    end
end

local function refresh_monitors()
    monitors = {}
    local callback = ffi.cast("MONITORENUMPROC", function(hMonitor, hdcMonitor, lprcMonitor, dwData)
        local mi = ffi.new("MONITORINFO")
        mi.cbSize = ffi.sizeof("MONITORINFO")
        if ffi.C.GetMonitorInfoA(hMonitor, mi) ~= 0 then
            table.insert(monitors, {
                name = "Monitor " .. (#monitors + 1) .. " (" .. (mi.rcMonitor.right - mi.rcMonitor.left) .. "x" .. (mi.rcMonitor.bottom - mi.rcMonitor.top) .. ")",
                x_min = mi.rcMonitor.left, y_min = mi.rcMonitor.top,
                x_max = mi.rcMonitor.right, y_max = mi.rcMonitor.bottom
            })
        end
        return 1
    end)
    ffi.C.EnumDisplayMonitors(nil, nil, callback, 0)
    callback:free()
end

function on_tick()
    if not tracking_enabled then return end
    if ffi.C.GetCursorPos(pt) == 0 then return end
    
    local dist = math.sqrt((pt.x - last_mouse_x)^2 + (pt.y - last_mouse_y)^2)
    if dist < move_threshold then idle_time = idle_time + 0.016 
    else idle_time = 0; last_mouse_x, last_mouse_y = pt.x, pt.y end

    if auto_disable_time > 0 and idle_time >= auto_disable_time then
        if center_on_stop then is_closing = true else tracking_enabled = false end
    end

    local any_moving = false

    for _, profile in ipairs(tracker_profiles) do
        local mon = monitors[profile.monitor_idx]
        if mon then
            local mouse_on_monitor = (pt.x >= mon.x_min and pt.x < mon.x_max and pt.y >= mon.y_min and pt.y < mon.y_max)
            profile.off_mon_timer = mouse_on_monitor and 0 or (profile.off_mon_timer + 0.016)
            local mouse_x, mouse_y = pt.x - mon.x_min, pt.y - mon.y_min
            
            local current_zoom = zoom_active and profile.zoom or 1.0
            local crop_w = math.floor(profile.width / current_zoom)
            local crop_h = math.floor(profile.height / current_zoom)
            
            local speed = 0.02 + ((profile.speed or 30) / 100) ^ 2 * 0.38
            local centerX, centerY = get_center_pos(profile)
            local target_x, target_y = profile.cur_x, profile.cur_y
            
            local r_delay = profile.reset_delay or 2.0
            local o_delay = profile.off_delay or 1.0
            local should_reset = is_closing or (idle_time >= r_delay and mouse_on_monitor) or (profile.off_mon_timer >= o_delay)

            if should_reset then target_x, target_y = centerX, centerY 
            elseif mouse_on_monitor then
                local view_center_x = profile.cur_x + crop_w * 0.5
                local dz_x = crop_w * ((profile.deadzone or 0) / 100) * 0.5
                if mouse_x < view_center_x - dz_x then target_x = mouse_x - crop_w * 0.5 + dz_x
                elseif mouse_x > view_center_x + dz_x then target_x = mouse_x - crop_w * 0.5 - dz_x end
                local view_center_y = profile.cur_y + crop_h * 0.5
                local dz_y = crop_h * ((profile.deadzone or 0) / 100) * 0.5
                if mouse_y < view_center_y - dz_y then target_y = mouse_y - crop_h * 0.5 + dz_y
                elseif mouse_y > view_center_y + dz_y then target_y = mouse_y - crop_h * 0.5 - dz_y end
            end

            local dx, dy = target_x - profile.cur_x, target_y - profile.cur_y
            if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then any_moving = true end
            profile.cur_x, profile.cur_y = profile.cur_x + (dx * speed), profile.cur_y + (dy * speed)

            local src_w, src_h = obs.obs_source_get_base_width(profile.source), obs.obs_source_get_base_height(profile.source)
            if src_w > 0 and src_h > 0 then
                profile.cur_x = clamp(profile.cur_x, 0, src_w - crop_w)
                profile.cur_y = clamp(profile.cur_y, 0, src_h - crop_h)
                
                -- Update Crop Filter
                obs.obs_data_set_int(profile.settings, "left", math.floor(profile.cur_x))
                obs.obs_data_set_int(profile.settings, "top", math.floor(profile.cur_y))
                obs.obs_data_set_int(profile.settings, "cx", crop_w)
                obs.obs_data_set_int(profile.settings, "cy", crop_h)
                obs.obs_source_update(profile.filter, profile.settings)
            end
        end
    end
    if is_closing and not any_moving then tracking_enabled = false; is_closing = false end
end

function script_properties()
    refresh_monitors()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_bool(props, "center_on_stop", "Center View Before Disabling")
    obs.obs_properties_add_bool(props, "split_hotkeys", "Split Hotkeys (Enable / Disable)")
    obs.obs_properties_add_int_slider(props, "auto_disable_time", "Auto-Disable if Idle (sec)", 0, 30, 1)
    obs.obs_properties_add_int_slider(props, "move_threshold", "Movement Threshold (px)", 1, 1000, 1)
    
    local sc = obs.obs_properties_add_int_slider(props, "source_count", "Number of Sources", 1, MAX_SOURCES, 1)
    obs.obs_property_set_modified_callback(sc, function(p, prop, settings)
        local count = obs.obs_data_get_int(settings, "source_count")
        for i = 1, MAX_SOURCES do
            local group = obs.obs_properties_get(p, "group_" .. i)
            if group then obs.obs_property_set_visible(group, i <= count) end
        end
        return true
    end)

    for i = 1, MAX_SOURCES do
        local g_props = obs.obs_properties_create()
        obs.obs_properties_add_list(g_props, "s" .. i .. "_name", "Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
        local m_list = obs.obs_properties_add_list(g_props, "s" .. i .. "_mon", "Monitor Boundary", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
        for idx, m in ipairs(monitors) do obs.obs_property_list_add_int(m_list, m.name, idx) end

        local p_list = obs.obs_properties_add_list(g_props, "s" .. i .. "_preset", "Preset", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
        obs.obs_property_list_add_string(p_list, "TikTok (608x1080)", "tiktok")
        obs.obs_property_list_add_string(p_list, "Square (1080x1080)", "square")
        obs.obs_property_list_add_string(p_list, "Custom", "custom")

        obs.obs_properties_add_int(g_props, "s" .. i .. "_w", "Width", 100, 3840, 1)
        obs.obs_properties_add_int(g_props, "s" .. i .. "_h", "Height", 100, 3840, 1)
        obs.obs_properties_add_float_slider(g_props, "s" .. i .. "_zoom", "Zoom Multiplier", 0.5, 5.0, 0.1)
        obs.obs_properties_add_int_slider(g_props, "s" .. i .. "_speed", "Speed %", 0, 100, 1)
        obs.obs_properties_add_int_slider(g_props, "s" .. i .. "_dz", "Deadzone %", 0, 100, 1)
        obs.obs_properties_add_float_slider(g_props, "s" .. i .. "_rdelay", "On-Screen Idle Reset (sec)", 0.0, 10.0, 0.5)
        obs.obs_properties_add_float_slider(g_props, "s" .. i .. "_off_delay", "Off-Screen Reset (sec)", 0.0, 10.0, 0.5)

        local group = obs.obs_properties_add_group(props, "group_" .. i, "Source " .. i, obs.OBS_GROUP_NORMAL, g_props)
        obs.obs_property_set_visible(group, i == 1)
    end
    
    local sources = obs.obs_enum_sources()
    for i = 1, MAX_SOURCES do
        local p = obs.obs_properties_get(props, "s" .. i .. "_name")
        if p then
            obs.obs_property_list_clear(p)
            obs.obs_property_list_add_string(p, "<None>", "")
            if sources then
                for _, src in ipairs(sources) do
                    local n = obs.obs_source_get_name(src)
                    obs.obs_property_list_add_string(p, n, n)
                end
            end
        end
    end
    if sources then obs.source_list_release(sources) end
    return props
end

function script_update(settings)
    center_on_stop = obs.obs_data_get_bool(settings, "center_on_stop")
    split_hotkeys = obs.obs_data_get_bool(settings, "split_hotkeys")
    auto_disable_time = obs.obs_data_get_int(settings, "auto_disable_time")
    move_threshold = obs.obs_data_get_int(settings, "move_threshold")

    if timer_active then obs.timer_remove(on_tick) end
    for _, p in ipairs(tracker_profiles) do
        obs.obs_source_release(p.source); obs.obs_source_release(p.filter); obs.obs_data_release(p.settings)
    end
    tracker_profiles = {}

    local count = obs.obs_data_get_int(settings, "source_count")
    for i = 1, count do
        local name = obs.obs_data_get_string(settings, "s" .. i .. "_name")
        if name and name ~= "" and name ~= "<None>" then
            local src = obs.obs_get_source_by_name(name)
            if src then
                local filter_name = "Track_P" .. i
                local scale_filter_name = "Stretch_P" .. i
                
                -- Anti-stacking cleanup
                local old_f = obs.obs_source_get_filter_by_name(src, filter_name)
                if old_f then obs.obs_source_filter_remove(src, old_f); obs.obs_source_release(old_f) end
                local old_s = obs.obs_source_get_filter_by_name(src, scale_filter_name)
                if old_s then obs.obs_source_filter_remove(src, old_s); obs.obs_source_release(old_s) end
                
                local preset = obs.obs_data_get_string(settings, "s" .. i .. "_preset")
                local w, h = obs.obs_data_get_int(settings, "s" .. i .. "_w"), obs.obs_data_get_int(settings, "s" .. i .. "_h")
                if preset == "tiktok" then w, h = 608, 1080 elseif preset == "square" then w, h = 1080, 1080 end
                
                -- Create Crop Filter
                local s_data = obs.obs_data_create()
                obs.obs_data_set_bool(s_data, "relative", false)
                local f = obs.obs_source_create_private("crop_filter", filter_name, s_data)
                obs.obs_source_filter_add(src, f)
                
                -- Create Scale Filter (To force the Stretch)
                local scale_data = obs.obs_data_create()
                obs.obs_data_set_string(scale_data, "resolution", tostring(w) .. "x" .. tostring(h))
                obs.obs_data_set_string(scale_data, "sampling", "bicubic")
                local sf = obs.obs_source_create_private("scale_filter", scale_filter_name, scale_data)
                obs.obs_source_filter_add(src, sf)
                obs.obs_data_release(scale_data)
                
                table.insert(tracker_profiles, {
                    source = src, filter = f, settings = s_data,
                    monitor_idx = obs.obs_data_get_int(settings, "s" .. i .. "_mon"),
                    width = w, height = h, zoom = obs.obs_data_get_double(settings, "s" .. i .. "_zoom"),
                    speed = obs.obs_data_get_int(settings, "s" .. i .. "_speed"),
                    deadzone = obs.obs_data_get_int(settings, "s" .. i .. "_dz"),
                    reset_delay = obs.obs_data_get_double(settings, "s" .. i .. "_rdelay"),
                    off_delay = obs.obs_data_get_double(settings, "s" .. i .. "_off_delay"),
                    cur_x = 0, cur_y = 0, off_mon_timer = 0
                })
            end
        end
    end
    if #tracker_profiles > 0 then obs.timer_add(on_tick, 16); timer_active = true end
end

function script_load(settings)
    hotkey_toggle_id = obs.obs_hotkey_register_frontend("toggle_tracking_k", "Toggle / Enable Mouse Tracking", toggle_tracking)
    hotkey_disable_id = obs.obs_hotkey_register_frontend("disable_tracking_k", "Disable Mouse Tracking (Split Mode Only)", disable_tracking)
    hotkey_reset_id = obs.obs_hotkey_register_frontend("reset_tracking_k", "Reset Tracker Position", reset_to_center)
    hotkey_zoom_id = obs.obs_hotkey_register_frontend("toggle_zoom_k", "Toggle Zoom Level", toggle_zoom)
end

function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "source_count", 1)
    obs.obs_data_set_default_bool(settings, "center_on_stop", true)
    obs.obs_data_set_default_bool(settings, "split_hotkeys", false)
    obs.obs_data_set_default_int(settings, "auto_disable_time", 0)
    obs.obs_data_set_default_int(settings, "move_threshold", 10)
    for i = 1, MAX_SOURCES do
        obs.obs_data_set_default_string(settings, "s" .. i .. "_preset", "tiktok")
        obs.obs_data_set_default_int(settings, "s" .. i .. "_w", 608)
        obs.obs_data_set_default_int(settings, "s" .. i .. "_h", 1080)
        obs.obs_data_set_default_double(settings, "s" .. i .. "_zoom", 2.0)
        obs.obs_data_set_default_int(settings, "s" .. i .. "_speed", 30)
        obs.obs_data_set_default_double(settings, "s" .. i .. "_rdelay", 2.0)
        obs.obs_data_set_default_double(settings, "s" .. i .. "_off_delay", 1.0)
    end
end

function script_description()
    return "Mouse Tracking Screen V2.4.\n\nBUGS\n-Zooming have a odd effect"
end