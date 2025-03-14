local config = import('micro/config')

local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local icon_utils = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon_utils.Icons()

-- Entry is the object of scanlist
local Entry = {}
Entry.__index = Entry

-- Return a new object used when adding to scanlist
function Entry:new(file_name, abs_path, owner, indent_level)
    local instance = setmetatable({}, Entry)
    local is_dir = utils.is_dir(abs_path)
    instance.is_dir = is_dir
    instance.file_name = file_name
    instance.abs_path = abs_path
    instance.icon = (is_dir and icons['dir'] or icon_utils.GetIcon(file_name))
    instance.owner = owner
    instance.indent_level = indent_level
    return instance
end

-- Since decreasing/increasing is common, we include these with the object
function Entry:decrease_owner(minus_num)
    self.owner = self.owner - minus_num
end

function Entry:increase_owner(plus_num)
    self.owner = self.owner + plus_num
end

-- Builds and returns the string representation of the entry
-- The string is made up of an icon, the file name, and a slash if it's a directory
function Entry:get_content()
    local content = self.icon .. ' ' .. utils.get_basename(self.abs_path) .. (self.is_dir and '/' or '')
    if self.owner > 0 then
        -- Add a space and repeat it * the indent number
        content = utils.repeat_str(' ', 2 * self.indent_level) .. content
    end
    return content
end

return Entry