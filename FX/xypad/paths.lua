-- @noindex

local ImGui = require 'imgui' '0.9.2'
local path_history = require 'path_history'

-- Path state constants with clear meanings
local PATH_STATE = {
    ACTIVE = 'active',   -- Currently selected path (visible, bright)
    RECENT = 'recent',   -- Most recently drawn path
    FADING = 'fading',   -- Recently active, now fading
    INACTIVE = 'inactive', -- Normal passive state
    HIDDEN = 'hidden'    -- Below visibility threshold
}

-- Module state
local mouse_down = false
local path_points = {}     -- Hold current path being drawn
local loaded_paths = {}
local selected_paths = {}  -- Table for multi-selection
local active_path_id = nil -- For backwards compatibility

-- Add a point to the current path
local function add_path_point(x, y, time)
    table.insert(path_points, {
        x = x,
        y = y,
        time = time or reaper.time_precise()
    })
end

-- Calculate Bezier control points for smooth curves
local function calculate_bezier_control_points(points, smooth_factor)
    if #points < 3 then return {} end

    local control_points = {}

    for i = 2, #points - 1 do
        local prev = points[i - 1]
        local curr = points[i]
        local next = points[i + 1]

        -- Calculate control point distances based on distances to adjacent points
        local prev_dist = math.sqrt((curr.x - prev.x) ^ 2 + (curr.y - prev.y) ^ 2)
        local next_dist = math.sqrt((next.x - curr.x) ^ 2 + (next.y - curr.y) ^ 2)

        -- Control point 1 (after current point)
        local cp1_x = curr.x + (next.x - prev.x) * smooth_factor * (prev_dist / (prev_dist + next_dist))
        local cp1_y = curr.y + (next.y - prev.y) * smooth_factor * (prev_dist / (prev_dist + next_dist))

        -- Control point 2 (before next point)
        local cp2_x = next.x - (next.x - prev.x) * smooth_factor * (next_dist / (prev_dist + next_dist))
        local cp2_y = next.y - (next.y - prev.y) * smooth_factor * (next_dist / (prev_dist + next_dist))

        table.insert(control_points, {
            cp1_x = cp1_x,
            cp1_y = cp1_y,
            cp2_x = cp2_x,
            cp2_y = cp2_y,
        })
    end

    return control_points
end

-- Draw path with time-based effects
local function draw_path_with_effects(draw_list, points, color, thickness, smooth_factor, current_time, fade_time,
                                      thickness_effect)
    if #points < 2 then return end

    -- Simple line drawing with time-based thickness and opacity
    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i + 1]

        -- Skip points without timestamp data
        if not p1.time or not p2.time then
            -- Just draw a regular line
            ImGui.DrawList_AddLine(
                draw_list,
                p1.x, p1.y,
                p2.x, p2.y,
                color,
                thickness
            )
        else
            -- Calculate segment time and age
            local segment_time = math.min(p1.time, p2.time)
            local elapsed = current_time - segment_time
            local segment_age = math.min(1.0, elapsed / fade_time)

            -- Calculate segment opacity with quadratic curve for more dramatic effect
            local segment_opacity = 1.0 - (segment_age * segment_age)

            -- Apply opacity to color
            local r = (color >> 24) & 0xFF
            local g = (color >> 16) & 0xFF
            local b = (color >> 8) & 0xFF
            local alpha = (color & 0xFF)

            -- Apply segment opacity to the alpha channel
            local segment_alpha = math.floor(alpha * segment_opacity)
            local segment_color = (r << 24) | (g << 16) | (b << 8) | segment_alpha

            -- Calculate segment thickness (if enabled) with more dramatic effect
            local segment_thickness = thickness
            if thickness_effect then
                -- Path starts thick and gets thinner over time
                local thickness_factor = 1.0 - segment_age
                segment_thickness = thickness * (0.5 + 2.0 * thickness_factor) -- More dramatic effect
            end

            -- Only draw if visible
            if segment_alpha > 0 then
                ImGui.DrawList_AddLine(
                    draw_list,
                    p1.x, p1.y,
                    p2.x, p2.y,
                    segment_color,
                    segment_thickness
                )
            end
        end
    end
end

