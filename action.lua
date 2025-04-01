local config = import('micro/config')
local micro = import('micro')
local os = import('os')
local golib_ioutil = import('ioutil')
local buffer = import('micro/buffer')



local Action = {}
Action.__index = Action

-- Return a new object used when adding to scanlist
function Action:new(pane)
    local instance = setmetatable({}, Action)
    instance.pane = pane
    return instance
end

function Action:cursor_move_up()
  --  self.pane.Cursor:Up()
    --self:highlight_current_line()
end

function Action:cursor_move_down()
   -- self.pane.Cursor:Down()
    self:highlight_current_line()
end

-- Highlights the line of cursor
function Action:highlight_current_line() -- todo no one is calling this
    -- Puts the cursor back in bounds (if it isn't) for safety
    self.pane.Cursor:Relocate()
    self.pane:Center()
    self.pane.Cursor:SelectLine()
end

return Action
