dofile_once( "mods/index_core/files/_lib.lua" )

function new_generic_inventory( gui, uid, screen_w, screen_h, data, zs, xys, slot_func )
    local root_x, root_y = 19, 20
    local pic_x, pic_y = root_x, root_y
    
    local this_data = data.item_list
    if( this_data ~= nil ) then
        if( data.is_opened ) then
            uid = new_image( gui, uid, 0, 0, zs.background, data.gmod.show_full and "data/ui_gfx/inventory/background.png" or "mods/index_core/files/pics/vanilla_fullless_bg.xml" )

            if( not( data.gmod.can_see )) then
                local delta = math.max(( data.memo.inv_alpha or data.frame_num ) - data.frame_num, 0 )
                local alpha = 0.5*math.cos( math.pi*delta/30 )
                uid = new_image( gui, uid, -2, -2, zs.background + 1, "data/ui_gfx/empty_black.png", screen_w + 4, screen_h + 4, alpha )
            end
        end
        
        local function check_shortcut( id, is_quickest )
            if( id < 5 ) then
                return get_input({ ( is_quickest and 29 or 33 ) + id, "Key" }, ( is_quickest and "za_quickest_" or "zb_quick_" )..id, false, true )
            end
        end
        local w, h, step = 0, 0, 1
        
        local cat_wands = pic_x
        local inv_id = data.inventories_player[1]
        local slot_data = data.slot_state[ inv_id ].quickest
        for i,slot in ipairs( slot_data ) do
            uid, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, slot_func, {
                inv_id = inv_id,
                id = slot,
                inv_slot = {i,-1},
                force_equip = check_shortcut( i, true ),
            }, data.is_opened, false, true )
            pic_x, pic_y = pic_x + w + step, pic_y
        end
        
        pic_x = pic_x + 2
        local cat_items = pic_x
        slot_data = data.slot_state[ inv_id ].quick
        for i,slot in ipairs( slot_data ) do
            uid, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, slot_func, {
                inv_id = inv_id,
                id = slot,
                inv_slot = {i,-2},
                force_equip = check_shortcut( i, false ),
            }, data.is_opened, false, true )
            pic_x, pic_y = pic_x + w + step, pic_y
        end

        if( data.Controls[2][2]) then
            data.memo.inv_alpha = data.frame_num + 15
            data.is_opened = not( data.is_opened )
        end

        if( data.is_opened ) then
            new_text( gui, cat_wands + 1, pic_y - 13, zs.main_far_back, GameTextGetTranslatedOrNot( "$hud_title_wands" ))
            new_text( gui, cat_items + 1, pic_y - 13, zs.main_far_back, GameTextGetTranslatedOrNot( "$hud_title_throwables" ))
            if( data.gmod.show_full ) then --by default display only the first row of full inv ( data.gmod.show_fullest )
                pic_x = pic_x + 9
                new_text( gui, pic_x + 1, pic_y - 13, zs.main_far_back, GameTextGetTranslatedOrNot( "$menuoptions_heading_misc" ))
                
                local core_y = pic_y
                inv_id = data.inventories_player[2]
                slot_data = data.slot_state[ inv_id ]
                for i,col in ipairs( slot_data ) do
                    for e,slot in ipairs( col ) do
                        uid, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, slot_func, {
                            inv_id = inv_id,
                            id = slot,
                            inv_slot = {i,e},
                        }, data.is_opened, true, true )
                        pic_x, pic_y = pic_x, pic_y + h + step
                    end
                    pic_x, pic_y = pic_x + w + step, core_y
                end
            end
        end

        pic_y = pic_y + h
        if( data.is_opened ) then
            root_x, root_y = root_x - 3, root_y - 3
            pic_x, pic_y = pic_x + 3 - step, pic_y + 3
        end
    end
    
    return uid, data, {root_x,root_y}, {pic_x,pic_y}
end

