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
	Settings.setOption("scrollbar", false)
end

function Settings.getOption(optionKey)
	return config.GetGlobalOption(Settings.Const.pluginName .. "." .. optionKey)
end

function Settings.setOption(key, value)
	config.RegisterCommonOption(Settings.Const.pluginName, key, value)
end

return Settings