local config = import('micro/config')
local micro  = import('micro')
local micro = import('micro')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
local filepath = import('path/filepath')

-- Entry is the object of scanlist
local Entry_list = {}
Entry_list.__index = Entry_list


-- Structures the output of the scanned directory content to be used in the scanlist table
-- This is useful for both initial creation of the tree, and when nesting with uncompress_target()
function Entry_list:build_entry_list(directory, ownership, indent_level)
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
	local entry_name

	for i = 1, #all_files_names do
		entry_name = all_files_names[i]

		local new_entry = Entry:new(entry_name, filepath.Join(directory, entry_name), ownership)

		-- Logic to make sure all directories are appended first to entries table so they are shown first
		if not new_entry.is_dir then
			-- If this is a file, add it to (temporary) files
			entries_files[#entries_files + 1] = new_entry
		else
			-- Otherwise, add to entries
			entries_directories[#entries_directories + 1] = new_entry
		end
	end

	-- Append all file entries to directories entries (So they can be correctly sorted)
	utils.get_appended_tables(entries_directories, entries_files)
	-- Return all entries (directories + files)
	return entries_directories
end

function Entry_list:new(directory, list)
    local instance = setmetatable({}, Entry_list)
    local list = Entry_list:build_entry_list(directory,0,0)
    instance.list = list
	instance.content = nil
	return instance
end

function Entry_list:get_entry(index)
    return self.list[index]
end

function Entry_list:size()
    return #self.list
end

function Entry_list:get_all_nested_entries()
		local entries = {}
		for i = 1, self:size() - 1 do
			entries[#entries + 1] = self:get_entry(i)
			if self:get_entry(i).is_open == true then
				nested_entries = self:get_entry(i):get_entry_list():get_all_nested_entries()
				for z = 1, #nested_entries - 1 do
					entries[#entries + 1] = nested_entries[z]
				end
			end
		end
	
	return entries
end

function Entry_list:get_content(offset)
	if self.content == nil or true then --todo
		local lines = {}
		offset = offset or 0 
		for i = 1, self:size() - 1 do
			lines[#lines + 1] = self:get_entry(i):get_content(offset) .. (i < self:size() and '\n' or '')
			if self:get_entry(i).is_open == true then
				nested_entries = self:get_entry(i):get_entry_list():get_content(offset + 1)
				for z = 1, #nested_entries - 1 do
					lines[#lines + 1] = nested_entries[z]
				end
			end
		end
		self.content = lines
	end
	return self.content
end

return Entry_list