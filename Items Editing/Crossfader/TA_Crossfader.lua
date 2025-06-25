-- @noindex

if not reaper.ImGui_GetBuiltinPath then
    local title = 'Crossfader ❤️ ReaImGui'
    local message = 'This script requires the ReaImGui Extension, which can be installed via ReaPack.'

    if reaper.MB(message, title, 0) then
        if reaper.ReaPack_BrowsePackages then
            reaper.ReaPack_BrowsePackages('ReaImGui')
        end
    end

    return
end

package.path = table.concat({
    package.path,

    -- script path
    ({reaper.get_action_context()})[2]:match('^.+[\\//]') .. '?.lua',

    -- imgui
    reaper.ImGui_GetBuiltinPath() .. '/?.lua',
}, ';')

local ui = require 'ui'

local function loop()
    if ui.render() then
        reaper.defer(loop)
    end
end

loop()