---@class Entry
---@field name string
---@field icon string
---@field path string
---@field parent Entry? The only entry that hasn't a parent is the root one
---@field content string
---@field is_open boolean
---@field is_dotfile_cache boolean
local Entry = {}
Entry.__index = Entry

--- @param name string
--- @param icon string
--- @param path string
--- @param parent Entry?
--- @return Entry
function Entry:new(name, icon, path, parent)
    local instance = setmetatable({}, Entry)
    instance.name = name
    instance.icon = icon

    instance.path = path
    instance.parent = parent
    instance.content = nil
    instance.is_open = false
    instance.is_dotfile_cache = nil
    return instance
end

---@return boolean
function Entry:is_dotfile()
	if not self.is_dotfile_cache then 
		self.is_dotfile_cache = string.sub(self.name, 1, 1) == "."
	end 
	return self.is_dotfile_cache
end


-- Abstract function
function Entry:is_dir() end

return Entry
