local buffer = import('micro/buffer')
local util = import('micro/util')
local utils = require("utils")
local INFO = require("info")


---@class Virtual
---@field bp any 	
---@field cursor Cursor
---@field selected_lines []number
---@field last_line_interact number?
local Virtual = {}
Virtual.__index = Virtual

function Virtual:new(bp)
    local instance = setmetatable({}, Virtual)
    instance.bp = bp
    instance.cursor = self.Cursor:new(bp)
    instance.selected_lines = {}
    instance.last_line_interact = nil
    return instance
end

function Virtual:click_event()
    self.last_line_interact = self.cursor:get_line_num()
    self.selected_lines = {self.cursor:get_line_num()}
    self.cursor:save_current_loc()
    self.bp:Deselect()
    self.cursor:select_all()
end


function Virtual:was_last_click_on(line_num)
	return self.last_line_interact == line_num
end

function Virtual:was_last_click_doubleclick()
	return self.bp.DoubleClick
end

function Virtual:was_last_click_tripleclick()
	return self.bp.TripleClick
end


function Virtual:was_last_click_on_header()
	return self.last_line_interact < INFO.HEADER_SIZE
end

function Virtual:unselect_all()
   self.bp:Deselect()
end

function Virtual:drag_event()
    local hovered_line = self.cursor:get_loc_y()
    local start_click_line = self.cursor.last_click_loc.Y
    local previous_interacted_line = self.last_line_interact or start_click_line
    local is_up_direction = hovered_line < previous_interacted_line
    local is_hovered_line_selected = self:is_line_selected(hovered_line)
    self.last_line_interact = hovered_line

    if hovered_line == start_click_line then
        self.bp:RemoveAllMultiCursors()
        self.selected_lines = {start_click_line}
        self:refresh()
        return
    end

    if hovered_line == previous_interacted_line then
        self:refresh()
        return
    end

    if is_hovered_line_selected then
        self.bp:RemoveMultiCursor()
        table.remove(self.selected_lines)
    else
        table.insert(self.selected_lines, hovered_line)
        self.cursor:restore_loc()

        self.bp:SpawnMultiCursorUpN(is_up_direction and 1 or -1 )
    end
    self:refresh()
end


function Virtual:insert_line(line_num, content)
    self.bp.Buf.EventHandler:Insert(buffer.Loc(0, line_num), content)
end

function Virtual:clear()
	self.bp.Buf.EventHandler:Remove(self.bp.Buf:Start(), self.bp.Buf:End())
end


function Virtual:backspace()
	self.bp:Backspace()
end

function Virtual:is_line_selected(line_number)
    for _, line in ipairs(self.selected_lines) do
        if line == line_number then
            return true
        end
    end
    return false
end

function Virtual:select_line_on_cursor()
    self.selected_lines = {self.cursor:get_loc().Y}
    self.bp.Cursor:SelectLine()
end

function Virtual:refresh()
    self.cursor:restore_loc()
    self.cursor:select_all()
end

function Virtual:move_cursor_and_select_line(line_num)
	if line_num > self.bp.Buf:LinesNum() - 1 then 
		self:move_cursor_and_select_last_line()
	else
	    self.bp.Cursor.Y = line_num
	    self.bp.Cursor:SelectLine()
	end
end	

function Virtual:move_cursor_and_select_first_line()
	self:move_cursor_and_select_line(INFO.LINE_PREVIOUS_DIRECTORY + 1)
	self:adjust()
end	

function Virtual:move_cursor_and_select_last_line()
	self:move_cursor_and_select_line(self.bp.Buf:LinesNum() - 1)
	self:adjust()
end	

function Virtual:move_cursor(line_num)
        self.selected_lines = {self.cursor:get_line_num()}
        self.bp.Cursor.Y = line_num
end

function Virtual:adjust()
	self.bp:Center()
end

---@class Cursor
---@field bp any 	
---@field cursor_loc_tmp any
---@field last_click_loc any
Virtual.Cursor = {}

function Virtual.Cursor:new(bp)
    local self = setmetatable({}, { __index = Virtual.Cursor })
    self.bp = bp
    self.cursor_loc_tmp = nil
    self.last_click_loc = {}
    self.cycle_index = 1
    self.en_start_position = nil
    self.en_visual_start_position = nil
    self.bounds = {}
    return self
end

function Virtual.Cursor:select_all()
    local cursors = self.bp.Buf:GetCursors()
   -- self:restore_loc()
    for i = 1, #cursors do
        cursors[i]:SelectLine()
    end
end

function Virtual.Cursor:get_line_text()
	return self.bp.Buf:line(self:get_line_num())
end

function Virtual.Cursor:get_line_len()
	return util.CharacterCountInString(self:get_line_text())
end

function Virtual.Cursor:move_to_entry_name_start()
	self:set_loc_x(self.bounds.x_left)
end


function Virtual.Cursor:move_to_entry_name_end()
	self.bp:Deselect()
	self.bp.Cursor:End()
