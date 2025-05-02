local micro = import('micro')
local os = import('os')
local shell = import('micro/shell')
local filepath = import('path/filepath')
local utils = require("utils")
local icon_utils = require("icons")
local dir_icons = icon_utils.ICONS_DIR
local INFO = require("info")
local File = require("file")
local Entry = require("entry")
local Pref = require("preferences")

---@class Directory : Entry 
---@field empty_entry File? This is the entry shown when directory have no files inside and SHOW_EMPTY_ON_DIRECTORIES is on 
---@field children Entry[]?
---@field children_ignored Entry[]?
local Directory = setmetatable({}, { __index = Entry })
Directory.__index = Directory

---@param path string
---@param parent Entry?
---@return Directory
function Directory:new(path, parent)
	local instance = Entry:new(
		filepath.Base(path),
		nil,
		path,
		parent
	)
 	---@cast instance Directory
 	setmetatable(instance, Directory)
  	instance.empty_entry = nil
    instance.children = nil
    instance.children_ignored = nil
    instance.nested_children = {}
    instance:update_content()
    return instance
end

local a = 0
function Directory:children_create(directory)
	a = a + 1
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
    local result = utils.get_appended_tables(directories, files)
    if #result == 0 and Pref:get(Pref.OPTS.SHOW_EMPTY_ON_DIRECTORIES) then 
    	result = {self:get_empty_entry()}
    end
	return result
end

-- To increase performance this function does 2 things at the same thime
-- Returns the content of all open nested children of the current directory
-- Returns the nested children 
function Directory:get_nested_children_content(show_mode_filter, offset)
	local nested_content, nested_children = {}, {}
	for _, child in ipairs(self:get_children()) do
		if show_mode_filter(child) then 
			table.insert(nested_content, child:get_content(offset) .. "\n")
			table.insert(nested_children, child)
			if child:is_dir() and child.is_open then
				---@cast child Directory
				local c, r = child:get_nested_children_content(show_mode_filter, offset + 1)
				for _ ,nested_child_content in ipairs(c) do --maybe use childappend here? todo
					table.insert(nested_content,  nested_child_content)
				end
				for _ ,nested_child in ipairs(r) do
					table.insert(nested_children, nested_child)
				end
			end
		end
	end
	self.nested_children = nested_children
	return nested_content, nested_children
end

-- Returns a list of all files/directories inside the current directory that are ignored by the GIT system 
function Directory:get_children_git_ignored()
	if not self.children_ignored then
		-- True/false if the target dir returns a non-fatal error when checked with 'git status'
		local function has_git()
			local git_rp_results = shell.RunCommand('git  -C ' .. self.path .. ' rev-parse --is-inside-work-tree')--todo git might be not installed
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

-- Lazy getter
function Directory:get_empty_entry()
	if not self.empty_entry then 
		self.empty_entry = File:new_empty(self)
	end 
	return self.empty_entry
end

-- Lazy getter
function Directory:get_children()

	return self.children
end

function Directory:get_nested_children()
	return self.nested_children
end

function Directory:set_is_open(status)
	if not self.children then
		self.children = self:children_create()
    end
    
    self.is_open = status
    self:update_content()
end

function Directory:toggle_is_open_all_nested()
	local status = true

	local function helper(directory)
        directory:set_is_open(status)
        
        for _, child in ipairs(directory:get_children()) do
            if child:is_dir() then
                ---@cast child Directory
                helper(child)
            end
        end
    end
    
	local children = self:get_children()
    if self.is_open  and #children > 0 and children[1].is_open then 
		status = false
	end

 	helper(self) 
 	self:set_is_open(true)
end

--todo this does not work since the children nested 2 degrees will have a wrong file may consider jksl
function Directory:set_name(name)
	Entry.set_name(self, name)
	local dir = self.path
	for _ ,child in ipairs(self:get_nested_children()) do
		child:update_path(dir)
	end
end


function Directory:append_child(child)
	table.insert(self.children, child)
	table.insert(self.nested_children, child)
end

function Directory:is_empty(num)
	if not self.children then return true end
 	return #self.children == 0
end

--- override 
function Directory:is_dir()
 	return true
end

-- override
function Directory:update_content()
 	self.icon = self.is_open and dir_icons['opened'] or dir_icons['closed']

	if Pref:get(Pref.OPTS.SHOW_ARROWS) then
		local arrows = self.is_open and dir_icons['arrow_open'] or dir_icons['arrow_closed']
		self.icon = arrows .. self.icon
	end
	
	Entry.update_content(self)
	if Pref:get(Pref.OPTS.SHOW_SLASH_ON_DIRECTORY) then
		self.content = self.content .. "/"
	end
end



function Directory:len_nested()
 	return #self:get_nested_children()
end

function Directory:delete_child(entry)
 	for i = #self.children, 1, -1 do 
        if self.children[i] == entry then
            table.remove(self.children, i)
            return 
        end
    end
end

return Directory