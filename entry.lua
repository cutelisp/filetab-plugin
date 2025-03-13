local config = import('micro/config')
local icon = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon.Icons()
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')


-- Entry is the object of scanlist
local entry = {}
entry.__index = entry

-- Return a new object used when adding to scanlist
function entry:new(abspath, icon, owner, indent)
    local instance = setmetatable({}, entry)
    instance.abspath = abspath
    instance.icon = icon
    instance.owner = owner
    instance.indent = indent
    return instance
end

-- Since decreasing/increasing is common, we include these with the object
function entry:decrease_owner(minus_num)
    self.owner = self.owner - minus_num
end

function entry:increase_owner(plus_num)
    self.owner = self.owner + plus_num
end

-- True/false if entry is a direcory
function entry:is_dir()
    return self.icon == icons['dir'] or self.icon == icons['dir_open']
end

-- Builds and returns the entire string of the entry
function entry:get_content()
    -- Add the icon base on path
    -- Add a forward slash to the right to signify it's a dir
    local content = self.icon .. ' ' .. utils.get_basename(self.abspath) .. (self:is_dir() and '' or '/')

    if self.owner > 0 then
        -- Add a space and repeat it * the indent number
        content = utils.repeat_str(' ', 2 * self.indent) .. content 
    end
    return content
end

return entry