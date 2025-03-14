-- @noindex
local storage = require 'storage'

-- Path storage namespace
local PATH_NAMESPACE = 'paths'
local PATH_INDEX_KEY = 'index'
local PINNED_INDEX_KEY = 'pinned_index'

-- Version information, increment as needed and provide migration
-- branches in the migrate functions 
local CURRENT_INDEX_VERSION = 1
local CURRENT_PATH_VERSION = 1

local save_path, load_path, delete_path
local save_index, load_index, migrate_index
local save_pinned_index, load_pinned_index
local add_path, load_all, update_path, remove_path, clear_all
local pin_path, unpin_path, is_path_pinned
local migrate_path_data

-- Find a path in an index by ID
local function find_by_id(index, path_id)
    for i, meta in ipairs(index.paths) do
        if meta.id == path_id then
            return meta, i
        end
    end

    return nil, nil
end

-- Build a lookup table of path IDs for a given index
local function build_id_lookup(index)
    local lookup = {}

    for _, meta in ipairs(index.paths) do
        lookup[meta.id] = true
    end

    return lookup
end

-- Find and update a path by ID, returning true if found and udpated
local function find_and_update(index, path_id, update_fn)
    local meta, _ = find_by_id(index, path_id)
    if meta then
        update_fn(meta)
        return true
    end
    return false
end

-- Find and remove a path by ID, returning true if found and removed
local function find_and_remove(index, path_id)
    local _, i = find_by_id(index, path_id)
    if i then
        table.remove(index.paths, i)
        return true
    end
    return false
end

-- Save a path to storage
function save_path(path_id, path_data)
    path_data.data_version = path_data.data_version or CURRENT_PATH_VERSION
    return storage.save_to_project(path_id, path_data, PATH_NAMESPACE)
end

-- Load a path from storage
function load_path(path_id)
    local path_data = storage.load_from_project(path_id, nil, PATH_NAMESPACE)

    -- migrate if necessary
    local data_version = path_data and (path_data.data_version or 0)

    if data_version < CURRENT_PATH_VERSION then
        path_data = migrate_path_data(path_data, data_version)
    end

    return path_data
end

-- Delete a path
function delete_path(path_id)
    return storage.remove_from_project(path_id, PATH_NAMESPACE)
end

-- Save the history index
function save_index(index_data)
    index_data.data_version = CURRENT_INDEX_VERSION
    return storage.save_to_project(PATH_INDEX_KEY, index_data, PATH_NAMESPACE)
end

-- Load the path index
function load_index()
    local default_value = {
        data_version = CURRENT_INDEX_VERSION,
        paths = {},
    }

    local index = storage.load_from_project(PATH_INDEX_KEY, default_value, PATH_NAMESPACE)

    if not index then
        error("Could not load path history index!")
    end

    local data_version = index.data_version or 0
    if data_version < CURRENT_INDEX_VERSION then
        index = migrate_index(index, data_version)
        save_index(index)
    end

    return index
end

function save_pinned_index(pinned_data)
    pinned_data.data_version = CURRENT_INDEX_VERSION
    return storage.save_to_project(PINNED_INDEX_KEY, pinned_data, PATH_NAMESPACE)
end

function load_pinned_index()
    local default_value = {
        data_version = CURRENT_INDEX_VERSION,
        paths = {},
    }

    local pinned = storage.load_from_project(PINNED_INDEX_KEY, default_value, PATH_NAMESPACE)

    if not pinned then
        error("Could not load pinned path index!")
    end

    local data_version = pinned.data_version or 0

    if data_version < CURRENT_INDEX_VERSION then
        pinned = migrate_index(pinned, data_version)
        save_pinned_index(pinned)
    end

    return pinned
end

-- Migrate index to current version
function migrate_index(index, from_version)
    -- Add migration logic here
    if from_version < 1 then
        index.paths = index.paths or {}
    end

    index.data_version = CURRENT_INDEX_VERSION
    return index
end

-- Migrate path data
function migrate_path_data(path_data, from_version)

    if from_version < 1 then
        -- basic essential properties
        path_data.points = path_data.points or {}
        path_data.name = path_data.name or "Unnamed Path"
        path_data.created = path_data.created or os.time()
    end

    path_data.data_version = CURRENT_PATH_VERSION
    return path_data
end

function is_path_pinned(path_id)
    return find_by_id(load_pinned_index(), path_id) ~= nil
end

