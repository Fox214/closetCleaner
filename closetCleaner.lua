_addon.name = 'closetCleaner'
_addon.version = '0'
_addon.author = 'Brimstone'
_addon.commands = {'cc','closetCleaner'}

if windower.file_exists(windower.addon_path..'data/bootstrap.lua') then
    debugging = {windower_debug = true,command_registry = false,general=false,logging=false}
else
    debugging = {}
end

__raw = {lower = string.lower, upper = string.upper, debug=windower.debug,text={create=windower.text.create,
    delete=windower.text.delete,registry = {}},prim={create=windower.prim.create,delete=windower.prim.delete,registry={}}}


language = 'english'
file = require 'files'
require 'strings'
require 'tables'
require 'logger'
-- Restore the normal error function (logger changes it)
error = _raw.error

require 'lists'
require 'sets'


windower.text.create = function (str)
    if __raw.text.registry[str] then
        msg.addon_msg(123,'Text object cannot be created because it already exists.')
    else
        __raw.text.registry[str] = true
        __raw.text.create(str)
    end
end

windower.text.delete = function (str)
    if __raw.text.registry[str] then
        local library = false
        if windower.text.saved_texts then
            for i,v in pairs(windower.text.saved_texts) do
                if v._name == str then
                    __raw.text.registry[str] = nil
                    windower.text.saved_texts[i]:destroy()
                    library = true
                    break
                end
            end
        end
        if not library then
            -- Text was not created through the library, so delete it normally
            __raw.text.registry[str] = nil
            __raw.text.delete(str)
        end
    else
        __raw.text.delete(str)
    end
end

windower.prim.create = function (str)
    if __raw.prim.registry[str] then
        msg.addon_msg(123,'Primitive cannot be created because it already exists.')
    else
        __raw.prim.registry[str] = true
        __raw.prim.create(str)
    end
end

windower.prim.delete = function (str)
    if __raw.prim.registry[str] then
        __raw.prim.registry[str] = nil
        __raw.prim.delete(str)
    else
        __raw.prim.delete(str)
    end
end

texts = require 'texts'
require 'pack'
bit = require 'bit'
socket = require 'socket'
mime = require 'mime'
res = require 'resources'
extdata = require 'extdata'
require 'helper_functions'
require 'actions'
packets = require 'packets'

-- Resources Checks
if res.items and res.bags and res.slots and res.statuses and res.jobs and res.elements and res.skills and res.buffs and res.spells and res.job_abilities and res.weapon_skills and res.monster_abilities and res.action_messages and res.skills and res.monstrosity and res.weather and res.moon_phases and res.races then
else
    error('Missing resources!')
end

require 'packet_parsing'
require 'statics'
require 'equip_processing'
require 'targets'
require 'user_functions'
require 'refresh'
require 'export'
require 'validate'
require 'flow'
require 'triggers'

initialize_packet_parsing()
gearswap_disabled = false

windower.register_event('load',function()
    windower.debug('load')
    refresh_globals()
    
    if world.logged_in then
        refresh_user_env()
        if debugging.general then windower.send_command('@unload spellcast;') end
    end
end)

windower.register_event('unload',function ()
    windower.debug('unload')
    user_pcall('file_unload')
    if logging then logfile:close() end
end)

windower.register_event('addon command',function (...)
    windower.debug('addon command')
    -- logit('\n\n'..tostring(os.clock)..table.concat({...},' '))
    local splitup = {...}
    if not splitup[1] then return end -- handles //cu
    
    for i,v in pairs(splitup) do splitup[i] = windower.from_shift_jis(windower.convert_auto_trans(v)) end

    local cmd = table.remove(splitup,1):lower()
    
    if cmd == 'inv' then
        export_inv()
    elseif cmd == 'sets' then
        export_sets()
    elseif cmd == 'test' then
        run_test()
    elseif strip(cmd) == 'help' then
        print('closetCleaner: Valid commands are:')
        print(' inv   : Exports all items in inventory to closetCleaner/report/<playername>.txt.')
        print(' sets  : Exports all items gearswap/<job>.lua files to closetCleaner/report/sets.txt.')
    else
        local handled = false
        if not gearswap_disabled then
            for i,v in ipairs(unhandled_command_events) do
                handled = equip_sets(v,nil,cmd,unpack(splitup))
                if handled then break end
            end
        end
        if not handled then
            print('checkusage: Command not found')
        end
    end
end)

