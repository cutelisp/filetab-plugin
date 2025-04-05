local buffer = import('micro/buffer')
local micro = import('micro')
local config = import('micro/config')
local Virtual = dofile(config.ConfigDir .. '/plug/filemanager/virtualcursor.lua')

local View = {}
View.__index = View

function View:new(bp)
	local instance = setmetatable({}, View)
	instance.bp = bp
	instance.entry_list = nil
	instance.directory = nil
	instance.virtual = Virtual:new(bp)
	return instance
end

function View:refresh(entry_list, directory)
	if entry_list then self:set_entry_list(entry_list) end
	if directory then self:set_directory(directory) end

	local cursor_y = self.virtual.cursor:get_loc().Y
	self:clear()
	self:print_header()
	self:print_entries()
	micro.InfoBar():Error(self.virtual.selected_lines)
	self.virtual:refresh()
	self.virtual:rr()

	self.bp:Tab():Resize() -- Resizes all views after messing with ours 	-- todo idk wts this
end

-- Print static header,directory, an ASCII separator, The ".." and use a newline if there are things in the current directory
function View:print_header() --todo
	self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 0), self.directory .. '\n')
	self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 1), string.rep('─', self.bp:GetView().Width) .. '\n') -- TODO this \n is probably wrong
	self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 2), (self.entry_list:size() > 0 and '..\n' or '..'))
end

function View:print_entries()
	self.bp.Buf.EventHandler:Insert(buffer.Loc(0, 3), table.concat(self.entry_list:get_content()))
end

-- Delete everything in the view/buffer
function View:clear()
	self.bp.Buf.EventHandler:Remove(self.bp.Buf:Start(), self.bp.Buf:End())
end

function View:collapse_directory(line_number, entry)
	local entry = entry or self:get_entry_at_line(line_number)

	if entry.is_open then
		entry:set_is_open(false)
		self:refresh()
	end
end

function View:expand_directory(line_number, entry)
	local entry = entry or self:get_entry_at_line(line_number)

	if not entry.is_open then
		entry:set_is_open(true)
		self:refresh()
	end
end

function View:toggle_directory(line_number)
	local entry = self:get_entry_at_line(line_number or self.virtual.cursor:get_loc().Y)

	if entry.is_open then
		self:collapse_directory(_, entry)
	else
		self:expand_directory(_, entry)
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

View.expand_directory = execute_multiple_times(View.expand_directory)
View.toggle_directory = execute_multiple_times(View.toggle_directory)
View.collapse_directory = execute_multiple_times(View.collapse_directory)

function View:move_cursor_to_owner()
	local current_cursor_y = self.virtual.cursor:get_loc().Y
	local owner = self:get_entry_at_line(current_cursor_y).owner
	if owner then
		local owner_line = self:get_line_at_entry(owner)
		self.virtual:move_cursor_and_select_line(owner_line)
	end
end

-- The entries are nested within entry_lists, so the entry corresponding to a given line number
-- might not be located in self.entry_list at the same index as that line number.
-- This function consolidates all the displayed entries into a single array, ensuring that each
-- displayed entry corresponds to its respective line with an offset of 2 due to the header.
function View:get_entry_at_line(line_number)
	local all_entries = self.entry_list:get_all_nested_entries()
	return all_entries[line_number - 2]
end

function View:get_line_at_entry(entry)
	local all_entries = self.entry_list:get_all_nested_entries()

	for i = 1, #all_entries do
		if all_entries[i] == entry then
			return i + 2
		end
	end
	return nil
end

function View:set_entry_list(entry_list)
	self.entry_list = entry_list
end

function View:set_directory(directory)
	self.directory = directory
end

return View
