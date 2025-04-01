local config = import('micro/config')
local micro  = import('micro')
local utils = dofile(config.ConfigDir .. '/plug/filemanager/utils.lua')
local filepath = import('path/filepath')


local Entry_list = {}
Entry_list.__index = Entry_list

function Entry_list:new(directory, list)
    local instance = setmetatable({}, Entry_list)
    instance.list = list
	instance.content = nil
	return instance
end

function Entry_list:size()
    return #self.list
end

-- Returns all entries from open nested directories within the self entry list.
function Entry_list:get_all_nested_entries()
		local entries = {}
		for i = 1, self:size() - 1 do
			entries[#entries + 1] = self:get_entry(i)
			if self:get_entry(i).is_open == true then
				nested_entries = self:get_entry(i):get_entry_list():get_all_nested_entries()
				for z = 1, #nested_entries - 1 do
					entries[#entries + 1] = nested_entries[z]
				end
			end
		end
	return entries
end

-- Returns the content of all nested entries of self entry_list
function Entry_list:get_content(offset)
	if self.content == nil or true then --todo
		local lines = {}
		local offset = offset or 0 
		for i = 1, self:size() - 1 do
			lines[#lines + 1] = self:get_entry(i):get_content(offset) .. (i < self:size() - 1 and '\n' or '')
			if self:get_entry(i).is_open == true then
				nested_entries = self:get_entry(i):get_entry_list():get_content(offset + 1)
				for z = 1, #nested_entries - 1 do
					lines[#lines + 1] = nested_entries[z]
				end
			end
		end
		self.content = lines
	end
	return self.content
end

function Entry_list:get_entry(index)
    return self.list[index]
end

return Entry_list