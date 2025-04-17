local buffer = import('micro/buffer')
local micro = import('micro')
local config = import('micro/config')
local golib_os = import('os')

---@module "utils"
local utils = dofile(config.ConfigDir .. '/plug/filetab/src/utils.lua')
---@module "entry"
local Entry = utils.import("entry")
---@module "info"
local INFO = utils.import("info")
---@module "preferences"
local Preferences = utils.import("preferences")
---@module "settings"
local Settings = utils.import("settings")
---@module "virtual"
local Virtual = utils.import("virtual")


---@class View
---@field bp bp 	
---@field settings Settings
---@field path string?
---@field directory any
---@field virtual Virtual
---@field rename_at_cursor_line_num number?
local View = {}
View.__index = View

function View:new(bp, settings)
	local instance = setmetatable({}, View)
	instance.bp = bp
	instance.settings = settings
	instance.path = nil
	instance.root_directory = nil 
	instance.virtual = Virtual:new(bp)
	instance.rename_at_cursor_line_num = nil
	return instance
end

function View:load(path, directory)
	self.path = path
	self.root_directory = directory

	self:clear()
	self:print_header()
	if self.root_directory.is_open then
		self:print_entries()
	end
	self.virtual:move_cursor_and_select_line(INFO.DEFAULT_LINE_ON_OPEN)
	self.bp:Tab():Resize() -- Resizes all views after messing with ours 	-- todo idk wts this
end

function View:refreshtwo(path, directory)

	local line_num = self.virtual.cursor:get_line_num()
	self:clear()
	self:print_header()
	if self.root_directory.is_open then 
		self:print_entries()
	end
--	self.virtual:refresh()
	self.virtual:move_cursor_and_select_line(line_num)
	self.bp:Tab():Resize() -- Resizes all views after messing with ours 	-- todo idk wts this
end

function View:refresh(path, directory)
	if path then self.path = path end
	if directory then self.root_directory = directory end

	local line_num = self.virtual.cursor:get_line_num()
	self:clear()
	self:print_header()
	if self.root_directory.is_open then 
		self:print_entries()

		end
	self.virtual:refresh()
	self.virtual:move_cursor_and_select_line(line_num)
	self.bp:Tab():Resize() -- Resizes all views after messing with ours 	-- todo idk wts this
end

-- Print static header,directory, an ASCII separator, The ".." and use a newline if there are things in the current directory
function View:print_header() --todo
	self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 0), self.path .. '\n')
	self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 1), string.rep('─', self.bp:GetView().Width) .. '\n') -- TODO this \n is probably wrong
	self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 2), '..\n')
	if Preferences:get(Preferences.OPTIONS.SHOW_ROOT_DIRECTORY) then 
		self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 3),self.root_directory:get_content() .. "\n")
	end 
end

function View:print_entries()
	local show_mode = self.settings:get(Settings.OPTIONS.SHOW_MODE)
	local show_root_directory = Preferences:get(Preferences.OPTIONS.SHOW_ROOT_DIRECTORY)
	
	local entries = self.root_directory:get_children_content(Settings.SHOW_MODES_FILTER[show_mode], show_root_directory and 1 or 0)
	-- Delete the last \n, otherwise it will create a blank line on bottom 
	entries[#entries] = entries[#entries]:gsub("\n$", "")

	if show_root_directory then 
		self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 4), table.concat(entries))
	else
		self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 3), table.concat(entries))
	end 
end

-- Delete everything in the view/buffer
function View:clear()
	self.bp.Buf.EventHandler:Remove(self.bp.Buf:Start(), self.bp.Buf:End())
end

function View:collapse_directory(directory)
	if directory.is_open then
		directory:set_is_open(false)
		self:refreshtwo()
	end
end

function View:expand_directory(directory)
	if not directory.is_open then
		directory:set_is_open(true)
		self:refreshtwo()
	end
end

function View:toggle_directory(directory)
	if directory.is_open then
		self:collapse_directory(directory)
	else
		self:expand_directory(directory)
	end
end

-- Executes the function once for each cursor.
-- Always executes from the highest line to the lowest. If the cursor_list is in ascending order, it scans in reverse.
local function execute_multiple_times(func)
	return function(self, line_number, entry)
		local cursor_list = self.virtual.selected_lines
		local reverse = #cursor_list > 1 and cursor_list[1] > cursor_list[2]

		local start, stop, step
		if reverse then
			start, stop, step = 1, #cursor_list, 1
		else
			start, stop, step = #cursor_list, 1, -1
		end

		for i = start, stop, step do
			func(self, cursor_list[i], entry)
		end
	end
