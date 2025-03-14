-- @noindex

local json = require 'dkjson'
local log = require 'logging'

local CURRENT_PROJECT = 0
local EXTENSION_NAME = 'XY Pad'

local storage = {}

-- Project-specific storage (saved in .RPP file)
function storage.save_to_project(key, value, namespace)
    namespace = namespace or "default"
    local full_key = namespace .. ":" .. key

    if value == nil then
        -- Remove the key if value is nil
        reaper.SetProjExtState(CURRENT_PROJECT, EXTENSION_NAME, full_key, "")
        return true
    end

    local json_str = json.encode(value)

    if type(json_str) ~= "string" then
        log("Error encoding JSON for " .. full_key)
        return false
    end

    reaper.SetProjExtState(CURRENT_PROJECT, EXTENSION_NAME, full_key, json_str)
    return true
end

function storage.load_from_project(key, default_value, namespace)
    namespace = namespace or "default"
    local full_key = namespace .. ":" .. key

    local _, json_str = reaper.GetProjExtState(CURRENT_PROJECT, EXTENSION_NAME, full_key)

    if not json_str or json_str == '' then
        return default_value
    end

    local decoded_value = json.decode(json_str)

    if decoded_value == nil then
        log("Error decoding JSON for " .. full_key)
        return default_value
    end

    return decoded_value
end

function storage.remove_from_project(key, namespace)
    namespace = namespace or "default"
    local full_key = namespace .. ":" .. key
    reaper.SetProjExtState(CURRENT_PROJECT, EXTENSION_NAME, full_key, "")
    return true
end

-- List all keys in a specific namespace
function storage.list_project_keys(namespace)
    namespace = namespace or "default"
    local keys = {}
    local prefix = namespace .. ":"
    local prefix_len = #prefix

    -- Use EnumProjExtState to iterate through all keys
    local i = 0
    while true do
        local retval, key, _ = reaper.EnumProjExtState(CURRENT_PROJECT, EXTENSION_NAME, i)
        if not retval or not key then break end

        -- Check if this key belongs to our namespace
        if key:sub(1, prefix_len) == prefix then
            table.insert(keys, key:sub(prefix_len + 1))
        end

        i = i + 1
    end

    return keys
end

-- Application-level storage (used for IPC between scripts)
function storage.save_to_reaper(key, value, namespace)
    namespace = namespace or EXTENSION_NAME

    if value == nil then
        reaper.DeleteExtState(namespace, key, true)
        return true
    end

    local json_str = json.encode(value)

    if type(json_str) ~= "string" then
        log("Error encoding JSON for app state " .. key)
        return false
    end

    -- false = not persist (for IPC)
    reaper.SetExtState(namespace, key, json_str, false)
    return true
end

function storage.load_from_reaper(key, default_value, namespace)
    namespace = namespace or EXTENSION_NAME

    local json_str = reaper.GetExtState(namespace, key)

    if not json_str or json_str == '' then
        return default_value
    end

    local decoded_value = json.decode(json_str)

    if decoded_value == nil then
        log("Error decoding JSON for app state " .. key)
        return default_value
    end

    return decoded_value
end

function storage.remove_from_reaper(key, namespace)
    namespace = namespace or EXTENSION_NAME
    reaper.DeleteExtState(namespace, key, true)
    return true
end

return storage
