local config = import('micro/config')


local Preferences = {}

---@enum pre_options
Preferences.OPTS = {
	DOUBLE_CLICK = "doubleClick",
	OPEN_ON_START = "openOnStart",
	SHOW_ROOT_DIRECTORY = "showRootDirectory",
	SHOW_ARROWS = "showArrows",
	SHOW_EMPTY_ON_DIRECTORIES = "showEmptyOnDirectories",
	SHOW_ON_RIGHT = "showOnRight",
	SHOW_EMPTY_ON_ROOT = "showEmptyOnRoot",
	PERSITENCE_OVER_TABS = "PersistenceOverTabs",
	OPEN_ON_NEW_TAB = "OpenOnNewTab",
	SHOW_SLASH_ON_DIRECTORY = "ShowSlashOnDirectory",
}

Preferences.DEFAULT_OPTIONS = {
	[Preferences.OPTS.OPEN_ON_START] = true,
	[Preferences.OPTS.DOUBLE_CLICK] = true,
	[Preferences.OPTS.OPEN_ON_NEW_TAB] = false,
	[Preferences.OPTS.SHOW_ROOT_DIRECTORY] = true,
	[Preferences.OPTS.SHOW_EMPTY_ON_DIRECTORIES] = false,
	[Preferences.OPTS.SHOW_EMPTY_ON_ROOT] = true,
	[Preferences.OPTS.SHOW_SLASH_ON_DIRECTORY] = true,
	[Preferences.OPTS.SHOW_ARROWS] = true,
	[Preferences.OPTS.SHOW_ON_RIGHT] = false,
	[Preferences.OPTS.PERSITENCE_OVER_TABS] = true
}

---@param option pre_options
function Preferences:get(option)
	return config.GetGlobalOption("filetab" .. "." .. option) or Preferences.DEFAULT_OPTIONS[option]
end

return Preferences
