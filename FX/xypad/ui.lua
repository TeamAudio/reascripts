-- @noindex

package.path = package.path .. ';' .. reaper.ImGui_GetBuiltinPath() .. '/?.lua'

local ImGui = require 'imgui' '0.9.2'
local config = require 'config'
local fonts = require 'fonts'
local mappings = require 'mappings'
local path_history = require 'path_history'
local paths = require 'paths'

local IMGUI_CONTEXT_NAME = 'XY Pad'

local _ctx = ImGui.CreateContext(IMGUI_CONTEXT_NAME)
fonts.attach(_ctx)

local mappings_open = false
local options_open = false
local history_open = false

local mouse_down = false
local path_points = {}    -- hold current path being drawn
local last_frame_time = 0 -- track time between frames

-- Cache paths from storage
local loaded_paths = {}
local active_path_id = nil -- currently selected path

local col_white = 0xFFFFFFFF

-- GUI Functionality
-- Get XY Pad window dimensions
local function get_window_dimensions()
    local win_x, win_y = ImGui.GetWindowPos(_ctx)
    local win_w, win_h = ImGui.GetWindowSize(_ctx)

    return win_x, win_y, win_w, win_h
end

-- Get mouse position and return raw and normalized values
local function get_mouse_position(win_x, win_y, win_w, win_h)
    local mse_x, mse_y = ImGui.GetMousePos(_ctx)
    local mse_norm_x, mse_norm_y = (mse_x - win_x) / win_w, 1 - (mse_y - win_y) / win_h
    local mse_round_x, mse_round_y = tonumber(string.format('%.2f', mse_norm_x)),
        tonumber(string.format('%.2f', mse_norm_y))
    return mse_x, mse_y, mse_norm_x, mse_norm_y, mse_round_x, mse_round_y
end

-- Check if mouse is within window bounds
local function should_handle_mouse_input(mse_x, mse_y, win_x, win_y, win_w, win_h)
    if not (mse_x > win_x and mse_x < win_x + win_w and mse_y > win_y and mse_y < win_y + win_h) then
        return false
    end

    return true
end

-- Draw XY lines
local function draw_xy(draw_list, x, y, w, h, x_color, y_color, x_lines, y_lines, line_width)
    for i = 1, x_lines do
        ImGui.DrawList_AddLine(draw_list, x + (w / (x_lines + 1)) * i, y, x + (w / (x_lines + 1)) * i, y + h, x_color,
            line_width)
    end

    for i = 1, y_lines do
        ImGui.DrawList_AddLine(draw_list, x, y + (h / (y_lines + 1)) * i, x + w, y + (h / (y_lines + 1)) * i, y_color,
            line_width)
    end
end

-- Create a simple frame context with direct access to values
local function create_frame_context(options)
    -- Get window dimensions first (avoiding repeated function calls)
    local win_x, win_y, win_w, win_h = get_window_dimensions()

    -- Get mouse position values in one call
    local mse_x, mse_y, mse_norm_x, mse_norm_y,
    mse_round_x, mse_round_y = get_mouse_position(win_x, win_y, win_w, win_h)

    -- Get rendering info
    local draw_list = ImGui.GetWindowDrawList(_ctx)
    local font_height = ImGui.GetFontSize(_ctx)
    local current_time = reaper.time_precise()
    local delta_time = current_time - last_frame_time

    -- Return a flat structure for direct access
    return {
        -- Window geometry
        win_x = win_x,
        win_y = win_y,
        win_w = win_w,
        win_h = win_h,

        -- Mouse state
        mse_x = mse_x,
        mse_y = mse_y,
        mse_norm_x = mse_norm_x,
        mse_norm_y = mse_norm_y,
        mse_round_x = mse_round_x,
        mse_round_y = mse_round_y,

        -- Rendering info
        draw_list = draw_list,
        font_height = font_height,
        current_time = current_time,
        delta_time = delta_time,

        -- Options reference
        options = options,
    }
end

-- Draw cursor circle
local function draw_cursor(draw_list, x, y, col, radius, stroke)
    ImGui.DrawList_AddCircle(draw_list, x, y, radius, col, 0, stroke)
