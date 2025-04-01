VERSION = "0.0.1"

local micro = import('micro')
local config = import('micro/config')
local shell = import('micro/shell')
local buffer = import('micro/buffer')
local os = import('os')
local filepath = import('path/filepath')

local icon = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')
local Tab = dofile(config.ConfigDir .. '/plug/filemanager/tab.lua')
local Action = dofile(config.ConfigDir .. '/plug/filemanager/action.lua')



function Icons()
	return icon.Icons()
end

function GetIcon(filename)
	return icon.GetIcon(filename)
end

function FileIcon(buf)
	return icon.GetIcon(buf.Path)
end


local tab

-- Holds the micro.CurPane() we're manipulating
local tree_view
-- Keeps track of the current working directory
local current_dir
-- Keep track of current highest visible indent to resize width appropriately
local highest_visible_indent = 0
-- Holds a table of entries, entry is the object of entry.lua



-- Find everything nested under the target, and remove it from the scanlist
local function compress_target(y, delete_y)
	local icons = Icons()

	-- Can't compress the top stuff, or if there's nothing there, so exit early
	if y == 0 or utils.is_scanlist_empty(scanlist) then
		return
	end
	-- Check if the target is a dir, since files don't have anything to compress
	-- Also make sure it's actually an uncompressed dir by checking the gutter message
	if tab.entry_list[y].icon == icons['dir_open'] then
		local delete_index
		-- Add the original target y to stuff to delete
		local delete_under = { [1] = y }
		local new_table = {}
		local del_count = 0
		-- Loop through the whole table, looking for nested content, or stuff with ownership == y...
		-- and delete matches. y+1 because we want to start under y, without actually touching y itself.
		for i = 1, #tab.entry_list do
			delete_index = false
			-- Don't run on y, since we don't always delete y
			if i ~= y then
				-- On each loop, check if the ownership matches
				for x = 1, #delete_under do
					-- Check for something belonging to a thing to delete
					if tab.entry_list[i].owner == delete_under[x] then
						-- Delete the target if it has an ownership to our delete target
						delete_index = true
						-- Keep count of total deleted (can't use #delete_under because it's for deleted dir count)
						del_count = del_count + 1
						-- Check if an uncompressed dir
						if tab.entry_list[i].icon == icons['dir_open'] then
							-- Add the index to stuff to delete, since it holds nested content
							delete_under[#delete_under + 1] = i
						end
						-- See if we're on the "deepest" nested content
						if tab.entry_list[i].indent_level == highest_visible_indent and tab.entry_list[i].indent_level > 0 then
							-- Save the lower indent, since we're minimizing/deleting nested dirs
							highest_visible_indent = highest_visible_indent - 1
						end
						-- Nothing else to do, so break this inner loop
						break
					end
				end
			end
			if not delete_index then
				-- Save the index in our new table
				new_table[#new_table + 1] = tab.entry_list[i]
			end
		end

		tab.entry_list = new_table
		tab.entry_list = new_table

		if del_count > 0 then
			-- Ownership adjusting since we're deleting an index
			for i = y + 1, #tab.entry_list do
				-- Don't touch root file/dirs
				if tab.entry_list[i].owner > y then
					-- Minus ownership, on everything below i, the number deleted
					tab.entry_list[i]:decrease_owner(del_count)
				end
			end
		end

		-- If not deleting, then update the gutter message to be + to signify compressed
		if not delete_y then
			-- Update the dir message
			tab.entry_list[y].icon = icons['dir']
		end
	elseif config.GetGlobalOption('filemanager.compressparent') and not delete_y then
		goto_parent_dir()
		-- Prevent a pointless refresh of the view
		return
	end

	-- Put outside check above because we call this to delete targets as well
	if delete_y then
		local second_table = {}
		-- Quickly remove y
		for i = 1, #tab.entry_list do
			if i == y then
				-- Reduce everything's ownership by 1 after y
				for x = i + 1, #tab.entry_list do
					-- Don't touch root file/dirs
					if tab.entry_list[x].owner > y then
						-- Minus 1 since we're just deleting y
						tab.entry_list[x]:decrease_owner(1)
					end
				end
			else
				-- Put everything but y into the temporary table
				second_table[#second_table + 1] = tab.entry_list[i]
			end
		end
		-- Put everything (but y) back into scanlist, with adjusted ownership values
		tab.entry_list = second_table
		tab.entry_list = second_table
	end

	if tree_view:GetView().Width > (utils.get_tree_min_with() + highest_visible_indent) then
		-- Shave off some width
		tab:resize(min_width + highest_visible_indent)
	end

	tab:view_refresh()
end

-- Prompts the user for deletion of a file/dir when triggered
-- Not local so Micro can access it
function prompt_delete_at_cursor()
	local icons = Icons()

	local y = utils.get_safe_y(tree_view)
	-- Don't let them delete the top 3 index dir/separator/..
	if y == 0 or utils.is_scanlist_empty(scanlist) then
		micro.InfoBar():Error('You can\'t delete that')
		-- Exit early if there's nothing to delete
		return
	end

	micro.InfoBar():YNPrompt(
		'Do you want to delete the '
			.. (tab.entry_list[y].icon == icons['dir'] and 'dir' or 'file')
			.. ' "'
			.. tab.entry_list[y].abs_path
			.. '"? ',
		function(yes, canceled)
			if yes and not canceled then
				-- Use Go's os.Remove to delete the file
				local go_os = import('os')
				-- Delete the target (if its a dir then the children too)
				local remove_log = go_os.RemoveAll(tab.entry_list[y].abs_path)
				if remove_log == nil then
					micro.InfoBar():Message('filemanager deleted: ', tab.entry_list[y].abs_path)
					-- Remove the target (and all nested) from tab.entry_list[y + 1]
					-- true to delete y
					compress_target(utils.get_safe_y(tree_view), true)
				else
					micro.InfoBar():Error('Failed deleting file/dir: ', remove_log)
				end
			else
				micro.InfoBar():Message('Nothing was deleted')
			end
		end
	)
end




-- Opens the dir's get_content nested under itself
local function uncompress_target(entry_y)
	
	if not tab.entry_list[entry_y].is_dir or tab.entry_list[entry_y].is_open or entry_y < 2  then
		return
	end
	-- Only uncompress if it's a dir and it's not already uncompressed

		-- Get a new scanlist with results from the scan in the target dir
		local scan_results = tab:get_entry_list(tab.entry_list[entry_y].abs_path, entry_y, tab.entry_list[entry_y].indent_level + 1)
		-- Don't run any of this if there's nothing in the dir we scanned, pointless
		if scan_results ~= nil then
			-- Will hold all the old values + new scan results
			local new_table = {}
			-- By not inserting in-place, some unexpected results can be avoided
			-- Also, table.insert actually moves values up (???) instead of down
			for i = 1, #tab.entry_list do
				-- Put the current val into our new table
				new_table[#new_table + 1] = tab.entry_list[i]
				if i == y then
					-- Fill in the scan results under y
					for x = 1, #scan_results do
						new_table[#new_table + 1] = scan_results[x]
					end
					-- Basically "moving down" everything below y, so ownership needs to increase on everything
					for inner_i = y + 1, #tab.entry_list do
						-- When root not pushed by inserting, don't change its ownership
						-- This also has a dual-purpose to make it not effect root file/dirs
						-- since y is always >= 3
						if tab.entry_list[inner_i].owner > y then
							-- Increase each indicies ownership by the number of scan results inserted
							tab.entry_list[inner_i]:increase_owner(#scan_results)
						end
					end
				end
			end

			-- Update our scanlist with the new values
			tab.entry_list = new_table
			tab.entry_list = new_table

		end

		-- Change to minus to signify it's uncompressed
		tab.entry_list[y].icon = icons['dir_open']

		-- Check if we actually need to resize, or if we're nesting at the same indent
		-- Also check if there's anything in the dir, as we don't need to expand on an empty dir
		if scan_results ~= nil then
			if tab.entry_list[y].indent_level > highest_visible_indent and #scan_results >= 1 then
				-- Save the new highest indent
				highest_visible_indent = tab.entry_list[y].indent_level
				-- Increase the width to fit the new nested content
				tab:resize(tree_view:GetView().Width + tab.entry_list[y].indent_level)
			end
		end
		tab.entry_list[entry_y].is_open =
		tab:view_refresh()
	
end


-- Prompts for a new name, then renames the file/dir at the cursor's position
-- Not local so Micro can use it
function rename_at_cursor(_, args)
	if micro.CurPane() ~= tree_view then
		micro.InfoBar():Message('Rename only works with the cursor in the tree!')
		return
	end

	-- Safety check they actually passed a name
	if #args < 1 then
		micro.InfoBar():Error('When using "rename" you need to input a new name')
		return
	end

	local new_name = args[1]

	-- +1 since Go uses zero-based indices
	local y = utils.get_safe_y(tree_view)
	-- Check if they're trying to rename the top stuff
	if y == 0 then
		-- Error since they tried to rename the top stuff
		micro.InfoBar():Message('You can\'t rename that!')
		return
	end

	-- The old file/dir's path
	local old_path = tab.entry_list[y].abs_path
	-- Join the path into their supplied rename, so that we have an absolute path
	local new_path = utils.dirname_and_join(old_path, new_name)
	-- Use Go's os package for renaming the file/dir
	local golib_os = import('os')
	-- Actually rename the file
	local log_out = golib_os.Rename(old_path, new_path)
	-- Output the log, if any, of the rename
	if log_out ~= nil then
		micro.Log('Rename log: ', log_out)
	end

	-- Check if the rename worked
	if not utils.is_path(new_path) then
		micro.InfoBar():Error('Path doesn\'t exist after rename!')
		return
	end

	-- NOTE: doesn't alphabetically sort after refresh, but it probably should
	-- Replace the old path with the new path
	tab.entry_list[y].abs_path = new_path
	-- Refresh the tree with our new name
	tab:view_refresh()
end

-- Prompts the user for the file/dir name, then creates the file/dir using Go's os package
local function create_filedir(filedir_name, make_dir)
	local icons = Icons()

	if micro.CurPane() ~= tree_view then
		micro.InfoBar():Message('You can\'t create a file/dir if your cursor isn\'t in the tree!')
		return
	end

	-- Safety check they passed a name
	if filedir_name == nil then
		micro.InfoBar():Error('You need to input a name when using "touch" or "mkdir"!')
		return
	end

	-- The target they're trying to create on top of/in/at/whatever
	local y = utils.get_safe_y(tree_view)
	-- Holds the path passed to Go for the eventual new file/dir
	local filedir_path
	-- A true/false if scanlist is empty
	local is_scanlist_empty = utils.is_scanlist_empty(tab.entry_list)

	-- Check there's actually anything in the list, and that they're not on the ".."
	if not is_scanlist_empty and y ~= 0 then
		-- If they're inserting on a folder, don't strip its path
		if tab.entry_list[y].icon == icons['dir'] or tab.entry_list[y].icon == icons['dir_open'] then
			-- Join our new file/dir onto the dir
			filedir_path = filepath.Join(tab.entry_list[y].abs_path, filedir_name)
		else
			-- The current index is a file, so strip its name and join ours onto it
			filedir_path = utils.dirname_and_join(tab.entry_list[y].abs_path, filedir_name)
		end
	else
		-- if nothing in the list, or cursor is on top of "..", use the current dir
		filedir_path = filepath.Join(current_dir, filedir_name)
	end

	-- Check if the name is already taken by a file/dir
	if utils.is_path(filedir_path) then
		micro.InfoBar():Error('You can\'t create a file/dir with a pre-existing name')
		return
	end

	-- Use Go's os package for creating the files
	local golib_os = import('os')
	-- Create the dir or file
	if make_dir then
		-- Creates the dir
		golib_os.Mkdir(filedir_path, golib_os.ModePerm)
		micro.Log('filemanager created directory: ' .. filedir_path)
	else
		-- Creates the file
		golib_os.Create(filedir_path)
		micro.Log('filemanager created file: ' .. filedir_path)
	end

	-- If the file we tried to make doesn't exist, fail
	if not utils.is_path(filedir_path) then
		micro.InfoBar():Error('The file/dir creation failed')

		return
	end

	-- Creates a sort of default object, to be modified below
	local new_filedir = entry:new(filedir_path, (make_dir and icons['dir'] or GetIcon(filedir_name)), 0, 0)
	-- Refresh with our new value(s)
	local last_y

	-- Only insert to scanlist if not created into a compressed dir, since it'd be hidden if it was
	-- Wrap the below checks so a y=0 doesn't break something
	if not is_scanlist_empty and y ~= 0 then
		-- +1 so it's highlighting the new file/dir
		last_y = tree_view.Cursor.Loc.Y + 1

		-- Only actually add the object to the list if it's not created on an uncompressed folder
		if tab.entry_list[y].icon == icons['dir'] then
			-- Exit early, since it was created into an uncompressed folder

			return
		elseif tab.entry_list[y].icon == icons['dir_open'] then
			-- Check if created on top of an uncompressed folder
			-- Change ownership to the folder it was created on top of..
			-- otherwise, the ownership would be incorrect
			new_filedir.owner = y
			-- We insert under the folder, so increment the indent
			new_filedir.indent_level = tab.entry_list[y].indent_level + 1
		else
			-- This triggers if the cursor is on top of a file...
			-- so we copy the properties of it
			new_filedir.owner = tab.entry_list[y].owner
			new_filedir.indent_level = tab.entry_list[y].indent_level
		end

		-- A temporary table for adding our new object, and manipulation
		local new_table = {}
		-- Insert the new file/dir, and update ownership of everything below it
		for i = 1, #tab.entry_list do
			-- Don't use i as index, as it will be off by one on the next pass after below "i == y"
			new_table[#new_table + 1] = tab.entry_list[i]
			if i == y then
				-- Insert our new file/dir (below the last item)
				new_table[#new_table + 1] = new_filedir
				-- Increase ownership of everything below it, since we're inserting
				-- Basically "moving down" everything below y, so ownership needs to increase on everything
				for inner_i = y + 1, #tab.entry_list do
					-- When root not pushed by inserting, don't change its ownership
					-- This also has a dual-purpose to make it not effect root file/dirs
					-- since y is always >= 3
					if tab.entry_list[inner_i].owner > y then
						-- Increase each indicies ownership by 1 since we're only inserting 1 file/dir
						tab.entry_list[inner_i]:increase_owner(1)
					end
				end
			end
		end
		-- Update the scanlist with the new object & updated ownerships
		tab.entry_list = new_table
		tab.entry_list = new_table
	else
		-- The scanlist is empty (or cursor is on ".."), so we add on our new file/dir at the bottom
		tab.entry_list[#tab.entry_list + 1] = new_filedir
		-- Add current position so it takes into account where we are
		last_y = #tab.entry_list + tree_view.Cursor.Loc.Y
	end

	tab:view_refresh()
	select_line(last_y)
end

-- Triggered with "touch filename"
function new_file(_, args)
	-- Safety check they actually passed a name
	if #args < 1 then
		micro.InfoBar():Error('When using "touch" you need to input a file name')
		return
	end

	local file_name = args[1]

	-- False because not a dir
	create_filedir(file_name, false)
end

-- Triggered with "mkdir dirname"
function new_dir(_, args)
	-- Safety check they actually passed a name
	if #args < 1 then
		micro.InfoBar():Error('When using "mkdir" you need to input a dir name')
		return
	end

	local dir_name = args[1]

	-- True because dir
	create_filedir(dir_name, true)
end

-- open_tree setup's the view
local function open_tree()
	tab:open()
	tree_view = tab.pane
end




-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Functions exposed specifically for the user to bind
-- Some are used in callbacks as well
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function uncompress_at_cursor()
	if micro.CurPane() == tree_view then
		tab:expand_directory_at_cursor()
	end
end

function compress_at_cursor()
	if micro.CurPane() == tree_view then
		-- False to not delete y
		compress_target(utils.get_safe_y(tree_view), false)
	end
end

-- Goes up 1 visible directory (if any)
-- Not local so it can be bound
function goto_prev_dir()
	local icons = Icons()

	if micro.CurPane() ~= tree_view or utils.is_scanlist_empty(scanlist) then
		return
	end

	local cur_y = utils.get_safe_y(tree_view)
	-- If they try to run it on the ".." do nothing
	if cur_y ~= 0 then
		local move_count = 0
		for i = cur_y - 1, 1, -1 do
			move_count = move_count + 1
			-- If a dir, stop counting
			if tab.entry_list[i].icon == icons['dir'] or tab.entry_list[i].icon == icons['dir_open'] then
				-- Jump to its parent (the ownership)
				tree_view.Cursor:UpN(move_count)
				utils.select_line(tree_view)
				break
			end
		end
	end
end

-- Goes down 1 visible directory (if any)
-- Not local so it can be bound
function goto_next_dir()
	local icons = Icons()

	if micro.CurPane() ~= tree_view or utils.is_scanlist_empty(scanlist) then
		return
	end

	local cur_y = utils.get_safe_y(tree_view)
	local move_count = 0
	-- If they try to goto_next on "..", pretends the cursor is valid
	if cur_y == 0 then
		cur_y = 1
		move_count = 1
	end
	-- Only do anything if it's even possible for there to be another dir
	if cur_y < #tab.entry_list then
		for i = cur_y + 1, #tab.entry_list do
			move_count = move_count + 1
			-- If a dir, stop counting
			if tab.entry_list[i].icon == icons['dir'] or tab.entry_list[i].icon == icons['dir_open'] then
				-- Jump to its parent (the ownership)
				tree_view.Cursor:DownN(move_count)
				utils.select_line(tree_view)
				break
			end
		end
	end
end

-- Goes to the parent directory (if any)
-- Not local so it can be keybound
function goto_parent_dir()
	if micro.CurPane() ~= tree_view or utils.is_scanlist_empty(scanlist) then
		return
	end

	local cur_y = utils.get_safe_y(tree_view)
	-- Check if the cursor is even in a valid location for jumping to the owner
	if cur_y > 0 then
		-- Jump to its parent (the ownership)
		tree_view.Cursor:UpN(cur_y - tab.entry_list[cur_y].owner)
		utils.select_line(tree_view)
	end
end

function try_open_at_cursor()
	if micro.CurPane() ~= tree_view or utils.is_scanlist_empty(scanlist) then
		return
	end

	tab:load_entry(tree_view.Cursor.Loc.Y, 'vsplit')
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Shorthand functions for actions to reduce repeat code
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Used to fail certain actions that we shouldn't allow on the tree_view
local function false_if_tree(view)
	if view == tree_view then
		return false
	end
end

-- Select the line at the cursor
local function selectline_if_tree(view)
	if view == tree_view then
		utils.select_line(tree_view)
	end
end

-- Move the cursor to the top, but don't allow the action
local function aftermove_if_tree(view)
	if view == tree_view then
		if tree_view.Cursor.Loc.Y < 2 then
			-- If it went past the "..", move back onto it
			tree_view.Cursor:DownN(2 - tree_view.Cursor.Loc.Y)
		end
		utils.select_line(tree_view)
	end
end

local function clearselection_if_tree(view)
	if view == tree_view then
		-- Clear the selection when doing a find, so it doesn't copy the current line
		tree_view.Cursor:ResetSelection()
	end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- All the events for certain Micro keys go below here
-- Other than things we flat-out fail
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local function is_tab_selected()
	return tab and tab:get_is_selected()
end









-- Close current
function preQuit(view)
	if view == tree_view then
		-- A fake quit function
		tab:close()
		-- Don't actually "quit", otherwise it closes everything without saving for some reason
		return false
	end
end

-- Close all
function preQuitAll(_)
	tab:close()
end



-- Alt-Shift-{
-- Go to target's parent directory (if exists)
function preParagraphPrevious(view)
	if view == tree_view then
		goto_prev_dir()
		-- Don't actually do the action
		return false
	end
end



-- Alt-Shift-}
-- Go to next dir (if exists)
function preParagraphNext(view)
	if view == tree_view then
		goto_next_dir()
		-- Don't actually do the action
		return false
	end
end






function onNextSplit(view)
	selectline_if_tree(view)
end

function onPreviousSplit(view)
	selectline_if_tree(view)
end

function preMousePress(view, event)
	if view == tree_view and event then
		if type(event.Position) == "function" then
			local x, y = event:Position()
			if x and y then
				-- Fixes the y because softwrap messes with it
				local _, new_y = tree_view:GetMouseClickLocation(x, y)
				-- Try to open whatever is at the click's y index
				tab:load_entry(new_y, 'vsplit')
			end
		end
		-- Don't actually allow the mousepress to trigger, so we avoid highlighting stuff
		return false
	end
end










-- CtrlF
function preFind(view)
	-- Since something is always selected, clear before a find
	-- Prevents copying the selection into the find input
	clearselection_if_tree(view)
end

-- FIXME: doesn't work for whatever reason
function onFind(view)
	-- Select the whole line after a find, instead of just the input txt
	selectline_if_tree(view)
end

-- CtrlN after CtrlF
function onFindNext(view)
	selectline_if_tree(view)
end

-- CtrlP after CtrlF
function onFindPrevious(view)
	selectline_if_tree(view)
end

-- NOTE: This is a workaround for "cd" not having its own callback
local precmd_dir

function preCommandMode(_)
	precmd_dir = os.Getwd()
end

-- Update the current dir when using "cd"
function onCommandMode(_)
	local new_dir = os.Getwd()
	-- Only do anything if the tree is open, and they didn't cd to nothing
	if tree_view ~= nil and new_dir ~= precmd_dir and new_dir ~= current_dir then
		--view_show(new_dir)todo
	end
end






-- Tab
-- Workaround for tab getting inserted into opened files
-- Ref https://github.com/zyedidia/micro/issues/992
local tab_pressed = false
function preIndentSelection(view)
	if tab:get_is_selected() then
		tab_pressed = true
		tab:load(tab.view:get_entry_at_line(tab.view:get_cursor_y()).abs_path)
		return false
	end
end

function preInsertTab(_)
	if tab_pressed then
		tab_pressed = false
		return false
	end
end

-- Enter
function preInsertNewline()
	if tab:get_is_selected() then
		if tab.view:get_cursor_y() == 2 then
		  	tab.action:load_back_directory(tab.current_directory)	
		else
			tab.view:toggle_directory()
		end
		return false
	end
end

-- PageUp
function onCursorPageUp()
	if is_tab_selected() then
		tab.view:move_cursor_top()
		return false
	end
end

-- PageDown
function onCursorPageDown()
	if is_tab_selected() then
		tab.view:highlight_current_line()
	end
end

-- Up Arrow
function preCursorUp()
	-- Disallow selecting past the ".." in the tab
	if is_tab_selected() and tab.view:get_cursor_y() == 2 then
		return false
	end

end

function onCursorUp()
	if is_tab_selected() then
		tab.view:highlight_current_line()
	end
end

-- Down Arrow
function onCursorDown()
	if is_tab_selected() then
		tab.view:highlight_current_line()
	end
end

-- Left Arrow
function preCursorLeft()
	if is_tab_selected() then
		if not tab.view:is_cursor_in_header() then
			tab.view:collapse_directory()
		end
		return false
	end
end

-- Right Arrow
function preCursorRight()
	if is_tab_selected() then
		if not tab.view:is_cursor_in_header() then
			tab.view:expand_directory()
		end
		return false
	end
end

-- Ctrl + Up
function preCursorStart(view)
	if is_tab_selected() then
		tab.view:move_cursor_top()
		return false
	end
end

-- Ctrl + Down
function onCursorEnd(view)
	if is_tab_selected() then
		tab.view:highlight_current_line()
	end
end


-- Shift + Up
function preSelectUp()
	if is_tab_selected() then
		tab.view:move_cursor_to_owner()
		return false
	end
end

------------------------------------------------------------------
-- Fail a bunch of useless actions
-- Some of these need to be removed (read-only makes some useless)
------------------------------------------------------------------

function preStartOfLine(view)
	return false_if_tree(view)
end

function preStartOfText(view)
	return false_if_tree(view)
end

function preEndOfLine(view)
	return false_if_tree(view)
end

function preMoveLinesDown(view)
	return false_if_tree(view)
end

function preMoveLinesUp(view)
	return false_if_tree(view)
end

function preWordRight(view)
	return false_if_tree(view)
end

function preWordLeft(view)
	return false_if_tree(view)
end

function preSelectDown(view)
	return false_if_tree(view)
end

function preSelectLeft(view)
	return false_if_tree(view)
end

function preSelectRight(view)
	return false_if_tree(view)
end

function preSelectWordRight(view)
	return false_if_tree(view)
end

function preSelectWordLeft(view)
	return false_if_tree(view)
end

function preSelectToStartOfLine(view)
	return false_if_tree(view)
end

function preSelectToStartOfText(view)
	return false_if_tree(view)
end

function preSelectToEndOfLine(view)
	return false_if_tree(view)
end

function preSelectToStart(view)
	return false_if_tree(view)
end

function preSelectToEnd(view)
	return false_if_tree(view)
end

function preDeleteWordLeft(view)
	return false_if_tree(view)
end

function preDeleteWordRight(view)
	return false_if_tree(view)
end

function preOutdentSelection(view)
	return false_if_tree(view)
end

function preOutdentLine(view)
	return false_if_tree(view)
end

function preSave(view)
	return false_if_tree(view)
end

function preCut(view)
	return false_if_tree(view)
end

function preCutLine(view)
	return false_if_tree(view)
end

function preDuplicateLine(view)
	return false_if_tree(view)
end

function prePaste(view)
	return false_if_tree(view)
end

function prePastePrimary(view)
	return false_if_tree(view)
end

function preMouseMultiCursor(view)
	return false_if_tree(view)
end

function preSpawnMultiCursor(view)
	return false_if_tree(view)
end

function preSelectAll(view)
	return false_if_tree(view)
end

function init()

	current_dir = os.Getwd()
	tab = Tab:new(micro.CurPane(), current_dir)
	-- Let the user disable showing of dotfiles like ".editorconfig" or ".DS_STORE"
	config.RegisterCommonOption('filemanager', 'showdotfiles', true)
	-- Let the user disable showing files ignored by the VCS (i.e. gitignored)
	config.RegisterCommonOption('filemanager', 'showignored', true)
	-- Let the user disable going to parent directory via left arrow key when file selected (not directory)
	config.RegisterCommonOption('filemanager', 'compressparent', true)
	-- Let the user choose to list sub-folders first when listing the get_content of a folder
	--config.RegisterCommonOption('filemanager', 'foldersfirst', true)
	-- Lets the user have the filetree auto-open any time Micro is opened
	-- false by default, as it's a rather noticable user-facing change
	config.RegisterCommonOption('filemanager', 'openonstart', true)
	-- Use nerd fonts icons
	config.RegisterCommonOption('filemanager', 'nerdfonts', true)

	-- Use file icon in status bar
	micro.SetStatusInfoFn('filemanager.FileIcon')


	-- Open/close the tree view

	config.MakeCommand('tree', Tab.toggle, config.NoComplete)
	-- Rename the file/dir under the cursor
	config.MakeCommand('rename', rename_at_cursor, config.NoComplete)
	-- Create a new file
	config.MakeCommand('touch', new_file, config.NoComplete)
	-- Create a new dir
	config.MakeCommand('mkdir', new_dir, config.NoComplete)
	-- Delete a file/dir, and anything contained in it if it's a dir
	config.MakeCommand('rm', prompt_delete_at_cursor, config.NoComplete)

	-- Command to open current selection in vsplit
	config.MakeCommand('vopen', function()
		if tree_view ~= nil then
			tab:load_entry(tree_view.Cursor.Loc.Y, 'vsplit')
		end
	end, config.NoComplete)

	-- Command to open current selection in hsplit
	config.MakeCommand('hopen', function()
		if tree_view ~= nil then
			tab:load_entry(tree_view.Cursor.Loc.Y, 'hsplit')
		end
	end, config.NoComplete)

	-- Adds colors to the ".." and any dir's in the tree view via syntax highlighting
	-- TODO: Change it to work with git, based on untracked/changed/added/whatever
	config.AddRuntimeFile('filemanager', config.RTSyntax, 'syntax/filemanager.yaml')







	-- NOTE: This must be below the syntax load command or coloring won't work
	-- Just auto-open if the option is enabled
	-- This will run when the plugin first loads
	if config.GetGlobalOption('filemanager.openonstart') then
		-- Check for safety on the off-chance someone's init.lua breaks this
		if tree_view == nil then
			open_tree()


			micro.InfoBar():Error(utils.get_buffer_end(tree_view))

		--	buf.EventHandler:Insert(, "table.concat(lines)")
			-- Puts the cursor back in the empty view that initially spawns
			-- This is so the cursor isn't sitting in the tree view at startup
			--micro.CurPane():NextSplit()
		else
			-- Log error so they can fix it
			micro.Log(
				'Warning: filemanager.openonstart was enabled, but somehow the tree was already open so the option was ignored.'
			)
		end
	end
end
