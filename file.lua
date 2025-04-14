local micro = import('micro')
local config = import('micro/config')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local icon_utils = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon_utils.Icons()
local filepath = import('path/filepath')


local File = {}
File.__index = File

function File:new(file_name, abs_path, parent)
    local instance = setmetatable({}, File)
    instance.file_name = file_name
    instance.abs_path = abs_path
    instance.icon = icon_utils.GetIcon(file_name)
    instance.is_open = false
    instance.parent = parent or nil
    instance.content = nil
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
	    local content = self.icon .. ' ' .. self.file_name
	    if offset then
	        content = string.rep(' ', 2 * offset) .. content
	    end
		self.content = content
	end
 	return self.content
end

function File:set_file_name(file_name)
	-- Since update, the content is not up-to-date
	self.content = nil
	self.file_name = file_name
end

return File
