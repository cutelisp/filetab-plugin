local micro = import('micro')
local config = import('micro/config')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local icon_utils = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon_utils.Icons()
local Entry_list = dofile(config.ConfigDir .. '/plug/filemanager/entry_list.lua')
local filepath = import('path/filepath')


local Entry = {}
Entry.__index = Entry

function Entry:new(file_name, abs_path, owner)
    local instance = setmetatable({}, Entry)
    local is_dir = utils.is_dir(abs_path)
    instance.is_dir = utils.is_dir(abs_path)
    instance.file_name = file_name
    instance.abs_path = abs_path
    instance.icon = (is_dir and icons['dir'] or icon_utils.GetIcon(file_name))
    instance.is_open = false 
    instance.entry_list = nil
    instance.owner = owner or nil 
    return instance
end

-- Returns a new entry_list objet of the given directory
function Entry:get_new_entry_list(directory, owner)
	----local show_dotfiles = config.GetGlobalOption('filemanager.showdotfiles')
	--local show_ignored_files = config.GetGlobalOption('filemanager.showignored') --TODO not working ignored_files not fetching correctly ig

	-- Gets a list of all the files names in the current dir
	local all_files_names, error_message = utils.get_files_names(directory, true, true)

	-- files will be nil if the directory is read-protected (no permissions)
	if all_files_names == nil then
		micro.InfoBar():Error('Error scanning dir: ', directory, ' | ', error_message)
		return nil
	end

	local entries_directories = {}
	local entries_files = {}
	local new_entry_name

	for i = 1, #all_files_names do
		new_entry_name = all_files_names[i]

		local new_entry = Entry:new(new_entry_name, filepath.Join(directory, new_entry_name), owner)

		-- Logic to make sure all directories are appended first to entries table so they are shown first
		if new_entry.is_dir then
            table.insert(entries_directories, new_entry)
		else
            table.insert(entries_files, new_entry)
		end
	end

	-- Append all file entries to directories entries (So they can be correctly sorted)
	utils.get_appended_tables(entries_directories, entries_files)
	return Entry_list:new(directory, entries_directories)
end

-- Builds and returns the string representation of the entry
-- The string is made up of an icon, the file name, and a slash if it's a directory
function Entry:get_content(offset)
    local content = self.icon .. ' ' .. self.file_name .. (self.is_dir and '/' or '')
    if offset then
        content = string.rep(' ', 2 * offset) .. content    
    end
    return content
end

function Entry:set_is_open(status)
    if self.is_dir then
        if not self.entry_list then
            self.entry_list = self:get_new_entry_list(self.abs_path, self)
	    end
        self.icon = status and icons['dir_open'] or icons['dir']
    end
    self.is_open = status
end

function Entry:get_entry_list()
    return self.entry_list
end

return Entry