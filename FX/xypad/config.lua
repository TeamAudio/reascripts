-- @noindex

local storage = require 'storage'

local CONFIG_NAMESPACE = 'config'
local CONFIG_KEY = 'main'

local DEFAULT_X_LINES = 2
local DEFAULT_Y_LINES = 2
local DEFAULT_GRID_LINES_LINKED = true
local DEFAULT_GRID_LINE_X_COLOR = 0xFFFFFFFF
local DEFAULT_GRID_LINE_Y_COLOR = 0xFFFFFFFF
local DEFAULT_GRID_LINES_LINKED_COLOR = true
local DEFAULT_GRID_LINE_WIDTH = 1.0

local DEFAULT_PAD_BG_COLOR = 0x000000FF
local DEFAULT_CURSOR_COLOR = 0xFF0000FF
local DEFAULT_CURSOR_RADIUS = 10
local DEFAULT_CURSOR_STROKE = 2

-- Path drawing defaults
local DEFAULT_PATH_COLOR = 0xFF8000FF -- Orange, full opacity
local DEFAULT_PATH_WIDTH = 2.0
local DEFAULT_PATH_SHOW = true
local DEFAULT_PATH_SMOOTH_FACTOR = 0.5 -- 0.0 to 1.0, higher = smoother

-- Path history and fade options
local DEFAULT_MAX_PATHS = 10
local DEFAULT_PATH_FADE_TIME = 3.0        -- seconds until full fade
local DEFAULT_DESELECTED_FADE_TIME = 1.0  -- seconds for deselected paths to fade
local DEFAULT_INACTIVE_PATH_OPACITY = 0.4 -- base opacity for inactive paths

-- Path visibility and fading options
local DEFAULT_PATH_MIN_OPACITY = 0.05     -- minimum opacity before path is hidden
local DEFAULT_SELECTED_PATH_OPACITY = 0.8 -- opacity for selected path(s)
local DEFAULT_RECENT_PATH_OPACITY = 0.6   -- opacity for most recently drawn path

-- Path thickness options
local DEFAULT_PATH_THICKNESS_EFFECT = true  -- enable thickness variation
local DEFAULT_PATH_MAX_THICKNESS = 5.0      -- thickness at start of path
local DEFAULT_PATH_MIN_THICKNESS = 1.0      -- thickness at end of path
local DEFAULT_PATH_PERSIST_TIME = 2.0       -- seconds new paths remain bright
local DEFAULT_PATH_THICKNESS_CONTRAST = 1.5 -- contrast for thickness variation

local function save_config(config)
    return storage.save_to_project(CONFIG_KEY, config, CONFIG_NAMESPACE)
end

local function default_config()
    return {
        x_lines = DEFAULT_X_LINES,
        y_lines = DEFAULT_Y_LINES,
        grid_lines_linked = DEFAULT_GRID_LINES_LINKED,
        grid_line_x_color = DEFAULT_GRID_LINE_X_COLOR,
        grid_line_y_color = DEFAULT_GRID_LINE_Y_COLOR,
        grid_lines_linked_color = DEFAULT_GRID_LINES_LINKED_COLOR,
        grid_line_width = DEFAULT_GRID_LINE_WIDTH,
        pad_bg_color = DEFAULT_PAD_BG_COLOR,
        cursor_color = DEFAULT_CURSOR_COLOR,
        cursor_radius = DEFAULT_CURSOR_RADIUS,
        cursor_stroke = DEFAULT_CURSOR_STROKE,

        -- Path drawing options
        path_color = DEFAULT_PATH_COLOR,
        path_width = DEFAULT_PATH_WIDTH,
        path_show = DEFAULT_PATH_SHOW,
        path_smooth_factor = DEFAULT_PATH_SMOOTH_FACTOR,

        -- Path history and fade options
        max_paths = DEFAULT_MAX_PATHS,
        path_fade_time = DEFAULT_PATH_FADE_TIME,
        deselected_fade_time = DEFAULT_DESELECTED_FADE_TIME,
        inactive_path_opacity = DEFAULT_INACTIVE_PATH_OPACITY,

        -- Path visibility and fading options
        path_min_opacity = DEFAULT_PATH_MIN_OPACITY,
        selected_path_opacity = DEFAULT_SELECTED_PATH_OPACITY,
        recent_path_opacity = DEFAULT_RECENT_PATH_OPACITY,

        -- Path thickness options
        path_thickness_effect = DEFAULT_PATH_THICKNESS_EFFECT,
        path_max_thickness = DEFAULT_PATH_MAX_THICKNESS,
        path_min_thickness = DEFAULT_PATH_MIN_THICKNESS,
        path_persist_time = DEFAULT_PATH_PERSIST_TIME,
        path_thickness_contrast = DEFAULT_PATH_THICKNESS_CONTRAST,
    }
end

local function load_config()
    return storage.load_from_project(CONFIG_KEY, default_config(), CONFIG_NAMESPACE)
end

return {
    save_config = save_config,
    load_config = load_config,
    default_config = default_config,
}
