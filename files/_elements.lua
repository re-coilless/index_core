dofile_once( "mods/index_core/files/_lib.lua" )

function new_generic_inventory( gui, uid, screen_w, screen_h, data, zs, xys )
    local root_x, root_y = unpack( xys.full_inv or { 19, 20 })
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
                return get_input({( is_quickest and 29 or 33 ) + id, "Key" }, ( is_quickest and "za_quickest_" or "zb_quick_" )..id, false, true )
            end
        end
        local w, h, step = 0, 0, 1
        xys.inv_root, xys.full_inv = { root_x - 3, root_y - 3 }, { root_x + 2, root_y + 26 }

        local cat_wands = pic_x
        local inv_id = data.inventories_player[1]
        local slot_data = data.slot_state[ inv_id ].quickest
        for i,slot in ipairs( slot_data ) do
            uid, data, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, {
                inv_id = inv_id,
                id = slot,
                inv_slot = {i,-1},
                force_equip = check_shortcut( i, true ),
            }, data.is_opened, false, true )
            pic_x, pic_y = pic_x + w + step, pic_y
        end
        
        pic_x = pic_x + data.inv_spacings[1]
        local cat_items = pic_x
        slot_data = data.slot_state[ inv_id ].quick
        for i,slot in ipairs( slot_data ) do
            uid, data, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, {
                inv_id = inv_id,
                id = slot,
                inv_slot = {i,-2},
                force_equip = check_shortcut( i, false ),
            }, data.is_opened, false, true )
            pic_x, pic_y = pic_x + w + step, pic_y
        end

        if( data.is_opened ) then
            uid = new_font_vanilla_shadow( gui, uid, cat_wands + 1, pic_y - 13, zs.main_far_back, GameTextGetTranslatedOrNot( "$hud_title_wands" ))
            uid = new_font_vanilla_shadow( gui, uid, cat_items + 1, pic_y - 13, zs.main_far_back, GameTextGetTranslatedOrNot( "$hud_title_throwables" ))

            pic_x = pic_x + data.inv_spacings[2]
            uid = new_font_vanilla_shadow( gui, uid, pic_x + 1, pic_y - 13, zs.main_far_back, GameTextGetTranslatedOrNot( "$menuoptions_heading_misc" ))
        end
        if( data.gmod.show_full ) then
            if( data.is_opened or data.always_show_full ) then
                local core_y = pic_y
                inv_id = data.inventories_player[2]
                slot_data = data.slot_state[ inv_id ]
                for i,col in ipairs( slot_data ) do
                    local count = not( data.gmod.show_fullest or false ) and 1 or #col
                    for e = 1,count do
                        local slot = col[e]
                        uid, data, w, h = slot_setup( gui, uid, pic_x, pic_y, zs, data, {
                            inv_id = inv_id,
                            id = slot,
                            inv_slot = {i,e},
                        }, data.is_opened, true, data.is_opened )
                        pic_x, pic_y = pic_x, pic_y + h + step
                    end
                    pic_x, pic_y = pic_x + w + step, core_y
                end
            end
        end

        pic_y = pic_y + h
        data.xys.inv_root_orig = { root_x, root_y }
        data.xys.full_inv_orig = { pic_x, pic_y }
        if( data.is_opened ) then
            root_x, root_y = root_x - 3, root_y - 3
            pic_x, pic_y = pic_x + 3 - step, pic_y + 3
        end

        -- if( InputIsKeyJustDown( 41--[[escape]])) then
        --     data.inv_toggle = data.is_opened
        -- else
        if( data.Controls[2][2]) then
            data.inv_toggle = true
        end
    end
    
    return uid, data, {root_x,root_y}, {pic_x,pic_y}
end