end

-- Write X and Y values
local function label(draw_list, x, y, msg, col)
    ImGui.DrawList_AddText(draw_list, x, y, col, msg)
end

-- Handle mouse interaction for path creation
local function handle_mouse_interaction(frame)
    -- Unpack what we need from the frame
    local mse_x = frame.mse_x
    local mse_y = frame.mse_y
    local win_x = frame.win_x
    local win_y = frame.win_y
    local win_w = frame.win_w
    local win_h = frame.win_h
    local current_time = frame.current_time
    local options = frame.options
    local draw_list = frame.draw_list
    local font_height = frame.font_height
    local mse_norm_x = frame.mse_norm_x
    local mse_norm_y = frame.mse_norm_y
    local mse_round_x = frame.mse_round_x
    local mse_round_y = frame.mse_round_y

    if not should_handle_mouse_input(mse_x, mse_y, win_x, win_y, win_w, win_h) then
        return
    end

    ImGui.SetMouseCursor(_ctx, 7)

    if ImGui.IsMouseDown(_ctx, 0) and ImGui.IsWindowFocused(_ctx) then
        if not paths.is_mouse_down() then
            paths.set_mouse_down(true)
            mappings.reload_mappings()

            -- Start a new path
            paths.add_path_point(mse_x, mse_y, current_time)
        else
            -- Continue existing path
            paths.handle_mouse_movement(mse_x, mse_y, current_time)
        end

        -- Draw cursor and display coordinates
        draw_cursor(draw_list, mse_x, mse_y, options.cursor_color, options.cursor_radius,
            options.cursor_stroke)
        label(draw_list, win_x + 5, (win_y - 5) + (win_h - font_height - 5),
            'X: ' .. mse_round_x .. ', Y: ' .. mse_round_y, col_white)

        -- Update parameter mappings
        mappings.set_params('x', mse_norm_x)
        mappings.set_params('y', mse_norm_y)

        -- Draw the current path being created
        paths.process_path_drawing(frame)
    else
        if paths.is_mouse_down() then
            -- Mouse was released - save the path
            if #paths.get_path_points() > 1 and options.path_show then
                loaded_paths = path_history.load_all()
            end

            paths.set_mouse_down(false)
        end
    end
end

-- Render the path history controls
local function render_history_controls(options)
    if ImGui.Button(_ctx, "Clear All History") then
        path_history.clear_all()
        loaded_paths = {}
        active_path_id = nil
    end

    ImGui.SameLine(_ctx)

    if ImGui.Button(_ctx, "Reload Paths") then
        loaded_paths = path_history.load_all()
    end

    ImGui.SameLine(_ctx)

    local path_show = options.path_show
    local show_changed
    show_changed, path_show = ImGui.Checkbox(_ctx, "Show Paths", path_show)
    if show_changed then
        options.path_show = path_show
        config.save_config(options)
    end

    ImGui.Separator(_ctx)
end

