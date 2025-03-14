-- @noindex

local ImGui = require 'imgui' '0.9.2'

local fonts = {}

local font_definitions = {
  main = { 'sans-serif', 14, ImGui.FontFlags_None},
  labels = { 'sans-serif', 12, ImGui.FontFlags_None},
  heading = { 'sans-serif', 18, ImGui.FontFlags_None},
}

local function get_font(key)
    local font = fonts[key]

    if not font or not ImGui.ValidatePtr(font, "ImGui_Font*") then
        local definition = font_definitions[key]

        if not definition then
            error('Font definition not found for key: ' .. key)
        end

        font = ImGui.CreateFont(table.unpack(definition))
        fonts[key] = font
    end

    return font
end

local function attach(ctx)
    for key, _ in pairs(font_definitions) do
        ImGui.Attach(ctx, get_font(key))
    end
end

return {
  get_font = get_font,
  attach = attach,
}
