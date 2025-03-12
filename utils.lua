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
	is_dir = is_dir, 
	is_dotfile = is_dotfile,
	is_scanlist_empty = is_scanlist_empty
}