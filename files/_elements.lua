dofile_once( "mods/index_core/files/_lib.lua" )

function index.new_generic_slot( pic_x, pic_y, slot_data, can_drag, is_full, is_quick )
	local info = slot_data.idata or {}
	if( not( slot_data.id )) then
		slot_data.id = -1
		info = { id = slot_data.id, in_hand = 0 }
	elseif( not( pen.vld( info.id, true ))) then
		info = pen.t.get( index.D.item_list, slot_data.id )
	end
	if( pen.vld( slot_data.id, true )) then
		if( EntityHasTag( info.id, "index_unlocked" )) then
			can_drag = true
		elseif( info.is_locked ) then can_drag = false end
	elseif( EntityHasTag( index.D.dragger.item_id, "index_unlocked" )) then
		local inv_info = pen.t.get( index.D.item_list, slot_data.inv_id, nil, nil, {})
		if( not( pen.vld( inv_info.id, true )) or not( inv_info.is_frozen )) then can_drag = true end
	end
	
	local w, h, clicked, r_clicked, is_hovered = index.D.slot_func(
		pic_x, pic_y, slot_data, info, pen.vld( info.in_hand, true ), can_drag, is_full, is_quick )
	if( pen.vld( info.cat )) then
		index.cat_callback( info, "on_inventory", {
			pic_x, pic_y, {
				can_drag = can_drag,
				is_dragged = pen.vld( index.D.dragger.item_id, true ) and index.D.dragger.item_id == info.id,
				in_hand = pen.vld( info.in_hand, true ),
				is_quick = is_quick,
				is_full = is_full,
			}
		})
	end
	
	return w, h
end

