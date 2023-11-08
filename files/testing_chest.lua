return function( gui, uid, pic_x, pic_y, inv_data, data, zs, xys, slot_func )
    local this_data = data.inv_list
    if( #this_data > 0 ) then
        local w, h, step = 0, 0, 1

        local offset = 16 + step
        local core_x, core_y = pic_x - offset, pic_y - offset
        pic_x, pic_y = core_x, core_y

        --open only if the full inv is active + inv managing mode is engaged, else show the indicator that is lootable
        
        local inv_id = inv_data.id
        local inv_data = data.slot_state[ inv_id ]
        for i,line in ipairs( inv_data ) do
            for e,slot in ipairs( line ) do
                uid, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, this_data, slot_func, slot, w, h, "universal", inv_id, {i,-e}, true )
                pic_x, pic_y = pic_x + w + step, pic_y
            end
            pic_x, pic_y = core_x, pic_y + h + step
        end
    end

    return uid, data
end