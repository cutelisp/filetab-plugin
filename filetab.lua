local config = import('micro/config')
local micro = import('micro')
local filepath = import('path/filepath')
local buffer = import('micro/buffer')
---@module "view"
local View = dofile(config.ConfigDir .. '/plug/filemanager/view.lua')
---@module "directory"
local Directory = dofile(config.ConfigDir .. '/plug/filemanager/directory.lua')
---@module "settings"
local Settings = dofile(config.ConfigDir .. '/plug/filemanager/settings.lua')
local INFO = dofile(config.ConfigDir .. '/plug/filemanager/info.lua')
---@module "preferences"
local Preferences = dofile(config.ConfigDir .. '/plug/filemanager/preferences.lua')


local Filetab = {}
Filetab.__index = Filetab

function Filetab:new(bp, current_path)
	local instance = setmetatable({}, Filetab)
	instance.is_selected = true
	instance.bp = bp
	instance.current_path = current_path
	instance.is_open = false
	instance.session_settings = Settings:new(bp)
	instance.view = View:new(bp, instance.session_settings)
	instance.a = true
	return instance
end

-- Changes the current directory, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Filetab:load(path)
	self.current_path = path

	local root = Directory:new(filepath.Base(path), path, nil, self.session_settings:get(Settings.OPTIONS.SHOW_DOTFILES))	
	root.children = root:children_create()

	self.view:refresh(self.current_path, root)
	self.view.virtual:move_cursor_and_select_line(INFO.DEFAULT_LINE_ON_OPEN)
end

-- (Tries to) go load one "step" from the current directory
function Filetab:load_back_directory()
	local current_path = self.current_path
	local one_back_directory = filepath.Dir(current_path)
	-- Try opening, assuming they aren't at "root", by checking if it matches last dir
	if one_back_directory ~= current_path then
		self:load(one_back_directory)
	end
end

function Filetab:toggle_scrollbar()
	self.session_settings:toggle(Settings.OPTIONS.SCROLLBAR)
end

function Filetab:toggle_show_dotfiles()
	self.session_settings:toggle(Settings.OPTIONS.SHOW_DOTFILES)
end

function Filetab:cycle_show_mode()
	if self.a then 
		self.session_settings:set(Settings.OPTIONS.SHOW_MODE, Settings.SHOW_MODES.IGNORE_DOTFILES)
		self.a = false
	else
		self.session_settings:set(Settings.OPTIONS.SHOW_MODE, Settings.SHOW_MODES.SHOW_ALL)
		self.a = true
	end
	self.view:refresh()
end

-- Set the various display settings, but only on our view (by using SetOptionNative instead of SetOption)
function Filetab:setup_settings()
--	Settings.load_default_bp(self.bp)
	self:resize(INFO.MIN_WIDTH)--todo
	self.bp.Buf.Type.Scratch = true
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
	
	self:load(self.current_path)
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