-- Render individual path item in the history list
local function render_path_item(i, path, current_time)
    -- Get current selection state from paths module
    local is_active = paths.is_path_selected(path.id)
    local pin_label = path.pinned and " [Saved]" or ""

    -- Build a unique label with the path name
    local path_label = (is_active and "> " or "  ") .. path.name .. pin_label

    -- Allow multi-select with Ctrl/Cmd
    local select_flags = ImGui.SelectableFlags_None
    local mods = ImGui.GetKeyMods(_ctx)
    local ctrl_down = ImGui.Mod_Ctrl == (mods & ImGui.Mod_Ctrl)

    -- Selectable for each path
    if ImGui.Selectable(_ctx, path_label, is_active, select_flags) then
        -- Toggling of state is handled internally by paths.select_path
        paths.select_path(path.id, ctrl_down, current_time)

        path_history.update_path(path.id, path)
    end

    -- Context menu for path options
    if ImGui.BeginPopupContextItem(_ctx) then
        if ImGui.MenuItem(_ctx, "Rename") then
            -- For now just use a simple name
            path.name = "Path " .. i
            path_history.update_path(path.id, path)
        end

        if path.pinned then
            if ImGui.MenuItem(_ctx, "Unsave") then
                path_history.unpin_path(path.id)
                path.pinned = false
            end
        else
            if ImGui.MenuItem(_ctx, "Save") then
                path_history.pin_path(path.id)
                path.pinned = true
            end
        end

        if ImGui.MenuItem(_ctx, "Delete") then
            if paths.is_path_selected(path.id) then
                paths.select_path(path.id, false, current_time)
            end

            path_history.remove_path(path.id)
            table.remove(loaded_paths, i)
        end

        ImGui.Separator(_ctx)

        -- Color picker
        local color_changed
        color_changed, path.color = ImGui.ColorEdit4(_ctx, "Path Color", path.color)

        -- Width slider
        local width_changed
        width_changed, path.width = ImGui.SliderDouble(_ctx, "Width", path.width, 0.5, 10.0, "%.1f")

        if color_changed or width_changed then
            path_history.update_path(path.id, path)
        end

        ImGui.EndPopup(_ctx)
    end

    -- Tooltip showing created time
    if ImGui.IsItemHovered(_ctx) then
        ImGui.BeginTooltip(_ctx)
        ImGui.Text(_ctx, "Created: " .. os.date("%Y-%m-%d %H:%M:%S", math.floor(path.created)))
        ImGui.EndTooltip(_ctx)
    end
end

function show_or_hide(is_open)
    return is_open and "Hide" or "Show"
end

-- Open Mapping window
local function xy_menu_bar(ctx)
    if ImGui.BeginMenuBar(ctx) then
        if ImGui.MenuItem(ctx, show_or_hide(mappings_open) .. ' Mappings') then
            mappings_open = not mappings_open
        end

        if ImGui.MenuItem(ctx, show_or_hide(options_open) .. ' Options') then
            options_open = not options_open
        end

        if ImGui.MenuItem(ctx, show_or_hide(history_open) .. ' Path History') then
            history_open = not history_open
            if history_open and not loaded_paths then
                loaded_paths = path_history.load_all()
            end
        end

        ImGui.EndMenuBar(ctx)
    end
end

local function render_xy_pad(options)
    local child_flags = ImGui.ChildFlags_FrameStyle

    ImGui.PushFont(_ctx, fonts.get_font("main"))
    ImGui.PushStyleColor(_ctx, ImGui.Col_FrameBg, options.pad_bg_color)
    ImGui.BeginChild(_ctx, 'xy-pad', 0, 0, child_flags, 0)
    ImGui.SetConfigVar(_ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly, 1)

    -- Create a frame context for direct access to values
    local frame = create_frame_context(options)

    -- Record and track delta time between frames
    local current_time = reaper.time_precise()
    local delta_time = current_time - last_frame_time
    last_frame_time = current_time

    paths.draw_historical_paths(frame)

    handle_mouse_interaction(frame)

    draw_xy(
        frame.draw_list,
        frame.win_x,
        frame.win_y,
        frame.win_w,
        frame.win_h,
        options.grid_line_x_color,
        options.grid_line_y_color,
        options.x_lines,
        options.y_lines,
        options.grid_line_width
    )

    ImGui.EndChild(_ctx)
    ImGui.PopStyleColor(_ctx)
    ImGui.PopFont(_ctx)
end

local function render_heading(text)
    ImGui.PushFont(_ctx, fonts.get_font("heading"))
    ImGui.SeparatorText(_ctx, text)
    ImGui.PopFont(_ctx)
end

