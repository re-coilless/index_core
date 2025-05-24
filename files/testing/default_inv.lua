return function( pic_x, pic_y, inv_info, xys, slot_func )
    local inv_id = inv_info.id
    if( EntityGetRootEntity( inv_id ) ~= inv_id ) then return end
    if( index.D.is_opened and index.D.gmod.allow_external_inventories ) then
        local w, h, step = 0, 0, 1
        
        local slot_data = index.D.slot_state[ inv_id ]
        local offset_x, offset_y = 9*#slot_data + step, 9*#slot_data[1] + step
        local core_x, core_y = pic_x - offset_x, pic_y - offset_y
        pic_x, pic_y = core_x, core_y
        for i,col in pairs( slot_data ) do
            for e,slot in ipairs( col ) do
                w, h = index.new_generic_slot( pic_x, pic_y, {
                    inv_slot = { i, e },
                    inv_id = inv_id, id = slot,
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
        
        local pic = pen.magic_storage( inv_id, "index_loot_marker", "value_string" ) or index.D.loot_marker
        
        local alpha = 0.7
        local w, h = pen.get_pic_dims( pic )
        local clicked, _, is_hovered = pen.new_image( pic_x - w/2, pic_y - w/2, pen.LAYERS.WORLD_BACK + 0.001,
            pic, { color = pen.PALETTE.SHADOW, alpha = 0.3, can_click = true })
        if( not( index.D.is_opened )) then
            index.D.tip_func( index.is_inv_empty( index.D.slot_state[ inv_id ]) and "[OPEN]" or "[LOOT]", { is_active = is_hovered })
            if( is_hovered ) then alpha = 1 end
            if( clicked ) then
                index.D.inv_toggle = true
                for i,gmod in ipairs( index.D.gmods ) do
                    if( gmod.allow_external_inventories ) then
                        GlobalsSetValue( index.GLOBAL_GLOBAL_MODE, tostring( i ))
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