function index.new_generic_inventory( screen_w, screen_h, xys )
    local root_x, root_y = unpack( xys.full_inv or { 19, 20 })
    local pic_x, pic_y = root_x, root_y
    
    local function check_shortcut( id, is_quickest )
        if( id <= 4 ) then return index.get_input(( is_quickest and "quickest_" or "quick_" )..id ) end
    end
    
    pen.hallway( function()
        local full_depth = 1
        if( index.D.gmod.show_fullest or pen.c.index_settings.force_vanilla_fullest ) then
            full_depth = #index.D.slot_state[ index.D.invs_p.f ][1] end
        if( index.D.is_opened ) then
            local bg_x, bg_y = pic_x - 3, pic_y - 3
            pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_a.xml" )
            for i = 1,( 5*#index.D.slot_state[ index.D.invs_p.q ].quickest - 1 ) do
                bg_x = bg_x + 4
                pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_b.xml" )
            end
            bg_x = bg_x + 4
            pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_c.xml" )
            bg_x = bg_x + 3
            pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_d.xml" )
            bg_x = bg_x + 5
            pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_c.xml", { s_x = -1 })
            for i = 1,( 5*#index.D.slot_state[ index.D.invs_p.q ].quick - 1 ) do
                pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_b.xml" )
                bg_x = bg_x + 4
            end
            pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_e.xml" )
            if( index.D.gmod.show_full and full_depth == 1 and not( index.D.gmod.allow_external_inventories )) then
                bg_x = bg_x + 7
                pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_a.xml" )
                for i = 1,( 5*#index.D.slot_state[ index.D.invs_p.f ]) do
                    bg_x = bg_x + 4
                    pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND, "mods/index_core/files/pics/vanilla_inv_b.xml" )
                end
                bg_x = bg_x + 2
                pen.new_image( bg_x, bg_y, pen.LAYERS.BACKGROUND - 0.01, "mods/index_core/files/pics/vanilla_inv_e.xml" )
            end
            
            if( not( index.D.gmod.can_see )) then
                local delta = math.max(( index.M.inv_alpha or index.D.frame_num ) - index.D.frame_num, 0 )
                local alpha = 0.5*math.cos( math.pi*delta/30 )
                pen.new_image( -2, -2, pen.LAYERS.BACKGROUND + 1,
                    "data/ui_gfx/empty_black.png", { s_x = screen_w + 4, s_y = screen_h + 4, alpha = alpha })
            end
        end

        xys.inv_root, xys.full_inv = { root_x - 3, root_y - 3 }, { root_x + 2, root_y + 26 }

        local cat_wands = pic_x
        local w, h, step = 0, 0, 1
        for i,slot in ipairs( index.D.slot_state[ index.D.invs_p.q ].quickest ) do
            w, h = index.new_generic_slot( pic_x, pic_y, {
                inv_slot = { i, -1 },
                inv_id = index.D.invs_p.q, id = slot,
                force_equip = check_shortcut( i, true ),
            }, index.D.is_opened, false, true )
            pic_x = pic_x + w + step
        end
        pic_x = pic_x + index.D.inv_spacings[1]

        local cat_items = pic_x
        for i,slot in ipairs( index.D.slot_state[ index.D.invs_p.q ].quick ) do
            w, h = index.new_generic_slot( pic_x, pic_y, {
                inv_slot = { i, -2 },
                inv_id = index.D.invs_p.q, id = slot,
                force_equip = check_shortcut( i, false ),
            }, index.D.is_opened, false, true )
            pic_x = pic_x + w + step
        end

        if( index.D.is_opened ) then
            pic_x = pic_x + index.D.inv_spacings[2]
            pen.new_shadowed_text( cat_wands + 1, pic_y - 13, pen.LAYERS.MAIN_DEEP,
                GameTextGetTranslatedOrNot( "$hud_title_wands" ))
            pen.new_shadowed_text( cat_items + 1, pic_y - 13, pen.LAYERS.MAIN_DEEP,
                GameTextGetTranslatedOrNot( "$hud_title_throwables" ))
            if( index.D.gmod.show_full ) then
                pen.new_shadowed_text( pic_x + 1, pic_y - 13, pen.LAYERS.MAIN_DEEP,
                    GameTextGetTranslatedOrNot( "$menuoptions_heading_misc" ))
            end
        end
        
        if( index.D.gmod.show_full and ( index.D.is_opened or index.D.always_show_full )) then
            for i,col in ipairs( index.D.slot_state[ index.D.invs_p.f ]) do
                for e = 1,full_depth do
                    w, h = index.new_generic_slot( pic_x, pic_y, {
                        inv_slot = { i, e },
                        inv_id = index.D.invs_p.f, id = col[e],
                    }, index.D.is_opened, true, index.D.is_opened )
                    pic_y = pic_y + h + step
                end
                pic_x, pic_y = pic_x + w + step, root_y
            end
        end

        pic_y = pic_y + h
        index.D.xys.inv_root_orig = { root_x, root_y }
        index.D.xys.full_inv_orig = { pic_x, pic_y }
        if( index.D.is_opened ) then
            root_x, root_y = root_x - 3, root_y - 3
            pic_x, pic_y = pic_x + 3 - step, pic_y + 3
        end

        -- if( InputIsKeyJustDown( 41--[[escape]])) then
        --     index.D.inv_toggle = index.D.is_opened
        -- else
        if( index.D.Controls.inv[2]) then index.D.inv_toggle = true end
    end)
    return { root_x, root_y }, { pic_x, pic_y }
end

function index.new_generic_applets( screen_w, screen_h, xys )
    local data = index.D.applets
    local pic_x_l, pic_x_r, pic_y = 0, screen_w, 4

    local function applet_setup( pic_x, type )
        local is_left = type == 1
        local sign = is_left and -1 or 1
        local tbl = {
            { "l", "l_state", "l_frame", "applets_l_drift", "l_hover" },
            { "r", "r_state", "r_frame", "applets_r_drift", "r_hover" },
        }

        local l = #data[ tbl[ type ][1]]*11
        local drift_target, core_off = 5, is_left and -10 or 0
        local total_drift, allow_clicks = l - drift_target, true
        if( not( data[ tbl[ type ][2]])) then
            local clicked, r_clicked, is_hovered = pen.new_interface(
                is_left and -1 or ( screen_w - 10 ), -1, 11, 19, pen.LAYERS.TIPS_FRONT )
            index.D.tip_func( "[APPLETS]", { is_active = is_hovered })
            if( not( is_hovered )) then drift_target = 0 end

            if( clicked ) then
                allow_clicks = false
                index.play_sound( "click" )
                data[ tbl[ type ][2]] = true
                data[ tbl[ type ][3]] = index.D.frame_num
            end
        else
            local delta = index.D.frame_num - ( data[ tbl[ type ][3]] or 0 )
            if( delta < 16 ) then
                local k = 5
                allow_clicks = false
                local v = k*math.sin( delta*math.pi/k )/( math.pi*delta^2 )
                core_off = total_drift*( 1 - v )
            else core_off = total_drift end
        end
        
        index.D[ tbl[ type ][4]] = total_drift
        local arrow_off = is_left and ( l - 8 ) or 0
        local extra_off = pen.estimate( tbl[ type ][4], drift_target, "exp5", 1 )
        pic_x = pic_x - sign*( core_off + extra_off )

        if( data[ tbl[ type ][2]]) then
            arrow_off = arrow_off + extra_off + 2
            if( is_left ) then pic_x = pic_x - 10 end
            local reset_em, got_one = 0, false
            local clicked, is_hovered = false, false
            for i,icon in ipairs( data[ tbl[ type ][1]]) do
                local t_x = pic_x + sign*( i - 1 )*11
                local metahover = not( got_one ) and data[ tbl[ type ][5]][i]
                local clicked,_,is_hovered = pen.new_interface( t_x, pic_y, 10, 10, pen.LAYERS.MAIN_BACK )
                pen.new_image( t_x - 1, pic_y - 1, pen.LAYERS.MAIN_BACK, icon.pic, { angle = metahover and math.rad( -5 ) or 0 })

                pen.hallway( function()
                    if( not( allow_clicks )) then return end
                    index.D.tip_func( icon.name..( pen.vld( icon.desc ) and "\n"..icon.desc or "" ), { tid = "applet_tip",
                        pos = { is_left and 2 or ( screen_w - 1 ), pic_y + 14 }, is_active = metahover, is_left = not( is_left )})
                    if( not( clicked and reset_em == 0 )) then return end
                    if( not( icon.mute or false )) then index.play_sound( "click" ) end
                    
                    reset_em = i
                    if( pen.vld( icon.toggle ) and icon.toggle( true ) and not( is_left )) then
                        pen.t.loop( index.D.gmods, function( i, gmod )
                            if( not( gmod.menu_capable )) then return end
                            GlobalsSetValue( index.GLOBAL_GLOBAL_MODE, tostring( i ))
                            return true
                        end)
                    end
                    for k,icn in ipairs( data[ tbl[ type ][1]]) do
                        if( pen.vld( icn.toggle )) then icn.toggle( false ) end
                    end
                end)
                if( is_hovered and not( data[ tbl[ type ][5]][i] )) then index.play_sound( "hover" ) end
                data[ tbl[ type ][5]][i] = is_hovered
                if( is_hovered ) then got_one = true end
            end
        else pen.colourer( nil, pen.PALETTE.VNL.YELLOW ) end

        if( is_left ) then pic_x = pic_x - ( l - 10 ) end
        pen.new_image( pic_x - sign*( 1 + arrow_off ), pic_y + 1,
            pen.LAYERS.MAIN_BACK - 0.001, "data/ui_gfx/keyboard_cursor"..( is_left and ".png" or "_right.png" ))
        index.D.box_func( pic_x, pic_y, pen.LAYERS.MAIN_DEEP - 0.1, { total_drift + 5, 10 })
        if( is_left ) then
            pic_x = pic_x + arrow_off + 11
        else pic_x = pic_x - ( 3 + arrow_off ) end
        return pic_x
    end

    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        
        if( index.D.is_opened ) then
            if( index.D.gmod.show_full and #data.r > 1 ) then pic_x_r = applet_setup( pic_x_r, 2 ) end
        elseif( #data.l > 1 ) then pic_x_l = applet_setup( pic_x_l, 1 ) end
    end)
    return { pic_x_l, pic_y }, { pic_x_r, pic_y }
end

function index.new_generic_hp( screen_w, screen_h, xys )
    local data = index.D.DamageModel
    local red_shift, length, height = 0, 0, 0
    local pic_x, pic_y = unpack( xys.hp or { screen_w - 41, 20 })
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( not( ComponentGetIsEnabled( data.comp ))) then return end
        local max_hp, hp = data.hp_max, data.hp
        if( max_hp <= 0 ) then return end
        
        length, height, max_hp, hp, red_shift = index.new_vanilla_hp(
            pic_x, pic_y, pen.LAYERS.MAIN_BACK, index.D.player_id, { dmg_data = data })
        
        local max_hp_text, hp_text = pen.get_short_num( max_hp ), pen.get_short_num( hp )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "data/ui_gfx/hud/health.png", { has_shadow = true })
        pen.new_text( pic_x + 13, pic_y, pen.LAYERS.MAIN, hp_text, { is_huge = false, has_shadow = true, alpha = 0.9 })
        
        local tip = index.hud_text_fix( "$hud_health" )..( index.D.short_hp and hp_text.."/"..max_hp_text or hp.."/"..max_hp )
        index.tipping( pic_x - ( length + 2 ), pic_y - 1, nil, length + 4, 8, tip, { pos = { pic_x - 44, pic_y + 10 }, is_left = true })
        pic_y = pic_y + 10
    end)

    GameSetPostFxParameter( "low_health_indicator_alpha_proper", index.D.hp_flashing_intensity*red_shift, 0, 0, 0 )

    return { pic_x, pic_y }
end

function index.new_generic_air( screen_w, screen_h, xys )
    local data = index.D.DamageModel
    local pic_x, pic_y = unpack( xys.hp )
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( not( ComponentGetIsEnabled( data.comp ))) then return end
        if( not( data.can_air ) or data.air/data.air_max > 0.9 ) then return end

        pen.new_text( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "o2", { is_huge = false, has_shadow = true, alpha = 0.9 })
        index.new_vanilla_bar( pic_x, pic_y,
            pen.LAYERS.MAIN_BACK, { 40, 2, 40*math.max( data.air, 0 )/data.air_max }, pen.PALETTE.VNL.MANA, nil, 0.75 )

        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$hud_air" )..index.hud_num_fix( data.air, data.air_max, 2 )
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_flight( screen_w, screen_h, xys )
    local data = index.D.CharacterData
    local pic_x, pic_y = unpack( xys.air )
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( data.flight_always or data.flight_max == 0 ) then return end

        if( index.M.flight_shake == nil ) then
            if( index.D.Controls.fly[1] and data.flight <= 0 ) then
                index.M.flight_shake = index.D.frame_num
            end
        end

        local shake_frame = index.D.frame_num - ( index.M.flight_shake or index.D.frame_num )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "data/ui_gfx/hud/jetpack.png", { has_shadow = true })
        index.new_vanilla_bar( pic_x, pic_y, pen.LAYERS.MAIN_BACK, { 40, 2, 40*math.max( data.flight, 0 )/data.flight_max },
            pen.PALETTE.VNL.FLIGHT, index.M.flight_shake ~= nil and shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$hud_jetpack" )..index.hud_num_fix( data.flight, data.flight_max, 2 )
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        if( shake_frame >= 20 ) then index.M.flight_shake = nil end
        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_mana( screen_w, screen_h, xys )
    local data = index.D.active_info
    local pic_x, pic_y = unpack( xys.flight )
    pen.hallway( function()
        if( not( pen.vld( data.id, true ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        index.M.mana_shake = index.M.mana_shake or {}

        local value = { 0, 0 }
        local potion_info = {}
        local throw_it_back = nil
        if( pen.vld( data.wand_info )) then
            local mana = data.wand_info.mana
            local mana_max = data.wand_info.mana_max
            value = { math.min( math.max( mana, 0 ), mana_max ), mana_max }
            if( index.M.mana_shake[ index.D.active_item ] == nil ) then
                if( index.D.no_mana_4life ) then index.M.mana_shake[ index.D.active_item ] = index.D.frame_num end
            end

            local shake_frame = index.D.frame_num - ( index.M.mana_shake[ index.D.active_item ] or index.D.frame_num )
            throw_it_back = index.M.mana_shake[ index.D.active_item ] ~= nil and -shake_frame or nil
            if( shake_frame >= 20 ) then index.M.mana_shake[ index.D.active_item ] = nil end
        elseif( pen.vld( data.matter_info ) and data.matter_info.volume >= 0 ) then
            value = { math.max( data.matter_info.matter[1], 0 ), data.matter_info.volume }
            potion_info = { pic = "data/ui_gfx/hud/potion.png" }
            if( index.D.fancy_potion_bar ) then
                potion_info.color = pen.magic_uint( GameGetPotionColorUint( index.D.active_item ))
                potion_info.alpha = 0.8
            end
        end
        
        if( value[1] < 0 or value[2] <= 0 ) then return end
        
        local ratio = math.min( value[1]/value[2], 1 )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, potion_info.pic or "data/ui_gfx/hud/mana.png", { has_shadow = true })
        if( pen.vld( potion_info.color )) then
            pen.new_pixel( pic_x - 40, pic_y + 1, pen.LAYERS.MAIN_BACK + 0.001, pen.PALETTE.W, math.min( 40*ratio + 0.5, 40 ), 2 ) end
        index.new_vanilla_bar( pic_x, pic_y,
            pen.LAYERS.MAIN_BACK, { 40, 2, 40*ratio }, potion_info.color or pen.PALETTE.VNL.MANA, throw_it_back, potion_info.alpha )
        
        local tip = ""
        if( pen.vld( potion_info )) then
            tip = data.name..( data.fullness ~= nil and "\n"..data.fullness or "" )
        else tip = index.hud_text_fix( "$hud_wand_mana" )..index.hud_num_fix( value[1], value[2]) end

        local tip_x, tip_y = unpack( xys.hp )
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_reload( screen_w, screen_h, xys )
    local data = index.D.active_info
    local pic_x, pic_y = unpack( xys.mana )
    local is_real = pen.vld( data.wand_info, true )

    index.M.reload_max = index.M.reload_max or {}
    index.M.reload_shake = index.M.reload_shake or {}

    pen.hallway( function()
        if( not( is_real )) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( data.wand_info.never_reload ) then return end

        local reloading = data.wand_info.reload_frame
        local reloading_full = index.M.reload_max[ index.D.active_item ]
        if(( reloading_full or -1 ) < reloading ) then reloading_full = reloading end
        index.M.reload_max[ index.D.active_item ] = reloading_full
        
        if( reloading_full <= index.D.reload_threshold ) then return end

        local reloading_shake = index.M.reload_shake[ index.D.active_item ]
        local it_is_time = index.D.just_fired and reloading_full ~= reloading 
        if( not( pen.vld( reloading_shake )) and it_is_time ) then reloading_shake = index.D.frame_num end
        index.M.reload_shake[ index.D.active_item ] = reloading_shake
        
        local shake_frame = index.D.frame_num - ( reloading_shake or index.D.frame_num )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "data/ui_gfx/hud/reload.png", { has_shadow = true })
        index.new_vanilla_bar( pic_x, pic_y, pen.LAYERS.MAIN_BACK,
            { 40, 2, 40*reloading/reloading_full }, pen.PALETTE.VNL.CAST, pen.vld( reloading_shake ) and -shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$hud_wand_reload" )..string.format( "%.2f", reloading/60 ).."s"
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        if( shake_frame >= 20 ) then index.M.reload_shake[ index.D.active_item ] = nil end
        pic_y = pic_y + 8
    end)

    local is_done = (( data.wand_info or {}).reload_frame or 0 ) == 0 
    if( not( is_real ) or is_done ) then index.M.reload_max[ index.D.active_item ] = nil end
    return { pic_x, pic_y }
end

function index.new_generic_delay( screen_w, screen_h, xys )
    local data = index.D.active_info
    local pic_x, pic_y = unpack( xys.reload )
    local is_real = pen.vld( data.wand_info, true )
    
    index.M.delay_max = index.M.delay_max or {}
    index.M.delay_shake = index.M.delay_shake or {}

    pen.hallway( function()
        if( not( is_real )) then return end
        if( index.D.gmod.menu_capable ) then return end

        local delay = data.wand_info.delay_frame
        local delay_full = index.M.delay_max[ index.D.active_item ]
        if(( delay_full or -1 ) < delay ) then delay_full = delay end
        index.M.delay_max[ index.D.active_item ] = delay_full
        
        if( delay_full <= index.D.reload_threshold ) then return end

        local delay_shake = index.M.delay_shake[ index.D.active_item ]
        local it_is_time = index.D.just_fired and delay_full ~= delay
        if( not( pen.vld( delay_shake )) and it_is_time ) then delay_shake = index.D.frame_num end
        index.M.delay_shake[ index.D.active_item ] = delay_shake
        
        local shake_frame = index.D.frame_num - ( delay_shake or index.D.frame_num )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "data/ui_gfx/hud/fire_rate_wait.png", { has_shadow = true })
        index.new_vanilla_bar( pic_x, pic_y, pen.LAYERS.MAIN_BACK,
            { 40, 2, 40*delay/delay_full }, pen.PALETTE.VNL.CAST, pen.vld( delay_shake ) and -shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$inventory_castdelay" )..string.format( "%.2f", delay/60 ).."s"
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        if( shake_frame >= 20 ) then index.M.delay_shake[ index.D.active_item ] = nil end
        pic_y = pic_y + 8
    end)
    
    local is_done = (( data.wand_info or {}).delay_frame or 0 ) == 0 
    if( not( is_real ) or is_done ) then index.M.delay_max[ index.D.active_item ] = nil end
    return { pic_x, pic_y }
end

function index.new_generic_bossbar( screen_w, screen_h, xys )
    local x, y = unpack( index.D.player_xy )
    local pic_x, pic_y = unpack( xys.bossbar or { screen_w/2, screen_h - 23 })
    pen.t.loop( EntityGetInRadiusWithTag( x, y, 1000, "hittable" ), function( i, enemy )
        local bar_comp = EntityGetFirstComponent( enemy, "HealthBarComponent" )
        if( not( pen.vld( bar_comp, true ))) then return end
        
        local b_x, b_y = EntityGetTransform( enemy )
        local distance = math.sqrt(( b_x - x )^2 + ( b_y - y )^2 )
        if( distance > ComponentGetValue2( bar_comp, "gui_max_distance_visible" )) then return end
        local in_world, is_boss = ComponentGetValue2( bar_comp, "in_world" ), EntityHasTag( enemy, "boss" )

        local bar_func = function( pic_x, pic_y, pic_z, entity_id, data )
            local custom_pos = ( data.custom or {}).pos or {}
            if( not( data.in_world )) then data.length, data.height = custom_pos[3], custom_pos[4] or data.height end
            data.color_hp = data.custom.color

            local name = index.get_entity_name( entity_id )
            local length, height, max_hp, hp = index.new_vanilla_hp( pic_x, pic_y, pic_z, entity_id, data )
            
            if( not( data.in_world ) and pen.vld( data.custom.pic )) then
                local pic_w, pic_h = pen.get_pic_dims( data.custom.pic )
                local off_x, off_y = custom_pos[5] or 0, custom_pos[6] or 0
                local t_x, t_y = pic_x - pic_w/2 + off_x, pic_y - 2 + off_y
                pen.new_image( t_x, t_y, pic_z - 0.01, data.custom.pic )
                if( pen.vld( data.custom.color_bg )) then
                    t_x, t_y = t_x + ( custom_pos[1] or 0 ), t_y + ( custom_pos[2] or 0 )
                    pen.new_pixel( t_x, t_y, pic_z + 0.1, data.custom.color_bg, length, height )
                end
            end

            local rounding = 10
            local off_name, off_perc = 3, -1
            local off_text = (( height - ({ pen.get_text_dims( "100", true )})[2])/2 + 1 )
            if( max_hp >= 10^6 ) then rounding = 1000 elseif( max_hp >= 10^5 ) then rounding = 100 end
            if( not( data.in_world ) and pen.vld( data.custom.pic )) then off_name, off_perc = 8, -6 end

            if( not( pen.vld( name ))) then name = data.is_boss and "Boss" or "Enemy" end
            local t_x = pic_x + ( data.in_world and 0 or ( -length/2 + off_name ))
            local t_y = pic_y + ( data.in_world and ( height + 1 ) or off_text )
            pen.new_text( t_x, t_y, pic_z - 0.01, pen.capitalizer( name ), { is_centered_x = data.in_world, has_shadow = true })
            
            local value = pen.rounder( 100*hp/max_hp, rounding ).."%"
            t_x, t_y = pic_x + ( data.in_world and 4 or ( length/2 + off_perc )), pic_y + ( data.in_world and 0.5 or off_text )
            pen.new_text( t_x, t_y, pic_z - 0.01, value, { is_centered_x = data.in_world, alpha = 0.75, is_right_x = not( data.in_world ),
                color = data.custom.color_text or pen.PALETTE.VNL[ pen.vld( data.custom.pic ) and "ACTION_OTHER" or "BROWN" ]})
            pen.new_text( t_x, t_y, pic_z + 0.007, value, { is_centered_x = data.in_world, is_right_x = not( data.in_world )})
            
            if( pen.vld( data.custom.func_extra ) and not( in_world )) then
                data.custom.func_extra( pic_x, pic_y, pic_z, entity_id, data, hp/max_hp ) end
            return length, height
        end

        local func_path = pen.magic_storage( enemy, "index_bar", "value_string" )
        if( pen.vld( func_path )) then bar_func = dofile_once( func_path ) end

        local custom = index.D.boss_bars[ EntityGetFilename( enemy )] or {}
        local pics = EntityGetComponent( enemy, "SpriteComponent", "health_bar" )
        if( pen.vld( pics ) and pen.vld( custom )) then
            for i,pic in ipairs( pics ) do EntitySetComponentIsEnabled( enemy, pic, false ) end
        elseif( pen.vld( pics )) then return end

        local bar_x, bar_y = pic_x, pic_y
        in_world = ( in_world or custom.in_world )
        if( index.D.boss_bar_mode ~= 1 ) then in_world = index.D.boss_bar_mode == 2 end
        if( in_world ) then bar_x, bar_y = pen.world2gui( b_x, b_y ); bar_y = bar_y + 20 end --pen.get_creature_dimensions
        local l,h = ( custom.func or bar_func )( bar_x, bar_y, pen.LAYERS.WORLD_BACK, enemy, {
            custom = custom,
            centered = true, in_world = in_world, is_boss = is_boss,
            low_hp = 0, low_hp_min = 0, only_slider = pen.vld( custom ) and not( in_world ),
            length_mult = in_world and 0.75 or 2, height = in_world and 9 or 13,
        })
        
        if( not( in_world )) then pic_y = pic_y - ( h + 4 ) end
    end)
    return { pic_x, pic_y }
end

function index.new_generic_gold( screen_w, screen_h, xys )
    local data = index.D.Wallet
    local pic_x, pic_y = unpack( xys.delay )
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( data.money < 0 ) then return end
        
        local le_money = data.money_always and -1 or math.floor( pen.estimate( "index_gold", data.money, "exp10", data.money/1000 ))
        
        local tip_x, tip_y = unpack( xys.hp )
        local v = pen.get_short_num( le_money )
        local money_string = " "..(( data.money_always or index.D.short_gold ) and v or le_money ).."$"
        local tip = string.gsub( index.hud_text_fix( "$hud_gold" ), "\n$", money_string )
        local is_hovered = index.tipping( pic_x + 2.5, pic_y - 1, pen.LAYERS.TIPS,
            10.5 + pen.get_text_dims( v, true ), 8, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        
        local c = is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W
        pen.new_image( pic_x + 2.5, pic_y - 1.5, pen.LAYERS.MAIN, "data/ui_gfx/hud/money.png", { color = c, has_shadow = true })
        pen.new_text( pic_x + 13, pic_y, pen.LAYERS.MAIN, v, { color = c, is_huge = false, has_shadow = true, alpha = 0.9 })

        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_orbs( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.gold )
    pen.hallway( function()
        if( index.D.gmod.menu_capable ) then return end
        if( index.D.orbs <= 0 ) then return end
        pic_y = pic_y + 1
        
        local v = tostring( index.D.orbs )
        local tip_x, tip_y = unpack( xys.hp )
        local tip = GameTextGet( "$hud_orbs", v )
        local is_hovered = index.tipping( pic_x + 2, pic_y - 1, pen.LAYERS.TIPS,
            11 + pen.get_text_dims( v, true ), 8, tip, { pos = { tip_x - 44, tip_y }, is_left = true })

        local c = is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W
        pen.new_image( pic_x + 3, pic_y, pen.LAYERS.MAIN, "data/ui_gfx/hud/orbs.png", { color = c, has_shadow = true })
        pen.new_text( pic_x + 13, pic_y, pen.LAYERS.MAIN, v, { color = c, is_huge = false, has_shadow = true, alpha = 0.9 })

        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_info( screen_w, screen_h, xys )
    local function do_info( p_x, p_y, txt, alpha, is_right, hover_func )
        local offset_x = 0
        txt = pen.capitalizer( txt )
        if( is_right ) then
            local w,h = pen.get_text_dims( txt, true )
            offset_x = w + 1; p_x = p_x - offset_x
        end

        local color = pen.vld( hover_func ) and hover_func( offset_x ) or nil
        pen.new_shadowed_text( p_x, p_y, pen.LAYERS.MAIN, txt, { color = color, alpha = alpha })
    end
    
    local pic_x, pic_y = 0, 0
    index.M.ui_info = index.M.ui_info or { 0, 0 }
    pen.hallway( function()
        if( index.D.is_opened and index.D.gmod.show_full ) then return end
        if( index.M.ui_info[1] == 0 and index.D.pointer_delta[3] >= index.D.info_threshold ) then return end

        local info = ""
        local best_kind, dist_tbl = -1, {}
        local x, y = unpack( index.D.pointer_world )
        pen.t.loop( EntityGetInRadius( x, y, index.D.info_radius ), function( i, entity_id )
            if( entity_id == index.D.player_id ) then return end
            if( EntityGetRootEntity( entity_id ) ~= entity_id ) then return end

            local kind, name = {}, ""
            local item_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ItemComponent" )
            local info_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "UIInfoComponent" )
            if( pen.vld( info_comp, true )) then name = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "name" ) or "" ) end

            if( index.check_item_name( name )) then
                kind = { 0, name }
            elseif( pen.vld( item_comp, true ) and ComponentGetValue2( item_comp, "is_pickable" )) then
                local name_func = function( item_id, item_comp, default_name )
                    local name = index.get_entity_name( item_id, item_comp )
                    return pen.vld( name ) and name or default_name
                end
                pen.t.loop( index.D.item_cats, function( k, cat )
                    if( not( cat.on_check( entity_id ))) then return end
                    local func = pen.vld( cat.on_info_name ) and cat.on_info_name or name_func
                    kind = { k, func( entity_id, item_comp, cat.name )}
                    return true
                end)
            elseif( EntityHasTag( entity_id, "hittable" ) or EntityHasTag( entity_id, "mortal" )) then
                name = index.get_entity_name( entity_id )
                if( index.check_item_name( name )) then kind = { 0, GameTextGetTranslatedOrNot( name )} end
            end

            if( not( pen.vld( kind ))) then return end
            if( best_kind < 0 or best_kind > kind[1]) then best_kind = kind[1] end
            table.insert( dist_tbl, { entity_id, unpack( kind )})
        end)
        if( pen.vld( dist_tbl )) then
            local the_one = pen.get_closest(
                index.D.pointer_world[1], index.D.pointer_world[2], dist_tbl, nil, nil, function( thing ) return thing[2] == best_kind end)
            if( the_one ~= 0 ) then info = the_one[3] end
        end
        
        local fading = 1
        if( index.check_item_name( info )) then
            index.M.ui_info = { info, math.max( index.M.ui_info[2], index.D.frame_num )}
        elseif( index.M.ui_info[1] ~= 0 ) then
            info = index.M.ui_info[1]

            local delta = index.D.frame_num - index.M.ui_info[2]
            if( delta > 2*index.D.info_fading ) then
                index.M.ui_info, info = nil, ""
            elseif( delta > index.D.info_fading ) then
                fading = math.max( fading*math.sin(( 2*index.D.info_fading - delta )*math.pi/( 2*index.D.info_fading )), 0.01 )
            end
        end

        if( not( pen.vld( info ))) then return end
        local tip_anim = (( pen.c.ttips or {})[ "dft" ] or {}).going or 0
        local is_obstructed = index.D.dragger.item_id > 0 or ( index.D.frame_num - tip_anim ) < 2
        if( index.D.always_show_full or index.D.info_pointer ) then
            pic_x, pic_y = unpack( index.D.pointer_ui )
            pic_x, pic_y = pic_x + ( is_obstructed and -2 or 6 ), pic_y + 3
            fading = fading*index.D.info_pointer_alpha
        else
            pic_x, pic_y = xys.full_inv[1], xys.inv_root[2]
            pic_x, pic_y = pic_x + 3, pic_y + 5 + ( index.D.is_opened and 3 or 0 )
            is_obstructed = false
        end

        do_info( pic_x, pic_y, info, fading, is_obstructed )
    end)
    pen.hallway( function()
        if( index.D.gmod.menu_capable ) then return end

        index.M.mtr_prb = index.M.mtr_prb or { 0, 0 }
        local fading, matter = 0.5, index.M.mtr_prb[1]
        if( index.D.pointer_matter > 0 ) then
            matter = index.D.pointer_matter
            index.M.mtr_prb = { index.D.pointer_matter, math.max( index.M.mtr_prb[2], index.D.frame_num )}
        elseif( index.M.mtr_prb[1] > 0 ) then
            local delta = index.D.frame_num - index.M.mtr_prb[2]
            if( delta > 2*index.D.info_fading ) then
                index.M.mtr_prb, matter = nil, 0
            elseif( delta > index.D.info_fading ) then
                fading = math.max( fading*math.sin(( 2*index.D.info_fading - delta )*math.pi/( 2*index.D.info_fading )), 0.01 )
            end
        end

        if( matter == 0 and index.D.info_mtr_state ~= 3 ) then return end
        if( index.D.info_mtr_state ~= 1 or index.M.mtr_prb[2] > index.D.frame_num ) then
            fading = index.D.info_mtr_state == 3 and 1 or math.min( fading*4, 1 )
        end
        
        local no_matter = index.D.info_mtr_state == 3 and matter == 0
        local txt = GameTextGetTranslatedOrNot( no_matter and "$mat_air" or CellFactory_GetUIName( matter ))
        
        pic_x, pic_y = unpack( xys.delay )
        do_info( pic_x + 2, pic_y - 2.5, txt, fading, true, function( offset_x )
            local _,_,is_hovered = pen.new_interface( pic_x + 2 - offset_x, pic_y - 1, offset_x, 8, pen.LAYERS.TIPS )
            if( is_hovered ) then index.M.mtr_prb = { matter, index.D.frame_num + 300 } end
            return is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W
        end)
    end)
    return { pic_x, pic_y }
end

function index.new_generic_ingestions( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.hp )
    pic_y = pic_y + index.D.effect_icon_spacing
    local orb_x, orb_y = unpack( xys.orbs )
    pic_x, orb_y = orb_x, orb_y + 5
    if(( pic_y - orb_y ) < 0 ) then pic_y = orb_y end

    local data = index.D.icon_data.ings
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        pic_y = pic_y + 3

        for i,this_one in ipairs( data ) do
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 1 )
            pic_x, pic_y = pic_x, pic_y + step_y - 1
        end

        pic_y = pic_y + 4
    end)
    return { pic_x, pic_y }
end

function index.new_generic_stains( screen_w, screen_h, xys )
    local data = index.D.icon_data.stains
    local pic_x, pic_y = unpack( xys.ingestions )
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end

        for i,this_one in ipairs( data ) do
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 2 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end

        pic_y = pic_y + 3
    end)
    return { pic_x, pic_y }
