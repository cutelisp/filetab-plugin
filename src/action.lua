local filepath = import('path/filepath')
local config = import('micro/config')

---@module "utils"
local utils = dofile(config.ConfigDir .. '/plug/filetab/src/utils.lua')
---@module "settings"
local Settings = utils.import("settings")
---@module "directory"
local Directory = utils.import("directory")


---@class Action
---@field ft Filetab
local Action = {}
Action.__index = Action

function Action:new(ft)
    local instance = setmetatable({}, Action)
    instance.ft = ft
    return instance
end

function Action:load_back_directory()
	local view_root_directory  = self.ft.view:get_root_directory()
	
	if view_root_directory.parent then
		self.ft.view:load(view_root_directory.parent)
	else
		local one_back_directory_path = filepath.Dir(self.ft.view.path)
		local one_back_directory = Directory:new(
			one_back_directory_path,
		 	nil
		)
		one_back_directory.children = one_back_directory:children_create(view_root_directory)
		one_back_directory:set_is_open(true)
		self.ft.view:load(one_back_directory)
	end
end

function Action:collapse_directory(directory)
	if directory.is_open then
		directory:set_is_open(false)
		self.ft.view:refreshtwo()
	end
end

function Action:expand_directory(directory)
	if not directory.is_open then
		directory:set_is_open(true)
		self.ft.view:refreshtwo()
	end
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
    	local directory = self.ft.view:get_entry_at_cursor()
        return original_function(self, directory)
    end
end

Action.collapse_directory_at_cursor = at_cursor(Action.collapse_directory)
Action.expand_directory_at_cursor = at_cursor(Action.expand_directory)
Action.toggle_directory_at_cursor = at_cursor(Action.toggle_directory)

function Action:cycle_show_mode()
    local current_mode = self.ft.session_settings:get(Settings.OPTIONS.SHOW_MODE)
    local found_current_mode, next_show_mode = false, nil

    -- This logic is very likely radioactive
    for _, value in pairs(Settings.SHOW_MODES) do
    	if found_current_mode then
     		next_show_mode = value 
       		break
	    end
	    if value == current_mode then
      		 found_current_mode = true
	    end
    end

    -- Handle the case where the current mode is the last in the list
    if not next_show_mode then 
	     for _, value in pairs(Settings.SHOW_MODES) do
	  		 next_show_mode = value 
	     	break 
	     end
    end 

    self.ft.session_settings:set(Settings.OPTIONS.SHOW_MODE, next_show_mode)
    self.ft.view:refresh()
end

function Action:load_directory_on_cursor()
	local directory  = self.ft.view:get_entry_at_cursor()
	self.ft.view:load(directory)
end

function Action:toggle_scrollbar()
	self.ft.session_settings:toggle(Settings.OPTIONS.SCROLLBAR)
end

return Action
