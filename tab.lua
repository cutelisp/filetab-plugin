local config = import('micro/config')
local micro = import('micro')
local os = import('os')


local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local icon_utils = dofile(config.ConfigDir .. '/plug/filemanager/icon.lua')
local icons = icon_utils.Icons()
local buffer = import('micro/buffer')

local filepath = import('path/filepath')

local Entry = dofile(config.ConfigDir .. '/plug/filemanager/entry.lua')

-- Entry is the object of scanlist
local Tab = {}
Tab.__index = Tab

-- Return a new object used when adding to scanlist
function Tab:new(file_name, current_directory)
    local instance = setmetatable({}, Tab)
    instance.curPane = file_name
    instance.min_width = 30
    instance.current_directory = current_directory
    instance.is_open = false
    instance.entry_list = {}


    return instance
end

-- Set the width of tab to num & lock it
function Tab:resize(num)
    if num < self.min_width then
        self.curPane:ResizePane(self.min_width)
    else
        self.curPane:ResizePane(num)
    end
end


-- Delete everything in the view/buffer
function Tab:clear()
    self.curPane.Buf.EventHandler:Remove(self.curPane.Buf:Start(), self.curPane.Buf:End())
end






-- close_tree will close the tree plugin view and release memory.
function Tab:close()
	if self.curPane ~= nil then
        self.curPane:Quit()
        self.is_open = false
	end
end



-- Set the various display settings, but only on our view (by using SetOptionNative instead of SetOption)
function Tab:setup_settings()
    -- Set the width of tree_view to 30% & lock it
    self:resize(self.min_width)

    -- tree_view.Buf.Type = buffer.BTLog
    -- Set the type to unsavable
    self.curPane.Buf.Type.Scratch = true
    self.curPane.Buf.Type.Readonly = true
    -- Softwrap long strings (the file/dir paths)
    self.curPane.Buf:SetOptionNative('softwrap', true)
    -- No line numbering
    self.curPane.Buf:SetOptionNative('ruler', false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    self.curPane.Buf:SetOptionNative('autosave', false)
    -- Don't show the statusline to differentiate the view from normal views
    self.curPane.Buf:SetOptionNative('statusformatr', '')
    self.curPane.Buf:SetOptionNative('statusformatl', 'filetab')
    self.curPane.Buf:SetOptionNative('scrollbar', false)
end



-- Delete everything in the view/buffer
function Tab:print_header()--todo
    -- Current dir
    self.curPane.Buf.EventHandler:Insert(buffer.Loc(0, 0), "self.current_dir" .. '\n')
    -- An ASCII separator
    self.curPane.Buf.EventHandler:Insert(buffer.Loc(0, 1), utils.repeat_str('─', self.curPane:GetView().Width) .. '\n') -- TODO this \n is probably wrong
    -- The ".." and use a newline if there are things in the current dir
    self.curPane.Buf.EventHandler:Insert(buffer.Loc(0, 2), (#self.entry_list > 0 and '..\n' or '..'))
end





function Tab:view_refresh(new_path)

	self:resize(self.min_width)
	self:clear()

  


	self:print_header()
	-- Holds the current basename of the path (purely for display)
	local content

	-- NOTE: might want to not do all these concats in the loop, it can get slow
	for i = 1, #self.entry_list do
		-- Newlines are needed for all inserts except the last
		-- If you insert a newline on the last, it leaves a blank spot at the bottom
		content = self.entry_list[i]:get_content() .. (i < #self.entry_list and '\n' or '')

		-- Insert line-by-line to avoid out-of-bounds on big folders
		-- +2 so we skip the 0/1/2 positions that hold the top dir/separator/..
		self.curPane.Buf.EventHandler:Insert(buffer.Loc(0, i + 2), content)
	end

	-- Resizes all views after messing with ours
	self.curPane:Tab():Resize() -- todo idk wts this
end

local golib_ioutil = import('ioutil')


-- Structures the output of the scanned directory content to be used in the scanlist table
-- This is useful for both initial creation of the tree, and when nesting with uncompress_target()
function Tab:get_entry_list(directory, ownership, indent_level)
	----local show_dotfiles = config.GetGlobalOption('filemanager.showdotfiles')
	--local show_ignored_files = config.GetGlobalOption('filemanager.showignored') --TODO not working ignored_files not fetching correctly ig

	-- Gets a list of all the files names in the current dir
	local all_files_names, error_message = utils.get_files_names(directory, true, true)

	-- files will be nil if the directory is read-protected (no permissions)
	if all_files_names == nil then
		micro.InfoBar():Error('Error scanning dir: ', directory, ' | ', error_message)
		return nil
	end

	-- The list of directories & files entries to be returned (and eventually put in the view)
	local entries_directories = {}
	local entries_files = {}
	local entry_name

	for i = 1, #all_files_names do
		entry_name = all_files_names[i]

		local new_entry = Entry:new(entry_name, filepath.Join(directory, entry_name), ownership, indent_level)

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

-- Moves the cursor to the ".." in tree_view
function Tab:move_cursor_top()
	-- 2 is the position of the ".."
	self.curPane.Cursor.Loc.Y = 2

	-- select the line after moving
	utils.select_line(self.curPane)
end

-- Changes the current directoty, get the new entry_list, refresh the view and move the cursor to the ".." by default
function Tab:view_show(directory)
	-- Clear the highest since this is a full refresh
	--highest_visible_indent = 0 todo
	self.current_dir = directory
	-- 0 ownership because this is a scan of the base dir, 0 indent because this is the base dir
	self.entry_list = self:get_entry_list(directory, 0, 0)
	self:view_refresh()
	self:move_cursor_top()
end


-- open_tree setup's the view
function Tab:open_tree()
	-- Open a new Vsplit (on the very left)
	micro.CurPane():VSplitIndex(buffer.NewBuffer('', ''), true)
	self.is_open = true
	self:setup_settings()
	self:view_show(os.Getwd())
end


-- toggle_tree will toggle the tree view visible (create) and hide (delete).
function Tab:toggle_tree()
	if not tab.is_open then
		tab:open_tree()
	else
		tab:close()
	end
end

return Tab