function export_inv()
	-- create file
	if not windower.dir_exists(windower.addon_path..'report') then
        windower.create_dir(windower.addon_path..'report')
    end
    
    local path = windower.addon_path..'report/'..player.name
    -- path = path..os.date(' %H %M %S%p  %y-%d-%m')
	-- if (not overwrite_existing) and windower.file_exists(path..'.lua') then
		-- path = path..' '..os.clock()
	-- end
	local f = io.open(path..'.txt','w+')
	f:write('closetCleaner Report:\n')
	f:write('=====================\n\n')
		
	local item_list = T{}
	for i = 0, #res.bags do
		item_list:extend(get_item_list(items[res.bags[i].english:gsub(' ', ''):lower()]))
	end
	for i,v in ipairs(item_list) do
		if v.name ~= empty then
			local slot = xmlify(tostring(v.slot))
			local name = xmlify(tostring(v.name))
			f:write(name.." < name slot > "..slot.."\n")
		end
	end
	f:close()
end

function export_sets()
	-- create file
	if not windower.dir_exists(windower.addon_path..'report') then
        windower.create_dir(windower.addon_path..'report')
    end
    
    local path = windower.addon_path..'report/sets'
    -- path = path..os.date(' %H %M %S%p  %y-%d-%m')
	-- if (not overwrite_existing) and windower.file_exists(path..'.lua') then
		-- path = path..' '..os.clock()
	-- end
	local f = io.open(path..'.txt','w+')
	f:write('closetCleaner sets Report:\n')
	f:write('=====================\n\n')
		
	local item_list = T{}
	list_sets( sets, f ) 
	-- f:write(table.tostring( sets ))
	-- f:write(table.val_to_str( sets ))
	-- f:write(table.values( sets ))
 	f:close()
end

function run_test()
	-- create file
	if not windower.dir_exists(windower.addon_path..'report') then
        windower.create_dir(windower.addon_path..'report')
    end
    
    local path = windower.addon_path..'report/'..player.name
    -- path = path..os.date(' %H %M %S%p  %y-%d-%m')
	-- if (not overwrite_existing) and windower.file_exists(path..'.lua') then
		-- path = path..' '..os.clock()
	-- end
	local f = io.open(path..'.txt','w+')
	f:write('closetCleaner Report:\n')
	f:write('=====================\n\n')
		
	local item_list = T{}
	for i = 0, #res.bags do
		item_list:extend(get_item_list(items[res.bags[i].english:gsub(' ', ''):lower()]))
		-- f:write(items[res.bags[i].english].." is item \n")
	end
	-- for _,item in ipairs(res.bags) do
		-- f:write(item.name.." is item \n")
	    -- if item.id ~= 0 and tryfilter(lowercase_name(get_log_name_by_item_id(item.id)), filter) then
            -- if not find_in_sets(item, sets) then
                -- extra_bag_items:add(item)
            -- end
        -- end
    -- end
	for i,v in ipairs(item_list) do
	-- for i = 0 , #item_list do
		if v.name ~= empty then
			local slot = xmlify(tostring(v.slot))
			local name = xmlify(tostring(v.name))
			f:write(name.." < name slot > "..slot.."\n")
			-- f:write(item_list[i].." < name slot > "..item_list[i].."\n")
			if slot ~= 'item' then
				-- mygear = name
				mygear = item_list[i]
				-- if search_sets(mygear, sets) then 
				if find_in_sets(mygear, sets) then 
					f:write(mygear.." is in sets!!!!! \n")
				else
					f:write(mygear.." unused! \n")
				end
			end
		end
	end
	-- for slot_name,gs_item_tab in pairs(table.reassign({},items.equipment)) do -- Not sure why I have to reassign it here
		-- if gs_item_tab.slot ~= empty then
			-- local item_tab
			-- local bag_name = to_windower_bag_api(res.bags[gs_item_tab.bag_id].en)
			-- if res.items[items[bag_name][gs_item_tab.slot].id] then
				-- print(res.items[items[bag_name][gs_item_tab.slot].id] )
				-- item_tab = items[bag_name][gs_item_tab.slot]
				-- item_list[slot_map[slot_name]+1] = {
					-- name = res.items[item_tab.id][language],
					-- slot = slot_name
					-- }
				-- f:write(item_list[slot_map[slot_name]+1].name.." < name slot > "..item_list[slot_map[slot_name]+1].slot.."\n")
				-- if item_list[slot_map[slot_name]+1].slot ~= 'item' then
					-- mygear = item_list[slot_map[slot_name]+1].name
					-- if search_sets(mygear, sets) then 
						-- f:write(mygear.." is in sets!!!!! \n")
					-- else
						-- f:write(mygear.." unused! \n")
					-- end
				-- end
				
			-- else
				-- msg.addon_msg(123,'Item is not in the resources yet.')
			-- end
		-- end
    -- end
	f:close()