end

function Virtual.Cursor:restore_loc()
    self.bp:Deselect()
    self:set_loc(self.last_click_loc)
end

function Virtual.Cursor:select_range(start_offset, length)
    self:set_loc_x(start_offset)
    for _ = 1, length do
        self.bp:SelectRight()
    end
end

function Virtual.Cursor:get_entry_name()
	return string.sub(self:get_line_text(), self.en_start_position)
end

function Virtual.Cursor:select_entry_name_all()
    self.bp:Deselect()
    self:select_range(self.en_visual_start_position, #self:get_entry_name())
end

function Virtual.Cursor:select_entry_name()
    self.bp:Deselect()
    local dot_location = utils.get_dot_location(self:get_entry_name())
    self:select_range(self.en_visual_start_position, dot_location - 1)
end

function Virtual.Cursor:select_entry_name_extension()
    self.bp:Deselect()
    local dot_location = utils.get_dot_location(self:get_entry_name())
    self:select_range(self.en_visual_start_position + dot_location, #self:get_entry_name() - dot_location)
end

Virtual.Cursor.select_functions = {
 	Virtual.Cursor.select_entry_name,
    Virtual.Cursor.select_entry_name_all,
    Virtual.Cursor.select_entry_name_extension
}

function Virtual.Cursor:cycle_select_entry_name_init(entry_name, has_slash)
	-- Each line contains an entry_name, but the Virtual class does not have direct access to it.
	-- This function takes the entry_name from the current line, (by parameter), and stores its starting position.
	-- For example:
	-- lineText: "  blueAndGreen.php"
	-- entry_name: "blueAndGreen.php"
	-- store: 3
	self.en_start_position = #self:get_line_text() - #entry_name + 1
 	-- The visual position in Micro may differ because a single character can consist of multiple bytes.
	self.en_visual_start_position = self:get_line_len() - #entry_name
	self.bounds = {
		y = self:get_loc_y(),
		x_left = self.en_visual_start_position,
		x_right = function ()
			local line_text = self.bp.Buf:line(self.bounds.y)
			return util.CharacterCountInString(line_text)
		end
	}
	self.cycle_index = 1
	if has_slash then
		self.bp:Deselect()
		--self:unselect_all()
		self:set_loc_x(self.bounds.x_right())
		self.bp:Backspace()
	end

end

function Virtual.Cursor:cycle_select_entry_name()
   	if utils.has_dot(self:get_entry_name()) then 
	    local func = Virtual.Cursor.select_functions[self.cycle_index]
	    func(self)
	else
		self:select_entry_name_all()
		self.cycle_index = 2
	end
	
	-- This assures cursor is inside entry's name bounds
	self:set_loc_x(self.en_visual_start_position +1)
	
	self.cycle_index = self.cycle_index % #Virtual.Cursor.select_functions + 1

end

function Virtual.Cursor:save_current_loc()
    --self.cursor_loc_tmp = self.bp.Cursor.Loc seems to pass a reference not a value
    self.last_click_loc.X = self.bp.Cursor.Loc.X
    self.last_click_loc.Y = self.bp.Cursor.Loc.Y
end

function Virtual.Cursor:adjust()
	if self:get_loc_y() < self.bounds.y then
		self:set_loc_x(self.bounds.x_left)
		self:set_loc_y(self.bounds.y)
		return 
	elseif self:get_loc_y() > self.bounds.y then
		self:set_loc_x(self.bounds:x_right())
		self:set_loc_y(self.bounds.y)
		return
	end

	if self:get_loc_x() < self.bounds.x_left then
		self:set_loc_x(self.bounds.x_left)
	elseif self:get_loc_x() > self.bounds:x_right() then
		self:set_loc_x(self.bounds:x_right())
	end
end

function Virtual.Cursor:get_can_move_right()
    return self:get_loc_x() < self.bounds:x_right()
end

function Virtual.Cursor:get_can_move_left()
    return self:get_loc_x() > self.bounds.x_left
end

function Virtual.Cursor:get_loc()
    return self.bp.Cursor.Loc
end

function Virtual.Cursor:get_loc_x()
    return self.bp.Cursor.Loc.X
end

function Virtual.Cursor:get_loc_y()
    return self.bp.Cursor.Loc.Y
end

function Virtual.Cursor:get_line_num()
    return self.bp.Cursor.Loc.Y
end

function Virtual.Cursor:set_loc(loc)
    self.bp.Cursor.Loc = loc
end

function Virtual.Cursor:is_on_header()
	return self:get_line_num() <= 4
end

function Virtual.Cursor:set_loc_x(loc_x)
    self.bp.Cursor.Loc.X = loc_x
end

function Virtual.Cursor:set_loc_y(loc_y)
    self.bp.Cursor.Loc.Y = loc_y
end

function Virtual.Cursor:ser_loc_zero_zero()
    self:set_loc({X = 0, Y = 0})
end

return Virtual