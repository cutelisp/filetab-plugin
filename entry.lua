---@class Entry
---@field name string
---@field icon string
---@field path string
---@field parent Entry
---@field content string
---@field is_open boolean
local Entry = {}
Entry.__index = Entry

--- @param name string
--- @param icon string
--- @param path string
--- @param parent Entry
--- @return Entry
function Entry:new(name, icon, path, parent)
    local instance = setmetatable({}, Entry)
    instance.name = name
    instance.icon = icon
    instance.path = path
    instance.parent = parent
    instance.content = nil
    instance.is_open = false
    return instance
end

return Entry
