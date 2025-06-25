-- @noindex

local crossfade = require 'crossfade'
local Fonts = require 'fonts'
local ImGui = require 'imgui' '0.9.2'
local theme = require 'theme'
local Trap = require 'trap'

local IMGUI_CTX_NAME = 'Crossfader'
local STORAGE_SECTION = 'Crossfader.General'

local function ctx()
    if ImGui.ValidatePtr(_ctx, 'ImGui_Context*') then
        return _ctx
    end

    _ctx = ImGui.CreateContext(IMGUI_CTX_NAME)

    return _ctx
end

Fonts:init(ctx(), STORAGE_SECTION)

local fade_len = 0.000

local function render_fade_len()
    ImGui.AlignTextToFramePadding(_ctx)
    ImGui.Text(_ctx, 'Fade Length')
    ImGui.SameLine(_ctx, 100)
    ImGui.SetNextItemWidth(_ctx, 75)
    _, fade_len = ImGui.InputDouble(_ctx, '##fade_len', fade_len, 0.0, 0.0, '%.3f' .. ' s')
end

local combo_options =
    'Linear\0' ..
    'Slow Exponential\0' ..
    'Slow Logarithmic\0' ..
    'Fast Exponential\0' ..
    'Fast Logarithmic\0' ..
    'Slow Sine\0' ..
    'Fast Sine\0'

local combo_choice = 0
local combo_select = false

local function render_fade_type()
    ImGui.AlignTextToFramePadding(_ctx)
    ImGui.Text(_ctx, 'Fade Type')
    ImGui.SameLine(_ctx, 100)
    ImGui.SetNextItemWidth(_ctx, 150)
    combo_select, combo_choice = ImGui.Combo(_ctx, '##fade_type', combo_choice, combo_options)

    if combo_select then
        crossfade.set_fade_shapes(combo_choice)
    end
end

local function render_window()
    local _ctx = ctx()
    render_fade_len()
    ImGui.NewLine(_ctx)
    render_fade_type()
    ImGui.NewLine(_ctx)

    if ImGui.Button(_ctx, 'Go', 50) then
        crossfade.crossfade(fade_len, combo_choice)
    end

    if ImGui.IsKeyPressed(_ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(_ctx, ImGui.Key_KeypadEnter) then
        crossfade.crossfade(fade_len, combo_choice)
    end
end

local window_flags
    = ImGui.WindowFlags_AlwaysAutoResize
    | ImGui.WindowFlags_NoCollapse
    | ImGui.WindowFlags_NoDocking

local function render()
    local _ctx = ctx()
    Fonts:check(_ctx)

    local visible, open

    Fonts.wrap(_ctx, Fonts.main, function()
        theme.main:wrap(_ctx, function()
            visible, open = ImGui.Begin(_ctx, 'Crossfader', true, window_flags)

            if visible then
                Trap(render_window)
                ImGui.End(_ctx)
            end
        end, Trap)
    end, Trap)

    return open
end

return {
    render = render
}
