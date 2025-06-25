-- @noindex

local CURRENT_PROJECT = 0
local BEGIN_BLOCK = 1
local END_BLOCK = -1
local NO_UI_REFRESH = false
local NO_FADE = 0
local INVALID_GAP = 5

local function get_previous_item(item)
    local prev_item_pos = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
    local prev_item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

    return prev_item_pos, prev_item_len
end

-- Item validator
local function validate_items(num_items, fade_len)
    local valid_table = {}
    local invalid_table = {}

    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(CURRENT_PROJECT, i)
        local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

        if item_len <= fade_len then
            table.insert(invalid_table, item)
        else
            table.insert(valid_table, item)
        end
    end

    return valid_table, invalid_table
end

-- Valid items
local function set_item_fades(item, prev_item, fade_len, fade_shape)
    reaper.SetMediaItemInfo_Value(item, 'D_FADEINLEN', fade_len)
    reaper.SetMediaItemInfo_Value(prev_item, 'D_FADEOUTLEN', fade_len)

    reaper.SetMediaItemInfo_Value(item, 'C_FADEINSHAPE', fade_shape)
    reaper.SetMediaItemInfo_Value(prev_item, 'C_FADEOUTSHAPE', fade_shape)
end

local function crossfade_valid_items(valid_item_table, fade_len, fade_shape)
    for i, item in ipairs(valid_item_table) do
        if i == 1 then
            reaper.SetMediaItemInfo_Value(item, 'D_FADEINLEN', NO_FADE)
        else
            local prev_item = valid_item_table[i - 1]
            local prev_item_pos, prev_item_len = get_previous_item(prev_item)
            local new_pos = prev_item_pos + prev_item_len - fade_len
            reaper.SetMediaItemPosition(item, new_pos, NO_UI_REFRESH)

            set_item_fades(item, prev_item, fade_len, fade_shape)
        end

        if i == #valid_item_table then
            reaper.SetMediaItemInfo_Value(item, 'D_FADEOUTLEN', NO_FADE)
        end
    end
end

-- Invalid items
local function get_invalid_start_pos(last_valid_item)
    local start_item_pos = reaper.GetMediaItemInfo_Value(last_valid_item, 'D_POSITION')
    local start_item_len = reaper.GetMediaItemInfo_Value(last_valid_item, 'D_LENGTH')
    local start_pos = start_item_pos + start_item_len + INVALID_GAP

    return start_pos
end

local function clear_item_fades(item)
    reaper.SetMediaItemInfo_Value(item, 'D_FADEINLEN', NO_FADE)
    reaper.SetMediaItemInfo_Value(item, 'D_FADEOUTLEN', NO_FADE)
end

local function reposition_invalid_items(invalid_item_table, start_pos)
    for i, item in ipairs(invalid_item_table) do
        if i == 1 then
            reaper.SetMediaItemPosition(item, start_pos, NO_UI_REFRESH)
        else
            local prev_item_pos, prev_item_len = get_previous_item(invalid_item_table[i - 1])
            local new_pos = prev_item_pos + prev_item_len
            reaper.SetMediaItemPosition(item, new_pos, NO_UI_REFRESH)
        end

        clear_item_fades(item)
    end
end

-- Secondary fade set function
local function set_fade_shapes(fade_shape)
    reaper.Undo_BeginBlock()
    local num_items = reaper.CountSelectedMediaItems(CURRENT_PROJECT)

    for i = 1, num_items - 1 do
        local cur_item = reaper.GetSelectedMediaItem(CURRENT_PROJECT, i)
        local prev_item = reaper.GetSelectedMediaItem(CURRENT_PROJECT, i - 1)

        reaper.SetMediaItemInfo_Value(cur_item, 'C_FADEINSHAPE', fade_shape)
        reaper.SetMediaItemInfo_Value(prev_item, 'C_FADEOUTSHAPE', fade_shape)
    end
    reaper.UpdateArrange()
    reaper.Undo_EndBlock('Set Fade Shapes', -1)
end

-- Main crossfade function
local function crossfade(fade_len, fade_shape)
    local num_items = reaper.CountSelectedMediaItems(CURRENT_PROJECT)

    if num_items < 2 then
        reaper.MB('Please select 2 or more media items.', 'Error', 0)
        return
    end

    reaper.PreventUIRefresh(BEGIN_BLOCK)
    reaper.Undo_BeginBlock()

    fade_len = fade_len or 0
    fade_shape = fade_shape or 0

    local valid_items, invalid_items = validate_items(num_items, fade_len)

    crossfade_valid_items(valid_items, fade_len, fade_shape)

    local last_valid_item = valid_items[#valid_items]
    local start_pos = get_invalid_start_pos(last_valid_item)

    reposition_invalid_items(invalid_items, start_pos)

    reaper.Undo_EndBlock('Crossfade', END_BLOCK)
    reaper.PreventUIRefresh(END_BLOCK)
    reaper.UpdateArrange()
end

return {
    crossfade = crossfade,
    set_fade_shapes = set_fade_shapes
}