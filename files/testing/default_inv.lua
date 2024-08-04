return function( pic_x, pic_y, inv_data, xys, slot_func )
    local inv_id = inv_data.id
    if( EntityGetRootEntity( inv_id ) == inv_id ) then
        local this_data = index.D.item_list
        if( #this_data > 0 and index.D.is_opened and index.D.gmod.allow_external_inventories ) then
            local w, h, step = 0, 0, 1
            
            local slot_data = index.D.slot_state[ inv_id ]
            local offset_x, offset_y = 9*#slot_data + step, 9*#slot_data[1] + step
            local core_x, core_y = pic_x - offset_x, pic_y - offset_y
            pic_x, pic_y = core_x, core_y
            for i,col in pairs( slot_data ) do
                for e,slot in ipairs( col ) do
                    w, h = slot_setup( pic_x, pic_y, {
                        inv_id = inv_id,
                        id = slot,
                        inv_slot = {i,e},
                    }, index.D.is_opened, 1 )
                    pic_x, pic_y = pic_x, pic_y + h + step
                end
                pic_x, pic_y = pic_x + w + step, core_y
            end
        else
            if( not( index.D.is_opened )) then
                local anim_var = index.D.frame_num%200
                if( anim_var < 30 ) then
                    pic_y = pic_y + ( 0.15*( anim_var - 15 ))^2 - 5.06
                end
            end
            
            local pic = pen.magic_storage( inv_id, "loot_marker", "value_string" ) or index.D.loot_marker
            
            local alpha = 0.7
            local w, h = pen.get_pic_dims( pic )
            local clicked, _, is_hovered = pen.new_image( pic_x - w/2, pic_y - w/2, pen.LAYERS.WORLD_BACK + 0.0001,
                pic, { color = {0,0,0}, alpha = 0.3, can_click = true })
            if( not( index.D.is_opened )) then
                index.D.tip_func( nil, pen.LAYERS.TIPS, { index.is_inv_empty( index.D.slot_state[ inv_id ]) and "[OPEN]" or "[LOOT]" }, nil, is_hovered )
                if( is_hovered ) then alpha = 1 end
                if( clicked ) then
                    index.D.inv_toggle = true
                    for i,gmod in ipairs( index.D.gmod.gmods ) do
                        if( gmod.allow_external_inventories ) then
                            pen.magic_storage( index.D.main_id, "global_mode", "value_int", i )
                            break
                        end
                    end
                end
            end
            
            local extra_scale = 16/18
            pen.new_image( pic_x - w/2 + 1, pic_y - w/2 + 1, pen.LAYERS.WORLD_BACK,
                index.D.loot_marker, { s_x = extra_scale, s_y = extra_scale, alpha = alpha })
        end
    end
end