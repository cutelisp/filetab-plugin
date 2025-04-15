local config = import('micro/config')

---@module "utils"
local utils = dofile(config.ConfigDir .. '/plug/filetab/src/utils.lua')
---@module "info"
local INFO = utils.import("info")


---@class Preferences
---@field options any[]
---@field bp any
local Preferences = {}
Preferences.__index = Preferences

---@enum pre_options
Preferences.OPTIONS = {
	OPEN_ON_START = "openOnStart",
	SHOW_DOTFILES = "showDotfiles",
}

Preferences.DEFAULT_OPTIONS = {
	[Preferences.OPTIONS.OPEN_ON_START] = true,
	[Preferences.OPTIONS.SHOW_DOTFILES] = true,
}

function Preferences:load_default_options(bp)
	local value
	for _, option in pairs(Preferences.OPTIONS) do
		value = config.GetGlobalOption(INFO.PLUGIN_NAME .. "." .. option) or Preferences.DEFAULT_OPTIONS[option]
		self:set(option, value)
	end
end

---@param option pre_options
---@param value any
function Preferences:set(option, value)
	self.options[option] = value
end

---@param option pre_options
function Preferences:get(option)
	return self.options[option] 
end

---@param option pre_options
function Preferences:toggle(option)
	local value = not self:get(option)
	self.options[option] = value
	self.bp.Buf:SetOptionNative(option, value)
end

---@param bp any
---@return Preferences
function Preferences:new(bp)
	local instance = setmetatable({}, Preferences)
	instance.bp = bp
	instance.options = {}
	instance:load_default_options()
	return instance
end

return Preferences