function new_generic_applets( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x_l, pic_x_r, pic_y = 0, screen_w, 4

    local this_data = data.applets
    if( this_data ~= nil ) then --icons must be behind the wands
        --pop up through sine (a little when pointer is nearby and all the way with bouncy once clicked)
        if( data.is_opened ) then
            -- if( #this_data.r > 1 ) then
                --hover area

                --do anim
                --draw all da shit
                --draw vanilla plate

                uid = new_vanilla_plate( gui, uid, pic_x_r, pic_y, zs.main_far_back - 0.1, { 20, 10 }) --extra 5 pixels to x dim

                -- zs.main_back
                pic_x_r = pic_x_r - 2
            -- end
        elseif( #this_data.l > 1 ) then
        end
    end

    return uid, data, {pic_x_l,pic_y}, {pic_x_r,pic_y}
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
            uid = tipping( gui, uid, nil, {
                pic_x - ( length + 2 ),
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
        if( this_data[6] and this_data[8]/this_data[7] < 0.9 ) then
            uid = new_font_vanilla_small( gui, uid, pic_x + 3, pic_y - 1, zs.main, "o2", { 255, 255, 255, 0.9 })
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*math.max( this_data[8], 0 )/this_data[7]}, "data/ui_gfx/hud/colors_mana_bar.png", nil, 0.75 )

            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$hud_air" )..hud_num_fix( this_data[8], this_data[7], 2 )
            uid = tipping( gui, uid, nil, {
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
            if( #data.Controls > 0 and data.Controls[4][1] and this_data[4] <= 0 ) then
                data.memo.flight_shake = data.frame_num + 20
            end
        end
        local shake_frame = ( data.memo.flight_shake or data.frame_num ) - data.frame_num
        uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/jetpack.png" )
        uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*math.max( this_data[4], 0 )/this_data[3]}, "data/ui_gfx/hud/colors_flying_bar.png", data.memo.flight_shake ~= nil and 20-shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = hud_text_fix( "$hud_jetpack" )..hud_num_fix( this_data[4], this_data[3], 2 )
        uid = tipping( gui, uid, nil, {
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
                tip = this_data.name.."@"..this_data.fullness
            else
                tip = hud_text_fix( "$hud_wand_mana" )..hud_num_fix( value[1], value[2])
            end

            local tip_x, tip_y = unpack( xys.hp )
            uid = tipping( gui, uid, nil, {
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
            uid = tipping( gui, uid, nil, {
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
            uid = tipping( gui, uid, nil, {
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
        uid = tipping( gui, uid, nil, {
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
        uid = tipping( gui, uid, nil, {
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

    if( not( data.is_opened and data.gmod.show_full ) and data.pointer_delta[3] < data.info_threshold ) then --this should be a callback
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
                pic_x, pic_y = xys.full_inv[1], xys.inv_root[2]
                pic_x, pic_y = pic_x + 3, pic_y + 5 + ( data.is_opened and 3 or 0 )
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
    pic_y = pic_y + data.effect_icon_spacing

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

function new_generic_pickup( gui, uid, screen_w, screen_h, data, zs, xys, info_func )
    local this_data = data.ItemPickUpper
    if( #this_data > 0 ) then
        local x, y = unpack( data.player_xy )
        y = y - data.player_core_off
        local entities = EntityGetInRadius( x, y, 200 ) or {}
        if( #entities > 0 ) then
            local stuff_to_figure = table_init( #data.item_cats + 1, {})
            local interactables = {}
            for i,ent in ipairs( entities ) do
                local action_comp = EntityGetFirstComponent( ent, "InteractableComponent" )
                if( action_comp ~= nil ) then
                    local b_x, b_y = EntityGetTransform( ent )
                    local dist = math.sqrt(( x - b_x )^2 + ( y - b_y )^2 )

                    local button_data = {
                        ent,
                        
                        ComponentGetValue2( action_comp, "radius" ),
                        GameTextGetTranslatedOrNot( ComponentGetValue2( action_comp, "name" )),
                        GameTextGetTranslatedOrNot( ComponentGetValue2( action_comp, "ui_text" )),

                        dist,
                    }

                    if( button_data[2] == 0 ) then
                        local box_comp = EntityGetFirstComponent( ent, "HitboxComponent" )
                        button_data[2] = check_bounds({x,y}, {b_x, b_y}, box_comp )
                    else
                        button_data[2] = dist <= button_data[2]
                    end
                    if( button_data[2]) then
                        table.insert( interactables, button_data )
                    end
                elseif( EntityGetRootEntity( ent ) == ent ) then
                    local item_comp = EntityGetFirstComponent( ent, "ItemComponent" )
                    if( item_comp ~= nil ) then
                        local i_x, i_y = EntityGetTransform( ent )
                        local dist = math.sqrt(( x - i_x )^2 + ( y - i_y )^2 )

                        local item_data = {
                            { ent, item_comp, },

                            ComponentGetValue2( item_comp, "is_pickable" ) or this_data[2],
                            ComponentGetValue2( item_comp, "item_pickup_radius" ),
                            ComponentGetValue2( item_comp, "next_frame_pickable" ),
                            ComponentGetValue2( item_comp, "auto_pickup" ),

                            ComponentGetValue2( item_comp, "play_pick_sound" ),
                            ComponentGetValue2( item_comp, "ui_display_description_on_pick_up_hint" ),
                            ComponentGetValue2( item_comp, "custom_pickup_string" ) or "",
                            
                            dist,
                        }

                        if( item_data[2]) then
                            if( item_data[3] == 0 ) then
                                local box_comp = EntityGetFirstComponent( ent, "HitboxComponent" )
                                item_data[3] = check_bounds({x,y}, {i_x,i_y}, box_comp )
                            else
                                item_data[3] = dist <= item_data[3]
                            end
                            if( item_data[3] and item_data[4] <= data.frame_num ) then
                                if( this_data[3] == 0 or ent == this_data[3]) then
                                    local item_info = {}
                                    data, item_info = get_item_data( ent, data )
                                    table.insert( item_data, item_info )
                                    if( item_info ~= nil ) then
                                        if( item_data[5]) then
                                            item_info = 1
                                        else
                                            item_info = item_info.cat + 1
                                        end
                                    else
                                        item_info = 0
                                    end
                                    if( item_info > 0 ) then
                                        table.insert( stuff_to_figure[item_info], item_data )
                                    end
                                end
                            end
                        end
                    end
                end
            end

            local pickup_info = {
                id = 0,
                desc = "",
            }
            local button_time, no_space, cant_buy, got_info = true, false, false, false
            for i,tbl in ipairs( stuff_to_figure ) do
                table.sort( tbl, function( a, b )
                    return a[9] < b[9]
                end)
                if( #tbl > 0 ) then
                    for k,item_data in ipairs( tbl ) do
                        local cost_check, is_shop = true, false
                        local cost_comp = EntityGetFirstComponentIncludingDisabled( item_data[1][1], "ItemCostComponent" )
                        if( cost_comp ~= nil ) then
                            is_shop = true
                            local cost = ComponentGetValue2( cost_comp, "cost" )
                            if( data.Wallet[2] or ( cost <= data.Wallet[3])) then
                                item_data[10].cost = cost
                            else
                                cost_check = false
                            end
                        end

                        local info_dump = false
                        if( cost_check ) then
                            local will_pause = data.item_cats[ item_data[10].cat ].on_gui_pause ~= nil
                            ComponentSetValue2( item_data[1][2], "inventory_slot", -5, -5 ) --is_hidden and slotless go to full by default
                            local new_data = (( will_pause or i == 1 or EntityHasTag( item_data[1][1], "index_slotless" )) and {inv_slot=1} or set_to_slot( item_data[10], data, true ))
                            if( new_data.inv_slot ~= nil ) then
                                if( i > 1 ) then
                                    pickup_info.id = item_data[1][1]
                                    pickup_info.desc = GameTextGet( item_data[8] == "" and ( is_shop and "$itempickup_purchase" or "$itempickup_pick" ) or item_data[8], "[USE]", item_data[10].name..( item_data[10].fullness or "" ))
                                    pickup_info.txt = "[GET]"
                                    pickup_info.info = item_data[10]
                                    pickup_info.do_sound = item_data[6]
                                    if( item_data[7]) then
                                        pickup_info.desc = { pickup_info.desc, item_data[10].desc }
                                    end

                                    if( i > 1 ) then
                                        button_time = false
                                        break
                                    end
                                else
                                    pick_up_item( data.player_id, data, item_data[10], item_data[6])
                                end
                            elseif( not( got_info )) then
                                no_space = true
                                info_dump = true
                            end
                        elseif( not( got_info )) then
                            cant_buy = true
                            info_dump = true
                        end
                        if( info_dump ) then
                            got_info = true
                            pickup_info.id = item_data[1][1]
                            pickup_info.name = item_data[10].name
                            pickup_info.info = item_data[10]
                        end
                    end
                    if( not( button_time )) then
                        break
                    end
                end
            end
            
            if( pickup_info.txt == nil and ( no_space or cant_buy )) then
                if( #interactables > 0 ) then
                    pickup_info.id = 0
                else
                    pickup_info.id = -pickup_info.id
                    pickup_info.desc = { GameTextGet( cant_buy and "$itempickup_notenoughgold" or "$itempickup_cannotpick", pickup_info.name ), true }
                end
            end
            if( pickup_info.id ~= 0 ) then
                if( data.is_opened and data.gmod.show_full ) then
                    pickup_info.id = -1
                    pickup_info.desc = { GameTextGet( "$itempickup_cannotpick_closeinventory", pickup_info.info.name ), true }
                elseif( data.item_cats[ pickup_info.info.cat ].on_gui_world ~= nil ) then
                    local i_x, i_y = EntityGetTransform( math.abs( pickup_info.id ))
                    local pic_x, pic_y = world2gui( i_x, i_y )
                    uid = data.item_cats[ pickup_info.info.cat ].on_gui_world( gui, uid, math.abs( pickup_info.id ), data, pickup_info.info, zs, pic_x, pic_y, no_space, cant_buy )
                end
                
                uid = info_func( gui, uid, screen_h, screen_w, data, pickup_info, zs, xyz )
                if( pickup_info.id > 0 and data.Controls[3][2]) then
                    local pkp_x, pkp_y = EntityGetTransform( pickup_info.id )
                    local anim_x, anim_y = world2gui( pkp_x, pkp_y )
                    table.insert( slot_anim, {
                        id = pickup_info.id,
                        x = anim_x,
                        y = anim_y,
                        frame = data.frame_num,
                    })

                    local orig_name = pickup_info.info.name
                    if( pickup_info.info.fullness ~= nil ) then
                        pickup_info.info.name = pickup_info.info.name..pickup_info.info.fullness
                    end

                    data.Controls[3][2] = false
                    pick_up_item( data.player_id, data, pickup_info.info, pickup_info.do_sound )
                    ComponentSetValue2( data.Controls[1], "mButtonFrameInteract", 0 )

                    pickup_info.info.name = orig_name
                end
            end

            local special_buttons = {} --search for the 19a buttons
            if( button_time ) then
                if( #interactables > 0 and #special_buttons == 0 ) then
                    table.sort( interactables, function( a, b )
                        return a[5] < b[5]
                    end)
                    --allow for custom code injection for info and trigger check (suppress the toggle event and the info overlay if is false)
                    uid = info_func( gui, uid, screen_h, screen_w, data, {
                        id = interactables[1][1],
                        desc = { capitalizer( interactables[1][3]), string.gsub( interactables[1][4], "$0", "[USE]" )},
                        txt = "[USE]",
                    }, zs, xyz )
                end
            else
                --suppress all the 19a buttons 
            end
        end
    end

    return uid, data
end

function new_generic_drop( this_item, data )
    local dude = EntityGetRootEntity( this_item )
    if( dude == data.player_id ) then
        play_sound( data, { "data/audio/Desktop/ui.bank", "ui/item_remove" })

        local do_default = true
        local this_data = from_tbl_with_id( data.item_list, this_item )
        local callback = data.item_cats[ this_data.cat ].on_drop
        if( callback ~= nil ) then
            do_default = callback( this_item, data, this_data, false )
        end
        if( do_default ) then
            local x, y = unpack( data.player_xy )
            drop_item( x, y, this_data, data, data.throw_force, not( data.no_action_on_drop ))
        end
        if( callback ~= nil ) then
            callback( this_item, data, this_data, true )
        end
    else
        play_sound( data, "error" )
    end
end

function new_generic_extra( gui, uid, screen_w, screen_h, data, zs, xys, slot_func )
    if( #data.inventories_extra > 0 ) then
        for i,extra_inv in ipairs( data.inventories_extra ) do
            local this_data = data.inventories[ extra_inv ]
            local x, y = EntityGetTransform( extra_inv )
            local pic_x, pic_y = world2gui( x, y )
            uid, data = this_data.func( gui, uid, pic_x, pic_y, this_data, data, zs, xys, slot_func )
        end
    end

    return uid, data
end

function new_generic_modder( gui, uid, screen_w, screen_h, data, zs, xys ) --disable if the pos of the right applet is close
    local this_data = data.gmod
    if( this_data ~= nil and data.is_opened ) then
        local w,h = get_text_dim( this_data.name )
        local pic_x, pic_y = xys.full_inv[1], xys.inv_root[2]
        if( not( this_data.show_full )) then
            pic_x, pic_y = xys.inv_root[1], xys.full_inv[2]
            pic_x = pic_x + 7 + w
            pic_y = pic_y + 13
        end
        
        local gonna_reset, gonna_highlight = false
        local clicked, r_clicked, is_hovered = false
        local arrow_left_c, arrow_right_c, arrow_left_a, arrow_right_a = {255,255,255}, {255,255,255}, 0.3, 0.3
        local arrow_hl_c = {255,255,178}

        local new_mode = data.global_mode
        uid, clicked, r_clicked, is_hovered = new_interface( data.the_gui, uid, { pic_x - ( 11 + w ), pic_y - 11, 15, 10 }, zs.tips )
        gonna_reset = gonna_reset or r_clicked
        gonna_highlight = gonna_highlight or is_hovered
        if( is_hovered ) then
            arrow_left_c = arrow_hl_c
            arrow_left_a = 1
            if( clicked ) then
                new_mode = new_mode - 1
            end
        end
        uid, clicked, r_clicked, is_hovered = new_interface( data.the_gui, uid, { pic_x - 10, pic_y - 11, 15, 10 }, zs.tips )
        gonna_reset = gonna_reset or r_clicked
        gonna_highlight = gonna_highlight or is_hovered
        if( is_hovered ) then
            arrow_right_c = arrow_hl_c
            arrow_right_a = 1
            if( clicked ) then
                new_mode = new_mode + 1
            end
        end
        uid, is_hovered, clicked, r_clicked = tipping( data.the_gui, uid, nil, { pic_x - ( 6 + w ), pic_y - 11, w + 6, 10 }, { this_data.name.."@"..this_data.desc }, zs.tips, this_data.show_full )
        gonna_reset = gonna_reset or r_clicked
        gonna_highlight = gonna_highlight or is_hovered

        local alpha = gonna_highlight and 1 or 0.3
        if( gonna_reset ) then
            for i,gmod in ipairs( data.gmod.gmods ) do
                if( gmod.is_default ) then
                    new_mode = i
                    break
                end
            end
        end
        if( data.global_mode ~= new_mode ) then
            local total_count = #this_data.gmods
            local go_ahead = true
            while( go_ahead ) do
                if( new_mode < 1 ) then
                    new_mode = total_count
                elseif( new_mode > total_count ) then
                    new_mode = 1
                end
                go_ahead = this_data.gmods[ new_mode ].is_hidden or false
                if( go_ahead ) then
                    new_mode = new_mode + ( arrow_left_a == 1 and -1 or 1 )
                end
            end

            play_sound( data, gonna_reset and "reset" or "click" )
            ComponentSetValue2( get_storage( data.main_id, "global_mode" ), "value_int", new_mode )
        end

        new_text( gui, pic_x - ( 3 + w ), pic_y - h, zs.main, this_data.name, {255,255,255,alpha})
        uid = new_vanilla_plate( gui, uid, pic_x - ( 4 + w ), pic_y - 9, zs.main_back, { w + 2, 6 })

        colourer( gui, arrow_left_c )
        uid = new_image( gui, uid, pic_x - ( 12 + w ), pic_y - 10, zs.main_back, "data/ui_gfx/keyboard_cursor_right.png", nil, nil, arrow_left_a )
        colourer( gui, arrow_right_c )
        uid = new_image( gui, uid, pic_x - 2, pic_y - 10, zs.main_back, "data/ui_gfx/keyboard_cursor.png", nil, nil, arrow_right_a )
    end

    return uid, data
end