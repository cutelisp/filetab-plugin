local config = import('micro/config')
local micro = import('micro')
local os = import('os')
local golib_ioutil = import('ioutil')
local buffer = import('micro/buffer')
local filepath = import('path/filepath')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
local Entry_list = dofile(config.ConfigDir .. '/plug/filemanager/entry_list.lua')


local View = {}
View.__index = View

-- Return a new object used when adding to scanlist
function View:new(pane)
    local instance = setmetatable({}, View)
    instance.pane = pane
	instance.entry_list = nil
    instance.directory = nil
    return instance
end

function View:refresh(entry_list, directory)
    if entry_list then self:set_entry_list(entry_list) end
    if directory then self:set_directory(directory) end

	local cursor_y = self:get_cursor_y()
	self:clear()
	self:print_header()
	self:print_entries()	
	self:move_cursor(cursor_y)
	self.pane:Tab():Resize()-- Resizes all views after messing with ours 	-- todo idk wts this
end

-- Print static header,directory, an ASCII separator, The ".." and use a newline if there are things in the current directory
function View:print_header()--todo
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 0), self.directory .. '\n')
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 1), utils.repeat_str('─', self.pane:GetView().Width) .. '\n') -- TODO this \n is probably wrong
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 2), (self.entry_list:size() > 0 and '..\n' or '..'))
end

function View:print_entries()
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 3), table.concat(self.entry_list:get_content()))---table.concat(lines)
end

-- Delete everything in the view/buffer
function View:clear()
    self.pane.Buf.EventHandler:Remove(self.pane.Buf:Start(), self.pane.Buf:End())
end

function View:collapse_directory(line_number, entry)
    local entry = entry and entry or self:get_entry_at_line(line_number or self:get_cursor_y())
    
    if entry.is_open then
		entry:set_is_open(false)
        self:refresh()
	end
end

function View:expand_directory(line_number, entry)
    local entry = entry or self:get_entry_at_line(line_number or self:get_cursor_y())

    if not entry.is_open then
        if not entry:get_entry_list() then
            entry_list = Entry_list:new(entry.abs_path, 0,0)
            entry:set_entry_list(entry_list)
	    end
        entry:set_is_open(true)
        self:refresh()
    end
end

function View:toggle_directory(line_number)
    local entry = self:get_entry_at_line(line_number or self:get_cursor_y())

    if entry.is_open then
        self:collapse_directory(_, entry)
    else
        self:expand_directory(_, entry)
    end

end

-- Highlights the line when you move the cursor up/down
function View:move_cursor(line_number) -- todo no one is calling this
    -- Ensure line_number is within valid bounds
    if line_number >= 2 then
        self.pane.Cursor.Loc.Y = line_number
    else
        self.pane.Cursor.Loc.Y = 2
    end

    self:highlight_current_line()
end

-- Highlights the line of cursor
function View:highlight_current_line() -- todo no one is calling this
    -- Puts the cursor back in bounds (if it isn't) for safety
    self.pane.Cursor:Relocate()
    self.pane:Center()
    self.pane.Cursor:SelectLine()
end



-- Moves the cursor to the ".." in tree_view (2 because ".." it's on 3rd line)
function View:move_cursor_top()
	self:move_cursor(2)
end

function View:get_cursor_y()
	return self.pane.Cursor.Loc.Y
end

-- The entries are nested within entry_lists, so the entry corresponding to a given line number
-- might not be located in self.entry_list at the same index as that line number.
-- This function consolidates all the displayed entries into a single array, ensuring that each
-- displayed entry corresponds to its respective line with an offset of 2 due to the header.
function View:get_entry_at_line(line_number)
    local all_entries = self.entry_list:get_all_nested_entries()
	return all_entries[line_number - 2]
end

function View:set_entry_list(entry_list)
    self.entry_list = entry_list
end

function View:set_directory(directory)
    self.directory = directory
end

return View
