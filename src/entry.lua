local filepath = import('path/filepath')
local INFO = require("info")


---@class Entry
---@field name string
---@field icon? string This might hold 2 icons when SHOW_ARROWS is true, can be nil since the value is given after constructor is called
---@field path string
---@field parent Entry? The only entry that hasn't a parent is the root one
---@field content string? This is what is printed on each line, this var holds the static content and it's accessed by get_content() or changed by content_update()
---@field is_open boolean
---@field is_dotfile_cache boolean
local Entry = {}
Entry.__index = Entry

--- @param name string
--- @param icon string?
--- @param path string
--- @param parent Entry?
--- @return Entry
function Entry:new(name, icon, path, parent)
    local instance = setmetatable({}, Entry)
    instance.name = name --todo extract here the name instead ofoutside
    instance.icon = icon
    instance.path = path
    instance.parent = parent
    instance.content = nil
    instance.is_open = false
    instance.is_dotfile_cache = nil
    return instance
end

-- Abstract function
function Entry:is_dir() end

function Entry:is_dotfile()
	if not self.is_dotfile_cache then 
		self.is_dotfile_cache = string.sub(self.name, 1, 1) == "."
	end 
	return self.is_dotfile_cache
end

function Entry:is_git_ignored()
	local children_ignored = self.parent:get_children_git_ignored()
	-- children_ignored directory records have a "/" at end
	local slash = self:is_dir() and '/' or ''

	return children_ignored[self.name .. slash]
end

function Entry:get_content(offset)
    if offset then
  		return string.rep(' ', 2 * offset) .. self.content
    else
    	return self.content
    end
end

function Entry:set_name(name)
	self.name = name
	self:update_path()
	self:update_content()
end

function Entry:update_path(dir)
	self.path = filepath.Join(dir or filepath.Dir(self.path), self.name)
end

function Entry:update_content()
	local content = self.icon .. self.name
	self.content = content
end

--todo do an is_open function
return Entry
