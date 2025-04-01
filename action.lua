local config = import('micro/config')
local micro = import('micro')
local os = import('os')
local golib_ioutil = import('ioutil')
local buffer = import('micro/buffer')
local filepath = import('path/filepath')


local Action = {}
Action.__index = Action

-- Return a new object used when adding to scanlist
function Action:new(tab)
    local instance = setmetatable({}, Action)
    instance.tab = tab
    return instance
end

function Action:cursor_move_down()
   -- self.pane.Cursor:Down()
    self:highlight_current_line()
end

-- (Tries to) go load one "step" from the current directory
function Action:load_back_directory()
    local current_dir = self.tab.current_directory
	local one_back_directory = filepath.Dir(current_dir)
	-- Try opening, assuming they aren't at "root", by checking if it matches last dir
	if one_back_directory ~= current_dir then
	    self.tab:load(one_back_directory)
	end
end


return Action
