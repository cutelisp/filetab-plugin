local config = import('micro/config')

local Settings = {}

Settings.Const = {
	pluginName = "filetab",
	minWidth = 30,
	previousDirectoryLine = 2,
	defaultLineOnOpen = 2,
}

-- If the `micro/settings.json` file contains any of these options,
-- the values in that file will override the ones specified here.
function Settings.load_default()
	Settings.set_option("scrollbar", false)
	Settings.set_option("openOnStart", true)
end

function Settings.get_option(optionKey)
	return config.GetGlobalOption(Settings.Const.pluginName .. "." .. optionKey)
end

function Settings.set_option(key, value)
	config.RegisterCommonOption(Settings.Const.pluginName, key, value)
end

return Settings