-- Stat a path to check if it exists, returning true/false
local function is_path(path)
	local go_os = import('os')
	-- Stat the file/dir path we created
	-- file_stat should be non-nil, and stat_err should be nil on success
	local file_stat, stat_err = go_os.Stat(path)
	-- Check if what we tried to create exists
	if stat_err ~= nil then
		-- true/false if the file/dir exists
		return go_os.IsExist(stat_err)
	elseif file_stat ~= nil then
		-- Assume it exists if no errors
		return true
	end
	return false
end


-- A check for if a path is a dir
local function is_dir(micro, path)
	-- Used for checking if dir
	local golib_os = import('os')
	-- Returns a FileInfo on the current file/path
	local file_info, stat_error = golib_os.Stat(path)
	-- Wrap in nil check for file/dirs without read permissions
	if file_info ~= nil then
		-- Returns true/false if it's a dir
		return file_info:IsDir()
	else
		-- Couldn't stat the file/dir, usually because no read permissions
		micro.InfoBar():Error('Error checking if is dir: ', stat_error)
		-- Nil since we can't read the path
		return nil
	end
end


-- Returns true/false if the file is a dotfile
local function is_dotfile(file_name)
	-- Check if the filename starts with a dot
	if string.sub(file_name, 1, 1) == '.' then
		return true
	else
		return false
	end
end

-- Simple true/false if scanlist is currently empty
local function is_scanlist_empty(scanlist)
	if next(scanlist) == nil then
		return true
	else
		return false
	end
end

return {
	is_path = is_path,
	is_dir = is_dir, 
	is_dotfile = is_dotfile,
	is_scanlist_empty = is_scanlist_empty,
}