local function render_mapping_group(m)
    ImGui.BeginGroup(_ctx)

    ImGui.PushFont(_ctx, fonts.get_font("labels"))

    if ImGui.Selectable(_ctx, m.mapping_name, m.selected) then
        m.selected = not m.selected
    end

    local call_result, needs_save

    ImGui.BeginGroup(_ctx)
    call_result, m.max = ImGui.SliderDouble(_ctx, 'Max', m.max, 0, 1, '%.2f')
    if call_result then needs_save = true end

    call_result, m.min = ImGui.SliderDouble(_ctx, 'Min', m.min, 0, 1, '%.2f')
    if call_result then needs_save = true end

    if m.max < m.min then
        m.max, m.min = m.min, m.max
    end

    ImGui.EndGroup(_ctx)

    ImGui.SameLine(_ctx)

    call_result, m.invert = ImGui.Checkbox(_ctx, 'Invert', m.invert)
    if call_result then needs_save = true end

    ImGui.SameLine(_ctx)
    call_result, m.bypass = ImGui.Checkbox(_ctx, 'Bypass', m.bypass)
    if call_result then needs_save = true end

    ImGui.PopFont(_ctx)

    if needs_save then
        mappings.save_mappings()
    end

    ImGui.EndGroup(_ctx)
end

local function render_mapping_table(title, ms)
    render_heading(title)

    for i, m in ipairs(ms) do
        ImGui.PushID(_ctx, ("%s-mapping-%d"):format(title, i))
        render_mapping_group(m)
        ImGui.Spacing(_ctx)
        ImGui.Spacing(_ctx)

        if i < #ms then
            ImGui.Separator(_ctx)
            ImGui.Spacing(_ctx)
            ImGui.Spacing(_ctx)
        end

        ImGui.PopID(_ctx)
    end
end

local function render_mapping()
    if not mappings_open then
        return
    end

    local parameter_window_flags
                                 = ImGui.WindowFlags_NoDocking
        | ImGui.WindowFlags_AlwaysAutoResize
        | ImGui.WindowFlags_NoCollapse

    local visible, open          = ImGui.Begin(_ctx, 'Mappings', true, parameter_window_flags)
    if visible then
        if not open then
            mappings_open = false
        end

        ImGui.PushFont(_ctx, fonts.get_font("main"))
        local should_clear = ImGui.Button(_ctx, "Remove Selection")
            or ImGui.IsKeyPressed(_ctx, ImGui.Key_Delete)

        if should_clear then
            mappings.remove_selected()
            ImGui.SetItemDefaultFocus(_ctx)
        end

        local ms = mappings.get_mappings()

        ImGui.Spacing(_ctx)
        ImGui.Spacing(_ctx)
        render_mapping_table('X Axis', ms.x)

        ImGui.Spacing(_ctx)
        ImGui.Spacing(_ctx)
        render_mapping_table('Y Axis', ms.y)

        ImGui.PopFont(_ctx)
        ImGui.End(_ctx)
    end
end

local function render_grid_options(options)
    render_heading('Grid Options')

    local imgui_result;
    local needs_save = false

    local link_xy = options.grid_lines_linked
    imgui_result, link_xy = ImGui.Checkbox(_ctx, 'Link X/Y Grid Lines', link_xy)

    if imgui_result then
        options.grid_lines_linked = link_xy
        needs_save = true
    end

    local x_lines = options.x_lines
    imgui_result, x_lines = ImGui.SliderInt(_ctx, 'x-axis', x_lines, 0, 10, "%d")
    if imgui_result then
        options.x_lines = x_lines

        if link_xy then
            options.y_lines = x_lines
        end

        needs_save = true
    end

    local y_lines = options.y_lines
    imgui_result, y_lines = ImGui.SliderInt(_ctx, 'y-axis', y_lines, 0, 10, "%d")
    if imgui_result then
        options.y_lines = y_lines

        if link_xy then
            options.x_lines = y_lines
        end

        needs_save = true
    end

    ImGui.Spacing(_ctx)

    local grid_lines_linked_color = options.grid_lines_linked_color
    imgui_result, grid_lines_linked_color = ImGui.Checkbox(_ctx, 'Link Grid Line Colors', grid_lines_linked_color)
    if imgui_result then
        options.grid_lines_linked_color = grid_lines_linked_color
        needs_save = true
    end

    local grid_line_x_color = options.grid_line_x_color
    imgui_result, grid_line_x_color = ImGui.ColorEdit4(_ctx, 'X Grid Line Color', grid_line_x_color)
    if imgui_result then
        options.grid_line_x_color = grid_line_x_color

        if grid_lines_linked_color then
            options.grid_line_y_color = grid_line_x_color
        end

        needs_save = true
    end

    local grid_line_y_color = options.grid_line_y_color
    imgui_result, grid_line_y_color = ImGui.ColorEdit4(_ctx, 'Y Grid Line Color', grid_line_y_color)
    if imgui_result then
        options.grid_line_y_color = grid_line_y_color

        if grid_lines_linked_color then
            options.grid_line_x_color = grid_line_y_color
        end

        needs_save = true
    end

    local grid_line_width = options.grid_line_width
    imgui_result, grid_line_width = ImGui.SliderDouble(_ctx, 'Grid Line Width', grid_line_width, 1.0, 5.0, "%.2f")
    if imgui_result then
        options.grid_line_width = grid_line_width
        needs_save = true
    end

    return needs_save
