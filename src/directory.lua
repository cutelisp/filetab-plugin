local micro = import('micro')
local os = import('os')
local shell = import('micro/shell')
local filepath = import('path/filepath')
local config = import('micro/config')

---@module "utils"
local utils = dofile(config.ConfigDir .. '/plug/filetab/src/utils.lua')
---@module "icons"
local icon_utils = utils.import("icons")
local icons = icon_utils.Icons()
---@module "info"
local INFO = utils.import("info")
---@module "file"
local File = utils.import("file")
---@module "entry"
local Entry = utils.import("entry")
---@module "settings"
local Settings = utils.import("settings")
---@module "preferences"
local Preferences = utils.import("preferences")


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
    instance.children_ignored = nil
    return instance
end

function Directory:get_child(num)
 	return self.children[num]
end

function Directory:len(num)
 	return self.children and #self.children or nil
end

function Directory:len_nested()
 	return #self:get_nested_children()
end

---@overload fun() : boolean
function Directory:is_dir()
 	return true
end

function Directory:get_content(offset)
	if not self.content or true then
		local arrow_icon = Preferences:get(Preferences.OPTIONS.SHOW_ARROWS) and (self.is_open and INFO.ICON_DIRECTORY_OPEN or INFO.ICON_DIRECTORY_CLOSED) or ""
		local content = arrow_icon .. self.icon .. self.name
		
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
					local new_directory = self:new(filepath.Join(self.path, file_name), self)
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

function Directory:get_nested_children_test(show_mode_filter)
	local children, nested_children  = {}, nil

	for _, child in ipairs(self:get_children()) do
		if show_mode_filter(child) then 
			table.insert(children, child)
			if child:is_dir() and child.is_open then
				nested_children = child:get_nested_children()
				for _, nested_child in ipairs(nested_children) do
					table.insert(children, nested_child)
				end
			end
		end
	end

	return children
end

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


-- Returns a list of all files/directories inside the current directory that are ignored by the GIT system 
function Directory:get_children_git_ignored()
	if not self.children_ignored then
		-- True/false if the target dir returns a non-fatal error when checked with 'git status'
		local function has_git()
			local git_rp_results = shell.RunCommand('git  -C ' .. self.path .. ' rev-parse --is-inside-work-tree')
			return git_rp_results:match('^true%s*$')
		end

		local entry_list = {}

		if has_git() then
			local ignored_entries, err =
			shell.RunCommand("git -C " .. self.path .." ls-files " .. self.path .. " --ignored --exclude-standard --others --directory")
			for entry_name in string.gmatch(ignored_entries, '([^\n]+)') do
				entry_list[entry_name] = true
			end
		end
		self.children_ignored = entry_list
	end
	return self.children_ignored
end


return Directory