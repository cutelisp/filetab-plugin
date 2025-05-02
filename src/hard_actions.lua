local micro = import('micro')
local filepath = import('path/filepath')
local os = import('os')
local utils = require("utils")
local Directory = require("directory")
local File = require("file")
local INFO = require("info")
local Settings = require("settings")
local Pref = require("preferences")


---@class Hard_action
---@field ft Filetab
---@field view any
---@field current_action any
---@field rename_at_cursor any
---@field delete_at_cursor any
local Hard_action = {}
Hard_action.__index = Hard_action
function Hard_action:new(ft)
    local instance = setmetatable({}, Hard_action)
    instance.ft = ft
    instance.view = ft.view
    instance.current = ft.view
    instance.rename_at_cursor = Hard_action.create_rename_at_cursor(instance)
    instance.delete_at_cursor = Hard_action.create_delete_at_cursor(instance)
    instance.new_file = Hard_action.create_new_file(instance)
    return instance
end

--- Define `set_current_action` como método da classe `Hard_action`.
function Hard_action:set_current_action(action)
    self.current = action
end

function Hard_action:is_any_ongoing()
    return self.current ~= nil
end

--- Creates the logic table for rename_at_cursor
---@param instance Hard_action
---@return table
function Hard_action.create_rename_at_cursor(inst)
    return {
        is_ongoing = false,
        entry = nil,
        
        init = function()
            local s = inst.rename_at_cursor
        	inst:set_current_action(s)
            local view = inst.view

            s.is_ongoing = true
            local entry = view:get_entry_at_cursor()
            s.entry = entry
           	-- The goal is to give to cycle_select_entry_name_init what is visually shown
           	-- The slash might be visible but it's never stored in entry.name 
            local has_slash = entry:is_dir() and Pref:get(Pref.OPTS.SHOW_SLASH_ON_DIRECTORY)
           	local entry_name = has_slash and entry.name  .. "/" or entry.name 
            view:set_read_only(false)
            view.virtual.cursor:cycle_select_entry_name_init(entry_name, has_slash)
            view.virtual.cursor:cycle_select_entry_name()
        end,
        exec = function()
            local s = inst.rename_at_cursor
            local view = inst.view

            local entry = s.entry
            local old_path = entry.path
            local new_entry_name = view.virtual.cursor:get_entry_name()
            local new_path = utils.dirname_and_join(old_path, new_entry_name)

            local err = os.Rename(old_path, new_path)
            if err then
          		micro.InfoBar():Error("Rename error: ", err)
            else
                entry:set_name(new_entry_name)
            end

            s.finish()
        end,
        finish = function()
            local view = inst.view
            local s = inst.rename_at_cursor

            view:set_read_only(true)
            s.is_ongoing = false
            view:refresh()
        end
    }
end


--- Creates the logic table for rename_at_cursor
---@param instance Hard_action
---@return table
function Hard_action.create_delete_at_cursor(instance)
    return {
        is_ongoing = false,
        entry = nil,
        
        init = function()
            local dac_state = instance.delete_at_cursor
            local view = instance.view
            dac_state.is_ongoing = true
            local entry = view:get_entry_at_cursor()
            dac_state.entry = entry

            view.virtual.cursor:cycle_select_entry_name_init(entry.name)
            view.virtual.cursor:cycle_select_entry_name()

        end,
        exec = function()
            local dac_state = instance.rename_at_cursor
            local view = instance.view

            local entry = dac_state.entry
            local old_path = entry.path
            local new_entry_name = view.virtual.cursor:get_entry_name()
            local new_path = utils.dirname_and_join(old_path, new_entry_name)

            local err = os.Rename(old_path, new_path)
            if err then
          		micro.InfoBar():Error("Rename error: ", err)
            else
                entry:set_name(new_entry_name)
            end

            dac_state.finish()
        end,
        finish = function()
            local dac_state = instance.rename_at_cursor
            local view = instance.view

            view:set_read_only(true)
            dac_state.is_ongoing = false
            view:refresh()
        end
    }
end

--- Creates the logic table for rename_at_cursor
---@param inst Hard_action
---@return table
function Hard_action.create_new_file(inst)
    return {
        is_ongoing = false,
        new_entry = nil,
        
        init = function()
        	local s = inst.rename_at_cursor
       		inst:set_current_action(s)
            s.is_ongoing = true
            local view, virtual, line, parent = inst.view, inst.view.virtual, nil, nil
            local cursor_entry = view:get_entry_at_cursor()
            
            parent = cursor_entry:is_dir() and cursor_entry or cursor_entry.parent
            parent:set_is_open(true)
            s.new_file = File:new("", "", parent)
            parent:append_child(s.new_filed)
            
            inst.view:refresh()
            line = inst.view:get_line_at_entry(s.new_file)
            inst.view.virtual:move_cursor_and_select_line(line)
            virtual.cursor:cycle_select_entry_name_init(s.new_file.name)
            virtual:unselect_all()
            view.virtual.cursor:set_loc_x(view.virtual.cursor.bounds:x_right())
            view:set_read_only(false)
        end,
        exec = function()
            local dac_state = instance.rename_at_cursor
            local view = instance.view

            local entry = dac_state.entry
            local old_path = entry.path
            local new_entry_name = view.virtual.cursor:get_entry_name()
            local new_path = utils.dirname_and_join(old_path, new_entry_name)

            local err = os.Rename(old_path, new_path)
            if err then
          		micro.InfoBar():Error("Rename error: ", err)
            else
                entry:set_name(new_entry_name)
            end

            dac_state.finish()
        end,
        finish = function()
            local dac_state = instance.rename_at_cursor
            local view = instance.view

            view:set_read_only(true)
            dac_state.is_ongoing = false
            view:refresh()
        end
    }
end


--- Checks if any action is ongoing.
---@return boolean
function Hard_action:is_any_ongoing()
    return self.rename_at_cursor.is_ongoing or 
    self.delete_at_cursor.is_ongoing or 
    self.new_file.is_ongoing
end

return Hard_action