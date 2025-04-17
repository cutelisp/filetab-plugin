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
local Directory = setmetatable({}, { __index = Entry })
Directory.__index = Directory

---@param path string
---@param parent Entry?
---@return Directory --todo
function Directory:new(path, parent)
	local entry = Entry:new(
		filepath.Base(path),
		icons['dir'],
		path,
		parent
	)
 	local instance = setmetatable(entry, Directory)
    instance.children = nil
    return instance
end

function Directory:get_child(num)
 	return self.children[num]
end

function Directory:len(num)
 	return self.children and #self.children or nil
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

function Directory:children_create(directory)
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

			-- Logic to make sure all directories are appended first to entries table so they are shown first
			if file:IsDir() then
				if directory and directory.name == file:Name() then 
					directory.parent = self
     				table.insert(directories, directory)
				else
					local new_directory = self:new(file_name, filepath.Join(self.path, file_name), self)
		            table.insert(directories, new_directory)
			 	end
			else
				local new_file = File:new(file_name, filepath.Join(self.path, file_name), self)
	            table.insert(files, new_file)
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
	local children, nested_children  = {}, nil

	for _, child in ipairs(self:get_children()) do
		table.insert(children, child)
		if child:is_dir() and child.is_open then
			nested_children = child:get_nested_children()
			for _, nested_child in ipairs(nested_children) do
				table.insert(children, nested_child)
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
function Directory:get_children_content(show_mode_filter, offset)
	if self.content == nil or true then --todo
		local lines, nested_children = {}, nil

		for _, child in ipairs(self:get_children()) do
			if show_mode_filter(child) then 
				table.insert(lines,  child:get_content(offset) .. "\n")
				if child:is_dir() and child.is_open then
					nested_children = child:get_children_content(show_mode_filter, offset + 1)
					for z = 1, #nested_children do
						lines[#lines + 1] = nested_children[z]
					end
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