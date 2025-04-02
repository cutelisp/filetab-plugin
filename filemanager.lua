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




-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Functions exposed specifically for the user to bind
-- Some are used in callbacks as well
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~





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












-- Close all
function preQuitAll(_)
	--tab:close()
end










function onNextSplit(view)
	selectline_if_tree(view)
end

function onPreviousSplit(view)
	selectline_if_tree(view)
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







local function is_tab_selected(view)
	return view == tab.pane 
end

-- Tab
-- Workaround for tab getting inserted into opened files
-- Ref https://github.com/zyedidia/micro/issues/992
local tab_pressed = false
function preIndentSelection(view)
	if tab:get_is_selected() then
		tab_pressed = true
		tab:load(tab.view:get_entry_at_line(tab.view.Cursor:get_y()).abs_path)
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
function preInsertNewline(view)
	if is_tab_selected(view) then
		if tab.view.Cursor:get_y() == 2 then
		  	tab.action:load_back_directory(tab.current_directory)	
		else
			tab.view:toggle_directory()
		end
		return false
	end
end

-- PageUp
function onCursorPageUp(view)
	if is_tab_selected(view) then
		--tab.view:empty_cursor_list()

		tab.view.Cursor:move(1)
		return false
	end
end

-- PageDown
function onCursorPageDown(view)
	if is_tab_selected(view) then
		tab.view.Highlight:current_line()
	end
end

-- Up Arrow
function preCursorUp(view)
	-- Disallow selecting past the ".." in the tab
	if is_tab_selected(view) and tab.view.Cursor:get_y() == 2 then
		return false
	end
end

function onCursorUp(view)
	if is_tab_selected(view) then
		tab.view.Highlight:current_line()
	end
end

-- Down Arrow
function onCursorDown(view)
	if is_tab_selected(view) then
		tab.view.Highlight:current_line()
	end
end

-- Left Arrow
function preCursorLeft(view)
	if is_tab_selected(view) then
		if not tab.view.Cursor:is_in_header() then
			tab.view:collapse_directory()
		end
		return false
	end
end

-- Right Arrow
function preCursorRight(view)
	if is_tab_selected(view) then
		if not tab.view.Cursor:is_in_header() then
			tab.view:expand_directory()
		end
		return false
	end
end

-- Ctrl + Q
-- If the target pane is the only one open aside from the file tab,
-- the file tab will close as well, causing the tab to be closed as well.
function preQuit(view)
	if is_tab_selected(view) then
		tab:close()
		return false
	elseif utils.get_panes_quantity(micro.CurTab()) == 2 then 
		tab:close()
		return true
	end
end

-- Ctrl + Up
function preCursorStart(view)
	if is_tab_selected(view) then
		tab.view.Cursor:move_to_top()
		return false
	end
end

-- Ctrl + Down
function onCursorEnd(view)
	if is_tab_selected(view) then
		tab.view.Highlight:current_line()
	end
end

-- Shift + Up
function preSelectUp(view)
	if is_tab_selected(view) then
		if tab.view.Cursor:get_x() ~= 0 then 
			-- Select all to the left placing Cursor.X to 0
			tab.view.Highlight:end_of_line()
			tab.view:append_cursor_list(tab.view.Cursor:get_y())
		end
		tab.view.Highlight:up_line()
		tab.view:append_cursor_list(tab.view.Cursor:get_y() - 1)
	end
end

-- Shift + Down
function preSelectDown(view)
	if is_tab_selected(view) then
		-- tab.view.Highlight:down_line() places X in 0, this checks if it's the first time
		if tab.view.Cursor:get_x() ~= 0 then 
			tab.view:append_cursor_list(tab.view.Cursor:get_y())
		end
		tab.view.Highlight:down_line()
		tab.view:append_cursor_list(tab.view.Cursor:get_y())
		micro.InfoBar():Error(tab.view:get_cursor_list())
		return false
	end
end

-- Shift + Up
function preSelectUp(view)
	if is_tab_selected(view) then
		tab.view.Cursor:move_to_owner()
		return false
	end
end

-- MouseWheelDown
function onScrollDown(view)
	if is_tab_selected(view) then
		tab.view:scroll_adjust()
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
	micro.InfoBar():Error('When using "touch" you need to input a file name')

	return false_if_tree(view)
end

function preMoveLinesDown(view)
	return false_if_tree(view)
end

function preMoveLinesUp(view)
	return false_if_tree(view)
end

function preWordRight(view)
	return true
	--return false_if_tree(view)
end

function preWordLeft(view)
	return true
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
function preToggleRuler(view)

	return false
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
	micro.InfoBar():Error('Wheas')

	return true --false_if_tree(view)
end

function preSpawnMultiCursor(view)
	return false_if_tree(view)
end

function preSelectAll(view)
	return true
end





function onMousePress(bp)
   -- micro.InfoBar():Message("asd")
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

 
	--config.TryBindKey("F2", "MousePress", false)
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
			tab:open()
			tree_view = tab.pane
			

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
