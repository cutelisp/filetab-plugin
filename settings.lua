local config = import('micro/config')
---@module "info"
local Info = dofile(config.ConfigDir .. '/plug/filemanager/info.lua')


---@class Settings
---@field options any[]
---@field bp any
local Settings = {}
Settings.__index = Settings

---@enum sett_options
Settings.OPTIONS = {
	SCROLLBAR = "scrollbar",
	RULER = "ruler",
	SOFTWRAP = "softwrap",
	STATUSFORMATR = "statusformatr",
	STATUSFORMATL = "statusformatl",
	READONLY = "readonly",
	SHOW_DOTFILES = "show_dotfiles",
	SHOW_MODE = "show_mode",
}

Settings.SHOW_MODES = {
	SHOW_ALL = "showAll",
	SHOW_NONE = "showNone",
	IGNORE_DOTFILES = "ignoreDotfiles",
	IGNORE_GIT = "ignoreGit",
}

Settings.DEFAULT_OPTIONS = {
	[Settings.OPTIONS.SCROLLBAR] = false,
	[Settings.OPTIONS.RULER] = false,
	[Settings.OPTIONS.SOFTWRAP] = false,
	[Settings.OPTIONS.STATUSFORMATR] = "", --todo place info
	[Settings.OPTIONS.STATUSFORMATL] = "filetab",
	[Settings.OPTIONS.READONLY] = true,
	[Settings.OPTIONS.SHOW_DOTFILES] = true,
	[Settings.OPTIONS.SHOW_MODE] = Settings.SHOW_MODES.SHOW_ALL,
}

function Settings:load_default_options(bp)
	local value
	for _, option in pairs(Settings.OPTIONS) do
		value = config.GetGlobalOption(Info.PLUGIN_NAME .. "." .. option) or Settings.DEFAULT_OPTIONS[option]
		self:set(option, value)
	end
end

---@param option sett_options
---@param value any
function Settings:set(option, value)
	self.options[option] = value
	self.bp.Buf:SetOptionNative(option, value)
end

---@param option sett_options
function Settings:toggle(option)
	local value = not self:get(option)
	self.options[option] = value
	self.bp.Buf:SetOptionNative(option, value)
end

---@param option options
function Settings:get(option)
	return self.options[option] 
end

---@param bp any
---@return Settings
function Settings:new(bp)
	local instance = setmetatable({}, Settings)
	instance.bp = bp
	instance.options = {}
	instance:load_default_options()
	return instance
end

return Settings