-- Draw a path with specified settings
local function draw_path(draw_list, points, color, thickness, smooth_factor, win_x, win_y, win_w, win_h, current_time,
                         fade_time, thickness_effect)
    -- If we have time-based fading and timestamps, use segment fading
    if current_time and fade_time and points[1] and points[1].time and thickness_effect then
        draw_path_with_effects(draw_list, points, color, thickness, smooth_factor, current_time, fade_time,
            thickness_effect)
        return
    end

    if #points < 2 then return end

    if smooth_factor > 0 and #points > 2 then
        -- Draw with Bezier curves for smoothing
        local control_points = calculate_bezier_control_points(points, smooth_factor)

        -- Draw the first line segment
        ImGui.DrawList_AddLine(
            draw_list,
            points[1].x, points[1].y,
            points[2].x, points[2].y,
            color, thickness
        )

        -- Draw bezier curves for middle segments
        for i = 2, #points - 2 do
            local cp = control_points[i - 1]
            ImGui.DrawList_AddBezierCubic(
                draw_list,
                points[i].x, points[i].y,
                cp.cp1_x, cp.cp1_y,
                cp.cp2_x, cp.cp2_y,
                points[i + 1].x, points[i + 1].y,
                color, thickness, 0 -- 0 segments means auto-calculation
            )
        end

        -- Draw the last line segment
        if #points > 2 then
            ImGui.DrawList_AddLine(
                draw_list,
                points[#points - 1].x, points[#points - 1].y,
                points[#points].x, points[#points].y,
                color, thickness
            )
        end
    else
        -- Simple line drawing without smoothing
        for i = 1, #points - 1 do
            ImGui.DrawList_AddLine(
                draw_list,
                points[i].x, points[i].y,
                points[i + 1].x, points[i + 1].y,
                color, thickness
            )
        end
    end
end

-- Save the current path to history
local function save_path_to_history(options)
    if #path_points < 2 then return end

    local current_time = reaper.time_precise()

    -- Create a new path entry
    local new_path = {
        name = os.date("%H:%M:%S"), -- Default name is timestamp
        points = path_points,
        created = current_time,
        last_active_time = current_time,
        was_active = false,
        state = PATH_STATE.ACTIVE,
        color = options.path_color,
        width = options.path_width,
    }

    -- Add path to history and get the assigned ID
    local path_id = path_history.add_path(new_path, options.max_paths)

    active_path_id = path_id

    -- Clear current drawing path
    path_points = {}

    return path_id
end

-- Find a path by ID
local function find_path_by_id(path_id)
    for _, path in ipairs(loaded_paths) do
        if path.id == path_id then
            return path
        end
    end
    return nil
end

-- Draw historical paths
local function draw_historical_paths(frame)
    local draw_list = frame.draw_list
    local options = frame.options
    local current_time = frame.current_time
    local win_x = frame.win_x
    local win_y = frame.win_y
    local win_w = frame.win_w
    local win_h = frame.win_h

    if not options.path_show or not loaded_paths then return end

    -- Find most recent path
    local most_recent_path = nil
    local most_recent_time = 0

    for _, path in ipairs(loaded_paths) do
        if not path.pinned and path.created > most_recent_time then
            most_recent_time = path.created
            most_recent_path = path
        end
    end

    -- Draw paths with proper state handling
    for _, path in ipairs(loaded_paths) do
        local path_color = path.color
        local base_opacity = options.inactive_path_opacity
        local fade_time = options.path_fade_time
        local thickness_effect = options.path_thickness_effect
        local should_draw = true
        local path_state = PATH_STATE.INACTIVE

        -- Determine path state and apply appropriate visual style
        if selected_paths[path.id] or path.id == active_path_id then
            -- Selected path
            path_state = PATH_STATE.ACTIVE
            path.state = PATH_STATE.ACTIVE

            -- Check if we need to fade from bright to selected state
            if path.visibility_reset_time and current_time < path.visibility_reset_time + 0.5 then
                -- Still in the "pop" phase (bright)
                base_opacity = 1.0
            elseif path.visibility_reset_time then
                -- Transition from bright to selected state
                local elapsed = current_time - (path.visibility_reset_time + 0.5)
                local fade_duration = 1.0 -- 1 second transition
                local transition_factor = math.min(1.0, elapsed / fade_duration)

                base_opacity = 1.0 - transition_factor * (1.0 - options.selected_path_opacity)
            else
                base_opacity = options.selected_path_opacity
            end

            fade_time = options.path_fade_time * 1.5 -- Slower fade for selected paths
            path.last_active_time = current_time
            path.was_active = false
        elseif path == most_recent_path then
            -- Most recent path
            path_state = PATH_STATE.RECENT
            path.state = PATH_STATE.RECENT
            base_opacity = options.recent_path_opacity

            -- Check if we're still in the "persist" period for most recent path
            local persist_time = options.path_persist_time or 2.0 -- default 2 seconds
            local elapsed = current_time - path.created

            if elapsed < persist_time then
                -- Still in persist period - use full opacity
                base_opacity = 1.0
            end
        elseif path.was_active then
            -- Recently deselected path - fade out
            path_state = PATH_STATE.FADING
            path.state = PATH_STATE.FADING

            local elapsed = current_time - path.last_active_time
            local fade_factor = 1.0 - math.min(1.0, math.max(0.0, elapsed / options.deselected_fade_time))
            base_opacity = options.path_min_opacity +
            (options.inactive_path_opacity - options.path_min_opacity) * fade_factor

            -- Apply opacity to color
            local r = (path.color >> 24) & 0xFF
            local g = (path.color >> 16) & 0xFF
            local b = (path.color >> 8) & 0xFF
            local a = math.floor((path.color & 0xFF) * base_opacity)
            path_color = (r << 24) | (g << 16) | (b << 8) | a

            -- Check if path should be hidden
            should_draw = base_opacity > options.path_min_opacity
            if not should_draw then
                path.state = PATH_STATE.HIDDEN
            end
        else
            -- Normal inactive path
            path_state = PATH_STATE.INACTIVE
            path.state = PATH_STATE.INACTIVE

            -- Apply base opacity
            local r = (path.color >> 24) & 0xFF
            local g = (path.color >> 16) & 0xFF
            local b = (path.color >> 8) & 0xFF
            local a = math.floor((path.color & 0xFF) * base_opacity)
            path_color = (r << 24) | (g << 16) | (b << 8) | a

            -- Check visibility threshold
            should_draw = base_opacity > options.path_min_opacity
        end

        -- Draw the path if it's visible
        if should_draw then
            draw_path(
                draw_list,
                path.points,
                path_color,
                path.width or options.path_width,
                options.path_smooth_factor,
                win_x, win_y, win_w, win_h,
                current_time,
                fade_time,
                thickness_effect and path_state ~= PATH_STATE.ACTIVE
            )
        end
    end
end

-- Process the current path being drawn
local function process_path_drawing(frame)
    if #path_points < 2 then return end

    local draw_list = frame.draw_list
    local options = frame.options
    local win_x = frame.win_x
    local win_y = frame.win_y
    local win_w = frame.win_w
    local win_h = frame.win_h
    local current_time = frame.current_time

    draw_path(
        draw_list,
        path_points,
        options.path_color,
        options.path_width,
        options.path_smooth_factor,
        win_x, win_y, win_w, win_h,
        current_time,
        options.path_fade_time,
        options.path_thickness_effect
    )
end

-- Handle mouse movement for path creation
local function handle_mouse_movement(mse_screen_x, mse_screen_y, current_time)
    if #path_points == 0 then return end

    -- Add a new point if mouse moved enough
    local last_point = path_points[#path_points]
    local dx = mse_screen_x - last_point.x
    local dy = mse_screen_y - last_point.y
    local dist_squared = dx * dx + dy * dy

    -- Only add points that are at least 3 pixels away from last point
    if dist_squared > 9 then
        add_path_point(mse_screen_x, mse_screen_y, current_time)
    end
end

-- Select a path
local function select_path(path_id, multi_select, current_time)
    loaded_paths = path_history.load_all()

    local path = find_path_by_id(path_id)
    if not path then
        return nil
    end

    -- Toggle selection
    if selected_paths[path_id] then
        selected_paths[path_id] = nil
        path.was_active = true
        path.last_active_time = current_time
        path.state = PATH_STATE.FADING
    else
        selected_paths[path_id] = true
        path.visibility_reset_time = current_time
        path.visibility = 1.0
        path.state = PATH_STATE.ACTIVE
    end

    if not multi_select then
        -- Single selection mode
        for id, _ in pairs(selected_paths) do
            if id ~= path_id then
                local old_path = find_path_by_id(id)
                if old_path then
                    old_path.was_active = true
                    old_path.last_active_time = current_time
                    old_path.state = PATH_STATE.FADING
                end
                selected_paths[id] = nil
            end
        end
    end

    -- For backwards compatibility
    active_path_id = next(selected_paths)

    return path
end

-- Initialize the path system
local function init()
    loaded_paths = path_history.load_all()
    path_points = {}
    mouse_down = false
    selected_paths = {}
    active_path_id = nil
end

-- Module exports
return {
    -- Constants
    PATH_STATE = PATH_STATE,

    -- Core functions
    init = init,
    add_path_point = add_path_point,
    save_path_to_history = save_path_to_history,
    find_path_by_id = find_path_by_id,
    select_path = select_path,

    -- Drawing functions
    draw_path = draw_path,
    draw_historical_paths = draw_historical_paths,
    process_path_drawing = process_path_drawing,

    -- Mouse handling
    handle_mouse_movement = handle_mouse_movement,

    -- State access
    get_path_points = function() return path_points end,
    get_loaded_paths = function() return loaded_paths end,
    get_active_path_id = function() return active_path_id end,
    is_path_selected = function(path_id) return selected_paths[path_id] ~= nil end,
    is_mouse_down = function() return mouse_down end,
    set_mouse_down = function(value) mouse_down = value end
}