end

local function render_pad_options(options)
    render_heading('Pad Options')

    local imgui_result;
    local needs_save = false

    local pad_bg_color = options.pad_bg_color
    imgui_result, pad_bg_color = ImGui.ColorEdit4(_ctx, 'Pad Background Color', pad_bg_color)
    if imgui_result then
        options.pad_bg_color = pad_bg_color
        needs_save = true
    end

    return needs_save
end

local function render_cursor_options(options)
    render_heading('Cursor Options')

    local imgui_result;
    local needs_save = false

    local cursor_color = options.cursor_color
    imgui_result, cursor_color = ImGui.ColorEdit4(_ctx, 'Cursor Color', cursor_color)
    if imgui_result then
        options.cursor_color = cursor_color
        needs_save = true
    end

    local cursor_radius = options.cursor_radius
    imgui_result, cursor_radius = ImGui.SliderInt(_ctx, 'Cursor Radius', cursor_radius, 1, 25, "%d")
    if imgui_result then
        options.cursor_radius = cursor_radius
        needs_save = true
    end

    local cursor_stroke = options.cursor_stroke
    imgui_result, cursor_stroke = ImGui.SliderInt(_ctx, 'Cursor Stroke', cursor_stroke, 1, 4, "%d")
    if imgui_result then
        options.cursor_stroke = cursor_stroke
        needs_save = true
    end

    return needs_save
end

-- Add path options to the options window
local function render_path_options(options)
    render_heading('Path Options')

    local imgui_result
    local needs_save = false

    -- Show paths option
    imgui_result, options.path_show = ImGui.Checkbox(_ctx, 'Show Paths', options.path_show)
    if imgui_result then needs_save = true end

    -- Path color selection
    imgui_result, options.path_color = ImGui.ColorEdit4(_ctx, 'Path Color', options.path_color)
    if imgui_result then needs_save = true end

    -- Path width slider
    imgui_result, options.path_width = ImGui.SliderDouble(_ctx, 'Path Width', options.path_width, 0.5, 10.0, "%.1f")
    if imgui_result then needs_save = true end

    -- Path smoothing factor
    imgui_result, options.path_smooth_factor = ImGui.SliderDouble(_ctx, 'Path Smoothing', options.path_smooth_factor, 0.0,
        1.0, "%.2f")
    if imgui_result then needs_save = true end

    ImGui.Separator(_ctx)

    -- Path thickness effect
    imgui_result, options.path_thickness_effect = ImGui.Checkbox(_ctx, 'Enable Thickness Effect', options.path_thickness_effect)
    if imgui_result then needs_save = true end

    ImGui.BeginDisabled(_ctx, not options.path_thickness_effect)

    imgui_result, options.path_thickness_contrast = ImGui.SliderDouble(_ctx, 'Thickness Contrast', options.path_thickness_contrast, 0.5, 3.0, "%.1f")
    if imgui_result then needs_save = true end

    imgui_result, options.path_max_thickness = ImGui.SliderDouble(_ctx, 'Max Thickness', options.path_max_thickness, 0.5, 10.0, "%.1f")
    if imgui_result then needs_save = true end

    imgui_result, options.path_min_thickness = ImGui.SliderDouble(_ctx, 'Min Thickness', options.path_min_thickness, 0.5, 10.0, "%.1f")
    if imgui_result then needs_save = true end

    ImGui.EndDisabled(_ctx)

    ImGui.Separator(_ctx)

    -- Opacity settings
    render_heading('Path Visibility')

    -- Max paths in history
    imgui_result, options.max_paths = ImGui.SliderInt(_ctx, 'Max History Paths', options.max_paths, 1, 30, "%d")
    if imgui_result then needs_save = true end

    -- Fade out time
    imgui_result, options.deselected_fade_time = ImGui.SliderDouble(_ctx, 'Fade Out Time', options.deselected_fade_time,
        0.1, 5.0, "%.1f s")
    if imgui_result then needs_save = true end

    -- Selected path opacity
    imgui_result, options.selected_path_opacity = ImGui.SliderDouble(_ctx, 'Selected Path Opacity',
        options.selected_path_opacity, 0.5, 1.0, "%.2f")
    if imgui_result then needs_save = true end

    -- Most recent path opacity
    imgui_result, options.recent_path_opacity = ImGui.SliderDouble(_ctx, 'Recent Path Opacity',
        options.recent_path_opacity, 0.3, 1.0, "%.2f")
    if imgui_result then needs_save = true end

    -- Inactive path opacity
    imgui_result, options.inactive_path_opacity = ImGui.SliderDouble(_ctx, 'Inactive Opacity',
        options.inactive_path_opacity, 0.1, 0.5, "%.2f")
    if imgui_result then needs_save = true end

    -- Minimum visible opacity
    imgui_result, options.path_min_opacity = ImGui.SliderDouble(_ctx, 'Minimum Visible Opacity',
        options.path_min_opacity, 0.1, 1.0, "%.2f")
    if imgui_result then needs_save = true end

    return needs_save
