local buffer = import('micro/buffer')

local View = {}
View.__index = View

function View:new(pane)
    local instance = setmetatable({}, View)
    instance.pane = pane
	instance.entry_list = nil
    instance.directory = nil
    instance.cursor_list = {}
    instance.Cursor = self.Cursor:new(instance)
    instance.Highlight = self.Highlight:new(instance)
    return instance
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


function View:refresh(entry_list, directory)
    if entry_list then self:set_entry_list(entry_list) end
    if directory then self:set_directory(directory) end

	local cursor_y = self.Cursor:get_y()
	self:clear()
	self:print_header()
	self:print_entries()	
	self.Cursor:move(cursor_y)
	self.pane:Tab():Resize()-- Resizes all views after messing with ours 	-- todo idk wts this
end

-- Print static header,directory, an ASCII separator, The ".." and use a newline if there are things in the current directory
function View:print_header()--todo
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 0), self.directory .. '\n')
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 1), string.rep('─', self.pane:GetView().Width) .. '\n')-- TODO this \n is probably wrong
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 2), (self.entry_list:size() > 0 and '..\n' or '..'))
end

function View:print_entries()
    self.pane.Buf.EventHandler:Insert(buffer.Loc(0, 3), table.concat(self.entry_list:get_content()))
end

-- Delete everything in the view/buffer
function View:clear()
    self.pane.Buf.EventHandler:Remove(self.pane.Buf:Start(), self.pane.Buf:End())
end

function View:empty_cursor_list()
    self.cursor_list = {}
end

function View:append_cursor_list (num)
    table.insert(self.cursor_list, num)
end

function View:get_cursor_list ()
    if #self.cursor_list == 0 then 
        return {self.Cursor:get_y()}
    end
    return self.cursor_list
end

-- This prevents overdownscrolling
function View:scroll_adjust ()
    self.pane:ScrollAdjust()
end










function View:collapse_directory(line_number, entry)
    local entry = entry and entry or self:get_entry_at_line(line_number or self.Cursor:get_y())
    
    if entry.is_open then
		entry:set_is_open(false)
        self:refresh()
	end
end

function View:expand_directory(line_number, entry)
    local entry = entry or self:get_entry_at_line(line_number or self.Cursor:get_y())

    if not entry.is_open then
        entry:set_is_open(true)
        self:refresh()
    end
end

function View:toggle_directory(line_number)
    local entry = self:get_entry_at_line(line_number or self.Cursor:get_y())

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
        local cursor_list = self:get_cursor_list()
        local reverse = #cursor_list > 1 and cursor_list[1] > cursor_list[2]

        local start, stop, step
        if reverse then
            start, stop, step = 1, #cursor_list, 1
        else
            start, stop, step = #cursor_list, 1, -1
        end

        for i = start, stop, step do
            local cursor = cursor_list[i]
            func(self, cursor, entry)
        end
    end
end

View.expand_directory = execute_multiple_times(View.expand_directory)
View.toggle_directory = execute_multiple_times(View.toggle_directory)
View.collapse_directory = execute_multiple_times(View.collapse_directory)


View.Highlight = {}

function View.Highlight:new(view)
    local self = setmetatable({}, { __index = View.Highlight })
    self.view = view
    return self
end

function View.Highlight:current_line()
   --self.view.pane.Cursor:Relocate()
   --self.view.pane:Center()
   self.view.pane.Cursor:SelectLine()
end

function View.Highlight:down_line()
    self.view.pane:SelectDown()
    self.view.pane:SelectToEndOfLine()
    self.view.pane.Cursor.Loc.X = 0
end

function View.Highlight:up_line()
    self.view.pane:SelectToStartOfLine()
end

function View.Highlight:end_of_line()
    self.view.pane:EndOfLine()
end


View.Cursor = {}

function View.Cursor:new(view)
    local self = setmetatable({}, { __index = View.Cursor })
    self.view = view
    return self
end

function View.Cursor:move(line_number)
    -- Ensure line_number is within valid bounds
    if line_number >= 2 then
        self.view.pane.Cursor.Loc.Y = line_number
    else
        self.view.pane.Cursor.Loc.Y = 2
    end

    self.view.Highlight:current_line()
end

function View.Cursor:move_to_owner()
    current_cursor_y = self:get_y()
    owner = self.view:get_entry_at_line(current_cursor_y).owner
    if owner then 
        owner_line = self.view:get_line_at_entry(owner)
        self:move(owner_line)
    end
end

function View.Cursor:move_to_top()
    self:move(2)
end

function View.Cursor:get_y()
    return self.view.pane.Cursor.Loc.Y
end

function View.Cursor:get_x()
    return self.view.pane.Cursor.Loc.X
end

function View.Cursor:is_in_header()
    return self:get_y() < 3 
end

return View
