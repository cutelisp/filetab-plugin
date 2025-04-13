VERSION = "0.0.1"

local micro = import('micro')
local config = import('micro/config')
local os = import('os')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local Filetab = dofile(config.ConfigDir .. '/plug/filemanager/filetab.lua')
local Settings = dofile(config.ConfigDir .. '/plug/filemanager/settings.lua')


local filetab_map = {}

local function get_filetab_by_bp(bp)
	for _, ft in ipairs(filetab_map) do
        if ft.bp == bp then
            return ft
        end
    end
    return nil
end

local function get_filetab_by_tab(tab)
    for _, ft in ipairs(filetab_map) do
        if ft.bp:Tab() == tab then
            return ft
        end
    end
    return nil
end

local function toggle_filetab()
	local ft = get_filetab_by_tab(micro.CurTab())

	if not ft then
		ft = Filetab:new(micro.CurPane(), os.Getwd())
		table.insert(filetab_map, ft)
		ft:toggle()
	else
		ft:toggle()
	end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- All the events for certain Micro keys go below here
-- Other than things we flat-out fail
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Up Arrow
function preCursorUp(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if ft.view:is_action_happening() or
		ft.view.virtual.cursor:get_loc_y() == Settings.Const.previousDirectoryLine then
		return false
	end
end

function onCursorUp(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	ft.view.virtual:select_line_on_cursor()

end

-- Down Arrow
function preCursorDown(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	return not ft.view:is_action_happening()
end

function onCursorDown(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	ft.view.virtual:select_line_on_cursor()
end

-- Left Arrow
function preCursorLeft(bp)--todo this is bugged if a file stars with an empty space
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if ft.view:is_rename_at_cursor_happening() then
		return ft.view.virtual.cursor:get_can_move_left()
	else
		ft.view:collapse_directory()
		return false
	end
end

-- Right Arrow
function preCursorRight(bp) 
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if ft.view:is_rename_at_cursor_happening() then
		return ft.view.virtual.cursor:get_can_move_right()
	else
		ft.view:expand_directory()
		return false
	end
end

-- Enter
function preInsertNewline(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	local view = ft.view
	if view:is_rename_at_cursor_happening() then
		view:rename_at_cursor()
		view:refresh()
	elseif view.virtual.cursor:get_loc_y() == Settings.Const.previousDirectoryLine then
		ft:load_back_directory()
	else
		view:toggle_directory()
	end

	return false
end

-- Workaround for tab getting inserted into opened files --todo check if this is happening
-- Ref https://github.com/zyedidia/micro/issues/992
-- Tab
function preIndentSelection(bp) --todo bug tabing ..
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	ft:load(ft.view:get_entry_at_line(ft.view.virtual.cursor:get_line_num()).abs_path)
	return false
end

-- Backspace
function preBackspace(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

    return ft.view:is_rename_at_cursor_happening() and ft.view.virtual.cursor:get_can_move_left()
end

-- PageUp
function preCursorPageUp(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if not ft.view:is_action_happening() then
		ft.view.virtual:move_cursor_and_select_line(Settings.Const.previousDirectoryLine)
	end
	return false
end

-- PageDown
function preCursorPageDown(bp) --todo not reaching bot 
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if ft.view:is_action_happening() then
		return false
	end
end

function onCursorPageDown(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	ft.view.virtual:select_line_on_cursor()
end

-- F2
function preSave(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if not ft.view:is_rename_at_cursor_happening() then
		ft.view:pre_rename_at_cursor()
	else
		ft.view.virtual.cursor:select_file_name_no_extension()--todo do a cycling all/name/extension
	end
	return false
end

-- Ctrl + Q
-- If the target pane is the only one open aside from the file tab,
-- the file tab will close as well, causing the tab to be closed as well.
function preQuit(bp)
	local ft = get_filetab_by_bp(bp)
	if ft then
		ft:close()
		micro.CurPane():Quit()
		return false
	elseif utils.get_panes_quantity(micro.CurTab()) == 2 then --todo add setting, maybe need to create new setting
		ft = get_filetab_by_tab(bp:Tab())
		ft:close()
		return true
	end
end

-- Ctrl + A
function preSelectAll(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if ft.view:is_rename_at_cursor_happening() then
		ft.view.virtual.cursor:select_file_name()
	else
		--ft.view.virtual.cursor:select_all()--todo
	end
	return false
end

-- Ctrl + Up Arrow
function preCursorStart(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if not ft.view:is_action_happening() then
		ft.view:move_cursor_to_owner()
	end
	return false
end

-- Ctrl + Down Arrow
function preCursorEnd(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	if not ft.view:is_action_happening() then --todo visual bug 
		ft.view:move_cursor_to_next_dir_outside()
	end
	return false
end

-- Ctrl + Right Arrow
function preWordRight(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	return ft.view:is_rename_at_cursor_happening() and
		ft.view.virtual.cursor:get_can_move_right()
end

-- Ctrl + Left Arrow
function preWordLeft(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	return ft.view:is_rename_at_cursor_happening() and ft.view.virtual.cursor:get_can_move_left()
end

function onWordLeft(bp)
	local ft = get_filetab_by_bp(bp)
	if ft then ft.view.virtual.cursor:adjust() end
end

-- Alt + Down Arrow
function preMoveLinesDown(bp) --todo
	return true
end

-- Alt + Up Arrow
function preMoveLinesUp(bp) --todo
	return true
end

-- Alt + Right Arrow
function preEndOfLine(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	return ft.view:is_rename_at_cursor_happening()
end

-- Alt + Left Arrow
function preStartOfTextToggle(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end
	
	if ft.view:is_rename_at_cursor_happening() then
		ft.view.virtual.cursor:move_to_file_name_start()
	end
	return false
end


-- Mouse Left Click
function onMousePress(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	ft.view.virtual:click_event()
end

--Left Click Drag
function onMouseDrag(bp)
	local ft = get_filetab_by_bp(bp)
	if not ft then return end

	ft.view.virtual:drag_event()
end

-- MouseWheel Down
function onScrollDown(bp)
	bp:ScrollAdjust() --fix micro bug
end

-- CtrlF
function preFind(bp)
	-- Since something is always selected, clear before a find
	-- Prevents copying the selection into the find input
	--	clearselection_if_tree(bp)
end

-- FIXME: doesn't work for whatever reason
function onFind(bp)
	-- Select the whole line after a find, instead of just the input txt
	--selectline_if_tree(bp)
end

-- CtrlN after CtrlF
function onFindNext(bp)
	--selectline_if_tree(bp)
end

-- CtrlP after CtrlF
function onFindPrevious(bp)
	--	selectline_if_tree(bp)
end

-- Shift + Up
function preSelectUp(bp) -- bug the first line is nor selected entirly --todo
	if is_tab_selected(bp) then
		if ft.view.Cursor:get_x() ~= 0 then
			ft.view.Highlight:end_of_line()
			ft.view:append_cursor_list(ft.view.Cursor:get_y())
		end
		ft.view.Highlight:up_line()
		ft.view:append_cursor_list(ft.view.Cursor:get_y() - 1)
	end
end

-- Shift + Down
function preSelectDown(bp) --todo
	if ft.view.Cursor:get_x() ~= 0 then
		ft.view.Highlight:current_line_undo()
		ft.view.Highlight:down_line()
		ft.view:append_cursor_list(ft.view.Cursor:get_y() - 1)
	end
	ft.view:append_cursor_list(ft.view.Cursor:get_y())
end

--TODO

-- Close all
function preQuitAll(_)
	--tab:close()
end

function onNextSplit(bp)
	--selectline_if_tree(bp)
end

function onPreviousSplit(bp)
	--selectline_if_tree(bp)
end

------------------------------------------------------------------
-- Fail a bunch of useless actions
-- Some of these need to be removed (read-only makes some useless)
------------------------------------------------------------------

-- Ctrl + R
function preToggleRuler(bp)
	return not is_action_on_any_tab(bp)
end

function preStartOfText(bp) --todo
	return not is_action_on_any_asdastab(bp)
end

function preSelectLeft(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectRight(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectWordRight(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectWordLeft(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectToStartOfLine(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectToStartOfText(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectToEndOfLine(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectToStart(bp)
	return not is_action_on_any_tab(bp)
end

function preSelectToEnd(bp)
	return not is_action_on_any_tab(bp)
end

function preDeleteWordLeft(bp)
	return not is_action_on_any_tab(bp)
end

function preDeleteWordRight(bp)
	return not is_action_on_any_tab(bp)
end

function preOutdentSelection(bp)
	return not is_action_on_any_tab(bp)
end

function preOutdentLine(bp)
	return not is_action_on_any_tab(bp)
end

function preCut(bp)
	return not is_action_on_any_tab(bp)
end

function preCutLine(bp)
	return not is_action_on_any_tab(bp)
end

function preDuplicateLine(bp)
	return true
end

function prePaste(bp)
	return not is_action_on_any_tab(bp)
end

function prePastePrimary(bp)
	return not is_action_on_any_tab(bp)
end

function preMouseMultiCursor(bp)
	return not is_action_on_any_tab(bp)
end

function onMouseMultiCursor(bp)
	return not is_action_on_any_tab(bp)
end

function preSpawnMultiCursor(bp)
	return not is_action_on_any_tab(bp)
end


function is_action_on_any_tab(bp)
	local ft = get_filetab_by_bp(bp)
	return ft or true and false
end



function init()
	-- Adds colors to the ".." and any dir's in the tree bp via syntax highlighting
	-- TODO: Change it to work with git, based on untracked/changed/added/whatever
	config.AddRuntimeFile('filemanager', config.RTSyntax, 'syntax/filemanager.yaml')

	Settings.load_default()

	local current_dir = os.Getwd()
	
	config.MakeCommand('ft', toggle_filetab, config.NoComplete)

	if Settings.get_option("openOnStart") then
		toggle_filetab()
	end
end
