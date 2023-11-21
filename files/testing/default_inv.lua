return function( gui, uid, pic_x, pic_y, inv_data, data, zs, xys, slot_func )
    local inv_id = inv_data.id
    if( EntityGetRootEntity( inv_id ) == inv_id ) then
        local this_data = data.item_list
        if( #this_data > 0 and data.is_opened and data.gmod.allow_external_inventories ) then
            local w, h, step = 0, 0, 1

            local slot_data = data.slot_state[ inv_id ]
            local offset_x, offset_y = 9*#slot_data + step, 9*#slot_data[1] + step
            local core_x, core_y = pic_x - offset_x, pic_y - offset_y
            pic_x, pic_y = core_x, core_y
            for i,col in pairs( slot_data ) do
                for e,slot in ipairs( col ) do
                    uid, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, slot_func, {
                        inv_id = inv_id,
                        id = slot,
                        inv_slot = {i,e},
                    }, data.is_opened, 1 )
                    pic_x, pic_y = pic_x, pic_y + h + step
                end
                pic_x, pic_y = pic_x + w + step, core_y
            end
        else --make it shake periodically + allow overriding pic
            local alpha, clicked, is_hovered = 0.7, false, false
            local w,h = get_pic_dim( data.loot_marker )
            colourer( data.the_gui, {0,0,0} )
            uid = new_image( data.the_gui, uid, pic_x - w/2, pic_y - w/2, zs.in_world_back + 0.0001, data.loot_marker, nil, nil, 0.3, true )
            if( not( data.is_opened )) then
                clicked,_,is_hovered = GuiGetPreviousWidgetInfo( data.the_gui )
                uid = new_vanilla_tooltip( data.the_gui, uid, nil, zs.tips, { is_inv_empty( data.slot_state[ inv_id ]) and "[OPEN]" or "[LOOT]" }, nil, is_hovered )
                if( is_hovered ) then alpha = 1 end
                if( clicked ) then
                    data.is_opened = true
                    for i,gmod in ipairs( data.gmod.gmods ) do
                        if( gmod.allow_external_inventories ) then
                            ComponentSetValue2( get_storage( data.main_id, "global_mode" ), "value_int", i )
                            break
                        end
                    end
                end
            end
            
            local extra_scale = 16/18
            uid = new_image( gui, uid, pic_x - w/2 + 1, pic_y - w/2 + 1, zs.in_world_back, data.loot_marker, extra_scale, extra_scale, alpha )
        end
    end

    return uid, data
end