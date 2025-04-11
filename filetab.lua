local config = import('micro/config')
local micro = import('micro')
local filepath = import('path/filepath')
local buffer = import('micro/buffer')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
local View = dofile(config.ConfigDir .. '/plug/filemanager/view.lua')
local Settings = dofile(config.ConfigDir .. '/plug/filemanager/settings.lua')


local Filetab = {}
Filetab.__index = Filetab

function Filetab:new(bp, current_directory)
	local instance = setmetatable({}, Filetab)
	instance.is_selected = true
	instance.bp = bp
	instance.current_directory = current_directory
	instance.is_open = false
	instance.entry_list = {}
	instance.view = View:new(bp)
	return instance
end

-- Changes the current directory, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Filetab:load(directory)
	self.current_directory = directory
	self.entry_list = Entry:get_new_entry_list(directory, nil)
	self.view:refresh(self.entry_list, self.current_directory)
	self.view.virtual:move_cursor_and_select_line(Settings.Const.defaultLineOnOpen)
end

-- (Tries to) go load one "step" from the current directory
function Filetab:load_back_directory()
	local current_dir = self.current_directory
	local one_back_directory = filepath.Dir(current_dir)
	-- Try opening, assuming they aren't at "root", by checking if it matches last dir
	if one_back_directory ~= current_dir then
		self:load(one_back_directory)
	end
end

-- Set the various display settings, but only on our view (by using SetOptionNative instead of SetOption)
function Filetab:setup_settings()
	self:resize(Settings.Const.minWidth)
	self.bp.Buf:SetOptionNative('scrollbar', Settings.get_option("scrollbar"))
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
function Filetab:resize(num)
	self.bp:ResizePane(num)
end

function Filetab:close()
	self.bp:Quit()
	self.is_open = false
end

function Filetab:open()
	-- Open a new Vsplit (on the very left)
	self.bp:VSplitIndex(buffer.NewBuffer('', ''), true)
	self.is_open = true
	self:setup_settings()
	self:load(self.current_directory)
end

function Filetab:toggle()
	if self.is_open then
		self:close()
	else
		self:open()
	end
end

function Filetab:get_tab()
	return self.bp:Tab()
end

function Filetab:get_is_selected()
	return micro.CurPane() == self.bp
end

return Filetab
