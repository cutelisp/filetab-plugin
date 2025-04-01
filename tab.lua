local config = import('micro/config')
local micro = import('micro')
local buffer = import('micro/buffer')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
local View = dofile(config.ConfigDir .. '/plug/filemanager/view.lua')
local Entry_list = dofile(config.ConfigDir .. '/plug/filemanager/entry_list.lua')
local Action = dofile(config.ConfigDir .. '/plug/filemanager/action.lua')


local Tab = {}
Tab.__index = Tab

function Tab:new(pane, current_directory)
    local instance = setmetatable({}, Tab)
	instance.is_selected = true
    instance.pane = pane
    instance.min_width = 30
    instance.current_directory = current_directory
    instance.is_open = false
    instance.entry_list = {}
	instance.view = View:new(pane)
    instance.action = Action:new(instance)
    return instance
end

-- Changes the current directory, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Tab:load(directory)
	self.current_directory = directory
	self.entry_list = Entry:get_new_entry_list(directory, nil)
	self.view:refresh(self.entry_list, self.current_directory)
	self.view:move_cursor_top()
end

-- Set the various display settings, but only on our view (by using SetOptionNative instead of SetOption)
function Tab:setup_settings()
    -- Set the width of tree_view to 30% & lock it
    self:resize(self.min_width)
    -- tree_view.Buf.Type = buffer.BTLog
    -- Set the type to unsavable
    self.pane.Buf.Type.Scratch = true
    self.pane.Buf.Type.Readonly = true
    -- Softwrap long strings (the file/dir paths)
    self.pane.Buf:SetOptionNative('softwrap', false)
    -- No line numbering
    self.pane.Buf:SetOptionNative('ruler', false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    self.pane.Buf:SetOptionNative('autosave', false)
    -- Don't show the statusline to differentiate the view from normal views
    self.pane.Buf:SetOptionNative('statusformatr', '')
    self.pane.Buf:SetOptionNative('statusformatl', 'filetab')
    self.pane.Buf:SetOptionNative('scrollbar', false)
end

-- Set the width of tab to num 
function Tab:resize(num)
    if num < self.min_width then
        self.pane:ResizePane(self.min_width)
    else
        self.pane:ResizePane(num)
    end
end

function Tab:close()
	if self.pane ~= nil then
        self.pane:Quit()
        self.is_open = false
	end
end

function Tab:open()
	-- Open a new Vsplit (on the very left)
	micro.CurPane():VSplitIndex(buffer.NewBuffer('', ''), true)
	self.is_open = true
	self:setup_settings()
	self:load(self.current_directory)
end

function Tab:toggle()
	if self.is_open then
		self.close()
	else
		self:open()
	end
end

function Tab:get_is_selected()
	return micro.CurPane() == self.pane
end

return Tab