local config = import('micro/config')
local micro = import('micro')
local golib_ioutil = import('ioutil')
local shell = import('micro/shell')
local buffer = import('micro/buffer')
local filepath = import('path/filepath')
local str = import('strings')

---@module "info"
local INFO = dofile(config.ConfigDir .. '/plug/filetab/src/info.lua')

local function import(filename)
	return dofile(config.ConfigDir .. '/plug/' .. INFO.PLUGIN_NAME .. '/src/' .. filename .. '.lua')
end

---@module "icons"
local icon = import("icons")

function Icons()
	return icon.Icons()--todo
end

local function get_panes_quantity(tab)
	return #tab.Panes
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

-- Appends the elements of the second table to the first table
local function get_appended_tables(table1, table2)
    for i = 1, #table2 do
        table1[#table1 + 1] = table2[i]
    end
    return table1
end

-- Joins the target dir's leading path to the passed name
function dirname_and_join(path, join_name)
    local leading_path = filepath.Dir(path)
    return filepath.Join(leading_path, join_name)
end


-- Returns true/false if the file is a dotfile
local function is_dotfile(self, aaa)--todo why self?
	return string.sub(aaa, 1, 1) == "."
end

-- This function is designed to identify the position of the first character 
-- in 'entry.content' that is neither a space nor an icon. This is necessary 
-- because 'entry.content' can have an offset due to leading spaces or icons. 
local function first_char_loc(str)
    for i = 1, #str do
        local char = str:sub(i, i)
        if char ~= " " then
	        -- When this condition is true it means the icon was found 
	        -- Adding 2 to the position accounts for the space between the icon and the 
	        -- file name.
            return i + 2
        end
    end
    return nil
end


-- Returns the postition of the last dot of the given string not considerating the first 
local function get_dot_location(str)
	local position = string.find(str, "%.[^%.]*$")
    return position
end

local function get_content(str)
	-- Correct the starting position to account the icon which is a multi-byte character
    local first_char_location = first_char_loc(str) + 3
    return string.sub(str, first_char_location)
end

return {
	get_ignored_files = get_ignored_files,
	get_appended_tables = get_appended_tables,
	dirname_and_join = dirname_and_join,
	is_dotfile = is_dotfile,
	get_panes_quantity = get_panes_quantity,
	first_char_loc = first_char_loc,
	get_dot_location = get_dot_location, 
	get_content = get_content,
	import = import
}