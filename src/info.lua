local config = import('micro/config')
local Preferences = require("preferences")


---@enum
Info = {
	PLUGIN_NAME = "filetab",
	EMPTY_ENTRY_STRING = "<EMPTY>",
	MIN_WIDTH = 30,
	LINE_PREVIOUS_DIRECTORY = 2,
	DEFAULT_LINE_ON_OPEN = 3,
	HEADER_SIZE = Preferences:get(Preferences.OPTS.SHOW_ROOT_DIRECTORY) and 4 or 3,
	ROOT_DIRECTORY_LINE = 3 -- This is false when SHOW_ROOT_DIRECTORY is false
}

return Info