local micro = import('micro')
local os = import('os')
local filepath = import('path/filepath')
local config = import('micro/config')

---@module "utils"
local utils = dofile(config.ConfigDir .. '/plug/filetab/src/utils.lua')
---@module "icons"
local icon_utils = utils.import("icons")
local icons = icon_utils.Icons()
---@module "file"
local File = utils.import("file")
---@module "entry"
local Entry = utils.import("entry")
---@module "settings"
local Settings = utils.import("settings")


---@class Directory : Entry
---@field children Entry[]?
---@field show_dotfiles boolean
local Directory = setmetatable({}, { __index = Entry })
Directory.__index = Directory

---@param name string
---@param path string
---@param parent Entry?
---@param show_dotfiles boolean
---@return Directory --todo
function Directory:new(name, path, parent, show_dotfiles)

	local entry = Entry:new(
		name,
		icons['dir'],
		path,
		parent
	)
 	local instance = setmetatable(entry, Directory)
  	instance.show_dotfiles = show_dotfiles
    instance.children = nil
    return instance
end

function Directory:get_child(num)
 	return self.children[num]
end

function Directory:len(num)
 	return #self.children
end

---@overload fun() : boolean
function Directory:is_dir()
 	return true
end

function Directory:get_content(offset)
	if not self.content or true then
		
	    local content = self.icon .. ' ' .. self.name
	    if offset then
	        content = string.rep(' ', 2 * offset) .. content
	    end
		self.content = content
	end
 	return self.content
end

function Directory:children_create()
	local all_files, err = os.ReadDir(self.path)

	-- files will be nil if the directory is read-protected (no permissions)
	if err then
		micro.InfoBar():Error('Error scanning directory: ', self.path, ' | ', err)
		return nil
	end

	local directories, files, file, file_name = {}, {}, nil, nil

	for i = 1, #all_files do
		file = all_files[i]
		file_name = file:Name()

		if self.show_dotfiles or not utils:is_dotfile(file_name) then
			-- Logic to make sure all directories are appended first to entries table so they are shown first
			if file:IsDir() then
				local new_directory = self:new(file_name, filepath.Join(self.path, file_name), self, self.show_dotfiles)
	            table.insert(directories, new_directory)
			else
				local new_file = File:new(file_name, filepath.Join(self.path, file_name), self)
	            table.insert(files, new_file)
			end
		end
	end

    -- Append all file entries to directories entries (So they can be correctly sorted)
	return utils.get_appended_tables(directories, files)
end

--local show_dotfiles = config.GetGlobalOption('filemanager.showdotfiles')
--local show_ignored_files = config.GetGlobalOption('filemanager.showignored') --TODO not working ignored_files not fetching correctly ig
function Directory:get_children()
	if not self.children then
		self.children = self:children_create()
	end
	return self.children
end

function Directory:get_nested_children()
	local children, child, nested_children  = {}, nil, nil
	for i = 1, self:len() do
		child = self:get_child(i)
		children[#children + 1] = child
		if child:is_dir() and child.is_open then
			nested_children = child:get_nested_children()
			for z = 1, #nested_children do
				children[#children + 1] = nested_children[z]
			end
		end
	end
	return children
end

Directory.show_mode_switch_case = {
     [Settings.SHOW_MODES.SHOW_ALL] = function()
			return true 
     end,
     [Settings.SHOW_MODES.SHOW_NONE] = function(entry)
			if not entry:is_dotfile() then
       				return true
       	end
     end,
     [Settings.SHOW_MODES.IGNORE_DOTFILES] = function(entry)
     	return not entry:is_dotfile()
     end,
     [Settings.SHOW_MODES.IGNORE_GIT] = function(entry)
         if not entry:is_dotfile() then
				return true
         end
     end,
 }

-- Returns the content of all nested entries of self entry_list
function Directory:get_children_content(show_mode, offset)
	if self.content == nil or true then --todo
		local lines, child, nested_children, offset = {}, nil, nil, offset or 0
		for i = 1, self:len() do
			child = self:get_child(i)

			local fun_is_entry_meant_to_show = Directory.show_mode_switch_case[show_mode]
			if fun_is_entry_meant_to_show(child) then 
				lines[#lines + 1] = child:get_content(offset) .. "\n"
   			end 

			if child:is_dir() and child.is_open then
				nested_children = child:get_children_content(show_dotfiles, offset + 1)
				for z = 1, #nested_children do
					lines[#lines + 1] = nested_children[z]
				end
			end
		end
		self.content = lines
	end
	return self.content
end

function Directory:set_is_open(status)--todo
	if self.children == nil then
		self:get_children()
    end

    self.icon = status and icons['dir_open'] or icons['dir']
    self.is_open = status
end

return Directory