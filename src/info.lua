local config = import('micro/config')

---@module "utils"
---@module "preferences"
local Preferences = dofile(config.ConfigDir .. '/plug/filetab/src/preferences.lua')

---@enum
Info = {
	PLUGIN_NAME = "filetab",
	MIN_WIDTH = 30,
	LINE_PREVIOUS_DIRECTORY = 2,
	DEFAULT_LINE_ON_OPEN = 3,
	HEADER_SIZE = Preferences:get(Preferences.OPTIONS.SHOW_ROOT_DIRECTORY) and 4 or 0,
	ROOT_DIRECTORY_LINE = 3 -- This is false when SHOW_ROOT_DIRECTORY is false
}

return Info