end

--View.expand_directory = execute_multiple_times(View.expand_directory)
--View.toggle_directory = execute_multiple_times(View.toggle_directory)
--View.collapse_directory = execute_multiple_times(View.collapse_directory)

function View:move_cursor_to_parent()
	local parent = self:get_entry_at_cursor().parent
	local parent_line = self:get_line_at_entry(parent)

	if parent_line then
		self.virtual:move_cursor_and_select_line(parent_line)
		self.virtual:adjust()--maybe change adjust to move_cursor_and_select
	end
end

function View:move_cursor_to_first_sibling()
	local parent = self:get_entry_at_cursor().parent
	local parent_line = self:get_line_at_entry(parent)

	self.virtual:move_cursor_and_select_line(parent_line + 1)
--	self.virtual:adjust() --todo make the adjust only ata certan range
end

function View:move_cursor_to_last_sibling()
	local parent = self:get_entry_at_cursor().parent
	local parent_line = self:get_line_at_entry(parent)

	self.virtual:move_cursor_and_select_line(parent_line + parent:len())
	self.virtual:adjust() --todo make the adjust only ata certan range
end

function View:move_cursor_to_entry(entry)
	local entry_line = self:get_line_at_entry(entry)
	self.virtual:move_cursor_and_select_line(entry_line)
end

function View:move_cursor_to_next_dir_outside()--todo has bug
	local current_cursor_line = self.virtual.cursor:get_loc_y()
	local parent = self:get_entry_at_line(current_cursor_line).parent
	if parent then
		local nested_entries = parent:get_entry_list():get_all_nested_entries()
		self.virtual:move_cursor_and_select_line(current_cursor_line + #nested_entries - 1)
	end
end

function View:pre_rename_at_cursor()
	local current_cursor_line = self.virtual.cursor:get_line_num()
	self.rename_at_cursor_line_num = current_cursor_line
	self.virtual.cursor:select_file_name_no_extension()
	self:set_read_only(false)
end

function View:rename_at_cursor()
	local entry = self:get_entry_at_line(self.rename_at_cursor_line_num)
	self.rename_at_cursor_line_num = nil
	local old_path = entry.abs_path
	local line_text = utils.get_content(self.virtual.cursor:get_line_text())
	local new_path = utils.dirname_and_join(old_path, line_text)

	entry:set_file_name(line_text)
	local log = golib_os.Rename(old_path, new_path)

	self:set_read_only(true)
	-- Output the log, if any, of the rename
	if log then 	micro.Log('Rename log: ', log) end
end

function View:is_action_happening()
	return self:is_rename_at_cursor_happening()
end

function View:is_rename_at_cursor_happening()
	return self.rename_at_cursor_line_num and true or false
end

-- The entries are nested within entry_lists, so the entry corresponding to a given line number
-- might not be located in self.entry_list at the same index as that line number.
-- This function consolidates all the displayed entries into a single array, ensuring that each
-- displayed entry corresponds to its respective line with an offset of 2 due to the header.
function View:get_entry_at_line(line_number)--todo check if its being claled with ant wo line:number
	if Preferences:get(Preferences.OPTIONS.SHOW_ROOT_DIRECTORY) and
		line_number == INFO.ROOT_DIRECTORY_LINE then
		return self.root_directory
	end
	local all_entries = self.root_directory:get_nested_children()
	local ln = line_number or self.virtual.cursor:get_line_num()
	return all_entries[ln - INFO.HEADER_SIZE + 1]
end

function View:get_entry_at_cursor()
	return self:get_entry_at_line(self.virtual.cursor:get_line_num())
end

function View:get_read_only(value)
	return self.bp.Buf.Type.Readonly
end

function View:get_line_at_entry(entry)
	local all_entries = self.root_directory:get_nested_children()
	
	if Preferences:get(Preferences.OPTIONS.SHOW_ROOT_DIRECTORY) and
		entry == self.root_directory then
		return INFO.ROOT_DIRECTORY_LINE
	end
 	for i, each in ipairs(all_entries) do
        if each == entry then
        	-- minus one because lines start on 0 
            return i + INFO.HEADER_SIZE - 1
        end
    end
	return nil
end

function View:set_read_only(value)
	self.bp.Buf.Type.Readonly = value
end

function View:get_root_directory()
	return self.root_directory
end

return View
