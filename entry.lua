local config = import('micro/config')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local icon_utils = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon_utils.Icons()

-- Entry is the object of scanlist
local Entry = {}
Entry.__index = Entry

-- Return a new object used when adding to scanlist
function Entry:new(file_name, abs_path, owner)
    local instance = setmetatable({}, Entry)
    local is_dir = utils.is_dir(abs_path)
    instance.is_dir = is_dir
    instance.file_name = file_name
    instance.abs_path = abs_path
    instance.icon = (is_dir and icons['dir'] or icon_utils.GetIcon(file_name))
    instance.owner = owner
    instance.is_open = false 
    instance.entry_list = nil
    return instance
end

-- Builds and returns the string representation of the entry
-- The string is made up of an icon, the file name, and a slash if it's a directory
function Entry:get_content(offset)
    local content = self.icon .. ' ' .. self.file_name .. (self.is_dir and '/' or '')
    if offset then
        content = string.rep(' ', 2 * offset) .. content    
    end
    return content
end

function Entry:set_is_open(status)
    if self.is_dir then
        self.icon = status and icons['dir_open'] or icons['dir']
    end
    self.is_open = status
end

-- Since decreasing/increasing is common, we include these with the object
function Entry:decrease_owner(minus_num)
    self.owner = self.owner - minus_num
end

function Entry:increase_owner(plus_num)
    self.owner = self.owner + plus_num
end

function Entry:get_entry_list()
    return self.entry_list
end

function Entry:set_entry_list(entry_list)
    self.entry_list = entry_list
end

return Entry