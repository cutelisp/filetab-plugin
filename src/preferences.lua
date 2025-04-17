local config = import('micro/config')

local Preferences = {}

---@enum pre_options
Preferences.OPTIONS = {
	OPEN_ON_START = "openOnStart",
	SHOW_ROOT_DIRECTORY = "showRootDirectory",
}

Preferences.DEFAULT_OPTIONS = {
	[Preferences.OPTIONS.OPEN_ON_START] = true,
	[Preferences.OPTIONS.SHOW_ROOT_DIRECTORY] = true,
}

---@param option pre_options
function Preferences:get(option)
	return config.GetGlobalOption("filetab" .. "." .. option) or Preferences.DEFAULT_OPTIONS[option]
end

return Preferences
