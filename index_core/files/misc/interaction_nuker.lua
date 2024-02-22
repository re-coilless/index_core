local entity_id, comp_id = GetUpdatedEntityID(), GetUpdatedComponentID()
local gonna_die = true

local action_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "InteractableComponent" )
if( action_comp ~= nil ) then
    if( ComponentGetIsEnabled( action_comp )) then
        if( ComponentGetValue2( comp_id, "execute_on_added" )) then
            ComponentSetValue2( comp_id, "execute_on_added", false )
            gonna_die = false
        end
        EntitySetComponentIsEnabled( entity_id, action_comp, gonna_die )
    else
        EntitySetComponentIsEnabled( entity_id, action_comp, true )
        gonna_die = false
    end
end

if( gonna_die ) then
    EntityRemoveComponent( entity_id, comp_id )
end