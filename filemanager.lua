VERSION = "0.0.1"

local micro = import('micro')
local config = import('micro/config')
local shell = import('micro/shell')
local buffer = import('micro/buffer')
local os = import('os')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local Tab = dofile(config.ConfigDir .. '/plug/filemanager/tab.lua')
local Settings = dofile(config.ConfigDir .. '/plug/filemanager/settings.lua')



local tree_view

local function get_tab(view)
	if tab.bp == view then
		return tab
	else
		return nil
	end
end

local function is_action_happening(tabb)
	return tabb.view:is_rename_at_cursor_happening()
end



-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- All the events for certain Micro keys go below here
-- Other than things we flat-out fail
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Up Arrow
function preCursorUp(view)
	local tabb = get_tab(view)
	if tabb then
		if is_action_happening(tabb) or tabb.view.virtual.cursor:get_loc_y() == Settings.Const.previousDirectoryLine then
			return false
		end
	end
end

function onCursorUp(view)
	local tabb = get_tab(view)
	if tabb then
		tab.view.virtual:select_line_on_cursor()
	end
end

-- Down Arrow
function preCursorDown(view)
	local tabb = get_tab(view)
	if tabb then
		if is_action_happening(tabb) then
			return false
		end
	end
end

function onCursorDown(view)
	local tabb = get_tab(view)
	if tabb then
		tab.view.virtual:select_line_on_cursor()
	end
end

-- Left Arrow
function preCursorLeft(view)
	local tabb = get_tab(view)
	if tabb then
		if tabb.view:is_rename_at_cursor_happening() then
			if tabb.view.virtual.cursor:get_can_move_left() then
				return true
			end
		else
			tab.view:collapse_directory()
		end
		return false
	end
end

-- Right Arrow
function preCursorRight(view)
	local tabb = get_tab(view)
	if tabb then
		if tabb.view:is_rename_at_cursor_happening() then
			if tabb.view.virtual.cursor:get_can_move_right() then
				return true
			end
		else
			tab.view:expand_directory()
		end
		return false
	end
end

-- Enter
function preInsertNewline(view)
	local tabb = get_tab(view)
	if tabb then
		if tabb.view:is_rename_at_cursor_happening() then
			tabb.view:rename_at_cursor()
			tabb.view:set_read_only(true)
			tabb.view:refresh()
		elseif tabb.view.virtual.cursor:get_loc_y() == Settings.Const.previousDirectoryLine then
			tabb:load_back_directory()
		else
			tabb.view:toggle_directory()
		end
		return false
	end
end

-- Backspace
function preBackspace(view)
	local tabb = get_tab(view)
	if tabb then
		if tabb.view:is_rename_at_cursor_happening() then
			if tabb.view.virtual.cursor:get_can_move_left() then
				return true
			end
		end
		return false
	end
	return true
end

-- PageUp
function preCursorPageUp(view)
	local tabb = get_tab(view)
	if tabb then
		if is_action_happening(tabb) then
			return false
		else
			tab.view.virtual:move_cursor_and_select_line(Config.previousDirectoryLine)
			return false
		end
	end
end

-- PageDown
function preCursorPageDown(view)
	local tabb = get_tab(view)
	if tabb then
		if is_action_happening(tabb) then
			return false
		end
	end
end

function onCursorPageDown(view)
	local tabb = get_tab(view)
	if tabb then
		tab.view.virtual:select_line_on_cursor()
	end
end

-- F2
function preSave(view)
	local tabb = get_tab(view)
	if tabb then
		if not tabb.view:is_rename_at_cursor_happening() then
			tabb.view:pre_rename_at_cursor()
		end
	end
	return false
end

-- Ctrl + Q
-- If the target pane is the only one open aside from the file tab,
-- the file tab will close as well, causing the tab to be closed as well.
function preQuit(view)
	local tabb = get_tab(view)
	if tabb then
		tabb:close()
		return false
	elseif utils.get_panes_quantity(micro.CurTab()) == 2 then --todo
		--	micro:Close()
		--tabb:close()
		return true
	end
end

-- Ctrl + A
function preSelectAll(view)
	local tabb = get_tab(view)
	if tabb then
		if tabb.view:is_rename_at_cursor_happening() then
			tabb.view.virtual.cursor:select_file_name()
		else
			--tab.view.virtual.cursor:select_all()--todo
		end
		return false
	end
	return true
end

-- Ctrl + Up Arrow
function preCursorStart(view)
	local tabb = get_tab(view)
	if tabb then
		if is_action_happening(tabb) then
			return false
		else
			tabb.view:move_cursor_to_owner()
			return false
		end
	end
end

-- Ctrl + Down Arrow
function preCursorEnd(view)
	local tabb = get_tab(view)
	if tabb then
		if is_action_happening(tabb) then
			return false
		else
			tabb.view:move_cursor_to_next_dir_outside()
			return false
		end
	end
end

-- Ctrl + Right Arrow
function preWordRight(view)
	local tabb = get_tab(view)
	if tabb then
		if tabb.view:is_rename_at_cursor_happening() then
			if tabb.view.virtual.cursor:get_can_move_right() then
				return true
			end
		end
		return false
	end
	return true
end

