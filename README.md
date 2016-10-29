Author: Brimstone

addon: closetCleaner

This addon is used in conjuction with gearswap to help find unneeded gear, all the include files are copies of those from the gearswap
addon except for closetCleaner.lua and ccConfig.lua

ccConfig should be setup, you will need to list your jobs that you actively play and keep gear for. You can also setup ignore lists so 
things like furniture, food, ninja tools, meds, helm items etc... are not tallied. You may also specify a max item count to limit the size of the report
as well as skip entire bags when searching current gear. 

To use this addon download and create a folder called closetCleaner in you .../Windower4/addons directory. This will look for files named
either <playername>_<job>.lua or <job>.lua in ../gearswap/data directory (only those specified in the ccjobs list)

It will tally up all the gear inside the init_gear_sets() function which are in the 'sets' tables. If you have sets defined elsewhere it will not be counted, if you have
sets defined in tables which are not in the 'sets' table space it will not be recognized. It only looks for items where the table key matches a slot 
(ie head, back, waist etc...) if you have aliased augmented items make sure the variable is defined inside init_gear_sets(). Setting one table name equal 
to another will cause a stack overflow (ie sets.A = sets.B crashes however sets.A = set_combine(sets.B, {}) will work) 

Output report should be: .../Windower4/closetCleaner/report/<playername>_report.txt

To use simply type: //lua l closetCleaner
Then: //cc report

If you change the config file, you'll need to //lua r closetCleaner, if you only change your <job>.lua files you can just rerun //cc report

Known issues:
1. it will not process include files  (except for organizer-lib)
2. it will not process gear outside the scope mentioned above (I'd like to fix this once some of these other limitations are handled)
3. it will not handle windower.raw_register_event statements (just comment them out before running //cc report)