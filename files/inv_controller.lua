dofile_once( "mods/index_core/files/_lib.lua" )

local controller_id = GetUpdatedEntityID()

--continously disable itempickupper and inventorygui
--check controls comp to set enabled or not (forced_state -1 is always disabled and 1 is always enabled)

--bars