-- Ctrl + Left Arrow
function preWordLeft(view)
	local tabb = get_tab(view)
	if tabb then
		if tabb.view:is_rename_at_cursor_happening() then
			if tabb.view.virtual.cursor:get_can_move_left() then
				return true --todo theres a bug here when this is the first input after rename on cursor
			end
		end
		return false
	end
	return true
end

-- Alt + Down Arrow
function preMoveLinesDown(view) --todo
	return true
end

-- Alt + Up Arrow
function preMoveLinesUp(view) --todo
	return true
end

-- Mouse Left Click
function onMousePress(view)
	local tabb = get_tab(view)
	if tabb then
		tabb.view.virtual:click_event()
	end
end

-- Mouse Left Click Release
function onMouseRelease(bp)
	--tab.view.virtual:move_cursor(3) --todo
end

--Left Click Drag
function onMouseDrag(view)
	tab.view.virtual:drag_event()
end

-- MouseWheel Down
function onScrollDown(view)
	view:ScrollAdjust()
end

-- CtrlF
function preFind(view)
	-- Since something is always selected, clear before a find
	-- Prevents copying the selection into the find input
--	clearselection_if_tree(view)
end

-- FIXME: doesn't work for whatever reason
function onFind(view)
	-- Select the whole line after a find, instead of just the input txt
	--selectline_if_tree(view)
end

-- CtrlN after CtrlF
function onFindNext(view)
	--selectline_if_tree(view)
end

-- CtrlP after CtrlF
function onFindPrevious(view)
--	selectline_if_tree(view)
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

-- Shift + Up
function preSelectUp(view) -- bug the first line is nor selected entirly --todo
	if is_tab_selected(view) then
		if tab.view.Cursor:get_x() ~= 0 then
			tab.view.Highlight:end_of_line()
			tab.view:append_cursor_list(tab.view.Cursor:get_y())
		end
		tab.view.Highlight:up_line()
		tab.view:append_cursor_list(tab.view.Cursor:get_y() - 1)
	end
end

-- Shift + Down
function preSelectDown(view) --todo
	if tab.view.Cursor:get_x() ~= 0 then
		tab.view.Highlight:current_line_undo()
		tab.view.Highlight:down_line()
		tab.view:append_cursor_list(tab.view.Cursor:get_y() - 1)
	end
	tab.view:append_cursor_list(tab.view.Cursor:get_y())
end

--TODO

-- Close all
function preQuitAll(_) 
	--tab:close()
end

function onNextSplit(view)
	--selectline_if_tree(view)
end

function onPreviousSplit(view)
	--selectline_if_tree(view)
end

------------------------------------------------------------------
-- Fail a bunch of useless actions
-- Some of these need to be removed (read-only makes some useless)
------------------------------------------------------------------

-- Ctrl + R
function preToggleRuler(view)
	return not is_action_on_any_tab(view)
end

function preStartOfText(view) --todo
	return not is_action_on_any_tab(view)
end

function preSelectLeft(view)
	return not is_action_on_any_tab(view)
end

function preSelectRight(view)
	return not is_action_on_any_tab(view)
end

function preSelectWordRight(view)
	return not is_action_on_any_tab(view)
end

function preSelectWordLeft(view)
	return not is_action_on_any_tab(view)
end

function preSelectToStartOfLine(view)
	return not is_action_on_any_tab(view)
end

function preSelectToStartOfText(view)
	return not is_action_on_any_tab(view)
end

function preSelectToEndOfLine(view)
	return not is_action_on_any_tab(view)
end

function preSelectToStart(view)
	return not is_action_on_any_tab(view)
end

function preSelectToEnd(view)
	return not is_action_on_any_tab(view)
end

function preDeleteWordLeft(view)
	return not is_action_on_any_tab(view)
end

function preDeleteWordRight(view)
	return not is_action_on_any_tab(view)
end

function preOutdentSelection(view)
	return not is_action_on_any_tab(view)
end

function preOutdentLine(view)
	return not is_action_on_any_tab(view)
end

function preCut(view)
	return not is_action_on_any_tab(view)
end

function preCutLine(view)
	return not is_action_on_any_tab(view)
end

function preDuplicateLine(view)
	return true
end

function prePaste(view)
	return not is_action_on_any_tab(view)
end

function prePastePrimary(view)
	return not is_action_on_any_tab(view)
end

function preMouseMultiCursor(view)
	return not is_action_on_any_tab(view)
end

function onMouseMultiCursor(view)
	return not is_action_on_any_tab(view)
end

function preSpawnMultiCursor(view)
	return not is_action_on_any_tab(view)
end

function preEndOfLine(view)
	return not is_action_on_any_tab(view)
end

function onStartOfLine(view)
	return not is_action_on_any_tab(view)
end

function is_action_on_any_tab(view)
	local tabb = get_tab(view)
	return tabb or true and false
end

function init()


	-- Adds colors to the ".." and any dir's in the tree view via syntax highlighting
	-- TODO: Change it to work with git, based on untracked/changed/added/whatever
	config.AddRuntimeFile('filemanager', config.RTSyntax, 'syntax/filemanager.yaml')

	Settings.load_default()

	local current_dir = os.Getwd()
	tab = Tab:new(micro.CurPane(), current_dir)

	if Settings.get_option("openOnStart") then
		tab:open()
		tree_view = tab.pane

	end
end
