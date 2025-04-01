local config = import('micro/config')
local micro = import('micro')
local os = import('os')
local golib_ioutil = import('ioutil')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local buffer = import('micro/buffer')
local filepath = import('path/filepath')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
local View = dofile(config.ConfigDir .. '/plug/filemanager/view.lua')
local Entry_list = dofile(config.ConfigDir .. '/plug/filemanager/entry_list.lua')
local Action = dofile(config.ConfigDir .. '/plug/filemanager/action.lua')


local Tab = {}
Tab.__index = Tab

-- Return a new object used when adding to scanlist
function Tab:new(pane, current_directory)
    local instance = setmetatable({}, Tab)
	instance.is_selected = true
    instance.curPane = pane
    instance.min_width = 30
    instance.current_directory = current_directory
    instance.is_open = false
    instance.entry_list = {}
	instance.view = View:new(pane)
    instance.action = Action:new(pane)

    return instance
end

function Tab:enter_key_pressed()
	self.view:toggle_directory()
end

-- Changes the current directory, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Tab:load(directory)
	self.current_dir = directory
	self.entry_list = Entry_list:new(directory, 0, 0)
	self.view:refresh(self.entry_list, self.current_directory)
	self.view:move_cursor_top()
end

-- (Tries to) go load one "step" from the current directory
function Tab:load_back_directory()
	-- Use Micro's dirname to get everything but the current dir's path
	local one_back_dir = filepath.Dir(self.current_directory)
	-- Try opening, assuming they aren't at "root", by checking if it matches last dir
	if one_back_dir ~= self.current_directory then
		self:load(one_back_dir)
	end
end

-- Set the various display settings, but only on our view (by using SetOptionNative instead of SetOption)
function Tab:setup_settings()
    -- Set the width of tree_view to 30% & lock it
    self:resize(self.min_width)
    -- tree_view.Buf.Type = buffer.BTLog
    -- Set the type to unsavable
    self.curPane.Buf.Type.Scratch = true
    self.curPane.Buf.Type.Readonly = true
    -- Softwrap long strings (the file/dir paths)
    self.curPane.Buf:SetOptionNative('softwrap', false)
    -- No line numbering
    self.curPane.Buf:SetOptionNative('ruler', false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    self.curPane.Buf:SetOptionNative('autosave', false)
    -- Don't show the statusline to differentiate the view from normal views
    self.curPane.Buf:SetOptionNative('statusformatr', '')
    self.curPane.Buf:SetOptionNative('statusformatl', 'filetab')
    self.curPane.Buf:SetOptionNative('scrollbar', false)
end

-- Set the width of tab to num & lock it
function Tab:resize(num)
    if num < self.min_width then
        self.curPane:ResizePane(self.min_width)
    else
        self.curPane:ResizePane(num)
    end
end

-- close_tree will close the tree plugin view and release memory.
function Tab:close()
	if self.curPane ~= nil then
        self.curPane:Quit()
        self.is_open = false
	end
end

-- open_tree setup's the view
function Tab:open()
	-- Open a new Vsplit (on the very left)
	micro.CurPane():VSplitIndex(buffer.NewBuffer('', ''), true)
	self.is_open = true
	self:setup_settings()
	self:load(self.current_directory)
end

-- toggle_tree will toggle the tree view visible (create) and hide (delete).
function Tab:toggle()
	if self.is_open then
		self.close()
	else
		self:open()
	end
end


-- toggle_tree will toggle the tree view visible (create) and hide (delete).
function Tab:get_is_selected()
	return self.is_selected
end
return Tab