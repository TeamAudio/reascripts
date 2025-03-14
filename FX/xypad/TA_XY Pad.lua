-- @noindex

local entrypath = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = string.format('%s?.lua;', entrypath)

package.path = package.path .. ';' .. reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

local mappings = require 'mappings'
local extstate = require 'extstate'
local ui = require 'ui'
local config = require 'config'

local active_project_changed = (function()
    -- use local reference to avoid global + table key lookups in hot path
    local get_current_project = reaper.EnumProjects

    -- hide related state inside closure
    local current_project, current_name = get_current_project(-1)

    return function()
        local new_project, new_name = get_current_project(-1)

        if new_project ~= current_project or new_name ~= current_name then
            current_project, current_name = new_project, new_name
            return true
        end

        return false
    end
end)()


local function receive_json_mapping()
    local m = extstate.receive_param()

    if not m then return end

    mappings.add_mapping(m.axis, m.track_guid, m.fx_guid, m.param_number)
end

local pad_window_flags
    = ImGui.WindowFlags_NoDocking
    | ImGui.WindowFlags_MenuBar
    | ImGui.WindowFlags_NoCollapse

local options = config.load_config()

local function loop()
    if active_project_changed() then
        mappings.reload_mappings()
        options = config.load_config()
    end

    local ctx = ui.ctx()

    local visible_xy, open_xy = ImGui.Begin(ctx, 'XY Pad', true, pad_window_flags)

    if visible_xy then
        receive_json_mapping()
        ui.render_xy_pad(options)
        ui.xy_menu_bar(ctx)
        ui.render_mapping()
        ui.render_options(options)
        ImGui.End(ctx)
    end

    if open_xy then
        reaper.defer(loop)
    end
end

mappings.reload_mappings()
loop()