end
local function render_options(options)
    if not options_open then
        return
    end

    local options_window_flags
                               = ImGui.WindowFlags_NoDocking
        | ImGui.WindowFlags_AlwaysAutoResize
        | ImGui.WindowFlags_NoCollapse

    local visible, open        = ImGui.Begin(_ctx, 'Options', true, options_window_flags)
    if visible then
        if not open then
            options_open = false
        end

        local needs_save = false

        for _, renderer in ipairs {
            render_pad_options,
            render_grid_options,
            render_cursor_options,
            render_path_options,
        } do
            if renderer(options) then
                needs_save = true
            end

            ImGui.Spacing(_ctx)
            ImGui.Spacing(_ctx)
            ImGui.Spacing(_ctx)
        end

        if needs_save then
            config.save_config(options)
        end

        ImGui.End(_ctx)
    end
end

-- Render history window
local function render_history(options)
    if not history_open then
        return
    end

    local history_window_flags =
        ImGui.WindowFlags_NoDocking |
        ImGui.WindowFlags_AlwaysAutoResize |
        ImGui.WindowFlags_NoCollapse

    local visible, open = ImGui.Begin(_ctx, 'Path History', true, history_window_flags)

    if visible then
        if not open then
            history_open = false
        end

        ImGui.PushFont(_ctx, fonts.get_font("main"))

        -- History controls
        render_history_controls(options)

        -- Path list
        if not loaded_paths or #loaded_paths == 0 then
            ImGui.TextDisabled(_ctx, "No paths recorded")
        else
            local current_time = reaper.time_precise()

            -- Display path list
            for i, path in ipairs(loaded_paths) do
                render_path_item(i, path, current_time)
            end
        end

        ImGui.PopFont(_ctx)
        ImGui.End(_ctx)
    end
end

local function init()
    -- Initialize path system
    paths.init()

    -- Track time for animations
    last_frame_time = reaper.time_precise()

    -- Load paths from storage
    loaded_paths = path_history.load_all()
end

local function ctx()
    if ImGui.ValidatePtr(_ctx, 'ImGui_Context*') then
        return _ctx
    end

    _ctx = ImGui.CreateContext(IMGUI_CONTEXT_NAME)

    return _ctx
end

return {
    ctx = ctx,
    init = init,
    render_mapping = render_mapping,
    render_options = render_options,
    render_xy_pad = render_xy_pad,
    render_history = render_history,
    xy_menu_bar = xy_menu_bar,
}