function new_generic_applets( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x_l, pic_x_r, pic_y = 0, screen_w, 4

    local this_data = data.applets
    if( this_data ~= nil and not( data.gmod.menu_capable )) then
        absolutely_abominable_piece_of_shit = god_do_i_hate_this_one
        local function applet_setup( gui, uid, data, this_data, pic_x, type )
            local is_left = type == 1
            local sign = is_left and -1 or 1
            local tbl = {
                { "l", "l_state", "l_frame", "applets_l_drift", "l_hover" },
                { "r", "r_state", "r_frame", "applets_r_drift", "r_hover" },
            }

            local l = #this_data[tbl[type][1]]*11
            local drift_target, core_off = 5, is_left and -10 or 0
            local total_drift, allow_clicks = l - drift_target, true
            if( not( this_data[tbl[type][2]])) then
                local clicked, r_clicked, is_hovered = false
                uid, clicked, r_clicked, is_hovered = new_interface( data.the_gui, uid, { is_left and -1 or ( screen_w - 10 ), -1, 11, 19, }, zs.tips_front )
                uid = data.tip_func( gui, uid, nil, zs.tips, { "[APPLETS]" }, nil, is_hovered, not( is_left ))
                if( clicked ) then
                    play_sound( data, "click" )
                    this_data[tbl[type][2]] = true
                    this_data[tbl[type][3]] = data.frame_num
                    allow_clicks = false
                end
                if( not( is_hovered )) then
                    drift_target = 0
                end
            else
                local delta = data.frame_num - ( this_data[tbl[type][3]] or 0 )
                if( delta < 16 ) then
                    allow_clicks = false
                    local k = 5
                    local v = k*math.sin( delta*math.pi/k )/( math.pi*delta^2 )
                    core_off = total_drift*( 1 - v )
                else
                    core_off = total_drift
                end
            end
            
            data[tbl[type][4]] = total_drift
            local extra_off, arrow_off = simple_anim( data, tbl[type][4], drift_target, 0.2 ), is_left and ( l - 8 ) or 0
            pic_x = pic_x - sign*( core_off + extra_off )
            if( this_data[tbl[type][2]]) then
                if( is_left ) then pic_x = pic_x - 10 end
                arrow_off = arrow_off + extra_off + 2
                local clicked, is_hovered, mute, reset_em, got_one = false, false, false, 0, false
                for i,icon in ipairs( this_data[tbl[type][1]]) do
                    local metahover = not( got_one ) and ( this_data[tbl[type][5]][i] or false )
                    uid, clicked, is_hovered, mute = icon.pic( got_one and data.a_gui or data.the_gui, uid, data, pic_x + sign*( i - 1 )*11, pic_y, zs.main_back, metahover and math.rad( -5 ) or 0 )
                    if( allow_clicks ) then
                        uid = data.tip_func( gui, uid, nil, zs.tips, { icon.name..( icon.desc == nil and "" or "@"..icon.desc ), is_left and 2 or ( screen_w - 1 ), pic_y + 14 }, nil, metahover, not( is_left ))
                        if( clicked and reset_em == 0 ) then
                            if( not( mute or false )) then play_sound( data, "click" ) end
                            
                            reset_em = i
                            if( icon.toggle ~= nil and icon.toggle( data, true )) then
                                if( not( is_left )) then
                                    for i,gmod in ipairs( data.gmod.gmods ) do
                                        if( gmod.menu_capable ) then
                                            ComponentSetValue2( get_storage( data.main_id, "global_mode" ), "value_int", i )
                                            break
                                        end
                                    end
                                end
                            end
                            for k,icn in ipairs( this_data[tbl[type][1]]) do
                                if( icn.toggle ~= nil ) then icn.toggle( data, false ) end
                            end
                        end
                    end
                    if( is_hovered and not( this_data[tbl[type][5]][i] )) then play_sound( data, "hover" ) end
                    this_data[tbl[type][5]][i] = is_hovered
                    if( is_hovered ) then got_one = true end
                end
            else
                colourer( gui, {255,255,178})
            end

            if( is_left ) then pic_x = pic_x - ( l - 10 ) end
            uid = new_image( gui, uid, pic_x - sign*( 1 + arrow_off ), pic_y + 1, zs.main_back - 0.001, "data/ui_gfx/keyboard_cursor"..( is_left and ".png" or "_right.png" ))
            uid = data.plate_func( gui, uid, pic_x, pic_y, zs.main_far_back - 0.1, { total_drift + 5, 10 })
            if( is_left ) then
                pic_x = pic_x + arrow_off + 11
            else
                pic_x = pic_x - ( 3 + arrow_off )
            end
            return uid, data, pic_x
        end

        if( data.is_opened ) then
            if( data.gmod.show_full and #this_data.r > 1 ) then
                uid, data, pic_x_r = applet_setup( gui, uid, data, this_data, pic_x_r, 2 )
            end
        elseif( #this_data.l > 1 ) then
            uid, data, pic_x_l = applet_setup( gui, uid, data, this_data, pic_x_l, 1 )
        end
    end

    return uid, data, {pic_x_l,pic_y}, {pic_x_r,pic_y}
end

function new_generic_hp( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.hp or { screen_w - 41, 20 })
    local red_shift, length, height = 0, 0, 0

    local this_data = data.DamageModel
    if( #this_data > 0 and ComponentGetIsEnabled( this_data[1]) and not( data.gmod.menu_capable )) then
        local max_hp, hp = this_data[2], this_data[3]
        if( max_hp > 0 ) then
            uid, length, height, max_hp, hp, red_shift = new_vanilla_hp( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, data, data.player_id, this_data )

            local max_hp_text, hp_text = get_short_num( max_hp ), get_short_num( hp )
            uid = new_shaded_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/health.png", {8,8})
            uid = pen.text( gui, uid, pic_x + 13, pic_y, zs.main, hp_text, { is_huge = false, is_shadow = true, alpha = 0.9 })
            
            local tip = hud_text_fix( "$hud_health" )..( data.short_hp and hp_text.."/"..max_hp_text or hp.."/"..max_hp )
            uid = tipping( gui, uid, nil, nil, {
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
    if( #this_data > 0 and ComponentGetIsEnabled( this_data[1]) and not( data.gmod.menu_capable )) then
        if( this_data[6] and this_data[8]/this_data[7] < 0.9 ) then
            uid = pen.new_text( gui, uid, pic_x + 3, pic_y - 1, zs.main, "o2", { is_huge = false, is_shadow = true, alpha = 0.9 })
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*math.max( this_data[8], 0 )/this_data[7]}, "data/ui_gfx/hud/colors_mana_bar.png", nil, 0.75 )

            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$hud_air" )..hud_num_fix( this_data[8], this_data[7], 2 )
            uid = tipping( gui, uid, nil, nil, {
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
    if( #this_data > 0 and this_data[2] and this_data[3] > 0 and not( data.gmod.menu_capable )) then
        if( data.memo.flight_shake == nil ) then
            if( #data.Controls > 0 and data.Controls[4][1] and this_data[4] <= 0 ) then
                data.memo.flight_shake = data.frame_num
            end
        end
        local shake_frame = data.frame_num - ( data.memo.flight_shake or data.frame_num )
        uid = new_shaded_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/jetpack.png", {8,8})
        uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*math.max( this_data[4], 0 )/this_data[3]}, "data/ui_gfx/hud/colors_flying_bar.png", data.memo.flight_shake ~= nil and shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = hud_text_fix( "$hud_jetpack" )..hud_num_fix( this_data[4], this_data[3], 2 )
        uid = tipping( gui, uid, nil, nil, {
            pic_x - 42,
            pic_y - 1,
            44,
            6,
        }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

        if( shake_frame >= 20 ) then
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
    if( this_data.id ~= nil and not( data.gmod.menu_capable )) then
        local potion_data = {}
        local throw_it_back = nil
        
        local value = {0,0}
        if( this_data.wand_info ~= nil ) then
            local mana_max = this_data.wand_info.mana_max
            local mana = this_data.wand_info.mana

            value = { math.min( math.max( mana, 0 ), mana_max ), mana_max }
            if( data.memo.mana_shake[data.active_item] == nil ) then
                if( data.no_mana_4life ) then
                    data.memo.mana_shake[data.active_item] = data.frame_num
                end
            end
            local shake_frame = data.frame_num - ( data.memo.mana_shake[data.active_item] or data.frame_num )
            throw_it_back = data.memo.mana_shake[data.active_item] ~= nil and -shake_frame or nil
            if( shake_frame >= 20 ) then
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
            uid = new_shaded_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, potion_data[1] or "data/ui_gfx/hud/mana.png", {8,8})
            if( potion_data[3] ~= nil ) then
                uid = new_image( gui, uid, pic_x - 40, pic_y + 1, zs.main + 0.001, potion_data[2], math.min( 40*ratio + 0.5, 40 ), 2 )
                colourer( gui, potion_data[3])
            end
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*ratio}, potion_data[2] or "data/ui_gfx/hud/colors_mana_bar.png", throw_it_back, potion_data[4])
            
            local tip = ""
            if( potion_data[3] ~= nil ) then
                tip = this_data.name..( this_data.fullness ~= nil and "@"..this_data.fullness or "" )
            else
                tip = hud_text_fix( "$hud_wand_mana" )..hud_num_fix( value[1], value[2])
            end

            local tip_x, tip_y = unpack( xys.hp )
            uid = tipping( gui, uid, nil, nil, {
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
    if( this_data.wand_info ~= nil and not( this_data.wand_info.never_reload ) and not( data.gmod.menu_capable )) then
        local reloading = this_data.wand_info.reload_frame
        data.memo.reload_max[data.active_item] = ( data.memo.reload_max[data.active_item] or -1 ) < reloading and reloading or data.memo.reload_max[data.active_item]
        if( data.memo.reload_max[data.active_item] > data.reload_threshold ) then
            if( data.memo.reload_max[data.active_item] ~= reloading ) then
                if( data.memo.reload_shake[data.active_item] == nil and data.just_fired ) then
                    data.memo.reload_shake[data.active_item] = data.frame_num
                end
            end
            
            local shake_frame = data.frame_num - ( data.memo.reload_shake[data.active_item] or data.frame_num )
            uid = new_shaded_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/reload.png", {8,8})
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*reloading/data.memo.reload_max[data.active_item]}, "data/ui_gfx/hud/colors_reload_bar.png", data.memo.reload_shake[data.active_item] ~= nil and -shake_frame or nil )
            
            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$hud_wand_reload" )..string.format( "%.2f", reloading/60 ).."s"
            uid = tipping( gui, uid, nil, nil, {
                pic_x - 42,
                pic_y - 1,
                44,
                6,
            }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

            if( shake_frame >= 20 ) then
                data.memo.reload_shake[data.active_item] = nil
            end
            pic_y = pic_y + 8
        end
    end
    if( this_data.wand_info == nil or ( this_data.wand_info.reload_frame or 0 ) == 0 ) then
        data.memo.reload_max[data.active_item] = nil
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_delay( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.reload )
    data.memo.delay_shake = data.memo.delay_shake or {}
    data.memo.delay_max = data.memo.delay_max or {}
    
    local this_data = data.active_info
    if( this_data.wand_info ~= nil and not( data.gmod.menu_capable )) then
        local cast_delay = this_data.wand_info.delay_frame
        data.memo.delay_max[data.active_item] = ( data.memo.delay_max[data.active_item] or -1 ) < cast_delay and cast_delay or data.memo.delay_max[data.active_item]
        if( data.memo.delay_max[data.active_item] > data.reload_threshold ) then
            if( data.memo.delay_max[data.active_item] ~= cast_delay ) then
                if( data.memo.delay_shake[data.active_item] == nil and data.just_fired ) then
                    data.memo.delay_shake[data.active_item] = data.frame_num
                end
            end
            
            local shake_frame = data.frame_num - ( data.memo.delay_shake[data.active_item] or data.frame_num )
            uid = new_shaded_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/fire_rate_wait.png", {8,8})
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*cast_delay/data.memo.delay_max[data.active_item]}, "data/ui_gfx/hud/colors_reload_bar.png", data.memo.delay_shake[data.active_item] ~= nil and -shake_frame or nil )
            
            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$inventory_castdelay" )..string.format( "%.2f", cast_delay/60 ).."s"
            uid = tipping( gui, uid, nil, nil, {
                pic_x - 42,
                pic_y - 1,
                44,
                6,
            }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

            if( shake_frame >= 20 ) then
                data.memo.delay_shake[data.active_item] = nil
            end
            pic_y = pic_y + 8
        end
    end
    if( this_data.wand_info == nil or ( this_data.wand_info.delay_frame or 0 ) == 0 ) then
        data.memo.delay_max[data.active_item] = nil
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_bossbar( gui, uid, screen_w, screen_h, data, zs, xys ) --make it line up to 3 bars horizontally with width check
    local pic_x, pic_y = unpack( xys.bossbar or {screen_w/2,screen_h-20})

    local bosses = EntityGetInRadiusWithTag( data.player_xy[1], data.player_xy[2], 1000, "index_bossbar" ) or {}
    if( #bosses > 0 ) then
        for i,boss in ipairs( bosses ) do
            local step, bar_func = 0, function( gui, uid, pic_x, pic_y, pic_zs, data, entity_id, this_data, params )
                local name, length, step, max_hp, hp = get_entity_name( entity_id ), 0, 0, 0, 0
                uid, length, step, max_hp, hp = new_vanilla_hp( gui, uid, pic_x, pic_y, pic_zs, data, entity_id, this_data, params )
                
                local num_width, rounding = 35, 10
                if( max_hp >= 10^6 ) then
                    rounding = 1000
                    num_width = num_width + 12
                elseif( max_hp >= 10^5 ) then
                    rounding = 100
                    num_width = num_width + 6
                end

                if( length > num_width ) then
                    if( not( pen.vld( name ))) then name = "Boss" end
                    uid = new_font_vanilla_shadow( gui, uid, pic_x - length/2 + 3, pic_y + 2.5, pic_zs[2] - 0.001, name )
                end

                local value = ( math.floor( rounding*100*hp/max_hp + 0.5 )/rounding ).."%"
                uid = new_font_vanilla_shadow( gui, uid, pic_x + length/2 - ( 1 + get_text_dim( value )), pic_y + 2.5, pic_zs[2] - 0.001, value, nil, true )

                return uid, length, step
            end

            local storage_bar = get_storage( boss, "index_bar" )
            if( storage_bar ~= nil ) then
                bar_func = dofile_once( ComponentGetValue2( storage_bar, "value_string" ))
            end

            uid,_,step = bar_func( gui, uid, pic_x, pic_y, {zs.in_world_back+0.01,zs.in_world_back}, data, boss, nil, {
                low_hp = 0, low_hp_min = 0,
                length_mult = 2, height = 13,
                centered = true,
            })
            pic_y = pic_y - ( step + 4 )
        end
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_gold( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.delay )

    local this_data = data.Wallet
    if( #this_data > 0 and this_data[3] >= 0 and not( data.gmod.menu_capable )) then
        local god_i_love_money_holy_fuck = -1
        if( not( this_data[2])) then
            data.memo.money = data.memo.money or this_data[3]
            local delta = this_data[3] - data.memo.money
            data.memo.money = data.memo.money + limiter( limiter( 0.1*delta, 1, true ), delta )
            god_i_love_money_holy_fuck = data.memo.money
        end

        local v = get_short_num( god_i_love_money_holy_fuck )
        local dims = {}
        uid = new_shaded_image( gui, uid, pic_x + 2.5, pic_y - 1.5, zs.main, "data/ui_gfx/hud/money.png", {8,8})
        uid, dims = pen.new_text( gui, uid, pic_x + 13, pic_y, zs.main, v, { is_huge = false, is_shadow = true, alpha = 0.9 })
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = hud_text_fix( "$hud_gold" )..( data.short_gold and v or god_i_love_money_holy_fuck ).."$"
        uid = tipping( gui, uid, nil, nil, {
            pic_x + 2.5,
            pic_y - 1,
            10.5 + dims[1],
            8,
        }, { tip, tip_x - 43, tip_y - 1 }, {zs.tips,zs.main_far_back}, true )

        pic_y = pic_y + 8
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_orbs( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.gold )
    
    if( data.orbs > 0 and not( data.gmod.menu_capable )) then
        pic_y = pic_y + 1
        
        local dims = {}
        uid = new_shaded_image( gui, uid, pic_x + 3, pic_y, zs.main, "data/ui_gfx/hud/orbs.png", {8,8})
        uid, dims = pen.new_text( gui, uid, pic_x + 13, pic_y, zs.main, data.orbs, { is_huge = false, is_shadow = true, alpha = 0.9 })

        local tip_x, tip_y = unpack( xys.hp )
        local tip = GameTextGet( "$hud_orbs", tostring( data.orbs ))
        uid = tipping( gui, uid, nil, nil, {
            pic_x + 2,
            pic_y - 1,
            11 + dims[1],
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
        uid = new_font_vanilla_shadow( gui, uid, p_x, p_y, zs.main, txt, {255,255,255,alpha}, true )
    end
    
    data.memo.ui_info = data.memo.ui_info or { 0, 0 }
    if( not( data.is_opened and data.gmod.show_full ) and ( data.memo.ui_info[1] ~= 0 or data.pointer_delta[3] < data.info_threshold )) then
        local info = ""

        local entities = EntityGetInRadius( data.pointer_world[1], data.pointer_world[2], data.info_radius ) or {}
        if( #entities > 0 ) then
            local best_kind = -1
            local dist_tbl = {}
            for i,entity_id in ipairs( entities ) do
                if( EntityGetRootEntity( entity_id ) == entity_id and entity_id ~= data.player_id ) then
                    local kind = {}
                    local item_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ItemComponent" )
                    
                    local name = ""
                    local info_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "UIInfoComponent" )
                    if( info_comp ~= nil ) then
                        name = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "name" ) or "" )
                    end
                    if( check_item_name( name )) then
                        kind = { 0, name }
                    elseif( item_comp ~= nil and ComponentGetValue2( item_comp, "is_pickable" )) then
                        local name_func = function( item_id, item_comp, default_name )
                            local name = get_entity_name( item_id, item_comp )
                            return name == "" and default_name or name
                        end
                        for k,cat in ipairs( data.item_cats ) do
                            if( cat.on_check( entity_id )) then
                                local func = cat.on_info_name == nil and name_func or cat.on_info_name
                                kind = { k, func( entity_id, item_comp, cat.name )}
                                break
                            end
                        end
                    elseif( EntityHasTag( entity_id, "hittable" ) or EntityHasTag( entity_id, "mortal" )) then
                        name = get_entity_name( entity_id )
                        if( check_item_name( name )) then
                            kind = { 0, GameTextGetTranslatedOrNot( name )}
                        end
                    end

                    if( #kind > 0 ) then
                        if( best_kind < 0 or best_kind > kind[1]) then best_kind = kind[1] end
                        table.insert( dist_tbl, { entity_id, unpack( kind )})
                    end
                end
            end
            if( #dist_tbl > 0 ) then
                local the_one = closest_getter( data.pointer_world[1], data.pointer_world[2], dist_tbl, nil, nil, function( thing )
                    return thing[2] == best_kind
                end)
                if( the_one ~= 0 ) then
                    info = the_one[3]
                end
            end
        end
        
        local fading = 1
        if( check_item_name( info )) then
            data.memo.ui_info = { info, math.max( data.memo.ui_info[2], data.frame_num )}
        elseif( data.memo.ui_info[1] ~= 0 ) then
            info = data.memo.ui_info[1]

            local delta = data.frame_num - data.memo.ui_info[2]
            if( delta > 2*data.info_fading ) then
                data.memo.ui_info = nil
                info = ""
            elseif( delta > data.info_fading ) then
                fading = math.max( fading*math.sin(( 2*data.info_fading - delta )*math.pi/( 2*data.info_fading )), 0.01 )
            end
        end
        if( info ~= "" ) then
            local is_obstructed = data.dragger.item_id > 0 or ( data.frame_num - tip_anim["generic"][2]) < 2
            if( data.always_show_full or data.info_pointer ) then
                pic_x, pic_y = unpack( data.pointer_ui )
                pic_x, pic_y = pic_x + ( is_obstructed and -2 or 6 ), pic_y + 3
                fading = fading*data.info_pointer_alpha
            else
                pic_x, pic_y = xys.full_inv[1], xys.inv_root[2]
                pic_x, pic_y = pic_x + 3, pic_y + 5 + ( data.is_opened and 3 or 0 )
                is_obstructed = false
            end
            do_info( gui, pic_x, pic_y, info, fading, is_obstructed )
        end
    end

    if( not( data.gmod.menu_capable )) then
        local fading = 0.5
        data.memo.mtr_prb = data.memo.mtr_prb or { 0, 0 }
        local matter = data.memo.mtr_prb[1]
        if( data.pointer_matter > 0 ) then
            matter = data.pointer_matter
            data.memo.mtr_prb = { data.pointer_matter, math.max( data.memo.mtr_prb[2], data.frame_num )}
        elseif( data.memo.mtr_prb[1] > 0 ) then
            local delta = data.frame_num - data.memo.mtr_prb[2]
            if( delta > 2*data.info_fading ) then
                data.memo.mtr_prb = nil
                matter = 0
            elseif( delta > data.info_fading ) then
                fading = math.max( fading*math.sin(( 2*data.info_fading - delta )*math.pi/( 2*data.info_fading )), 0.01 )
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
            do_info( gui, pic_x + 2, pic_y - 2.5, txt, fading, true, alphaer )
        end
    end
    
    return uid, data, {pic_x,pic_y}
end

function new_generic_ingestions( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.hp )
    pic_y = pic_y + data.effect_icon_spacing
    local orb_x, orb_y = unpack( xys.orbs )
    pic_x, orb_y = orb_x, orb_y + 5
    if(( pic_y - orb_y ) < 0 ) then pic_y = orb_y end

    local this_data = data.icon_data.ings
    if( #this_data > 0 and not( data.gmod.menu_capable )) then
        pic_y = pic_y + 3
        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = 0, 0
            uid, step_x, step_y = data.icon_func( gui, uid, pic_x, pic_y, zs.main, this_one, 1 )
            pic_x, pic_y = pic_x, pic_y + step_y - 1
        end
        pic_y = pic_y + 4
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_stains( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.ingestions )

    local this_data = data.icon_data.stains
    if( #this_data > 0 and not( data.gmod.menu_capable )) then
        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = 0, 0
            uid, step_x, step_y = data.icon_func( gui, uid, pic_x, pic_y, zs.main, this_one, 2 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end
        pic_y = pic_y + 3
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_effects( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.stains )

    local this_data = data.icon_data.misc
    if( #this_data > 0 and not( data.gmod.menu_capable )) then
        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = 0, 0
            if( this_one.amount < 2 ) then this_one.txt = "" end
            uid, step_x, step_y = data.icon_func( gui, uid, pic_x, pic_y, zs.main, this_one, 3 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end
        pic_y = pic_y + 3
    end

    return uid, data, {pic_x,pic_y}
end

function new_generic_perks( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.effects )
    
    local this_data = data.perk_data
    if( #this_data > 0 and not( data.gmod.menu_capable )) then
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
            uid, step_x, step_y = data.icon_func( gui, uid, pic_x, pic_y, zs.main, this_one, 4 )
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
        
        if( data.sampo > 0 ) then
            local msg, clr = GameTextGet( "$hint_endingmcguffin_use", "[USE]" ), nil

            local sampo_spot = EntityGetClosestWithTag( x, y, "ending_sampo_spot_underground" ) or 0
            if( sampo_spot == 0 ) then
                sampo_spot = EntityGetClosestWithTag( x, y, "ending_sampo_spot_mountain" ) or 0
                if( sampo_spot > 0 ) then
                    local ng_num = tonumber( SessionNumbersGetValue( "NEW_GAME_PLUS_COUNT" ))
                    local check_num, going_ng = ng_num + 5, false
                    if( data.orbs < 33 ) then
                        local seven_eleven = data.orbs > ORB_COUNT_IN_WORLD and check_num >= ORB_COUNT_IN_WORLD and data.orbs >= check_num
                        local eleven_seven = data.orbs >= check_num and data.orbs < ORB_COUNT_IN_WORLD
                        if( seven_eleven or eleven_seven ) then
                            going_ng = true

                            msg = "+"
                            if( ng_num > 4 ) then
                                msg = msg.."("..( ng_num + 1 )..")"
                            else
                                for i = 1,ng_num do msg = msg.."+" end
                            end
                            msg = GameTextGet( "$hint_endingmcguffin_enter_newgameplus", "[USE]", msg )
                        end
                    end
                    
                    if( not( going_ng )) then
                        if( data.orbs == 11 ) then
                            clr = {255,255,178}
                        elseif( data.orbs > 32 ) then
                            clr = {121,201,153}
                        else
                            clr = {208,70,70}
                        end
                    end
                end
            elseif( data.orbs > 11 ) then
                clr = {208,70,70}
            end
            
            if( sampo_spot > 0 ) then
                local sampo_x, sampo_y = EntityGetTransform( data.sampo )
                local spot_x, spot_y = EntityGetTransform( sampo_spot )
                if(( math.abs( sampo_x - spot_x ) + math.abs( sampo_y - spot_y )) < 32 ) then
                    uid = info_func( gui, uid, screen_h, screen_w, data, {
                        id = sampo_spot,
                        desc = { capitalizer( GameTextGetTranslatedOrNot( "$biome_boss_victoryroom" )), msg },
                        txt = "[COMPLETE]",
                        color = {{121,201,153}, clr },
                    }, zs, xys )

                    return uid, data
                end
            end
        end

        local entities = EntityGetInRadius( x, y, 200 ) or {}
        if( #entities > 0 ) then
            local stuff_to_figure = table_init( #data.item_cats + 1, {})
            local interactables = {}
            for i,ent in ipairs( entities ) do
                local action_comp = EntityGetFirstComponentIncludingDisabled( ent, "InteractableComponent" )
                if( action_comp ~= nil and EntityGetFirstComponent( ent, "LuaComponent", "index_ctrl" ) ~= nil ) then
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
                                    local this_info = nil
                                    data, this_info = get_item_data( ent, data )
                                    if( this_info.id ~= nil ) then
                                        table.insert( item_data, this_info )

                                        if( item_data[5]) then
                                            this_info = 1
                                        else
                                            this_info = this_info.cat + 1
                                        end
                                    else
                                        this_info = 0
                                    end
                                    if( this_info > 0 ) then
                                        table.insert( stuff_to_figure[this_info], item_data )
                                    end
                                end
                            end
                        end
                    end
                end
            end

            local pickup_data = {
                id = 0,
                desc = "",
            }
            local button_time, no_space, cant_buy, got_info = true, false, false, false
            for i,tbl in ipairs( stuff_to_figure ) do
                if( #tbl > 0 ) then
                    table.sort( tbl, function( a, b )
                        return a[9] < b[9]
                    end)

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
                            local will_pause = cat_callback( data, item_data[10], "on_gui_pause" ) ~= nil
                            ComponentSetValue2( item_data[1][2], "inventory_slot", -5, -5 )
                            local new_data = (( will_pause or i == 1 or EntityHasTag( item_data[1][1], "index_slotless" )) and {inv_slot=0} or set_to_slot( item_data[10], data, true ))
                            if( new_data.inv_slot ~= nil ) then
                                if( i > 1 ) then
                                    pickup_data.id = item_data[1][1]
                                    pickup_data.desc = GameTextGet( item_data[8] == "" and ( is_shop and "$itempickup_purchase" or "$itempickup_pick" ) or item_data[8], "[USE]", item_data[10].name..( item_data[10].fullness or "" ))
                                    pickup_data.txt = "[GET]"
                                    pickup_data.this_info = item_data[10]
                                    pickup_data.do_sound = item_data[6]
                                    if( item_data[7]) then
                                        pickup_data.desc = { pickup_data.desc, item_data[10].desc }
                                    end
                                    
                                    button_time = false
                                    break
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
                            pickup_data.id = item_data[1][1]
                            pickup_data.name = item_data[10].name
                            pickup_data.this_info = item_data[10]
                        end
                    end
                    if( not( button_time )) then
                        break
                    end
                end
            end
            
            --[[
            if( data.is_opened and data.gmod.show_fullest ) then
                --create inv with -1 id
                
                for i,tbl in ipairs( stuff_to_figure ) do
                    if( i > 1 and #tbl > 0 ) then
                        table.sort( tbl, function( a, b )
                            return a[1][1] > b[1][1]
                        end)

                        for k,item_data in ipairs( tbl ) do
                            local cost_comp = EntityGetFirstComponentIncludingDisabled( item_data[1][1], "ItemCostComponent" )
                            if( cost_comp == nil ) then
                                local this_info = item_data[10]
                                uid, data, w, h = slot_setup( gui, uid, screen_w/2, screen_h - 50, zs, data, {
                                    inv_id = 0,
                                    id = this_info.id,
                                    inv_slot = {0,0},
                                    idata = this_info,
                                }, true, true, false )

                                --cleanup the thing once again, make sure the shit inherently supports virtual invs
                                --update the documentation

                                --slot_pic gotta autoinit the pic
                                --10 in a row, scales vertically based on the item count; don't allow to swap
                            end
                        end
                    end
                end
                
                --destroy inv with -1 id
            end
            ]]

            if( pickup_data.txt == nil and ( no_space or cant_buy )) then
                if( #interactables > 0 ) then
                    pickup_data.id = 0
                else
                    pickup_data.id = -pickup_data.id
                    pickup_data.desc = { full_stopper( GameTextGet( cant_buy and "$itempickup_notenoughgold" or "$itempickup_cannotpick", pickup_data.name )), true }
                end
            end
            if( pickup_data.id ~= 0 ) then
                local ignore_default = false
                if( data.is_opened and data.gmod.show_full ) then
                    pickup_data.id = -1
                    pickup_data.desc = { GameTextGet( "$itempickup_cannotpick_closeinventory", pickup_data.this_info.name ), true }
                else
                    local guiing = cat_callback( data, pickup_data.this_info, "on_gui_world" ) --this should be able to nuke the info_func
                    if( guiing ~= nil ) then
                        local i_x, i_y = EntityGetTransform( math.abs( pickup_data.id ))
                        local pic_x, pic_y = world2gui( i_x, i_y )
                        uid, ignore_default = guiing( gui, uid, nil, math.abs( pickup_data.id ), data, pickup_data.this_info, pic_x, pic_y, zs, no_space, cant_buy, cat_callback( data, pickup_data.this_info, "on_tooltip" ))
                    end
                end
                
                if( not( ignore_default )) then
                    uid = info_func( gui, uid, screen_h, screen_w, data, pickup_data, zs, xys )
                end
                if( pickup_data.id > 0 and data.Controls[3][2]) then
                    local pkp_x, pkp_y = EntityGetTransform( pickup_data.id )
                    local anim_x, anim_y = world2gui( pkp_x, pkp_y )
                    table.insert( slot_anim, {
                        id = pickup_data.id,
                        x = anim_x,
                        y = anim_y,
                        frame = data.frame_num,
                    })
                    
                    local orig_name = pickup_data.this_info.name
                    if( pickup_data.this_info.fullness ~= nil ) then
                        pickup_data.this_info.name = pickup_data.this_info.name..pickup_data.this_info.fullness
                    end
                    pick_up_item( data.player_id, data, pickup_data.this_info, pickup_data.do_sound )
                    pickup_data.this_info.name = orig_name
                end
            end

            local do_action = button_time and #interactables > 0
            if( do_action ) then
                table.sort( interactables, function( a, b )
                    return a[5] < b[5]
                end)

                local will_show = true
                local button_data = interactables[1]
                local storage_check = get_storage( button_data[1], "index_check" )
                if( storage_check ~= nil ) then
                    button_data, will_show, do_action = dofile_once( ComponentGetValue2( storage_check, "value_string" ))( data, button_data )
                end
                if( will_show ) then
                    local message_func = info_func
                    local storage_info = get_storage( button_data[1], "index_message" )
                    if( storage_check ~= nil ) then
                        message_func = dofile_once( ComponentGetValue2( storage_info, "value_string" ))
                    end

                    uid = message_func( gui, uid, screen_h, screen_w, data, {
                        id = button_data[1],
                        desc = { capitalizer( button_data[3]), string.gsub( button_data[4], "$0", "[USE]" )},
                        txt = "[USE]",
                    }, zs, xys )
                end
            end
            if( data.Controls[3][2]) then
                data.Controls[3][2] = false
                
                if( do_action and not( data.memo.action_skip_next or false )) then
                    local action_id = interactables[1][1]
                    EntitySetComponentIsEnabled( action_id, EntityGetFirstComponentIncludingDisabled( action_id, "InteractableComponent" ), true )
                    EntitySetComponentIsEnabled( action_id, EntityGetFirstComponent( action_id, "LuaComponent", "index_ctrl" ), false )
                    ComponentSetValue2( data.Controls[1], "mButtonFrameInteract", data.frame_num + 1 )
                    data.memo.action_skip_next = true
                else
                    ComponentSetValue2( data.Controls[1], "mButtonFrameInteract", 0 )
                    data.memo.action_skip_next = false
                end
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
        local this_info = from_tbl_with_id( data.item_list, this_item )
        local inv_data = data.inventories[ this_info.inv_id ] or {}
        local callback = cat_callback( data, this_info, "on_drop" )
        if( callback ~= nil ) then
            do_default = callback( this_item, data, this_info, false )
        end
        if( inv_data.update ~= nil ) then
            if( inv_data.update( data, from_tbl_with_id( data.item_list, p, nil, nil, inv_data ), this_info, {})) then
                local reset_id = get_item_owner( p, true )
                if( reset_id > 0 ) then
                    active_item_reset( reset_id )
                end
            end
        end
        if( do_default ) then
            local x, y = unpack( data.player_xy )
            drop_item( x, y, this_info, data, data.throw_force, not( data.no_action_on_drop ))
        end
        if( callback ~= nil ) then
            callback( this_item, data, this_info, true )
        end
    else
        play_sound( data, "error" )
    end
end

function new_generic_extra( gui, uid, screen_w, screen_h, data, zs, xys )
    if( #data.inventories_extra > 0 ) then
        for i,extra_inv in ipairs( data.inventories_extra ) do
            local inv_data = data.inventories[ extra_inv ]
            local x, y = EntityGetTransform( extra_inv )
            local pic_x, pic_y = world2gui( x, y )
            uid, data = inv_data.func( gui, uid, pic_x, pic_y, inv_data, data, zs, xys, data.slot_func )
        end
    end

    return uid, data
end

function new_generic_modder( gui, uid, screen_w, screen_h, data, zs, xys )
    local mode_data = data.gmod
    if( mode_data ~= nil and data.is_opened and ( not( data.gmod.is_hidden ) or data.gmod.force_show )) then
        local check = true
        local w,h = get_text_dim( mode_data.name )
        local pic_x, pic_y = xys.full_inv[1], xys.inv_root[2]
        if( not( mode_data.show_full )) then
            pic_x, pic_y = xys.inv_root[1], xys.full_inv[2]
            pic_x = pic_x + 7 + w
            pic_y = pic_y + 13
        elseif( xys.applets_r[1] <= ( pic_x + 5 )) then
            check = false
        end
        if( check ) then
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
            end
            if( clicked or get_input({ 86--[["keypad_-"]], "Key" }, "bb_invmode_previous", false, true )) then
                new_mode = new_mode - 1
                arrow_left_a = 1
            end
            uid, clicked, r_clicked, is_hovered = new_interface( data.the_gui, uid, { pic_x - 10, pic_y - 11, 15, 10 }, zs.tips )
            gonna_reset = gonna_reset or r_clicked
            gonna_highlight = gonna_highlight or is_hovered
            if( is_hovered ) then
                arrow_right_c = arrow_hl_c
                arrow_right_a = 1
            end
            if( clicked or get_input({ 87--[["keypad_+"]], "Key" }, "ba_invmode_next", false, true )) then
                new_mode = new_mode + 1
                arrow_right_a = 1
            end
            uid, is_hovered, clicked, r_clicked = tipping( data.the_gui, uid, nil, nil, {
                pic_x - ( 6 + w ),
                pic_y - 11,
                w + 6,
                10
            }, { mode_data.name.."@"..mode_data.desc }, zs.tips, mode_data.show_full )
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
                local total_count = #mode_data.gmods
                local go_ahead = true
                while( go_ahead ) do
                    if( new_mode < 1 ) then
                        new_mode = total_count
                    elseif( new_mode > total_count ) then
                        new_mode = 1
                    end
                    go_ahead = mode_data.gmods[ new_mode ].is_hidden or false
                    if( go_ahead ) then
                        new_mode = new_mode + ( arrow_left_a == 1 and -1 or 1 )
                    end
                end

                play_sound( data, gonna_reset and "reset" or "click" )
                ComponentSetValue2( get_storage( data.main_id, "global_mode" ), "value_int", new_mode )
            end
            
            uid = pen.new_text( gui, uid, pic_x - ( 3 + w ), pic_y - ( 2 + h ), zs.main, mode_data.name, { alpha = alpha })
            uid = data.plate_func( gui, uid, pic_x - ( 4 + w ), pic_y - 9, zs.main_back, { w + 2, 6 })
            
            colourer( gui, arrow_left_c )
            uid = new_image( gui, uid, pic_x - ( 12 + w ), pic_y - 10, zs.main_back, "data/ui_gfx/keyboard_cursor_right.png", nil, nil, arrow_left_a )
            colourer( gui, arrow_right_c )
            uid = new_image( gui, uid, pic_x - 2, pic_y - 10, zs.main_back, "data/ui_gfx/keyboard_cursor.png", nil, nil, arrow_right_a )
        end
    end

    return uid, data
end