-- Add a new path
function add_path(path_data, max_paths)
    -- Generate a unique ID using reaper.genGuid
    local path_id = reaper.genGuid("")

    path_data.data_version = CURRENT_PATH_VERSION

    -- Save the path data
    save_path(path_id, path_data)

    -- Update the index
    local index = load_index()

    -- Create metadata for the index
    local path_meta = {
        id = path_id,
        name = path_data.name,
        created = path_data.created,
        color = path_data.color,
        width = path_data.width,
        last_active_time = path_data.last_active_time or path_data.created
    }

    -- Add to the beginning (newest first)
    table.insert(index.paths, 1, path_meta)

    -- Trim to max size without removing pinned paths
    -- Need to check both indices
    local pinned_index = load_pinned_index()
    local pinned_ids = build_id_lookup(pinned_index)

    while #index.paths > max_paths do
        local last_path = index.paths[#index.paths]
        if not pinned_ids[last_path.id] then
            -- Safe to remove from history if not pinned
            local removed = table.remove(index.paths)
            delete_path(removed.id)
        else
            -- Path is pinned, so leave it in storage but remove from history index
            table.remove(index.paths)
        end
    end

    -- Save the updated index
    save_index(index)

    return path_id
end

function pin_path(path_id)
    -- Check if already pinned
    if is_path_pinned(path_id) then
        return false
    end

    local index = load_index()

    local path_meta = nil

    -- Find path in history index
    for _, meta in ipairs(index.paths) do
        if meta.id == path_id then
            path_meta = {}
            for k, v in pairs(meta) do
                path_meta[k] = v
            end
            break
        end
    end

    -- not found? load directly for best result
    if not path_meta then
        local path_data = load_path(path_id)
        if not path_data then
            -- não existe
            return false
        end

        path_meta = {
            id = path_id,
            name = path_data.name,
            created = path_data.created,
            color = path_data.color,
            width = path_data.width,
            last_active_time = path_data.last_active_time or path_data.created,
        }
    end

    -- add to pinned index
    local pinned_index = load_pinned_index()

    table.insert(pinned_index.paths, path_meta)
    save_pinned_index(pinned_index)

    return true
end

function unpin_path(path_id)
    local pinned_index = load_pinned_index()

    -- find and remove from pinned index
    local was_removed = find_and_remove(pinned_index, path_id)

    if was_removed then
        save_pinned_index(pinned_index)

        -- check if path still exists in history
        local in_history = find_by_id(load_index(), path_id) ~= nil

        -- if not in history, delete the path data
        if not in_history then
            delete_path(path_id)
        end
    end

    return was_removed
end

-- Load all paths
function load_all()
    local index = load_index()

    local pinned_index = load_pinned_index()

    local paths = {}
    local seen_ids = {}

    -- Combine history and pinned paths, avoiding duplicates
    -- Process pinned first so they're appropriately marked
    for _, meta in ipairs(pinned_index.paths) do
        local path_data = load_path(meta.id)
        if path_data then
            path_data.id = meta.id
            path_data.name = meta.name
            path_data.pinned = true
            table.insert(paths, path_data)
            seen_ids[meta.id] = true
        end
    end

    for _, meta in ipairs(index.paths) do
        if not seen_ids[meta.id] then
            local path_data = load_path(meta.id)
            if path_data then
                path_data.id = meta.id
                path_data.name = meta.name
                path_data.pinned = false
                table.insert(paths, path_data)
            end
        end
    end

    return paths
end

-- Update a path
function update_path(path_id, path_data)
    -- Save the path data
    save_path(path_id, path_data)

    -- Update the index if necessary
    local index = load_index()

    local updated = find_and_update(index, path_id, function(meta)
        meta.name = path_data.name
        meta.color = path_data.color
        meta.width = path_data.width
        meta.last_active_time = path_data.last_active_time
    end)

    if updated then
        save_index(index)
    end

    local pinned_index = load_pinned_index()

    -- Update the pinned index too
    updated = find_and_update(pinned_index, path_id, function(meta)
        meta.name = path_data.name
        meta.color = path_data.color
        meta.width = path_data.width
        meta.last_active_time = path_data.last_active_time
    end)

    if updated then
        save_pinned_index(pinned_index)
    end
end

-- Remove a path
function remove_path(path_id)
    -- Remove from index
    local index = load_index()

    local was_removed = find_and_remove(index, path_id)

    if was_removed then
        save_index(index)
    end

    -- Remove from pinned index
    local pinned_index = load_pinned_index()

    was_removed = find_and_remove(pinned_index, path_id)

    if was_removed then
        save_pinned_index(pinned_index)
    end

    -- Remove from storage
    delete_path(path_id)
end

-- Clear all paths
function clear_all(keep_pinned)
    local index = load_index()

    local pinned_index = load_pinned_index()

    if keep_pinned then
        local pinned_ids = {}

        for _, meta in ipairs(pinned_index.paths) do
            pinned_ids[meta.id] = true
        end

        -- Remove all non-pinned paths
        for _, meta in ipairs(index.paths) do
            if not pinned_ids[meta.id] then
                delete_path(meta.id)
            end
        end

        index.paths = {}
    else
        -- Remove all paths
        for _, meta in ipairs(index.paths) do
            delete_path(meta.id)
        end

        -- Remove all pinned paths
        for _, meta in ipairs(pinned_index.paths) do
            delete_path(meta.id)
        end

        index.paths = {}
        pinned_index.paths = {}
        save_pinned_index(pinned_index)
    end

    save_index(index)
end

return {
    -- Basic path operations
    save_path = save_path,
    load_path = load_path,
    delete_path = delete_path,

    -- History index
    save_index = save_index,
    load_index = load_index,

    -- Pinned operations
    pin_path = pin_path,
    unpin_path = unpin_path,
    is_path_pinned = is_path_pinned,

    -- Path collection operations
    add_path = add_path,
    load_all = load_all,
    update_path = update_path,
    remove_path = remove_path,
    clear_all = clear_all,

    -- Version information
    get_index_version = function() return CURRENT_INDEX_VERSION end,
    get_path_version = function() return CURRENT_PATH_VERSION end,
}
