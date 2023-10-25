dofile_once( "mods/index_core/files/_lib.lua" )

function new_generic_inventory( gui, uid, screen_w, screen_h, data, zs, xys, slot_func )
    local pic_x, pic_y = 0, 0

    --clicking on item should switch to it
    local this_data = data.inv_list
    if( not( data.hide_on_empty ) or #this_data > 0 ) then
        if( data.is_opened ) then
            uid = new_image( gui, uid, pic_x, pic_y, zs.background, "data/ui_gfx/inventory/background.png" )
        end
        pic_x, pic_y = 19, 20

        local function call_em_all( slot, w, h, inv_type, inv_id, slot_num )
            local item = slot and from_tbl_with_id( this_data, slot ) or {id=-1}
            local slot_data = {item.id,inv_id,slot_num}
            local type_callbacks = data.inv_types[item.kind]
            uid, data, w, h = slot_func( gui, uid, pic_x, pic_y, zs, data, slot_data, item, type_callbacks, inv_type, item.id == data.active_item )
            if( type_callbacks ~= nil and type_callbacks.on_inventory ~= nil ) then
                uid, data = type_callbacks.on_inventory( gui, uid, item.id, data, item, pic_x, pic_y, zs, data.is_opened, item.id == data.active_item )
            end
            
            return w, h
        end
        
        local w, h, step = 0, 0, 1

        local inv_id = get_hooman_child( data.player_id, "inventory_quick" )
        local inv_data = data.slot_state.quickest
        for i,slot in ipairs( inv_data ) do
            w, h = call_em_all( slot, w, h, "quickest", inv_id, {i,0})
            pic_x, pic_y = pic_x + w + step, pic_y
        end

        pic_x = pic_x + 2
        inv_data = data.slot_state.quick
        for i,slot in ipairs( inv_data ) do
            w, h = call_em_all( slot, w, h, "quick", inv_id, {i,1})
            pic_x, pic_y = pic_x + w + step, pic_y
        end

        if( data.is_opened ) then
            pic_x = pic_x + 9
            inv_id = get_hooman_child( data.player_id, "inventory_full" )
            inv_data = data.slot_state.full
            for i,line in ipairs( inv_data ) do
                for e,slot in ipairs( line ) do
                    w, h = call_em_all( slot, w, h, "full", inv_id, {i,-e})
                    pic_x, pic_y = pic_x + w + step, pic_y
                end
            end
        end
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_hp( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = screen_w - 41, 20
    local red_shift = 0

    local this_data = data.DamageModel
    if( #this_data > 0 and ComponentGetIsEnabled( this_data[1])) then
        local max_hp = this_data[2]
        if( max_hp > 0 ) then
            local length = math.floor( 157.8 - 307.1/( 1 + ( math.min( math.max( max_hp, 0 ), 40 )/0.38 )^( 0.232 )) + 0.5 )
            length = length < 5 and 40 or length
            
            local hp = math.min( math.max( this_data[3], 0 ), max_hp )
            local low_hp = math.max( math.min( max_hp/4, data.hp_threshold ), data.hp_threshold_min )
            local pic = "data/ui_gfx/hud/colors_health_bar.png"
            if( hp < low_hp ) then
                local perc = ( low_hp - hp )/low_hp
                local freq = data.hp_flashing*( 1.5 - perc )
                
                data.memo.hp_flashing = data.memo.hp_flashing or {}
                if( freq ~= data.memo.hp_flashing[1] or -1 ) then
                    local freq_old = data.memo.hp_flashing[1] or 1
                    data.memo.hp_flashing = { freq, freq*( data.memo.hp_flashing[2] or 1 )/freq_old }
                end
                if( data.memo.hp_flashing[2] > 4*freq ) then
                    data.memo.hp_flashing[2] = data.memo.hp_flashing[2] - 4*freq
                end
                red_shift = 0.5*( math.sin((( data.memo.hp_flashing[2] + freq )*math.pi )/( 2*freq )) + 1 )
                data.memo.hp_flashing[2] = data.memo.hp_flashing[2] + 1

                if( red_shift > 0.5 ) then
                    uid = new_image( gui, uid, pic_x - ( length + 1 ), pic_y, zs.main_back - 0.001, "data/ui_gfx/hud/colors_health_bar_bg_low_hp.png", ( length + 2 )/2, 3 )
                else
                    pic = "data/ui_gfx/hud/colors_health_bar_damage.png"
                end
                red_shift = red_shift*perc
            end
            if( this_data[5] < 31 ) then
                local last_hp = math.min( math.max( this_data[4], 0 ), max_hp )
                uid = new_image( gui, uid, pic_x - length, pic_y + 1, zs.main + 0.001, "data/ui_gfx/hud/colors_health_bar_damage.png", 0.5*length*last_hp/max_hp, 2, ( 30 - this_data[5])/30 )
            end
            
            max_hp = math.min( math.floor( max_hp*25 + 0.5 ), 9e99 )
            hp = math.min( math.floor( hp*25 + 0.5 ), 9e99 )
            local max_hp_text = get_short_num( max_hp )
            local hp_text = get_short_num( hp )
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/health.png" )
            uid = new_font_vanilla_small( gui, uid, pic_x + 13, pic_y, zs.main, hp_text, { 255, 255, 255, 0.9 })
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {length,4,length*hp/max_hp}, pic )
            
            local tip = hud_text_fix( "$hud_health" )..( data.short_hp and hp_text.."/"..max_hp_text or hp.."/"..max_hp )
            uid = tipping( gui, uid, {
                pic_x - (length+2),
                pic_y - 1,
                length + 4,
                8,
            }, { tip, pic_x - 43, pic_y + 9 }, {zs.tips,zs.main_far_back}, true )

            pic_y = pic_y + 10
        end
    end
    GameSetPostFxParameter( "low_health_indicator_alpha_proper", data.hp_flashing_intensity*red_shift, 0, 0, 0 )

    return uid, data, {pic_x,pic_y}
end

function new_generic_air( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.hp )

    local this_data = data.DamageModel
    if( #this_data > 0 and ComponentGetIsEnabled( this_data[1])) then
        if( this_data[6] and this_data[7] > this_data[8]) then
            uid = new_font_vanilla_small( gui, uid, pic_x + 3, pic_y - 1, zs.main, "o2", { 255, 255, 255, 0.9 })
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*math.max( this_data[8], 0 )/this_data[7]}, "data/ui_gfx/hud/colors_mana_bar.png", nil, 0.75 )

            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$hud_air" )..hud_num_fix( this_data[8], this_data[7], 2 )
            uid = tipping( gui, uid, {
                pic_x - 42,
                pic_y - 1,
                44,
                6,
            }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

            pic_y = pic_y + 8
        end
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_flight( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.air )
    
    local this_data = data.CharacterData
    if( #this_data > 0 and this_data[2] and this_data[3] > 0 ) then
        if( data.memo.flight_shake == nil ) then
            if( #data.Controls > 0 and data.Controls[4] and this_data[4] <= 0 ) then
                data.memo.flight_shake = data.frame_num + 20
            end
        end
        local shake_frame = ( data.memo.flight_shake or data.frame_num ) - data.frame_num
        uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/jetpack.png" )
        uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*math.max( this_data[4], 0 )/this_data[3]}, "data/ui_gfx/hud/colors_flying_bar.png", data.memo.flight_shake ~= nil and 20-shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = hud_text_fix( "$hud_jetpack" )..hud_num_fix( this_data[4], this_data[3], 2 )
        uid = tipping( gui, uid, {
            pic_x - 42,
            pic_y - 1,
            44,
            6,
        }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

        if( shake_frame < 0 ) then
            data.memo.flight_shake = nil
        end
        pic_y = pic_y + 8
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_mana( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.flight )
    data.memo.mana_shake = data.memo.mana_shake or {}

    local this_data = data.active_info
    if( this_data.id ~= nil ) then
        local potion_data = {}
        local throw_it_back = nil
        
        local value = {0,0}
        if( this_data.wand_info ~= nil ) then
            local mana_max = this_data.wand_info.main[6]
            local mana = this_data.wand_info.main[8]

            value = { math.min( math.max( mana, 0 ), mana_max ), mana_max }
            if( data.memo.mana_shake[data.active_item] == nil ) then
                if( data.no_mana_4life ) then
                    data.memo.mana_shake[data.active_item] = data.frame_num + 20
                end
            end
            local shake_frame = ( data.memo.mana_shake[data.active_item] or data.frame_num ) - data.frame_num
            throw_it_back = data.memo.mana_shake[data.active_item] ~= nil and shake_frame-20 or nil
            if( shake_frame < 0 ) then
                data.memo.mana_shake[data.active_item] = nil
            end
        elseif( this_data.matter_info ~= nil ) then
            if( this_data.matter_info[1] >= 0 ) then
                value = { math.max( this_data.matter_info[2][1], 0 ), this_data.matter_info[1]}
                potion_data = { "data/ui_gfx/hud/potion.png", }
                if( data.fancy_potion_bar ) then
                    table.insert( potion_data, data.pixel )
                    table.insert( potion_data, uint2color( GameGetPotionColorUint( data.active_item )))
                    table.insert( potion_data, 0.8 )
                end
            end
        end
        if( value[1] >= 0 and value[2] > 0 ) then
            local ratio = math.min( value[1]/value[2], 1 )
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, potion_data[1] or "data/ui_gfx/hud/mana.png" )
            if( potion_data[3] ~= nil ) then
                uid = new_image( gui, uid, pic_x - 40, pic_y + 1, zs.main + 0.001, potion_data[2], math.min( 40*ratio + 0.5, 40 ), 2 )
                colourer( gui, potion_data[3])
            end
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*ratio}, potion_data[2] or "data/ui_gfx/hud/colors_mana_bar.png", throw_it_back, potion_data[4])

            local tip = ""
            if( potion_data[3] ~= nil ) then
                local v1, v2 = get_potion_info( entity_id, this_data.name, value[2], value[1], this_data.matter_info[2][2])
                tip = v1.."@"..v2
            else
                tip = hud_text_fix( "$hud_wand_mana" )..hud_num_fix( value[1], value[2])
            end

            local tip_x, tip_y = unpack( xys.hp )
            uid = tipping( gui, uid, {
                pic_x - 42,
                pic_y - 1,
                44,
                6,
            }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

            pic_y = pic_y + 8
        end
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_reload( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.mana )
    data.memo.reload_shake = data.memo.reload_shake or {}
    data.memo.reload_max = data.memo.reload_max or {}
    
    local this_data = data.active_info
    if( this_data.wand_info ~= nil and not( this_data.wand_info.main[9])) then
        local reloading = this_data.wand_info.main[10]
        data.memo.reload_max[data.active_item] = ( data.memo.reload_max[data.active_item] or -1 ) < reloading and reloading or data.memo.reload_max[data.active_item]
        if( data.memo.reload_max[data.active_item] > data.reload_threshold ) then
            if( data.memo.reload_max[data.active_item] ~= reloading ) then
                if( data.memo.reload_shake[data.active_item] == nil and data.just_fired ) then
                    data.memo.reload_shake[data.active_item] = data.frame_num + 20
                end
            end
            
            local shake_frame = ( data.memo.reload_shake[data.active_item] or data.frame_num ) - data.frame_num
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/reload.png" )
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*reloading/data.memo.reload_max[data.active_item]}, "data/ui_gfx/hud/colors_reload_bar.png", data.memo.reload_shake[data.active_item] ~= nil and 20-shake_frame or nil )
            
            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$hud_wand_reload" )..string.format( "%.2f", reloading/60 ).."s"
            uid = tipping( gui, uid, {
                pic_x - 42,
                pic_y - 1,
                44,
                6,
            }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

            if( shake_frame < 0 ) then
                data.memo.reload_shake[data.active_item] = nil
            end
            pic_y = pic_y + 8
        end
    end
    if( this_data.wand_info == nil or ( this_data.wand_info.main[10] or 0 ) == 0 ) then
        data.memo.reload_max[data.active_item] = nil
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_delay( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.reload )
    data.memo.delay_shake = data.memo.delay_shake or {}
    data.memo.delay_max = data.memo.delay_max or {}

    local this_data = data.active_info
    if( this_data.wand_info ~= nil ) then
        local cast_delay = this_data.wand_info.main[11]
        data.memo.delay_max[data.active_item] = ( data.memo.delay_max[data.active_item] or -1 ) < cast_delay and cast_delay or data.memo.delay_max[data.active_item]
        if( data.memo.delay_max[data.active_item] > data.delay_threshold ) then
            if( data.memo.delay_max[data.active_item] ~= cast_delay ) then
                if( data.memo.delay_shake[data.active_item] == nil and data.just_fired ) then
                    data.memo.delay_shake[data.active_item] = data.frame_num + 20
                end
            end
            
            local shake_frame = ( data.memo.delay_shake[data.active_item] or data.frame_num ) - data.frame_num
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/fire_rate_wait.png" )
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*cast_delay/data.memo.delay_max[data.active_item]}, "data/ui_gfx/hud/colors_reload_bar.png", data.memo.delay_shake[data.active_item] ~= nil and 20-shake_frame or nil )
            
            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$inventory_castdelay" )..string.format( "%.2f", cast_delay/60 ).."s"
            uid = tipping( gui, uid, {
                pic_x - 42,
                pic_y - 1,
                44,
                6,
            }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

            if( shake_frame < 0 ) then
                data.memo.delay_shake[data.active_item] = nil
            end
            pic_y = pic_y + 8
        end
    end
    if( this_data.wand_info == nil or ( this_data.wand_info.main[11] or 0 ) == 0 ) then
        data.memo.delay_max[data.active_item] = nil
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_gold( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.delay )

    local this_data = data.Wallet
    if( #this_data > 0 and this_data[3] >= 0 ) then
        local god_i_love_money_holy_fuck = "i"
        if( not( this_data[2])) then
            data.memo.money = data.memo.money or this_data[3]
            local delta = this_data[3] - data.memo.money
            data.memo.money = data.memo.money + limiter( limiter( 0.1*delta, 1, true ), delta )
            god_i_love_money_holy_fuck = data.memo.money
        end

        local v = get_short_num( god_i_love_money_holy_fuck )
        local final_length = 0
        uid = new_image( gui, uid, pic_x + 2.5, pic_y - 1.5, zs.main, "data/ui_gfx/hud/money.png" )
        uid, final_length = new_font_vanilla_small( gui, uid, pic_x + 13, pic_y, zs.main, v, { 255, 255, 255, 0.9 })
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = hud_text_fix( "$hud_gold" )..( data.short_gold and v or god_i_love_money_holy_fuck ).."$"
        uid = tipping( gui, uid, {
            pic_x + 2.5,
            pic_y - 1,
            10.5 + final_length,
            8,
        }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

        pic_y = pic_y + 8
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_orbs( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.gold )
    
    if( data.orbs > 0 ) then
        pic_y = pic_y + 1

        local final_length = 0
        uid = new_image( gui, uid, pic_x + 3, pic_y, zs.main, "data/ui_gfx/hud/orbs.png" )
        uid, final_length = new_font_vanilla_small( gui, uid, pic_x + 13, pic_y, zs.main, data.orbs, { 255, 255, 255, 0.9 })

        local tip_x, tip_y = unpack( xys.hp )
        local tip = GameTextGet( "$hud_orbs", tostring( data.orbs ))
        uid = tipping( gui, uid, {
            pic_x + 2,
            pic_y - 1,
            11 + final_length,
            8,
        }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

        pic_y = pic_y + 8
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_info( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = 0,0

    function do_info( gui, p_x, p_y, txt, alpha, is_right, hover_func )
        local offset_x = 0

        txt = capitalizer( txt )
        if( is_right ) then
            local w,h = get_text_dim( txt )
            offset_x = w + 1
            p_x = p_x - offset_x
        end
        if( hover_func ~= nil ) then hover_func( offset_x ) end
        new_shadow_text( gui, p_x, p_y, zs.main, txt, alpha )
    end

    if( data.pointer_delta[3] < data.info_threshold ) then
        local info = ""

        local entities = EntityGetInRadius( data.pointer_world[1], data.pointer_world[2], data.info_radius ) or {}
        if( #entities > 0 ) then
            local best_kind = 0
            local dist_tbl = {}
            for i,entity_id in ipairs( entities ) do
                if( EntityGetRootEntity( entity_id ) == entity_id and entity_id ~= data.player_id ) then
                    local info_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "UIInfoComponent" )
                    local item_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ItemComponent" )
                    local matter_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "MaterialInventoryComponent" )
                    local abil_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "AbilityComponent" )
                    local action_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ItemActionComponent" )
                    
                    local v = ""
                    if( info_comp ~= nil ) then
                        v = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "name" ) or "" )
                    end

                    local kind = {}
                    if( #v > 0 ) then
                        kind = { 1, v }
                    elseif( not( EntityHasTag( entity_id, "not_a_potion" )) and item_comp ~= nil and matter_comp ~= nil ) then
                        kind = { 2, {entity_id,item_comp,matter_comp,abil_comp}}
                    elseif( abil_comp ~= nil and item_comp ~= nil and ComponentGetValue2( abil_comp, "use_gun_script" )) then
                        kind = { 3, {entity_id,item_comp,abil_comp}}
                    elseif( action_comp ~= nil ) then
                        kind = { 4, "Spell" }
                    end
                    if( #kind > 0 ) then
                        if( best_kind < kind[1]) then best_kind = kind[1] end
                        table.insert( dist_tbl, { entity_id, unpack( kind )})
                    end
                end
            end
            if( #dist_tbl > 0 ) then
                local the_one = closest_getter( data.pointer_world[1], data.pointer_world[2], dist_tbl, nil, nil, function( thing )
                    return thing[2] == best_kind
                end)
                if( the_one ~= 0 ) then
                    local msg_list = {
                        function( v ) return v end,
                        function( v )
                            local barrel_size = EntityGetFirstComponentIncludingDisabled( v[1], "MaterialSuckerComponent" )
                            barrel_size = barrel_size == nil and ComponentGetValue2( v[3], "max_capacity" ) or ComponentGetValue2( barrel_size, "barrel_size" )
                            
                            local v1, v2 = get_potion_info( entity_id, get_item_name(v[1],v[4],v[2]), barrel_size, get_matters( ComponentGetValue2( v[3], "count_per_material_type" )))
                            return v1..v2
                        end,
                        function( v )
                            v = get_item_name( v[1], v[3], v[2] ) or ""
                            return v == "" and "Relic" or v
                        end,
                        function( v ) return v end,
                    }
                    info = msg_list[best_kind]( the_one[3])
                end
            end
        end
        if( info ~= "" ) then
            local inter_alpha = 1
            if( data.info_pointer ) then
                pic_x, pic_y = unpack( data.pointer_ui )
                pic_x, pic_y = pic_x + 8, pic_y + 3
                inter_alpha = inter_alpha*0.3
            else
                pic_x, pic_y = unpack( xys.full_inv )
                pic_x, pic_y = pic_x + 5, pic_y + 5
            end
            do_info( gui, pic_x, pic_y, info, inter_alpha )
        end
    end

    local fading = 0.5
    data.memo.mtr_prb = data.memo.mtr_prb or { 0, 0 }
    local matter = data.memo.mtr_prb[1]
    if( data.pointer_matter > 0 ) then
        matter = data.pointer_matter
        data.memo.mtr_prb = { data.pointer_matter, math.max( data.memo.mtr_prb[2], data.frame_num )}
    elseif( data.memo.mtr_prb[1] > 0 ) then
        local delta = data.frame_num - data.memo.mtr_prb[2]
        if( delta > 2*data.info_mtr_fading ) then
            data.memo.mtr_prb = nil
            matter = 0
        elseif( delta > data.info_mtr_fading ) then
            fading = math.max( fading*math.sin(( 2*data.info_mtr_fading - delta )*math.pi/( 2*data.info_mtr_fading )), 0.01 )
        end
    end
    if( matter > 0 or data.info_mtr_static ) then
        if( data.info_mtr_static ) then
            fading = 1
        elseif( data.memo.mtr_prb[2] > data.frame_num ) then
            fading = math.min( fading*4, 1 )
        end
        
        pic_x, pic_y = unpack( xys.delay )
        local alphaer = function( offset_x )
            local hovered = false
            uid, _, _, hovered = new_interface( gui, uid, { pic_x + 2 - offset_x, pic_y - 1, offset_x, 8 }, zs.tips )
            if( hovered ) then data.memo.mtr_prb = { matter, data.frame_num + 300 } end
        end
        
        local txt = "air"
        if( not( data.info_mtr_static and matter == 0 )) then
            txt = GameTextGetTranslatedOrNot( CellFactory_GetUIName( matter ))
        end
        do_info( gui, pic_x + 3, pic_y - 2.5, txt, fading, true, alphaer )
    end
    
    return uid, data, {pic_x,pic_y}
end

function new_generic_ingestions( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.orbs )

    local this_data = data.icon_data.ings
    if( #this_data > 0 ) then
        pic_y = pic_y + 3
        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = 0, 0
            uid, step_x, step_y = new_icon( gui, uid, pic_x, pic_y, zs.main, this_one, 1 )
            pic_x, pic_y = pic_x, pic_y + step_y - 1
        end
        pic_y = pic_y + 4
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_stains( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.ingestions )

    local this_data = data.icon_data.stains
    if( #this_data > 0 ) then
        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = 0, 0
            uid, step_x, step_y = new_icon( gui, uid, pic_x, pic_y, zs.main, this_one, 2 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end
        pic_y = pic_y + 3
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_effects( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.stains )

    local this_data = data.icon_data.misc
    if( #this_data > 0 ) then
        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = 0, 0
            uid, step_x, step_y = new_icon( gui, uid, pic_x, pic_y, zs.main, this_one, 3 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end
        pic_y = pic_y + 3
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_perks( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.effects )
    
    local this_data = data.perk_data
    if( #this_data > 0 ) then
        local perk_tbl_short = {}
        if( #this_data > data.max_perks ) then
            local extra_perk = {
                pic = "data/ui_gfx/perk_icons/perks_hover_for_more.png",
                txt = "",
                desc = "",
                tip = function( gui, uid, pic_x, pic_y, pic_z, alpha, v )
                    for i,pic in ipairs( v ) do
                        local drift_x = 14*(( i - 1 )%10 )
                        local drift_y = 14*math.floor(( i - 1 )/10 )
                        uid = new_image( gui, uid, pic_x - 3 + drift_x, pic_y - 1 + drift_y, pic_z, pic, nil, nil, alpha )
                    end
                    
                    return uid
                end,
                other_perks = {},
            }
            for i,perk in ipairs( this_data ) do
                if( #perk_tbl_short < data.max_perks ) then
                    table.insert( perk_tbl_short, perk )
                else
                    for k = 1,( perk.count or 1 ) do
                        table.insert( extra_perk.other_perks, perk.pic )
                    end
                end
            end
            table.insert( perk_tbl_short, extra_perk )
        else
            perk_tbl_short = this_data
        end

        for i,this_one in ipairs( perk_tbl_short ) do
            local step_x, step_y = 0, 0
            uid, step_x, step_y = new_icon( gui, uid, pic_x, pic_y, zs.main, this_one, 4 )
            pic_x, pic_y = pic_x, pic_y + step_y - 2
        end
        pic_y = pic_y + 5
    end

    return uid, data, {pic_x,pic_y}
end