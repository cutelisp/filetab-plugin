local config = import('micro/config')
local micro = import('micro')
local buffer = import('micro/buffer')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
local View = dofile(config.ConfigDir .. '/plug/filemanager/view.lua')
local Action = dofile(config.ConfigDir .. '/plug/filemanager/action.lua')
local Config = dofile(config.ConfigDir .. '/plug/filemanager/config.lua')


local Tab = {}
Tab.__index = Tab

function Tab:new(bp, current_directory)
	local instance = setmetatable({}, Tab)
	instance.is_selected = true
	instance.bp = bp
	instance.current_directory = current_directory
	instance.is_open = false
	instance.entry_list = {}
	instance.view = View:new(bp)
	instance.action = Action:new(instance)
	return instance
end

-- Changes the current directory, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Tab:load(directory)
	self.current_directory = directory
	self.entry_list = Entry:get_new_entry_list(directory, nil)
	self.view:refresh(self.entry_list, self.current_directory)
	self.view.virtual:move_cursor_and_select_line(Config.defaultLineOnOpen)
end

-- Set the various display settings, but only on our view (by using SetOptionNative instead of SetOption)
function Tab:setup_settings()
	self:resize(Config.tab.minWith)
	self.bp.Buf:SetOptionNative('scrollbar', Config.scrollBar)
	self.bp.Buf:SetOptionNative('ruler', false)
	self.bp.Buf.Type.Readonly = true
	self.bp.Buf.Type.Scratch = true
	self.bp.Buf:SetOptionNative('softwrap', false)
	self.bp.Buf:SetOptionNative('statusformatr', '')
	self.bp.Buf:SetOptionNative('statusformatl', 'filetab')
	--	self.bp.Buf:SetOptionNative('statusline', false)
	--	self.bp.Buf.Type.Syntax = true
end

-- Set the width of tab to num
function Tab:resize(num)
	self.bp:ResizePane(num)
end

function Tab:close()
	self.bp:Quit()
	self.is_open = false
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
		self:close()
	else
		self:open()
	end
end

function Tab:get_is_selected()
	return micro.CurPane() == self.bp
end

return Tab
