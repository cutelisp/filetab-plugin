local micro = import('micro')
local buffer = import('micro/buffer')
local Action = require("action")
local Directory = require("directory")
local Hard_action = require("hard_actions")
local INFO = require("info")
local Settings = require("settings")
local View = require("view")
local Preferences = require("preferences")


---@class Filetab
---@field is_selected boolean
---@field bp any
---@field current_path string
---@field session_settings Settings	
---@field view View
---@field action Action	
---@field root_directory Directory	
local Filetab = {}
Filetab.__index = Filetab

Filetab.shared_buffer = nil

---@param bp any
---@param current_path any
---@return Filetab
function Filetab:new(bp, current_path, tab, is_disciple)
	local instance = setmetatable({}, Filetab)
		instance.tab = tab
		instance.is_selected = true
		-- When PERSITENCE_OVER_TABS is off this variable holds the current state when tab closes
		instance.buf = is_disciple and Filetab.shared_buffer or nil
		instance.is_open = nil
		instance.session_settings = Settings:new(bp)
	if not is_disciple then 
		instance.view = View:new(bp,  instance.session_settings)
		instance.action = Action:new(instance)
		instance.hard_action = Hard_action:new(instance)
		instance.root_directory = Directory:new(current_path, nil)
	end 
	return instance
end

-- Changes the current directory, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Filetab:load(directory)
	self.root_directory = directory
	directory:set_is_open(true)
	self.view:load(directory)
end

-- Set the various display settings, but only on our view (by using SetOptionNative instead of SetOption)
function Filetab:setup_settings()
--	Settings.load_default_bp(self.bp)
	self.session_settings:load_default_options()
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
	self.buf_cache = self.bp.Buf
	self.bp:Quit()
	self.is_open = false
end

function Filetab:open()	
	local buf = self.buf
	if not buf then -- todo check if the buffer is empty instead
		if Preferences:get(Preferences.OPTS.PERSITENCE_OVER_TABS) then 
			Filetab.shared_buffer = buffer.NewBuffer('', '') 
			self.buf = Filetab.shared_buffer  
		else
			self.buf = buffer.NewBuffer('', '') 
		end
	end
	
	-- todo, maybe change this since panes[1] may be hsplited and filetab will not be shown correctly
	local show_on_right, panes = Preferences:get(Preferences.OPTS.SHOW_ON_RIGHT), self.tab.Panes
	local target_pane = show_on_right and panes[1] or panes[#panes]
	local new_bp = target_pane:VSplitIndex(self.buf , show_on_right)
	self:set_bp(new_bp)
	self:setup_settings()
	
	if not buf then  
		self:load(self.root_directory)
	end
	self.is_open = true
end

function Filetab:toggle()
	if self.is_open then
		self:close()
	else
		self:open()
	end
end

function Filetab:set_bp(bp)
	self.bp = bp
	if self.view then self.view:set_bp(bp) end
	if self.session_settings then self.session_settings.bp = bp end
end


function Filetab:get_buf()

		
	return self.buf
end

function Filetab:get_tab()
	return self.bp:Tab()
end

function Filetab:get_is_selected()
	return micro.CurPane() == self.bp
end


return Filetab
