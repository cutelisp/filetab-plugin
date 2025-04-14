local micro = import('micro')
local os = import('os')
local filepath = import('path/filepath')
local config = import('micro/config')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local icon_utils = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon_utils.Icons()
local File = dofile(config.ConfigDir .. '/plug/filemanager/file.lua')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
--local Entry = require('entry')


---@class Directory : Entry
---@field children Entry[]|nil
local Directory = setmetatable({}, { __index = Entry })
Directory.__index = Directory

---@param name string
---@param path string
---@param parent Entry
---@return Entry:Directory--todo
function Directory:new(name, path, parent)
	local entry = Entry:new(
		name,
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
 	return #self.children
end

function Directory:is_dir()--todo 
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

--local show_dotfiles = config.GetGlobalOption('filemanager.showdotfiles')
--local show_ignored_files = config.GetGlobalOption('filemanager.showignored') --TODO not working ignored_files not fetching correctly ig
function Directory:get_children()
	if not self.children then

		local all_files, err = os.ReadDir(self.path)

		-- files will be nil if the directory is read-protected (no permissions)
		if err then
			micro.InfoBar():Error('Error scanning directory: ', self.path, ' | ', err)
			return nil
		end

		local directories, files, file = {}, {}, nil

		for i = 1, #all_files do
			file = all_files[i]

			-- Logic to make sure all directories are appended first to entries table so they are shown first
			if file:IsDir() then
				local new_directory = self:new(file:Name(), filepath.Join(self.path, file:Name()), self)
	            table.insert(directories, new_directory)
			else
				local new_file = File:new(file:Name(), filepath.Join(self.path, file:Name()), self)
	            table.insert(files, new_file)
			end
		end

	    -- Append all file entries to directories entries (So they can be correctly sorted)
		self.children = utils.get_appended_tables(directories, files)
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

-- Returns the content of all nested entries of self entry_list
function Directory:get_children_content(offset)
	if self.content == nil or true then --todo
		local lines, child, nested_children, offset = {}, nil, nil, offset or 0
		for i = 1, self:len() do
			child = self:get_child(i)
			lines[#lines + 1] = child:get_content(offset) .. "\n"
			if child:is_dir() and child.is_open then
				nested_children = child:get_children_content(offset + 1)
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