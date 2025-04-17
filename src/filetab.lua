local config = import('micro/config')
local micro = import('micro')
local filepath = import('path/filepath')
local buffer = import('micro/buffer')

---@module "utils"
local utils = dofile(config.ConfigDir .. '/plug/filetab/src/utils.lua')
---@module "action"
local Action = utils.import("action")
---@module "directory"
local Directory = utils.import("directory")
---@module "info"
local INFO = utils.import("info")
---@module "settings"
local Settings = utils.import("settings")
---@module "view"
local View = utils.import("view")

---@class Filetab
---@field is_selected boolean
---@field bp any
---@field current_path string
---@field session_settings Settings	
---@field action Action	
---@field view View
local Filetab = {}
Filetab.__index = Filetab

---comment
---@param bp any
---@param current_path any
---@return Filetab
function Filetab:new(bp, current_path)
	local instance = setmetatable({}, Filetab)
	instance.is_selected = true
	instance.bp = bp
	instance.current_path = current_path
	instance.is_open = false
	instance.session_settings = Settings:new(bp)
	instance.action = Action:new(instance)
	instance.view = View:new(bp, instance.session_settings)
	return instance
end

-- Changes the current directory, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Filetab:load(path)
	self.current_path = path

	local root = Directory:new(filepath.Base(path), path, nil, self.session_settings:get(Settings.OPTIONS.SHOW_DOTFILES))	
	root.children = root:children_create()
root.is_open = true
	self.view:refresh(self.current_path, root)
	self.view.virtual:move_cursor_and_select_line(INFO.DEFAULT_LINE_ON_OPEN)
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
