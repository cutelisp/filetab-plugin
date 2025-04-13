local micro = import('micro')
local config = import('micro/config')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')


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
    self.last_line_interact = nil
    self.selected_lines = {self.cursor:get_line_num()}
    self.cursor:save_current_loc()
    self.bp:Deselect()
    self.cursor:select_all()
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
    self.bp.Cursor.Y = line_num
    self.bp.Cursor:SelectLine()
end

function Virtual:move_cursor(line_num)
        self.selected_lines = {self.cursor:get_line_num()}
        self.bp.Cursor.Y = line_num
end

Virtual.Cursor = {}

function Virtual.Cursor:new(bp)
    local self = setmetatable({}, { __index = Virtual.Cursor })
    self.bp = bp
    self.cursor_loc_tmp = nil
    self.last_click_loc = {}
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

function Virtual.Cursor:get_line_text_len()
	return #self.bp.Buf:line(self:get_line_num()) + 3
end

function Virtual.Cursor:move_to_file_name_start()
	local line_string = self:get_line_text()
	local first_char_loc = utils.first_char_loc(line_string)
	self.bp:Deselect()
	self:set_loc_x(first_char_loc)
end

function Virtual.Cursor:move_to_end()
	self.bp:Deselect()
	self.bp.Cursor:End()
end

-- Moves the cursor to the first character of file_name, 
-- Selects everything to end of the line
function Virtual.Cursor:select_file_name()
	self:move_to_file_name_start()
	self.bp:SelectToEndOfLine()
end

-- Selects the entire file name, if it's an extension file
-- unselect till the first dot 
function Virtual.Cursor:select_file_name_no_extension()
	self:select_file_name()
	local line_string = self:get_line_text()
	local dot_loc = utils.get_dot_location(line_string)

	if dot_loc then
		for i = 1, #line_string - dot_loc + 1 do
      		self.bp:SelectLeft()
  		end
	end
	-- Prevent the cursor escape out of bounds
	self:set_loc_x(dot_loc - 1)--todo bug here
end

function Virtual.Cursor:restore_loc()
    self.bp:Deselect()
    self:set_loc(self.last_click_loc)
end

function Virtual.Cursor:adjust()
	local first_char_loc = utils.first_char_loc(self:get_line_text())
	if self:get_loc_x() < first_char_loc then
		self:set_loc_x(first_char_loc)
	end
end


function Virtual.Cursor:save_current_loc()
    --self.cursor_loc_tmp = self.bp.Cursor.Loc seems to pass a reference not a value
    self.last_click_loc.X = self.bp.Cursor.Loc.X
    self.last_click_loc.Y = self.bp.Cursor.Loc.Y
end



function Virtual.Cursor:get_can_move_right()
	-- -3 because line text has an icon which has more than 1 byte
	local current_line_len = #self:get_line_text() - 3
    return self:get_loc_x() < current_line_len
end
function Virtual.Cursor:get_can_move_left()
    return self:get_loc_x() > utils.first_char_loc(self:get_line_text())
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

function Virtual.Cursor:set_loc_x(loc_x)
    self.bp.Cursor.Loc.X = loc_x
end

function Virtual.Cursor:ser_loc_zero_zero()
    self:set_loc({X = 0, Y = 0})
end

return Virtual