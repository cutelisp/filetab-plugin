local buffer = import('micro/buffer')

local INFO = require("info")
local Preferences = require("preferences")
local Settings = require("settings")
local Virtual = require("virtual")
local Utils = require("utils")


---@class View
---@field bp any
---@field settings Settings
---@field path string?
---@field directory any
---@field virtual Virtual
---@field rename_at_cursor_line_num number?
---@field is_root_directory_visible_cache boolean
---@field visual_entry_list []string
local View = {}
View.__index = View

function View:new(bp, settings)
	local instance = setmetatable({}, View)
	instance.bp = bp
	instance.settings = settings
	instance.path = nil
	instance.root_directory = nil 
	instance.is_root_directory_visible_cache = Preferences:get(Preferences.OPTS.SHOW_ROOT_DIRECTORY)
	instance.visual_entry_list = nil
	instance.virtual = Virtual:new(bp)
	return instance
end

function View:load(directory)
	self.root_directory = directory
	self.path = directory.path
	self:print()
	self.virtual:move_cursor_and_select_line(INFO.DEFAULT_LINE_ON_OPEN)
	self.bp:Tab():Resize() -- Resizes all views after messing with ours 	-- todo idk wts this
end

function View:refresh()
	local line_num = self.virtual.cursor:get_line_num()
	self:print()
	self.virtual:move_cursor_and_select_line(line_num)
	self.bp:Tab():Resize()
end

function View:print()
	self.virtual:clear()
	-- HEADER: Print current directory, separator, and ".."
	self.virtual:insert_line(0, self.path .. '\n')
	self.virtual:insert_line(1, string.rep('─', self.bp:GetView().Width) .. '\n')
	self.virtual:insert_line(2, '..\n')

	-- Fetch entries and prepare for display
	local is_root_directory_visible = self:get_is_root_directory_visible()
	local show_mode = self.settings:get(Settings.OPTIONS.SHOW_MODE)
	self.root_directory.children_nested = {}
	local entries = self.root_directory:get_nested_children_content(
		Settings.SHOW_MODES_FILTER[show_mode],
		is_root_directory_visible and 1 or 0
	)
	
	self.visual_entry_list = self.root_directory:get_nested_children()
	
	-- Remove trailing '\n' from the last entry otherwise last line will be a blank line 
	if #entries > 0 then entries[#entries] = entries[#entries]:gsub("\n$", "") end

	local line = 3
	if is_root_directory_visible then 
		self.virtual:insert_line(line, self.root_directory:get_content() .. "\n")
		line = 4
	end
	
	if self.root_directory.is_open then 
		if not self.root_directory:is_empty() then 
			self.virtual:insert_line(line, table.concat(entries))
		elseif Preferences:get(Preferences.OPTS.SHOW_EMPTY_ON_ROOT) then 
			local empty_entry = self.root_directory:get_empty_entry()
			self.virtual:insert_line(line, empty_entry:get_content(1))
			table.insert(visual_entry_list, empty_entry)
		end
	end
end

function View:move_cursor_to_next_dir_outside()--todo has bug
	local current_cursor_line = self.virtual.cursor:get_loc_y()
	local parent = self:get_entry_at_line(current_cursor_line).parent
	if parent then
		local nested_entries = parent:get_entry_list():get_all_nested_entries()
		self.virtual:move_cursor_and_select_line(current_cursor_line + #nested_entries - 1)
	end
end

function View:set_read_only(value)
	self.bp.Buf.Type.Readonly = value
end

function View:set_bp(bp)
	self.bp = bp 
	self.virtual.bp = bp
	self.virtual.cursor.bp = bp
end

-- The entries are nested within entry_lists, so the entry corresponding to a given line number
-- might not be located in self.entry_list at the same index as that line number.
-- This function consolidates all the displayed entries into a single array, ensuring that each
-- displayed entry corresponds to its respective line with an offset of 2 due to the header.
function View:get_entry_at_line(line_number)--todo check if its being claled with ant wo line:number
	if self:get_is_root_directory_visible() and line_number == INFO.ROOT_DIRECTORY_LINE then
		return self.root_directory
	end

	return self.visual_entry_list[line_number - INFO.HEADER_SIZE + 1]
end

function View:get_line_at_entry(entry)
	if self:get_is_root_directory_visible() and
		entry == self.root_directory then
		return INFO.ROOT_DIRECTORY_LINE
	else
	 	for i, each in ipairs(self.visual_entry_list) do
	        if each == entry then
	        	-- minus one because lines start on 0 
	            return i + INFO.HEADER_SIZE - 1
	        end
	    end
	end
	return nil
end

function View:get_parent_line(entry)
	local parent = entry.parent

	if parent == self.root_directory then 
		if self:get_is_root_directory_visible() then 
			return INFO.ROOT_DIRECTORY_LINE
		else
			return nil
		end
	else
		return self:get_line_at_entry(parent)
	end
end

function View:get_entry_at_cursor()
	return self:get_entry_at_line(self.virtual.cursor:get_line_num())
end

function View:get_read_only(value)
	return self.bp.Buf.Type.Readonly
end

function View:get_root_directory()
	return self.root_directory
end

function View:get_is_root_directory_visible()
	return self.is_root_directory_visible_cache
end

return View
