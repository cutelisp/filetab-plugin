local micro = import('micro')
local filepath = import('path/filepath')
local os = import('os')
local Directory = require("directory")
local INFO = require("info")
local Settings = require("settings")


---@class Action
---@field ft Filetab
---@field view View
local Action = {}
Action.__index = Action

function Action:new(ft)
    local instance = setmetatable({}, Action)
    instance.ft = ft
    instance.view = ft.view
    return instance
end

function Action:load_back_directory()
	local view_root_directory  = self.view:get_root_directory()
	
	if view_root_directory.path == "/" then return end

	if not view_root_directory.parent then
		local one_back_directory_path = filepath.Dir(self.view.path)
		local one_back_directory = Directory:new(
			one_back_directory_path,
		 	nil
		)
		one_back_directory.children = one_back_directory:children_create(view_root_directory)
		one_back_directory:set_is_open(true)
	end
	self.view:load(view_root_directory.parent)
end

function Action:collapse_directory(directory)
	if directory.is_open then
		directory:set_is_open(false)
		self.view:refresh()
	end
end

function Action:expand_directory(directory)
	if not directory.is_open then
		directory:set_is_open(true)
		self.view:refresh()
	end
end


function Action:toggle_directory_all_nested(directory)
	directory:toggle_is_open_all_nested()
	self.view:refresh()
end

function Action:toggle_directory(directory)
	if directory.is_open then  
		self:collapse_directory(directory)
	else 
		self:expand_directory(directory)
	end
end

local function at_cursor(original_function)
    return function(self)
    	local directory = self.view:get_entry_at_cursor()
        return original_function(self, directory)
    end
end

Action.collapse_directory_at_cursor = at_cursor(Action.collapse_directory)
Action.expand_directory_at_cursor = at_cursor(Action.expand_directory)
Action.toggle_directory_at_cursor = at_cursor(Action.toggle_directory)

function Action:_toggle_show_mode(show_mode_toggle_tbl)
    local current_show_mode = self.ft.session_settings:get(Settings.OPTIONS.SHOW_MODE)
    local next_show_mode = show_mode_toggle_tbl[current_show_mode]

    self.ft.session_settings:set(Settings.OPTIONS.SHOW_MODE, next_show_mode)
    self.view:refresh()
end

function Action:toggle_ignore_dotfiles()
    self:_toggle_show_mode(Settings.SHOW_MODE_TOGGLES["dotfiles"])
end

function Action:toggle_ignore_gitfiles()
	self:_toggle_show_mode(Settings.SHOW_MODE_TOGGLES["gitfiles"])
end

function Action:move_cursor_to_entry(entry)
	local entry_line = self.view:get_line_at_entry(entry)
	self.view.virtual:move_cursor_and_select_line(entry_line)
end

function Action:move_cursor_to_parent()
	local parent = self.view:get_entry_at_cursor().parent
	local parent_line = self.view:get_line_at_entry(parent)

	if parent_line then
		self.view.virtual:move_cursor_and_select_line(parent_line)
		self.view.virtual:adjust()--maybe change adjust to move_cursor_and_select
	end
end

function Action:move_cursor_to_first_sibling()
	local parent_line = self.view:get_parent_line(self.view:get_entry_at_cursor())
	if parent_line then 
		self.view.virtual:move_cursor_and_select_line(parent_line + 1)
	else
		-- If parent_line is nil, the cursor's parent entry is the root directory.
		-- This happens when Preferences.OPTIONS.SHOW_ROOT_DIRECTORY is false, 
		-- meaning the root exists but is hidden in the view.
		self.view.virtual:move_cursor_and_select_line(INFO.DEFAULT_LINE_ON_OPEN)
	end
end

function Action:move_cursor_to_last_sibling()
	local cursor_entry = self.view:get_entry_at_cursor()
	local parent = cursor_entry.parent
	
	if parent == self.view:get_root_directory() then 
		self.view.virtual:move_cursor_and_select_last_line()
	else
		local parent_line = self.view:get_parent_line(cursor_entry)
		self.view.virtual:move_cursor_and_select_line(parent_line + parent:len_nested())
		self.view.virtual:adjust() --todo make the adjust only ata certan range
	end
end

function Action:toggle_scrollbar()
	self.ft.session_settings:toggle(Settings.OPTIONS.SCROLLBAR)
end

function Action:delete_at_cursor()
	local entry = self.view:get_entry_at_cursor()

	micro.InfoBar():YNPrompt("Delete " .. entry.name .. "? (y, n, esc)", function (yes)
		if yes then 
			local err
			if entry:is_dir() then 
				err = os.RemoveAll(entry.path)
			else 
				err = os.Remove(entry.path)
			end
            if err then
          		micro.InfoBar():Error("Delete error: ", err)
            else
               	entry.parent:delete_child(entry)
               	self.view:refresh()
            end
		end
	end)
end

return Action