end

-- Utility function to help search sets
function search_sets(item, tab, stack)
    if stack and stack:contains(tab) then
        return false
    end

    local item_short_name = lowercase_name(item)
    local item_log_name = lowercase_name(item.."_log")

    for _,v in pairs(tab) do
        local name = (type(v) == 'table' and v.name) or v
        local aug = (type(v) == 'table' and (v.augments or v.augment))
        if type(aug) == 'string' then aug = {aug} end
        if type(name) == 'string' then
            if cmp_item(item, name, aug, item_short_name, item_log_name) then
                return true
            end
        elseif type(v) == 'table' then
            if not stack then stack = S{} end

            stack:add(tab)
            local try = search_sets(item, v, stack)
            stack:remove(tab)

            if try then
                return true
            end
        end
    end
    
    return false
end

-- Utility function to compare items that may possibly be augmented.
function cmp_item(item, name, aug, item_short_name, item_log_name)
    
    name = lowercase_name(name)
    item_short_name = lowercase_name(item_short_name)
    item_log_name = lowercase_name(item_log_name)

    if item_short_name == name or item_log_name == name then
        if not aug or extdata.compare_augments(aug, extdata.decode(item).augments) then
            return true
        end
    end
    
    return false
end

function print_r ( t, f )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            f:write(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        f:write(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        f:write(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        f:write(indent.."["..pos..'] => "'..val..'"\n')
                    else
                        f:write(indent.."["..pos.."] => "..tostring(val)..'\n')
                    end
                end
            else
                f:write(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        f:write(tostring(t).." {")
        sub_print_r(t,"  ")
        f:write("}")
    else
        sub_print_r(t,"  ")
    end
    f:write()
end

write_sets = T{}
function list_sets ( t, f )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            -- f:write(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        -- f:write(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        -- f:write(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
						if pos == "name" or pos == "main" or pos == "sub" or pos == "ranged" or pos == "ammo" or pos == "head" or pos == "neck" or pos == "left_ear" or pos == "right_ear" or pos == "body" or pos == "hands" or pos == "left_ring" or pos == "right_ring" or pos == "back" or pos == "waist" or pos == "legs" or pos == "feet" then
							if write_sets[val] == nil then
								-- count = table_count(t, val)
								write_sets[val] = 1
								-- write_sets[val] = 2
								-- f:write('"'..val..'" #'..count..'\n')
							else	
								gcs = tostring(write_sets[val])
								gcn = tonumber(write_sets[val])
								gca = write_sets[val] + 1
								f:write('else"'..val..'" #'..gca..'\n')
								write_sets[val] = gcs
							end
							-- f:write('"'..val..'" #'..write_sets[val]..'\n')
						end
                    else
                        -- f:write(indent.."["..pos.."] => "..tostring(val)..'\n')
                    end
                end
            else
                -- f:write(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        -- f:write(tostring(t).." {")
        sub_print_r(t,"  ")
        -- f:write("}")
    else
        sub_print_r(t,"  ")
    end
	for k,v in pairs(write_sets) do
		f:write('"'..k..'" #'..v..'\n')
	end
    f:write()
end

function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, ",\n" ) .. "}"
end

function table.values( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result, table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, ",\n" ) .. "}"
end

-- Count the number of times a value occurs in a table 
function table_count(tt, item)
  local count
  count = 0
  for ii,xx in pairs(tt) do
    if item == xx then count = count + 1 end
  end
  return count
end