dofile_once( "mods/index_core/files/_lib.lua" )

local controller_id = GetUpdatedEntityID()
local hooman = EntityGetParent( controller_id )

local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
local ctrl_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ControlsComponent" )

local comp_nuker = { iui_comp, pick_comp }
for i,comp in ipairs( comp_nuker ) do
    if( comp ~= nil and ComponentGetIsEnabled( comp )) then
        EntitySetComponentIsEnabled( hooman, comp, false )
    end
end

local forced_state = ComponentGetValue2( get_storage( controller_id, "forced_state" ), "value_int" )
local is_going = forced_state > 0
if( forced_state == 0 ) then
    is_going = ComponentGetValue2( ctrl_comp, "enabled" )
end

--bars