end

function index.new_generic_effects( screen_w, screen_h, xys )
    local data = index.D.icon_data.misc
    local pic_x, pic_y = unpack( xys.stains )
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end

        for i,this_one in ipairs( data ) do
            if( this_one.amount < 2 ) then this_one.txt = "" end
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 3 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end

        pic_y = pic_y + 3
    end)
    return { pic_x, pic_y }
end

function index.new_generic_perks( screen_w, screen_h, xys )
    local data = index.D.perk_data
    local pic_x, pic_y = unpack( xys.effects )
    pen.hallway( function()
        if( not( pen.vld( data ))) then return end
        if( index.D.gmod.menu_capable ) then return end

        local perk_tbl_short, extra_perk = {}, {
            pic = "data/ui_gfx/perk_icons/perks_hover_for_more.png",
            txt = "", desc = "", other_perks = {},
            tip = function( pic_x, pic_y, pic_z, perks ) --add hover tips
                for i,pic in ipairs( perks ) do
                    local drift_x = 14*(( i - 1 )%10 )
                    local drift_y = 14*math.floor(( i - 1 )/10 )
                    pen.new_image( pic_x - 3 + drift_x, pic_y - 1 + drift_y, pic_z, pic )
                end
            end,
        }

        if( #data > index.D.max_perks ) then
            for i,perk in ipairs( data ) do
                if( #perk_tbl_short >= index.D.max_perks ) then
                    for k = 1,( perk.count or 1 ) do table.insert( extra_perk.other_perks, perk.pic ) end
                else table.insert( perk_tbl_short, perk ) end
            end
            table.insert( perk_tbl_short, extra_perk )
        else perk_tbl_short = data end
        
        for i,this_one in ipairs( perk_tbl_short ) do
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 4 )
            pic_x, pic_y = pic_x, pic_y + step_y - 2
        end

        pic_y = pic_y + 5
    end)
    return { pic_x, pic_y }
end

function index.new_generic_pickup( screen_w, screen_h, xys, info_func )
    local data = index.D.ItemPickUpper
    if( not( pen.vld( data ))) then return end

    local x, y = unpack( index.D.player_xy )
    y = y - index.D.player_core_off
    
    if( pen.vld( index.D.sampo, true )) then
        local msg, clr = GameTextGet( "$hint_endingmcguffin_use", "[USE]" ), nil
        local sampo_spot = EntityGetClosestWithTag( x, y, "ending_sampo_spot_underground" )
        if( pen.vld( sampo_spot, true )) then
            sampo_spot = EntityGetClosestWithTag( x, y, "ending_sampo_spot_mountain" )
            if( pen.vld( sampo_spot, true )) then
                local ng_num = tonumber( SessionNumbersGetValue( "NEW_GAME_PLUS_COUNT" ))
                local check_num, going_ng = ng_num + 5, false
                if( index.D.orbs < 33 ) then
                    local seven_eleven = index.D.orbs > ORB_COUNT_IN_WORLD and check_num >= ORB_COUNT_IN_WORLD and index.D.orbs >= check_num
                    local eleven_seven = index.D.orbs >= check_num and index.D.orbs < ORB_COUNT_IN_WORLD
                    if( seven_eleven or eleven_seven ) then
                        going_ng, msg = true, "+"
                        if( ng_num < 5 ) then
                            for i = 1,ng_num do msg = msg.."+" end
                        else msg = msg.."("..( ng_num + 1 )..")" end
                        msg = GameTextGet( "$hint_endingmcguffin_enter_newgameplus", "[USE]", msg )
                    end
                end
                
                if( not( going_ng )) then
                    if( index.D.orbs == 11 ) then
                        clr = pen.PALETTE.VNL.YELLOW
                    elseif( index.D.orbs > 32 ) then
                        clr = pen.PALETTE.VNL.RUNIC
                    else clr = pen.PALETTE.VNL.RED end
                end
            end
        elseif( index.D.orbs > 11 ) then clr = pen.PALETTE.VNL.RED end
        
        if( pen.vld( sampo_spot, true )) then
            local sampo_x, sampo_y = EntityGetTransform( index.D.sampo )
            local spot_x, spot_y = EntityGetTransform( sampo_spot )
            if(( math.abs( sampo_x - spot_x ) + math.abs( sampo_y - spot_y )) < 32 ) then
                info_func( screen_h, screen_w, {
                    id = sampo_spot,
                    desc = { pen.capitalizer( GameTextGetTranslatedOrNot( "$biome_boss_victoryroom" )), msg },
                    txt = "[COMPLETE]",
                    color = { pen.PALETTE.VNL.RUNIC, clr },
                }, xys )
            end
        end
    end

    local entities = EntityGetInRadius( x, y, index.D.pickup_distance )
    if( not( pen.vld( entities ))) then return end

    local interactables = {}
    local stuff_to_figure = pen.t.init( #index.D.item_cats + 1, {})
    pen.t.loop( entities, function( i, id )
        local action_comp = EntityGetFirstComponentIncludingDisabled( id, "InteractableComponent" )
        if( pen.vld( action_comp, true ) and pen.vld( EntityGetFirstComponent( id, "LuaComponent", "index_ctrl" ), true )) then
            local b_x, b_y = EntityGetTransform( id )
            local dist = math.sqrt(( x - b_x )^2 + ( y - b_y )^2 )

            local info = {
                id = id, d = dist,
                
                radius = ComponentGetValue2( action_comp, "radius" ),
                name = GameTextGetTranslatedOrNot( ComponentGetValue2( action_comp, "name" )),
                desc = GameTextGetTranslatedOrNot( ComponentGetValue2( action_comp, "ui_text" )),
            }

            local is_allowed = false
            if( info.radius == 0 ) then
                is_allowed = pen.check_bounds({ x, y }, EntityGetFirstComponent( id, "HitboxComponent" ), { b_x, b_y })
            else is_allowed = dist <= info.radius end
            if( is_allowed ) then table.insert( interactables, info ) end
        elseif( EntityGetRootEntity( id ) == id ) then
            local item_comp = EntityGetFirstComponent( id, "ItemComponent" )
            if( not( pen.vld( item_comp, true ))) then return end

            local i_x, i_y = EntityGetTransform( id )
            local dist = math.sqrt(( x - i_x )^2 + ( y - i_y )^2 )

            local info = {
                id = id, comp = item_comp, d = dist,

                may_pick = ComponentGetValue2( item_comp, "is_pickable" ) or data.pick_always,
                pick_radius = ComponentGetValue2( item_comp, "item_pickup_radius" ),
                pick_frame = ComponentGetValue2( item_comp, "next_frame_pickable" ),
                pick_auto = ComponentGetValue2( item_comp, "auto_pickup" ),

                may_sfx = ComponentGetValue2( item_comp, "play_pick_sound" ),
                may_desc = ComponentGetValue2( item_comp, "ui_display_description_on_pick_up_hint" ),
                pick_desc = ComponentGetValue2( item_comp, "custom_pickup_string" ) or "",
            }

            if( pen.vld( data.pick_only, true ) and id ~= data.pick_only ) then return end
            if( not( info.may_pick ) or info.pick_frame > index.D.frame_num ) then return end

            if( info.pick_radius == 0 ) then
                info.may_pick = pen.check_bounds({ x, y }, EntityGetFirstComponent( id, "HitboxComponent" ), { i_x, i_y })
            else info.may_pick = dist <= info.pick_radius end
            if( not( info.may_pick )) then return end

            local mode = 0
            local data = index.get_item_data( id )
            if( data.id ~= nil ) then
                info.data = data
                if( info.pick_auto ) then
                    mode = 1
                else mode = data.cat + 1 end
            else return end
            table.insert( stuff_to_figure[ mode ], info )
        end
    end)

    local is_button, no_space = true, false
    local cant_buy, got_info = false, false
    local pickup_data = { id = 0, desc = "" }
    pen.t.loop( stuff_to_figure, function( i, tbl )
        if( not( pen.vld( tbl ))) then return end
        table.sort( tbl, function( a, b ) return a.d < b.d end)

        for k,info in ipairs( tbl ) do
            local cost_check, is_shop = true, false
            local cost_comp = EntityGetFirstComponentIncludingDisabled( info.id, "ItemCostComponent" )
            if( pen.vld( cost_comp, true )) then
                is_shop = true
                local cost = ComponentGetValue2( cost_comp, "cost" )
                if( index.D.Wallet.money_always or ( cost <= index.D.Wallet.money )) then
                    info.data.cost = cost
                else cost_check = false end
            end
            
            local info_dump = false
            if( cost_check ) then
                ComponentSetValue2( info.comp, "inventory_slot", -5, -5 )

                local will_pause = pen.vld( index.cat_callback( info.data, "on_gui_pause" ))
                local is_slotless = will_pause or i == 1 or EntityHasTag( info.id, "index_slotless" )
                local new_data = is_slotless and { inv_slot = 0 } or index.set_to_slot( info.data, true )
                if( pen.vld( new_data.inv_slot )) then
                    if( i > 1 ) then
                        pickup_data.desc = info.pick_desc
                        if( not( pen.vld( pickup_data.desc ))) then
                            pickup_data.desc = is_shop and "$itempickup_purchase" or "$itempickup_pick" end
                        pickup_data.desc = GameTextGet( pickup_data.desc, "[USE]", info.data.name..( info.data.fullness or "" ))
                        
                        pickup_data.id = info.id
                        pickup_data.txt = is_shop and "[BUY]" or ( EntityHasTag( info.id, "chest" ) and "[OPEN]" or "[GET]" )
                        pickup_data.do_sound, pickup_data.info = info.may_sfx, info.data
                        if( info.may_desc ) then pickup_data.desc = { pickup_data.desc, info.data.desc } end

                        is_button = false; break
                    else index.pick_up_item( index.D.player_id, info.data, info.may_sfx ) end
                elseif( not( got_info )) then no_space, info_dump = true, true end
            elseif( not( got_info )) then cant_buy, info_dump = true, true end

            if( info_dump ) then
                got_info, pickup_data.id = true, info.id
                pickup_data.name, pickup_data.info = info.data.name, info.data
            end
        end

        if( not( is_button )) then return true end
    end)
    
    --[[
    if( index.D.is_opened and index.D.gmod.show_fullest ) then
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
                        w, h = index.new_generic_slot( screen_w/2, screen_h - 50, {
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

    if( not( pen.vld( pickup_data.txt )) and ( no_space or cant_buy )) then
        if( not( pen.vld( interactables ))) then
            pickup_data.id = -pickup_data.id
            pickup_data.desc = { index.full_stopper(
                GameTextGet( cant_buy and "$itempickup_notenoughgold" or "$itempickup_cannotpick", pickup_data.name )), true }
        else pickup_data.id = 0 end
    end
    if( pickup_data.id ~= 0 ) then
        local ignore_default = false
        local guiing = index.cat_callback( pickup_data.info, "on_gui_world" )
        if( index.D.is_opened and index.D.gmod.show_full ) then
            pickup_data.id = -1
            pickup_data.desc = { GameTextGet( "$itempickup_cannotpick_closeinventory", pickup_data.info.name ), true }
        elseif( pen.vld( guiing )) then
            local i_x, i_y = EntityGetTransform( math.abs( pickup_data.id ))
            local pic_x, pic_y = pen.world2gui( i_x, i_y )
            ignore_default = guiing(
                pickup_data.info, nil, pic_x, pic_y, no_space, cant_buy, index.cat_callback( pickup_data.info, "on_tooltip" ))
        end
        
        if( not( ignore_default )) then info_func( screen_h, screen_w, pickup_data, xys ) end
        if( pen.vld( pickup_data.id, true ) and index.D.Controls.act[2]) then
            local pkp_x, pkp_y = EntityGetTransform( pickup_data.id )
            local anim_x, anim_y = pen.world2gui( pkp_x, pkp_y )
            table.insert( index.M.slot_anim, {
                id = pickup_data.id,
                x = anim_x, y = anim_y,
                frame = index.D.frame_num,
            })
            
            local orig_name = pickup_data.info.name
            if( pen.vld( pickup_data.info.fullness )) then
                pickup_data.info.name = pickup_data.info.name..pickup_data.info.fullness end
            index.pick_up_item( index.D.player_id, pickup_data.info, pickup_data.do_sound )
            pickup_data.info.name = orig_name
        end
    end

    local do_action = is_button and pen.vld( interactables )
    if( do_action ) then
        table.sort( interactables, function( a, b ) return a.d < b.d end)

        local will_show = true
        local info = interactables[1]
        local func_path = pen.magic_storage( info.id, "index_check", "value_string" )
        if( pen.vld( func_path )) then info, will_show, do_action = dofile_once( func_path )( info ) end
        if( will_show ) then
            local message_func = info_func
            local func_path = pen.magic_storage( info.id, "index_message", "value_string" )
            if( pen.vld( func_path )) then message_func = dofile_once( func_path ) end
            message_func( screen_h, screen_w, {
                id = info.id, txt = "[USE]",
                desc = { pen.capitalizer( info.name ), string.gsub( info.desc, "$0", "[USE]" )},
            }, xys )
        end
    end

    if( index.D.Controls.act[2]) then
        index.D.Controls.act[2] = false
        
        if( do_action and not( index.M.skip_next_action )) then
            local action_id = interactables[1].id
            EntitySetComponentIsEnabled( action_id, EntityGetFirstComponentIncludingDisabled( action_id, "InteractableComponent" ), true )
            EntitySetComponentIsEnabled( action_id, EntityGetFirstComponent( action_id, "LuaComponent", "index_ctrl" ), false )
            ComponentSetValue2( index.D.Controls.comp, "mButtonFrameInteract", index.D.frame_num + 1 )
            index.M.skip_next_action = true
        else
            ComponentSetValue2( index.D.Controls.comp, "mButtonFrameInteract", 0 )
            index.M.skip_next_action = false
        end
    end
end

function index.new_generic_drop( item_id )
    local dude = EntityGetRootEntity( item_id )
    if( dude ~= index.D.player_id ) then index.play_sound( "error" ); return end

    index.play_sound({ "data/audio/Desktop/ui.bank", "ui/item_remove" })
    
    local do_default = true
    local info = pen.t.get( index.D.item_list, item_id )
    local inv_info = index.D.invs[ info.inv_id ] or {}
    local callback = index.cat_callback( info, "on_drop" )
    if( pen.vld( callback )) then do_default = callback( info, false ) end
    if( pen.vld( inv_info.update ) and inv_info.update( pen.t.get( index.D.item_list, p, nil, nil, inv_info ), info, {})) then
        local reset_id = pen.get_item_owner( p, true )
        if( pen.vld( reset_id, true )) then pen.reset_active_item( reset_id ) end
    end
    if( do_default ) then
        local x, y = unpack( index.D.player_xy )
        index.drop_item( x, y, info, index.D.throw_force, not( index.D.no_action_on_drop ))
    end
    if( pen.vld( callback )) then callback( info, true ) end
end

function index.new_generic_extra( screen_w, screen_h, xys )
    if( not( pen.vld( index.D.invs_e ))) then return end
    for i,extra_inv in ipairs( index.D.invs_e ) do
        local x, y = EntityGetTransform( extra_inv )
        local pic_x, pic_y = pen.world2gui( x, y )
        local inv_info = index.D.invs[ extra_inv ]
        inv_info.func( pic_x, pic_y, inv_info, xys, index.D.slot_func )
    end
end

function index.new_generic_modder( screen_w, screen_h, xys )
    local mode_data = index.D.gmod
    if( not( pen.vld( mode_data )) or not( index.D.is_opened )) then return end
    if( index.D.gmod.is_hidden and not( index.D.gmod.force_show )) then return end
    
    local w,h = pen.get_text_dims( mode_data.name, true )
    local pic_x, pic_y = xys.full_inv[1], xys.inv_root[2]
    if( not( mode_data.show_full )) then
        pic_x = xys.inv_root[1] + 7 + w
        pic_y = xys.full_inv[2] + 13
    elseif( xys.applets_r[1] <= ( pic_x + 5 )) then return end
    
    local new_mode = index.D.global_mode
    local gonna_reset, gonna_highlight, arrow_left_a, arrow_right_a = false, false, 0.3, 0.3
    local arrow_left_c, arrow_right_c, arrow_hl_c = {255,255,255}, {255,255,255}, pen.PALETTE.VNL.YELLOW
    local clicked, r_clicked, is_hovered = pen.new_interface( pic_x - ( 11 + w ), pic_y - 11, 15, 10, pen.LAYERS.TIPS )
    if( is_hovered ) then arrow_left_c, arrow_left_a = arrow_hl_c, 1 end
    gonna_reset, gonna_highlight = gonna_reset or r_clicked, gonna_highlight or is_hovered
    if( clicked or index.get_input( "invmode_previous" )) then new_mode, arrow_left_a = new_mode - 1, 1 end

    clicked, r_clicked, is_hovered = pen.new_interface( pic_x - 10, pic_y - 11, 15, 10, pen.LAYERS.TIPS )
    if( is_hovered ) then arrow_right_c, arrow_right_a = arrow_hl_c, 1 end
    gonna_reset, gonna_highlight = gonna_reset or r_clicked, gonna_highlight or is_hovered
    if( clicked or index.get_input( "invmode_next" )) then new_mode, arrow_right_a = new_mode + 1, 1 end
    
    local tip_x, tip_y = unpack( xys.hp )
    local tip = mode_data.name.."\n{>indent>{{>color>{{-}|VNL|GREY|{-}"..mode_data.desc.."}<color<}}<indent<}"
    is_hovered, clicked, r_clicked = index.tipping(
        pic_x - ( 6 + w ), pic_y - 11, pen.LAYERS.TIPS, w + 6, 10, tip, { fully_featured = true,
        pos = { tip_x - 44, tip_y }, is_left = true, text_prefunc = function( text, data ) return text, 2, 0 end })
    gonna_reset, gonna_highlight = gonna_reset or r_clicked, gonna_highlight or is_hovered

    local alpha = gonna_highlight and 1 or 0.3
    if( gonna_reset ) then
        for i,gmod in ipairs( index.D.gmods ) do
            if( gmod.is_default ) then new_mode = i; break end
        end
    end

    pen.new_text( pic_x - ( 3 + w ), pic_y - ( 2 + h ), pen.LAYERS.MAIN, mode_data.name, { alpha = alpha })
    index.D.box_func( pic_x - ( 4 + w ), pic_y - 9, pen.LAYERS.MAIN_BACK, { w + 2, 6 })
    
    pen.new_image( pic_x - ( 12 + w ), pic_y - 10, pen.LAYERS.MAIN_BACK,
        "data/ui_gfx/keyboard_cursor_right.png", { color = arrow_left_c, alpha = arrow_left_a })
    pen.new_image( pic_x - 2, pic_y - 10, pen.LAYERS.MAIN_BACK,
        "data/ui_gfx/keyboard_cursor.png", { color = arrow_right_c, alpha = arrow_right_a })

    if( index.D.global_mode == new_mode ) then return end

    local go_ahead = true
    while( go_ahead ) do
        if( new_mode < 1 ) then
            new_mode = #index.D.gmods
        elseif( new_mode > #index.D.gmods ) then
            new_mode = 1
        end
        go_ahead = index.D.gmods[ new_mode ].is_hidden or false
        if( go_ahead ) then new_mode = new_mode + ( arrow_left_a == 1 and -1 or 1 ) end
    end

    index.play_sound( gonna_reset and "reset" or "click" )
    GlobalsSetValue( index.GLOBAL_GLOBAL_MODE, tostring( new_mode ))
end