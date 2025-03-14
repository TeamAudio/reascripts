-- @noindex

package.path = package.path .. ';' .. reaper.ImGui_GetBuiltinPath() .. '/?.lua'

local ImGui = require 'imgui' '0.9.2'
local mappings = require 'mappings'
local config = require 'config'
local fonts = require 'fonts'

local IMGUI_CONTEXT_NAME = 'XY Pad'

local _ctx = ImGui.CreateContext(IMGUI_CONTEXT_NAME)
fonts.attach(_ctx)

local mappings_open = false
local options_open = false

local mouse_down = false

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
    local mse_norm_x, mse_norm_y = (mse_x - win_x)/win_w, 1-(mse_y - win_y)/win_h
    local mse_round_x, mse_round_y = tonumber(string.format('%.2f', mse_norm_x)), tonumber(string.format('%.2f', mse_norm_y))
    return mse_x, mse_y, mse_norm_x, mse_norm_y, mse_round_x, mse_round_y
end

-- Check if mouse is within window bounds
local function mouse_in_bounds(in_check_x, in_check_y, win_x, win_y, win_w, win_h)
    return in_check_x > win_x and in_check_x < win_x + win_w and in_check_y > win_y and in_check_y < win_y + win_h
end

-- Draw XY lines
local function draw_xy(draw_list, x, y, w, h, x_color, y_color, x_lines, y_lines, line_width)
    for i = 1, x_lines do
        ImGui.DrawList_AddLine(draw_list, x + (w/(x_lines + 1))*i, y, x + (w/(x_lines + 1))*i, y + h, x_color, line_width)
    end

    for i = 1, y_lines do
        ImGui.DrawList_AddLine(draw_list, x, y + (h/(y_lines + 1))*i, x + w, y + (h/(y_lines + 1))*i, y_color, line_width)
    end
end

-- Draw cursor circle
local function draw_cursor(draw_list, x, y, col, radius, stroke)
    ImGui.DrawList_AddCircle(draw_list, x, y, radius, col, 0, stroke)
end

-- Write X and Y values
local function label(draw_list, x, y, msg, col)
    ImGui.DrawList_AddText(draw_list, x, y, col, msg)
end

local function show_or_hide(is_open)
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
        ImGui.EndMenuBar(ctx)
    end
end

local function render_xy_pad(options)
    local child_flags = ImGui.ChildFlags_FrameStyle

    ImGui.PushFont(_ctx, fonts.get_font("main"))
    ImGui.PushStyleColor(_ctx, ImGui.Col_FrameBg, options.pad_bg_color)
    ImGui.BeginChild(_ctx, 'xy-pad', 0, 0, child_flags, 0)
    ImGui.SetConfigVar(_ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly, 1)
    local font_height = ImGui.GetFontSize(_ctx)

    local win_x, win_y, win_w, win_h = get_window_dimensions()
    local draw_list = ImGui.GetWindowDrawList(_ctx)

    local mse_screen_x, mse_screen_y, mse_norm_x, mse_norm_y, mse_round_x, mse_round_y = get_mouse_position(win_x, win_y, win_w, win_h)

    if mouse_in_bounds(mse_screen_x, mse_screen_y, win_x, win_y, win_w, win_h) then
        ImGui.SetMouseCursor(_ctx, 7)
        if ImGui.IsMouseDown(_ctx, 0) and ImGui.IsWindowFocused(_ctx) then
            if not mouse_down then
                mouse_down = true
                mappings.reload_mappings()
            end
            draw_cursor(draw_list, mse_screen_x, mse_screen_y, options.cursor_color, options.cursor_radius, options.cursor_stroke)
            label(draw_list, win_x + 5, (win_y - 5) + (win_h - font_height - 5), 'X: ' .. mse_round_x .. ', Y: ' .. mse_round_y, options.pad_label_color)
            mappings.set_params('x', mse_norm_x)
            mappings.set_params('y', mse_norm_y)
        else
            mouse_down = false
        end
    end

    draw_xy(draw_list, win_x, win_y, win_w, win_h, options.grid_line_x_color, options.grid_line_y_color, options.x_lines, options.y_lines, options.grid_line_width)
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

    local visible, open = ImGui.Begin(_ctx, 'Mappings', true, parameter_window_flags)
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

    local pad_label_color = options.pad_label_color
    imgui_result, pad_label_color = ImGui.ColorEdit4(_ctx, 'Pad Label Color', pad_label_color)
    if imgui_result then
        options.pad_label_color = pad_label_color
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

local function render_options(options)
    if not options_open then
        return
    end

    local options_window_flags
        = ImGui.WindowFlags_NoDocking
        | ImGui.WindowFlags_AlwaysAutoResize
        | ImGui.WindowFlags_NoCollapse

    local visible, open = ImGui.Begin(_ctx, 'Options', true, options_window_flags)
    if visible then
        if not open then
            options_open = false
        end

        local needs_save = false

        for _, renderer in ipairs {
            render_pad_options,
            render_grid_options,
            render_cursor_options
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

local function ctx()
    if ImGui.ValidatePtr(_ctx, 'ImGui_Context*') then
        return _ctx
    end

    _ctx = ImGui.CreateContext(IMGUI_CONTEXT_NAME)

    return _ctx
end

return {
    ctx = ctx,
    render_mapping = render_mapping,
    render_options = render_options,
    render_xy_pad = render_xy_pad,
    xy_menu_bar = xy_menu_bar,
}