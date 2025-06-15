local gonna_die = true
local entity_id, comp_id = GetUpdatedEntityID(), GetUpdatedComponentID()
local action_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "InteractableComponent" ) or 0
if( action_comp > 0 ) then
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