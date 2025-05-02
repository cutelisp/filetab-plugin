local Entry = require("entry")
local INFO = require("info")
local icons = require("icons")
local get_icon = icons.GetIcon
local Pref = require("preferences")


---@class File : Entry
local File = setmetatable({}, { __index = Entry })
File.__index = File

---@param name string
---@param path string
---@param parent Entry
---@return File
function File:new(name, path, parent)
	local instance = Entry:new(
		name,
		get_icon(name),
		path,
		parent
	)
	---@cast instance File
    setmetatable(instance, File)
   	instance:update_content()
    return instance
end

-- This is used when SHOW_EMPTY_ON_DIRECTORIES
-- Altought this object does not represent a file it was not created on
-- File class due to File:update_content() override being what this object needs
function File:new_empty(parent)
	local instance = Entry:new(
		INFO.EMPTY_ENTRY_STRING,
		"",
		nil,
		parent
	)
	---@cast instance File
    setmetatable(instance, File)
   	instance:update_content()
    return instance
end

--- override 
function File:update_content()
	Entry.update_content(self)
	if Pref:get(Pref.OPTS.SHOW_ARROWS) then
		 self.content = "  " .. self.content
	end
end

--- override 
function File:is_dir()
 	return false
end

return File
