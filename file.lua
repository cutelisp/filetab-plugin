local micro = import('micro')
local config = import('micro/config')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local icon_utils = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon_utils.Icons()
local filepath = import('path/filepath')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
--local Entry = require('entry')


---@class File : Entry
local File = setmetatable({}, { __index = Entry })
File.__index = File

---@param name string
---@param path string
---@param parent Entry
---@return Entry:File--todo
function File:new(name, path, parent)
	local entry = Entry:new(
		name,
		icon_utils.GetIcon(name),
		path,
		parent
	)
    local instance = setmetatable(entry, File)
    return instance
end


--todo
function File:is_dir()
 	return false
end 

-- Builds and returns the string representation of the file
-- The string is made up of an icon, the file name, and a slash if it's a directory
function File:get_content(offset)
	if not self.content or true then
	    local content = self.icon .. ' ' .. self.name
	    if offset then
	        content = string.rep(' ', 2 * offset) .. content
	    end
		self.content = content
	end
 	return self.content
end

function File:set_file_name(name)
	-- Since update, the content is not up-to-date
	self.content = nil
	self.name = name
end

return File
