local micro = import('micro')

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
    self.selected_lines = {self.cursor:get_loc().Y}
    self.cursor:save_current_loc()
    self.bp:Deselect()
    --self.cursor:ser_loc_zero_zero()
    self.cursor:select_all()
   -- self.cursor:ser_loc_zero_zero()
end

function Virtual:unselect_all()
   self.bp:Deselect()
end

function Virtual:drag_event()
    local hovered_line = self.cursor:get_loc().Y
    local start_click_line = self.cursor.last_click_loc.Y 
    local previous_interacted_line = self.last_line_interact or start_click_line
    local is_up_direction = hovered_line < previous_interacted_line
    local is_hovered_line_selected = self:is_line_selected(hovered_line)
    self.last_line_interact = hovered_line
 --   micro.InfoBar():Error(self.selected_lines)

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

function Virtual:rr()
 --   self.bp.Cursor.Loc.Y = 0
 self.bp:Deselect()
    self.cursor:ser_loc_zero_zero()

-- self:move_cursor_and_select_line(5)
    self.bp:SpawnMultiCursorUpN(-1)
    self.bp:SpawnMultiCursorUpN(-1)
    self.cursor:select_all()

    --for i = 1, #cursors do
 --       cursors[i]:SelectLine()
 --   end
end


function Virtual:refresh()
    self.cursor:restore_loc()
    self.cursor:select_all()
end

function Virtual:move_cursor_and_select_line(line_num)
--    self.selected_lines = {self.cursor:get_loc().Y}
    self.bp.Cursor.Y = line_num
    self.bp.Cursor:SelectLine()
end

function Virtual:move_cursor(line_num)
        self.selected_lines = {self.cursor:get_loc().Y}
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

function Virtual.Cursor:restore_loc()
    self.bp:Deselect()
    self:set_loc(self.last_click_loc)
end

function Virtual.Cursor:save_current_loc()
    --self.cursor_loc_tmp = self.bp.Cursor.Loc seems to pass a reference not a value
    self.last_click_loc.X = self.bp.Cursor.Loc.X
    self.last_click_loc.Y = self.bp.Cursor.Loc.Y
end

function Virtual.Cursor:get_loc()
    return self.bp.Cursor.Loc
end

function Virtual.Cursor:set_loc(loc)
    self.bp.Cursor.Loc = loc
end

function Virtual.Cursor:ser_loc_zero_zero()
    self:set_loc({X = 0, Y = 0})
end

return Virtual