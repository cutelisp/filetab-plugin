local config = import('micro/config')
local micro = import('micro')
local golib_ioutil = import('ioutil')
local shell = import('micro/shell')
local buffer = import('micro/buffer')
local icon = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')



function Icons()
	return icon.Icons()
end

-- Returns a list of files (in the target dir) that are ignored by the VCS system (if exists)
-- aka this returns a list of gitignored files (but for whatever VCS is found)
local function get_ignored_files(tar_dir)
	local icons = Icons()

	-- True/false if the target dir returns a non-fatal error when checked with 'git status'
	local function has_git()
		local git_rp_results = shell.ExecCommand('git  -C "' .. tar_dir .. '" rev-parse --is-inside-work-tree')
		return git_rp_results:match('^true%s*$')
	end
	local readout_results = {}
	-- TODO: Support more than just Git, such as Mercurial or SVN
	if has_git() then
		-- If the dir is a git dir, get all ignored in the dir
		local git_ls_results =
		shell.ExecCommand('git -C "' .. tar_dir .. '" ls-files . --ignored --exclude-standard --others --directory')
		-- Cut off the newline that is at the end of each result
		for split_results in string.gmatch(git_ls_results, '([^\r\n]' .. icons['dir'] .. ')') do
			-- git ls-files adds a trailing slash if it's a dir, so we remove it (if it is one)
			readout_results[#readout_results + 1] = (
				string.sub(split_results, -1) == '/' and string.sub(split_results, 1, -2) or split_results
			)
		end
	end

	-- Make sure we return a table
	return readout_results
end

-- Returns a list of all the files of directory
local function get_files(directory, include_dotfiles)


	local result
	--local golib_ioutil = import('ioutil')

	local files, scan_error = golib_ioutil.ReadDir(directory)
	-- files will be nil if the directory is read-protected (no permissions)

	for file in files do
		result = file:Name()
	end
	return files
end

-- Consant for the min with of tree
local function get_tree_min_with()
	return 30
end

-- Appends the elements of the second table to the first table
local function get_appended_tables(table1, table2)
    for i = 1, #table2 do
        table1[#table1 + 1] = table2[i]
    end
end

-- A short "get y" for when acting on the scanlist
-- Needed since we don't store the first 3 visible indicies in scanlist
local function get_safe_y(tree_view, optional_y)
	-- Default to 0 so we can check against and see if it's bad
	local y = 0
	-- Make the passed y optional
	if optional_y == nil then
		-- Default to cursor's Y loc if nothing was passed, instead of declaring another y
		optional_y = tree_view.Cursor.Loc.Y
	end
	-- 0/1/2 would be the top "dir, separator, .." so check if it's past
	if optional_y > 2 then
		-- -2 to conform to our scanlist, since zero-based Go index & Lua's one-based
		y = tree_view.Cursor.Loc.Y - 2
	end
	return y
end

-- Returns the basename of a path (aka a name without leading path)
local function get_basename(path)
	if path == nil then
		--micro.Log('Bad path passed to get_basename')TODO
		return nil
	else
		-- Get Go's path lib for a basename callback
		local golib_path = import('filepath')
		return golib_path.Base(path)
	end
end

local function get_buffer_end(pane)
	return buffer.Loc(0, micro.CurPane().Buf:End().Y)
end


-- Hightlights the line when you move the cursor up/down
local function select_line(tree_view, last_y)
	-- Make last_y optional
	if last_y ~= nil then
		-- Don't let them move past ".." by checking the result first
		if last_y > 1 then
			-- If the last position was valid, move back to it
			tree_view.Cursor.Loc.Y = last_y
		end
	elseif tree_view.Cursor.Loc.Y < 2 then
		-- Put the cursor on the ".." if it's above it
		tree_view.Cursor.Loc.Y = 2
	end

	-- Puts the cursor back in bounds (if it isn't) for safety
	tree_view.Cursor:Relocate()

	-- Makes sure the cursor is visible (if it isn't)
	-- (false) means no callback
	tree_view:Center()

	-- Highlight the current line where the cursor is
	tree_view.Cursor:SelectLine()
end

-- Repeats a string x times, then returns it concatenated into one string
local function repeat_str(str, len)
	-- Do NOT try to concat in a loop, it freezes micro...
	-- instead, use a temporary table to hold values
	local string_table = {}
	for i = 1, len do
		string_table[i] = str
	end
	-- Return the single string of repeated characters
	return table.concat(string_table)
end


-- Joins the target dir's leading path to the passed name
function dirname_and_join(path, join_name)
    local leading_path = filepath.Dir(path)
    return filepath.Join(leading_path, join_name)
end

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

-- Returns true/false if the table has an entry equal to the given entry
local function is_entry_in_table(entry, table)
	for i = 1, #table do
		if table[i] == entry then
			return true
		end
	end
	return false
end

-- A check for if a path is a dir
local function is_dir(path)
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

local function insert_table_into_table(table_a, table_b, position)
    for i = 1, #table_b do
        table.insert(table_a, position + i , table_b[i])
    end
end

-- Returns true/false if the file is a dotfile
local function is_dotfile(file_name)
	return string.sub(file_name, 1, 1) == '.'
end

-- Returns true/false if the file is a dotfile todo
local function is_ignored_file(file_name)
	return false
end

-- Simple true/false if scanlist is currently empty
local function is_scanlist_empty(scanlist)
	if next(scanlist) == nil then
		return true
	else
		return false
	end
end

-- Simple true/false if scanlist is currently empty
local function scanlist_is_empty()
	if next(scanlist) == nil then
		return true
	else
		return false
	end
end

-- Returns the names of all files inside the given directory.
-- Checks if the file name should be returned based on include_dotfiles and include_ignored_files.
local function get_files_names(directory, include_dotfiles, include_ignored_files)
	local files, error_message = golib_ioutil.ReadDir(directory)
	-- files will be nil if the directory is read-protected (no permissions)
	if error_message then
		return nil, error_message
	end

	local result = {}

	-- Include all files
	if include_dotfiles and include_ignored_files then
		for i = 1, #files do
			table.insert(result, files[i]:Name())
		end
		return result
	end

	local function is_meant_to_show(file_name)
		if not include_dotfiles and is_dotfile(file_name) then
			return false
		elseif not include_ignored_files and is_ignored_file(file_name) then
			return false
		else
			return true
		end
	end

	-- Include all files but dotfiles/ignored_files
	if not include_dotfiles or not include_ignored_files then
		local file_name
		for i = 1, #files do
			file_name = files[i]:Name()
			if is_meant_to_show(file_name) then
				table.insert(result, file_name)
			end
		end
		return result
	end
end

return {
	get_ignored_files = get_ignored_files,
	get_tree_min_with = get_tree_min_with,
	get_basename = get_basename,
	get_appended_tables = get_appended_tables,
	get_files_names = get_files_names,
	get_safe_y = get_safe_y,
	select_line = select_line,
	repeat_str = repeat_str,
	dirname_and_join = dirname_and_join,
	is_entry_in_table = is_entry_in_table,
	is_path = is_path,
	is_dir = is_dir,
	insert_table_into_table = insert_table_into_table,
	is_dotfile = is_dotfile,
	is_scanlist_empty = is_scanlist_empty,
	get_buffer_end = get_buffer_end,
}
