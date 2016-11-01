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

function table_invert(t)
	local s={}
	for k,v in pairs(t) do	
		s[v]=k
	end
	return s
end

windower.register_event('addon command',function (...)
    windower.debug('addon command')
    local splitup = {...}
    if not splitup[1] then return end -- handles //cu
    
    for i,v in pairs(splitup) do splitup[i] = windower.from_shift_jis(windower.convert_auto_trans(v)) end

    local cmd = table.remove(splitup,1):lower()
	
	-- create file
	if not windower.dir_exists(windower.addon_path..'report') then
        windower.create_dir(windower.addon_path..'report')
    end
	local path = windower.addon_path..'report/'..player.name
    -- path = path..os.date(' %H %M %S%p  %y-%d-%m')
	-- if (not overwrite_existing) and windower.file_exists(path..'.lua') then
		-- path = path..' '..os.clock()
	-- end
	
	itemsBylongName = T{}
	itemsByName = T{}
	inventoryGear = T{}
	gsGear = T{}
	for k,v in pairs(res.items) do
		itemsBylongName[res.items[k].enl:lower()] = k
		itemsByName[res.items[k].en:lower()] = k
	end
    
	require 'ccConfig'
    if cmd == 'inv' then
        export_inv(path)
    elseif cmd == 'sets' then
        export_sets(path)
    elseif cmd == 'report' then
        run_report(path)
    elseif strip(cmd) == 'help' then
        print('closetCleaner: Valid commands are:')
        print(' inv   : Exports all items in inventory to closetCleaner/report/<playername>_inventory.txt.')
        print(' sets  : Exports all items gearswap/<job>.lua files to closetCleaner/report/<playername>_sets.txt.')
        print(' report  : Generates full usage report closetCleaner/report/<playername>_report.txt.')
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

function export_inv(path)
    reportName = path..'_inventory.txt'
    local f = io.open(reportName,'w+')
	f:write('closetCleaner Inventory Report:\n')
	f:write('=====================\n\n')
		
	local item_list = T{}
	checkbag = true 
	for n = 0, #res.bags do
		for i,v in ipairs(skipBags) do
			if res.bags[n].english == v then
				checkbag = false
			else	
				checkbag = true
			end
		end
		if checkbag then 
			for i,v in ipairs(get_item_list(items[res.bags[n].english:gsub(' ', ''):lower()])) do
				if v.name ~= empty then
					local slot = xmlify(tostring(v.slot))
					local name = xmlify(tostring(v.name)):gsub('NUM1','1')
					
					if itemsByName[name:lower()] ~= nil then
						itemid = itemsByName[name:lower()]
					elseif itemsBylongName[name:lower()] ~= nil then
						itemid = itemsBylongName[name:lower()]
					else
						print("Item: "..name.." not found in resources!")
					end
					f:write("Name: "..name.." Slot: "..slot.." Bag: "..res.bags[n].english.."\n")
					-- f:write(name.." id: "..itemid.."\n")
					-- f:write(name.."\n")
					if inventoryGear[itemid] == nil then 
						inventoryGear[itemid] = res.bags[n].english
					else
						inventoryGear[itemid] = inventoryGear[itemid]..", "..res.bags[n].english
					end
				end
			end
		end
	end
	f:close()
	print("File created: "..reportName)
end

-- Dummy include function
function include(str)
	-- No need to do anything with this
	if str == 'organizer-lib.lua' then
		return
	end
end

function export_sets(path)
	reportName = path..'_sets.txt'
    local f = io.open(reportName,'w+')
	f:write('closetCleaner sets Report:\n')
	f:write('=====================\n\n')
		
	supersets = {}
	sets = {}
	info = {}
	gear = {}
	sets.precast = {}
	sets.midcast = {}
	sets.precast.Pet = {}
	sets.midcast.Pet = {}
	sets.precast.JA = {}
	sets.defense = {}
	sets.buff = {}
	
	fpath = windower.addon_path:gsub('\\','/')
	fpath = fpath:gsub('//','/')
	gspath = fpath:gsub('closetCleaner\/','')..'gearswap/'
	dpath = gspath..'data/'
	for i,v in ipairs(ccjobs) do
		lname = string.lower(dpath..player.name..'_'..v..'.lua')
		lgname = string.lower(dpath..player.name..'_'..v..'_gear.lua')
		sname = string.lower(dpath..v..'.lua')
		sgname = string.lower(dpath..v..'_gear.lua')
		if windower.file_exists(lgname) then
			dofile(lgname)
			init_gear_sets()
			supersets[v] = deepcopy(sets)
		elseif windower.file_exists(lname) then
			dofile(lname)
			init_gear_sets()
			supersets[v] = deepcopy(sets)
		elseif windower.file_exists(sgname) then
			dofile(sgname)
			init_gear_sets()
			supersets[v] = deepcopy(sets)
		elseif windower.file_exists(sname) then
			dofile(sname)
			init_gear_sets()
			supersets[v] = deepcopy(sets)
		else
		   print('lua file for '..v..' not found!')
		end
	end
	
	list_sets( supersets , f ) 
 	f:close()
	print("File created: "..reportName)
end

function list_sets ( t, f )  
	write_sets = T{}
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
						f:write("\nval: "..val)
						if val ~= "" and val ~= "empty" then 
							if pos == "name" or pos == "main" or pos == "sub" or pos == "range" or pos == "ammo" or pos == "head" or pos == "neck" or pos == "left_ear" or pos == "right_ear" or pos == "body" or pos == "hands" or pos == "left_ring" or pos == "right_ring" or pos == "back" or pos == "waist" or pos == "legs" or pos == "feet" then
								if itemsByName[val:lower()] ~= nil then
									itemid = itemsByName[val:lower()]
								elseif itemsBylongName[val:lower()] ~= nil then
									itemid = itemsBylongName[val:lower()]
								else
									print("Item: '"..val.."' not found in resources! "..pos)
								end
								if write_sets[itemid] == nil then
									write_sets[itemid] = 1
								else	
									write_sets[itemid] = write_sets[itemid] + 1
								end
							end
						end
                    else
                        print("Error: Val needs to be table or string")
                    end
                end
            end
        end
    end
    sub_print_r(t,"  ")
	data = T{"Name", "Count", "Long Name"}
	form = T{"%22s", "%10s", "%60s"}
	print_row(f, data, form)
	print_break(f, form)
	f:write('\n')
	for k,v in pairs(write_sets) do
		data = T{res.items[k].en, tostring(v), res.items[k].enl}
		print_row(f, data, form)
		gsGear[k] = v
	end
    f:write()
end

-- pass in file handle and a table of formats and table of data
function print_row(f, data, form)
	for k,v in pairs(data) do
		f:write(string.format(form[k], v..' | '))
	end
	f:write('\n')
end

-- pass in file handle and a table of formats and table of data
-- Subtract 3 because above the column break is included in the format 
function print_break(f, form)
	for k,v in pairs(form) do
		number = string.match(v,"%d+")
		for i=1,number-3 do
			f:write('-')
		end
		f:write(' | ')
	end
	f:write('\n')
end

function run_report(path)
	mainReportName = path..'_report.txt'
	ignoredReportName = path..'_ignored.txt'
    local f = io.open(mainReportName,'w+')
    local f2 = io.open(ignoredReportName,'w+')
	f:write('closetCleaner Report:\n')
	f:write('=====================\n\n')
	f2:write('closetCleaner ignored Report:\n')
	f2:write('=====================\n\n')
	export_inv(path)
	export_sets(path)
	for k,v in pairs(inventoryGear) do
		if gsGear[k] == nil then
			gsGear[k] = 0
		end
	end
	data = T{"Name", "Count", "Location", "Long Name"}
	form = T{"%25s", "%10s", "%20s", "%60s"}
	print_row(f, data, form)
	print_break(f, form)
	print_row(f2, data, form)
	print_break(f2, form)
	-- f:write('\n')
	for k,v in spairs(gsGear, function(t,a,b) return t[b] > t[a] end) do
		if ccmaxuse == nil or v <= ccmaxuse then
			printthis = 1
			for i,s in ipairs(ccignore) do
				if string.match(res.items[k].en, s) or string.match(res.items[k].en, s) then
					printthis = nil
					if inventoryGear[k] == nil then
						data = T{res.items[k].en, tostring(v), "NOT FOUND", res.items[k].enl}
					else
						data = T{res.items[k].en, tostring(v), inventoryGear[k], res.items[k].enl}
					end
					print_row(f2, data, form)
					break
				end 
			end
			if printthis then
				if inventoryGear[k] == nil then
					data = T{res.items[k].en, tostring(v), "NOT FOUND", res.items[k].enl}
				else
					data = T{res.items[k].en, tostring(v), inventoryGear[k], res.items[k].enl}
				end
				print_row(f, data, form)
			end
		end
	end
	f:close()
	f2:close()
	print("File created: "..mainReportName)
	print("File created: "..ignoredReportName)
end

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end