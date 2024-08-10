dofile_once( "mods/index_core/files/_lib.lua" )

function index.new_generic_inventory( screen_w, screen_h, xys )
    local root_x, root_y = unpack( xys.full_inv or { 19, 20 })
    local pic_x, pic_y = root_x, root_y
    
    local this_data = index.D.item_list
    if( this_data ~= nil ) then
        if( index.D.is_opened ) then
            pen.new_image( 0, 0, pen.LAYERS.BACKGROUND,
                index.D.gmod.show_full and "data/ui_gfx/inventory/background.png" or "mods/index_core/files/pics/vanilla_fullless_bg.xml" )
            
            if( not( index.D.gmod.can_see )) then
                local delta = math.max(( index.M.inv_alpha or index.D.frame_num ) - index.D.frame_num, 0 )
                local alpha = 0.5*math.cos( math.pi*delta/30 )
                pen.new_image( -2, -2, pen.LAYERS.BACKGROUND + 1,
                    "data/ui_gfx/empty_black.png", { s_x = screen_w + 4, s_y = screen_h + 4, alpha = alpha })
            end
        end
        
        local function check_shortcut( id, is_quickest )
            if( id <= 4 ) then return index.get_input(( is_quickest and "za_quickest_" or "zb_quick_" )..id ) end
        end
        local w, h, step = 0, 0, 1
        xys.inv_root, xys.full_inv = { root_x - 3, root_y - 3 }, { root_x + 2, root_y + 26 }

        local cat_wands = pic_x
        local inv_id = index.D.inventories_player.q
        local slot_data = index.D.slot_state[ inv_id ].quickest
        for i,slot in ipairs( slot_data ) do
            w, h = slot_setup( pic_x, pic_y, {
                inv_id = inv_id,
                id = slot,
                inv_slot = {i,-1},
                force_equip = check_shortcut( i, true ),
            }, index.D.is_opened, false, true )
            pic_x, pic_y = pic_x + w + step, pic_y
        end
        
        pic_x = pic_x + index.D.inv_spacings[1]
        local cat_items = pic_x
        slot_data = index.D.slot_state[ inv_id ].quick
        for i,slot in ipairs( slot_data ) do
            w, h = slot_setup( pic_x, pic_y, {
                inv_id = inv_id,
                id = slot,
                inv_slot = {i,-2},
                force_equip = check_shortcut( i, false ),
            }, index.D.is_opened, false, true )
            pic_x, pic_y = pic_x + w + step, pic_y
        end

        if( index.D.is_opened ) then
            pen.new_shadowed_text( cat_wands + 1, pic_y - 13, pen.LAYERS.MAIN_DEEP,
                GameTextGetTranslatedOrNot( "$hud_title_wands" ))
            pen.new_shadowed_text( cat_items + 1, pic_y - 13, pen.LAYERS.MAIN_DEEP,
                GameTextGetTranslatedOrNot( "$hud_title_throwables" ))

            pic_x = pic_x + index.D.inv_spacings[2]
            pen.new_shadowed_text( pic_x + 1, pic_y - 13, pen.LAYERS.MAIN_DEEP,
                GameTextGetTranslatedOrNot( "$menuoptions_heading_misc" ))
        end
        if( index.D.gmod.show_full ) then
            if( index.D.is_opened or index.D.always_show_full ) then
                local core_y = pic_y
                inv_id = index.D.inventories_player.f
                slot_data = index.D.slot_state[ inv_id ]
                for i,col in ipairs( slot_data ) do
                    local count = not( index.D.gmod.show_fullest or false ) and 1 or #col
                    for e = 1,count do
                        local slot = col[e]
                        w, h = slot_setup( pic_x, pic_y, {
                            inv_id = inv_id,
                            id = slot,
                            inv_slot = {i,e},
                        }, index.D.is_opened, true, index.D.is_opened )
                        pic_x, pic_y = pic_x, pic_y + h + step
                    end
                    pic_x, pic_y = pic_x + w + step, core_y
                end
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
        if( index.D.Controls.inv[2]) then
            index.D.inv_toggle = true
        end
    end
    
    return { root_x, root_y }, { pic_x, pic_y }
end

function index.new_generic_applets( screen_w, screen_h, xys )
    local this_data = index.D.applets
    local pic_x_l, pic_x_r, pic_y = 0, screen_w, 4
    local function applet_setup( pic_x, type )
        local is_left = type == 1
        local sign = is_left and -1 or 1
        local tbl = {
            { "l", "l_state", "l_frame", "applets_l_drift", "l_hover" },
            { "r", "r_state", "r_frame", "applets_r_drift", "r_hover" },
        }

        local l = #this_data[ tbl[ type ][1]]*11
        local drift_target, core_off = 5, is_left and -10 or 0
        local total_drift, allow_clicks = l - drift_target, true
        if( not( this_data[ tbl[ type ][2]])) then
            local clicked, r_clicked, is_hovered = pen.new_interface(
                is_left and -1 or ( screen_w - 10 ), -1, 11, 19, pen.LAYERS.TIPS_FRONT )
            index.D.tip_func( "[APPLETS]", { is_active = is_hovered })
            if( not( is_hovered )) then drift_target = 0 end

            if( clicked ) then
                allow_clicks = false
                index.play_sound( "click" )
                this_data[ tbl[ type ][2]] = true
                this_data[ tbl[ type ][3]] = index.D.frame_num
            end
        else
            local delta = index.D.frame_num - ( this_data[tbl[type][3]] or 0 )
            if( delta < 16 ) then
                allow_clicks = false
                local k = 5
                local v = k*math.sin( delta*math.pi/k )/( math.pi*delta^2 )
                core_off = total_drift*( 1 - v )
            else core_off = total_drift end
        end
        
        index.D[ tbl[ type ][4]] = total_drift
        local arrow_off = is_left and ( l - 8 ) or 0
        local extra_off = pen.estimate( tbl[ type ][4], drift_target, 0.2 )
        pic_x = pic_x - sign*( core_off + extra_off )

        if( this_data[ tbl[ type ][2]]) then
            if( is_left ) then pic_x = pic_x - 10 end
            arrow_off = arrow_off + extra_off + 2
            local clicked, is_hovered, reset_em, got_one = false, false, 0, false
            for i,icon in ipairs( this_data[ tbl[ type ][1]]) do
                local t_x = pic_x + sign*( i - 1 )*11
                local metahover = not( got_one ) and ( this_data[ tbl[ type ][5]][i] or false )
                local clicked,_,is_hovered = pen.new_interface( t_x, pic_y, 10, 10, pen.LAYERS.MAIN_BACK )
                pen.new_image( t_x - 1, pic_y - 1, pen.LAYERS.MAIN_BACK, icon.pic, { angle = metahover and math.rad( -5 ) or 0 })

                pen.hallway( function()
                    if( not( allow_clicks )) then return end
                    index.D.tip_func( icon.name..( icon.desc == nil and "" or "@"..icon.desc ),
                        { pos = { is_left and 2 or ( screen_w - 1 ), pic_y + 14 }, is_active = metahover, is_left = not( is_left )})
                    if( not( clicked and reset_em == 0 )) then return end
                    if( not( icon.mute or false )) then index.play_sound( "click" ) end
                    
                    reset_em = i
                    if( icon.toggle ~= nil and icon.toggle( true ) and not( is_left )) then
                        pen.t.loop( index.D.gmod.gmods, function( i, gmod )
                            if( not( gmod.menu_capable )) then return end
                            pen.magic_storage( index.D.main_id, "global_mode", "value_int", i )
                            return true
                        end)
                    end
                    for k,icn in ipairs( this_data[ tbl[ type ][1]]) do
                        if( icn.toggle ~= nil ) then icn.toggle( false ) end
                    end
                end)
                if( is_hovered and not( this_data[ tbl[ type ][5]][i] )) then index.play_sound( "hover" ) end
                this_data[ tbl[ type ][5]][i] = is_hovered
                if( is_hovered ) then got_one = true end
            end
        else pen.colourer( nil, pen.PALETTE.VNL.YELLOW ) end

        if( is_left ) then pic_x = pic_x - ( l - 10 ) end
        pen.new_image( pic_x - sign*( 1 + arrow_off ), pic_y + 1,
            pen.LAYERS.MAIN_BACK - 0.001, "data/ui_gfx/keyboard_cursor"..( is_left and ".png" or "_right.png" ))
        index.D.plate_func( pic_x, pic_y, pen.LAYERS.MAIN_DEEP - 0.1, { total_drift + 5, 10 })
        if( is_left ) then
            pic_x = pic_x + arrow_off + 11
        else pic_x = pic_x - ( 3 + arrow_off ) end
        return pic_x
    end

    pen.hallway( function()
        if( this_data == nil ) then return end
        if( index.D.gmod.menu_capable ) then return end
        
        if( index.D.is_opened ) then
            if( index.D.gmod.show_full and #this_data.r > 1 ) then
                pic_x_r = applet_setup( pic_x_r, 2 )
            end
        elseif( #this_data.l > 1 ) then
            pic_x_l = applet_setup( pic_x_l, 1 )
        end
    end)

    return { pic_x_l, pic_y }, { pic_x_r, pic_y }
end

function index.new_generic_hp( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.hp or { screen_w - 41, 20 })
    local red_shift, length, height = 0, 0, 0
    local this_data = index.D.DamageModel
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( not( ComponentGetIsEnabled( this_data.comp ))) then return end
        local max_hp, hp = this_data.hp_max, this_data.hp
        if( max_hp <= 0 ) then return end
        
        length, height, max_hp, hp, red_shift = index.new_vanilla_hp( pic_x, pic_y, pen.LAYERS.MAIN_BACK, { dmg_data = this_data })
        
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
    local pic_x, pic_y = unpack( xys.hp )
    local this_data = index.D.DamageModel
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( not( ComponentGetIsEnabled( this_data.comp ))) then return end
        if( not( this_data.can_air ) or this_data.air/this_data.air_max > 0.9 ) then return end

        pen.new_text( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "o2", { is_huge = false, has_shadow = true, alpha = 0.9 })
        index.new_vanilla_bar( pic_x, pic_y,
            pen.LAYERS.MAIN_BACK, { 40, 2, 40*math.max( this_data.air, 0 )/this_data.air_max }, pen.PALETTE.VNL.MANA, nil, 0.75 )

        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$hud_air" )..index.hud_num_fix( this_data.air, this_data.air_max, 2 )
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_flight( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.air )
    local this_data = index.D.CharacterData
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( this_data.flight_always or this_data.flight_max == 0 ) then return end

        if( index.M.flight_shake == nil ) then
            if( index.D.Controls.fly[1] and this_data.flight <= 0 ) then
                index.M.flight_shake = index.D.frame_num
            end
        end

        local shake_frame = index.D.frame_num - ( index.M.flight_shake or index.D.frame_num )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "data/ui_gfx/hud/jetpack.png", { has_shadow = true })
        index.new_vanilla_bar( pic_x, pic_y, pen.LAYERS.MAIN_BACK,
            { 40, 2, 40*math.max( this_data.flight, 0 )/this_data.flight_max }, pen.PALETTE.VNL.FLIGHT, index.M.flight_shake ~= nil and shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$hud_jetpack" )..index.hud_num_fix( this_data.flight, this_data.flight_max, 2 )
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        if( shake_frame >= 20 ) then index.M.flight_shake = nil end
        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_mana( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.flight )
    local this_data = index.D.active_info
    pen.hallway( function()
        if( not( pen.vld( this_data.id, true ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        index.M.mana_shake = index.M.mana_shake or {}

        local value = {0,0}
        local potion_data = {}
        local throw_it_back = nil
        if( this_data.wand_info ~= nil ) then
            local mana = this_data.wand_info.mana
            local mana_max = this_data.wand_info.mana_max
            value = { math.min( math.max( mana, 0 ), mana_max ), mana_max }
            if( index.M.mana_shake[ index.D.active_item ] == nil ) then
                if( index.D.no_mana_4life ) then index.M.mana_shake[ index.D.active_item ] = index.D.frame_num end
            end

            local shake_frame = index.D.frame_num - ( index.M.mana_shake[ index.D.active_item ] or index.D.frame_num )
            throw_it_back = index.M.mana_shake[ index.D.active_item ] ~= nil and -shake_frame or nil
            if( shake_frame >= 20 ) then index.M.mana_shake[ index.D.active_item ] = nil end
        elseif( this_data.matter_info ~= nil and this_data.matter_info[1] >= 0 ) then
            value = { math.max( this_data.matter_info[2][1], 0 ), this_data.matter_info[1]}
            potion_data = { "data/ui_gfx/hud/potion.png" }
            if( index.D.fancy_potion_bar ) then
                table.insert( potion_data, pen.magic_uint( GameGetPotionColorUint( index.D.active_item )))
                table.insert( potion_data, 0.8 )
            end
        end
        
        if( value[1] < 0 or value[2] <= 0 ) then return end
        
        local ratio = math.min( value[1]/value[2], 1 )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, potion_data[1] or "data/ui_gfx/hud/mana.png", { has_shadow = true })
        if( potion_data[2] ~= nil ) then
            pen.new_pixel( pic_x - 40, pic_y + 1, pen.LAYERS.MAIN + 0.001, pen.PALETTE.W, math.min( 40*ratio + 0.5, 40 ), 2 )
        end
        index.new_vanilla_bar( pic_x, pic_y,
            pen.LAYERS.MAIN_BACK, { 40, 2, 40*ratio }, potion_data[2] or pen.PALETTE.VNL.MANA, throw_it_back, potion_data[4])
        
        local tip = ""
        if( potion_data[3] ~= nil ) then
            tip = this_data.name..( this_data.fullness ~= nil and "@"..this_data.fullness or "" )
        else tip = index.hud_text_fix( "$hud_wand_mana" )..index.hud_num_fix( value[1], value[2]) end

        local tip_x, tip_y = unpack( xys.hp )
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        pic_y = pic_y + 8
    end)
    return { pic_x, pic_y }
end

function index.new_generic_reload( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.mana )
    local this_data = index.D.active_info

    index.M.reload_max = index.M.reload_max or {}
    index.M.reload_shake = index.M.reload_shake or {}

    local is_real = pen.vld( this_data.wand_info, true )
    pen.hallway( function()
        if( not( is_real )) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( this_data.wand_info.never_reload ) then return end

        local reloading = this_data.wand_info.reload_frame
        local reloading_full = index.M.reload_max[ index.D.active_item ]
        if(( reloading_full or -1 ) < reloading ) then reloading_full = reloading end
        index.M.reload_max[ index.D.active_item ] = reloading_full
        
        if( reloading_full <= index.D.reload_threshold ) then return end

        local reloading_shake = index.M.reload_shake[ index.D.active_item ]
        if( reloading_shake == nil and index.D.just_fired and reloading_full ~= reloading ) then reloading_shake = index.D.frame_num end
        index.M.reload_shake[ index.D.active_item ] = reloading_shake
        
        local shake_frame = index.D.frame_num - ( reloading_shake or index.D.frame_num )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "data/ui_gfx/hud/reload.png", { has_shadow = true })
        index.new_vanilla_bar( pic_x, pic_y, pen.LAYERS.MAIN_BACK,
            { 40, 2, 40*reloading/reloading_full }, pen.PALETTE.VNL.CAST, reloading_shake ~= nil and -shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$hud_wand_reload" )..string.format( "%.2f", reloading/60 ).."s"
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        if( shake_frame >= 20 ) then index.M.reload_shake[ index.D.active_item ] = nil end
        pic_y = pic_y + 8
    end)

    local is_done = (( this_data.wand_info or {}).reload_frame or 0 ) == 0 
    if( not( is_real ) or is_done ) then index.M.reload_max[ index.D.active_item ] = nil end
    return { pic_x, pic_y }
end

function index.new_generic_delay( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.reload )
    local this_data = index.D.active_info

    index.M.delay_max = index.M.delay_max or {}
    index.M.delay_shake = index.M.delay_shake or {}

    local is_real = pen.vld( this_data.wand_info, true )
    pen.hallway( function()
        if( not( is_real )) then return end
        if( index.D.gmod.menu_capable ) then return end

        local delay = this_data.wand_info.delay_frame
        local delay_full = index.M.delay_max[ index.D.active_item ]
        if(( delay_full or -1 ) < delay ) then delay_full = delay end
        index.M.delay_max[ index.D.active_item ] = delay_full
        
        if( delay_full <= index.D.reload_threshold ) then return end

        local delay_shake = index.M.delay_shake[ index.D.active_item ]
        if( delay_shake == nil and index.D.just_fired and delay_full ~= delay ) then delay_shake = index.D.frame_num end
        index.M.delay_shake[ index.D.active_item ] = delay_shake
        
        local shake_frame = index.D.frame_num - ( delay_shake or index.D.frame_num )
        pen.new_image( pic_x + 3, pic_y - 1, pen.LAYERS.MAIN, "data/ui_gfx/hud/fire_rate_wait.png", { has_shadow = true })
        index.new_vanilla_bar( pic_x, pic_y, pen.LAYERS.MAIN_BACK,
            { 40, 2, 40*delay/delay_full }, pen.PALETTE.VNL.CAST, delay_shake ~= nil and -shake_frame or nil )
        
        local tip_x, tip_y = unpack( xys.hp )
        local tip = index.hud_text_fix( "$inventory_castdelay" )..string.format( "%.2f", delay/60 ).."s"
        index.tipping( pic_x - 42, pic_y - 1, nil, 44, 6, tip, { pos = { tip_x - 44, tip_y }, is_left = true })
        if( shake_frame >= 20 ) then index.M.delay_shake[ index.D.active_item ] = nil end
        pic_y = pic_y + 8
    end)
    
    local is_done = (( this_data.wand_info or {}).delay_frame or 0 ) == 0 
    if( not( is_real ) or is_done ) then index.M.delay_max[ index.D.active_item ] = nil end
    return { pic_x, pic_y }
end

function index.new_generic_bossbar( screen_w, screen_h, xys ) --make it line up to 3 bars horizontally with width check
    local pic_x, pic_y = unpack( xys.bossbar or {screen_w/2,screen_h-20})

    local bosses = EntityGetInRadiusWithTag( index.D.player_xy[1], index.D.player_xy[2], 1000, "index_bossbar" ) or {}
    if( #bosses > 0 ) then
        for i,boss in ipairs( bosses ) do
            local step, bar_func = 0, function( pic_x, pic_y, pic_zs, entity_id, this_data, params )
                local name = index.get_entity_name( entity_id )
                local length, step, max_hp, hp = index.new_vanilla_hp( pic_x, pic_y, pic_zs, entity_id, this_data, params )
                
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
                    pen.new_shadowed_text( pic_x - length/2 + 3, pic_y + 2.5, pic_zs[2] - 0.001, name )
                end

                local value = ( math.floor( rounding*100*hp/max_hp + 0.5 )/rounding ).."%"
                pen.new_shadowed_text( pic_x + length/2 - ( 1 + pen.get_text_dims( value, true )), pic_y + 2.5, pic_zs[2] - 0.001, value )

                return length, step
            end

            local func_path = pen.magic_storage( boss, "index_bar", "value_string" )
            if( func_path ~= nil ) then bar_func = dofile_once( func_path ) end

            _,step = bar_func( pic_x, pic_y, {pen.LAYERS.WORLD_BACK+0.01,pen.LAYERS.WORLD_BACK}, boss, nil, {
                low_hp = 0, low_hp_min = 0,
                length_mult = 2, height = 13,
                centered = true,
            })
            pic_y = pic_y - ( step + 4 )
        end
    end

    return { pic_x, pic_y }
end

function index.new_generic_gold( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.delay )
    local this_data = index.D.Wallet
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        if( this_data.money < 0 ) then return end

        local le_money = this_data.money_always and -1 or math.floor( pen.estimate( "index_gold", this_data.money, 0.09, 1 ))
        
        local tip_x, tip_y = unpack( xys.hp )
        local v = pen.get_short_num( le_money )
        local money_string = " "..(( this_data.money_always or index.D.short_gold ) and v or le_money ).."$"
        local tip = string.gsub( index.hud_text_fix( "$hud_gold" ), "@$", money_string )
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
    local pic_x, pic_y = 0,0
    local function do_info( p_x, p_y, txt, alpha, is_right, hover_func )
        local offset_x = 0
        
        txt = pen.capitalizer( txt )
        if( is_right ) then
            local w,h = pen.get_text_dims( txt, true )
            offset_x = w + 1
            p_x = p_x - offset_x
        end
        if( hover_func ~= nil ) then hover_func( offset_x ) end
        pen.new_shadowed_text( p_x, p_y, pen.LAYERS.MAIN, txt, { alpha = alpha })
    end
    
    index.M.ui_info = index.M.ui_info or { 0, 0 }
    if( not( index.D.is_opened and index.D.gmod.show_full ) and ( index.M.ui_info[1] ~= 0 or index.D.pointer_delta[3] < index.D.info_threshold )) then
        local info = ""

        local entities = EntityGetInRadius( index.D.pointer_world[1], index.D.pointer_world[2], index.D.info_radius ) or {}
        if( #entities > 0 ) then
            local best_kind = -1
            local dist_tbl = {}
            for i,entity_id in ipairs( entities ) do
                if( EntityGetRootEntity( entity_id ) == entity_id and entity_id ~= index.D.player_id ) then
                    local kind = {}
                    local item_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "ItemComponent" )
                    
                    local name = ""
                    local info_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "UIInfoComponent" )
                    if( info_comp ~= nil ) then
                        name = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "name" ) or "" )
                    end
                    if( index.check_item_name( name )) then
                        kind = { 0, name }
                    elseif( item_comp ~= nil and ComponentGetValue2( item_comp, "is_pickable" )) then
                        local name_func = function( item_id, item_comp, default_name )
                            local name = index.get_entity_name( item_id, item_comp )
                            return name == "" and default_name or name
                        end
                        for k,cat in ipairs( index.D.item_cats ) do
                            if( cat.on_check( entity_id )) then
                                local func = cat.on_info_name == nil and name_func or cat.on_info_name
                                kind = { k, func( entity_id, item_comp, cat.name )}
                                break
                            end
                        end
                    elseif( EntityHasTag( entity_id, "hittable" ) or EntityHasTag( entity_id, "mortal" )) then
                        name = index.get_entity_name( entity_id )
                        if( index.check_item_name( name )) then
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
                local the_one = pen.get_closest( index.D.pointer_world[1], index.D.pointer_world[2], dist_tbl, nil, nil, function( thing )
                    return thing[2] == best_kind
                end)
                if( the_one ~= 0 ) then
                    info = the_one[3]
                end
            end
        end
        
        local fading = 1
        if( index.check_item_name( info )) then
            index.M.ui_info = { info, math.max( index.M.ui_info[2], index.D.frame_num )}
        elseif( index.M.ui_info[1] ~= 0 ) then
            info = index.M.ui_info[1]

            local delta = index.D.frame_num - index.M.ui_info[2]
            if( delta > 2*index.D.info_fading ) then
                index.M.ui_info = nil
                info = ""
            elseif( delta > index.D.info_fading ) then
                fading = math.max( fading*math.sin(( 2*index.D.info_fading - delta )*math.pi/( 2*index.D.info_fading )), 0.01 )
            end
        end
        if( info ~= "" ) then
            local is_obstructed = index.D.dragger.item_id > 0 or ( index.D.frame_num - tip_anim["generic"][2]) < 2
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
        end
    end

    if( not( index.D.gmod.menu_capable )) then
        local fading = 0.5
        index.M.mtr_prb = index.M.mtr_prb or { 0, 0 }
        local matter = index.M.mtr_prb[1]
        if( index.D.pointer_matter > 0 ) then
            matter = index.D.pointer_matter
            index.M.mtr_prb = { index.D.pointer_matter, math.max( index.M.mtr_prb[2], index.D.frame_num )}
        elseif( index.M.mtr_prb[1] > 0 ) then
            local delta = index.D.frame_num - index.M.mtr_prb[2]
            if( delta > 2*index.D.info_fading ) then
                index.M.mtr_prb = nil
                matter = 0
            elseif( delta > index.D.info_fading ) then
                fading = math.max( fading*math.sin(( 2*index.D.info_fading - delta )*math.pi/( 2*index.D.info_fading )), 0.01 )
            end
        end
        if( matter > 0 or index.D.info_mtr_static ) then
            if( index.D.info_mtr_static ) then
                fading = 1
            elseif( index.M.mtr_prb[2] > index.D.frame_num ) then
                fading = math.min( fading*4, 1 )
            end
            
            pic_x, pic_y = unpack( xys.delay )
            local alphaer = function( offset_x )
                local _,_,hovered = pen.new_interface(
                    pic_x + 2 - offset_x, pic_y - 1, offset_x, 8, pen.LAYERS.TIPS )
                if( hovered ) then index.M.mtr_prb = { matter, index.D.frame_num + 300 } end
            end
            
            local txt = "air"
            if( not( index.D.info_mtr_static and matter == 0 )) then
                txt = GameTextGetTranslatedOrNot( CellFactory_GetUIName( matter ))
            end
            do_info( pic_x + 2, pic_y - 2.5, txt, fading, true, alphaer )
        end
    end
    
    return { pic_x, pic_y }
end

function index.new_generic_ingestions( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.hp )
    pic_y = pic_y + index.D.effect_icon_spacing
    local orb_x, orb_y = unpack( xys.orbs )
    pic_x, orb_y = orb_x, orb_y + 5
    if(( pic_y - orb_y ) < 0 ) then pic_y = orb_y end

    local this_data = index.D.icon_data.ings
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end
        pic_y = pic_y + 3

        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 1 )
            pic_x, pic_y = pic_x, pic_y + step_y - 1
        end

        pic_y = pic_y + 4
    end)
    return { pic_x, pic_y }
end

function index.new_generic_stains( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.ingestions )
    local this_data = index.D.icon_data.stains
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end

        for i,this_one in ipairs( this_data ) do
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 2 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end

        pic_y = pic_y + 3
    end)
    return { pic_x, pic_y }
end

function index.new_generic_effects( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.stains )
    local this_data = index.D.icon_data.misc
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end

        for i,this_one in ipairs( this_data ) do
            if( this_one.amount < 2 ) then this_one.txt = "" end
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 3 )
            pic_x, pic_y = pic_x, pic_y + step_y
        end

        pic_y = pic_y + 3
    end)
    return { pic_x, pic_y }
end

function index.new_generic_perks( screen_w, screen_h, xys )
    local pic_x, pic_y = unpack( xys.effects )
    local this_data = index.D.perk_data
    pen.hallway( function()
        if( not( pen.vld( this_data ))) then return end
        if( index.D.gmod.menu_capable ) then return end

        local perk_tbl_short = {}
        if( #this_data > index.D.max_perks ) then
            local extra_perk = {
                pic = "data/ui_gfx/perk_icons/perks_hover_for_more.png",
                txt = "",
                desc = "",
                tip = function( pic_x, pic_y, pic_z, alpha, v )
                    for i,pic in ipairs( v ) do
                        local drift_x = 14*(( i - 1 )%10 )
                        local drift_y = 14*math.floor(( i - 1 )/10 )
                        pen.new_image( pic_x - 3 + drift_x, pic_y - 1 + drift_y, pic_z, pic, { alpha = alpha })
                    end
                end,
                other_perks = {},
            }
            for i,perk in ipairs( this_data ) do
                if( #perk_tbl_short >= index.D.max_perks ) then
                    for k = 1,( perk.count or 1 ) do
                        table.insert( extra_perk.other_perks, perk.pic )
                    end
                else table.insert( perk_tbl_short, perk ) end
            end
            table.insert( perk_tbl_short, extra_perk )
        else perk_tbl_short = this_data end
        
        for i,this_one in ipairs( perk_tbl_short ) do
            local step_x, step_y = index.D.icon_func( pic_x, pic_y, pen.LAYERS.MAIN, this_one, 4 )
            pic_x, pic_y = pic_x, pic_y + step_y - 2
        end

        pic_y = pic_y + 5
    end)

    return { pic_x, pic_y }
end

function index.new_generic_pickup( screen_w, screen_h, xys, info_func )
    local this_data = index.D.ItemPickUpper
    if( #this_data > 0 ) then
        local x, y = unpack( index.D.player_xy )
        y = y - index.D.player_core_off
        
        if( index.D.sampo > 0 ) then
            local msg, clr = GameTextGet( "$hint_endingmcguffin_use", "[USE]" ), nil

            local sampo_spot = EntityGetClosestWithTag( x, y, "ending_sampo_spot_underground" ) or 0
            if( sampo_spot == 0 ) then
                sampo_spot = EntityGetClosestWithTag( x, y, "ending_sampo_spot_mountain" ) or 0
                if( sampo_spot > 0 ) then
                    local ng_num = tonumber( SessionNumbersGetValue( "NEW_GAME_PLUS_COUNT" ))
                    local check_num, going_ng = ng_num + 5, false
                    if( index.D.orbs < 33 ) then
                        local seven_eleven = index.D.orbs > ORB_COUNT_IN_WORLD and check_num >= ORB_COUNT_IN_WORLD and index.D.orbs >= check_num
                        local eleven_seven = index.D.orbs >= check_num and index.D.orbs < ORB_COUNT_IN_WORLD
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
                        if( index.D.orbs == 11 ) then
                            clr = {255,255,178}
                        elseif( index.D.orbs > 32 ) then
                            clr = {121,201,153}
                        else clr = {208,70,70} end
                    end
                end
            elseif( index.D.orbs > 11 ) then
                clr = {208,70,70}
            end
            
            if( sampo_spot > 0 ) then
                local sampo_x, sampo_y = EntityGetTransform( index.D.sampo )
                local spot_x, spot_y = EntityGetTransform( sampo_spot )
                if(( math.abs( sampo_x - spot_x ) + math.abs( sampo_y - spot_y )) < 32 ) then
                    info_func( screen_h, screen_w, {
                        id = sampo_spot,
                        desc = { pen.capitalizer( GameTextGetTranslatedOrNot( "$biome_boss_victoryroom" )), msg },
                        txt = "[COMPLETE]",
                        color = {{121,201,153}, clr },
                    }, xys )
                end
            end
        end

        local entities = EntityGetInRadius( x, y, 200 ) or {}
        if( #entities > 0 ) then
            local stuff_to_figure = pen.t.init( #index.D.item_cats + 1, {})
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
                        button_data[2] = pen.check_bounds({ x, y }, box_comp, { b_x, b_y })
                    else button_data[2] = dist <= button_data[2] end
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

                            ComponentGetValue2( item_comp, "is_pickable" ) or this_data.pick_always,
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
                                item_data[3] = pen.check_bounds({ x, y }, box_comp, { i_x, i_y })
                            else item_data[3] = dist <= item_data[3] end
                            if( item_data[3] and item_data[4] <= data.frame_num ) then
                                if( this_data.pick_only == 0 or ent == this_data.pick_only ) then
                                    local this_info = index.get_item_data( ent )
                                    if( this_info.id ~= nil ) then
                                        table.insert( item_data, this_info )
                                        if( item_data[5]) then
                                            this_info = 1
                                        else this_info = this_info.cat + 1 end
                                    else this_info = 0 end
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
                            if( index.D.Wallet.money_always or ( cost <= index.D.Wallet.money )) then
                                item_data[10].cost = cost
                            else cost_check = false end
                        end
                        
                        local info_dump = false
                        if( cost_check ) then
                            local will_pause = index.cat_callback( item_data[10], "on_gui_pause" ) ~= nil
                            ComponentSetValue2( item_data[1][2], "inventory_slot", -5, -5 )
                            local new_data = (( will_pause or i == 1 or EntityHasTag( item_data[1][1], "index_slotless" )) and {inv_slot=0} or index.set_to_slot( item_data[10], true ))
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
                                else index.pick_up_item( data.player_id, item_data[10], item_data[6]) end
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
                                w, h = slot_setup( screen_w/2, screen_h - 50, {
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
                    pickup_data.desc = { index.full_stopper( GameTextGet( cant_buy and "$itempickup_notenoughgold" or "$itempickup_cannotpick", pickup_data.name )), true }
                end
            end
            if( pickup_data.id ~= 0 ) then
                local ignore_default = false
                if( index.D.is_opened and index.D.gmod.show_full ) then
                    pickup_data.id = -1
                    pickup_data.desc = { GameTextGet( "$itempickup_cannotpick_closeinventory", pickup_data.this_info.name ), true }
                else
                    local guiing = index.cat_callback( pickup_data.this_info, "on_gui_world" ) --this should be able to nuke the info_func
                    if( guiing ~= nil ) then
                        local i_x, i_y = EntityGetTransform( math.abs( pickup_data.id ))
                        local pic_x, pic_y = pen.world2gui( i_x, i_y )
                        ignore_default = guiing( nil, math.abs( pickup_data.id ), pickup_data.this_info, pic_x, pic_y, no_space, cant_buy, index.cat_callback( pickup_data.this_info, "on_tooltip" ))
                    end
                end
                
                if( not( ignore_default )) then
                    info_func( screen_h, screen_w, pickup_data, xys )
                end
                if( pickup_data.id > 0 and index.D.Controls.act[2]) then
                    local pkp_x, pkp_y = EntityGetTransform( pickup_data.id )
                    local anim_x, anim_y = pen.world2gui( pkp_x, pkp_y )
                    table.insert( index.G.slot_anim, {
                        id = pickup_data.id,
                        x = anim_x,
                        y = anim_y,
                        frame = index.D.frame_num,
                    })
                    
                    local orig_name = pickup_data.this_info.name
                    if( pickup_data.this_info.fullness ~= nil ) then
                        pickup_data.this_info.name = pickup_data.this_info.name..pickup_data.this_info.fullness
                    end
                    index.pick_up_item( index.D.player_id, pickup_data.this_info, pickup_data.do_sound )
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
                local func_path = pen.magic_storage( button_data[1], "index_check", "value_string" )
                if( func_path ~= nil ) then button_data, will_show, do_action = dofile_once( func_path )( button_data ) end
                if( will_show ) then
                    local message_func = info_func
                    local func_path = pen.magic_storage( button_data[1], "index_message", "value_string" )
                    if( func_path ~= nil ) then message_func = dofile_once( func_path ) end

                    message_func( screen_h, screen_w, {
                        id = button_data[1],
                        desc = { pen.capitalizer( button_data[3]), string.gsub( button_data[4], "$0", "[USE]" )},
                        txt = "[USE]",
                    }, xys )
                end
            end
            if( index.D.Controls.act[2]) then
                index.D.Controls.act[2] = false
                
                if( do_action and not( index.M.action_skip_next or false )) then
                    local action_id = interactables[1][1]
                    EntitySetComponentIsEnabled( action_id, EntityGetFirstComponentIncludingDisabled( action_id, "InteractableComponent" ), true )
                    EntitySetComponentIsEnabled( action_id, EntityGetFirstComponent( action_id, "LuaComponent", "index_ctrl" ), false )
                    ComponentSetValue2( index.D.Controls.comp, "mButtonFrameInteract", index.D.frame_num + 1 )
                    index.M.action_skip_next = true
                else
                    ComponentSetValue2( index.D.Controls.comp, "mButtonFrameInteract", 0 )
                    index.M.action_skip_next = false
                end
            end
        end
    end
end

function index.new_generic_drop( this_item )
    local dude = EntityGetRootEntity( this_item )
    if( dude == index.D.player_id ) then
        index.play_sound({ "data/audio/Desktop/ui.bank", "ui/item_remove" })
        
        local do_default = true
        local this_info = pen.t.get( index.D.item_list, this_item )
        local inv_data = index.D.inventories[ this_info.inv_id ] or {}
        local callback = index.cat_callback( this_info, "on_drop" )
        if( callback ~= nil ) then
            do_default = callback( this_item, this_info, false )
        end
        if( inv_data.update ~= nil ) then
            if( inv_data.update( pen.t.get( index.D.item_list, p, nil, nil, inv_data ), this_info, {})) then
                local reset_id = pen.get_item_owner( p, true )
                if( reset_id > 0 ) then
                    pen.reset_active_item( reset_id )
                end
            end
        end
        if( do_default ) then
            local x, y = unpack( index.D.player_xy )
            index.drop_item( x, y, this_info, index.D.throw_force, not( index.D.no_action_on_drop ))
        end
        if( callback ~= nil ) then
            callback( this_item, this_info, true )
        end
    else index.play_sound( "error" ) end
end

function index.new_generic_extra( screen_w, screen_h, xys )
    if( #index.D.inventories_extra > 0 ) then
        for i,extra_inv in ipairs( index.D.inventories_extra ) do
            local inv_data = index.D.inventories[ extra_inv ]
            local x, y = EntityGetTransform( extra_inv )
            local pic_x, pic_y = pen.world2gui( x, y )
            inv_data.func( pic_x, pic_y, inv_data, xys, index.D.slot_func )
        end
    end
end

function index.new_generic_modder( screen_w, screen_h, xys )
    local mode_data = index.D.gmod
    if( mode_data ~= nil and index.D.is_opened and ( not( index.D.gmod.is_hidden ) or index.D.gmod.force_show )) then
        local check = true
        local w,h = pen.get_text_dims( mode_data.name, true )
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
            local arrow_left_c, arrow_right_c, arrow_left_a, arrow_right_a = {255,255,255}, {255,255,255}, 0.3, 0.3
            local arrow_hl_c = {255,255,178}

            local new_mode = index.D.global_mode
            local clicked, r_clicked, is_hovered = pen.new_interface( pic_x - ( 11 + w ), pic_y - 11, 15, 10, pen.LAYERS.TIPS )
            gonna_reset = gonna_reset or r_clicked
            gonna_highlight = gonna_highlight or is_hovered
            if( is_hovered ) then
                arrow_left_c = arrow_hl_c
                arrow_left_a = 1
            end
            if( clicked or index.get_input( "bb_invmode_previous" )) then
                new_mode = new_mode - 1
                arrow_left_a = 1
            end
            clicked, r_clicked, is_hovered = pen.new_interface( pic_x - 10, pic_y - 11, 15, 10, pen.LAYERS.TIPS )
            gonna_reset = gonna_reset or r_clicked
            gonna_highlight = gonna_highlight or is_hovered
            if( is_hovered ) then
                arrow_right_c = arrow_hl_c
                arrow_right_a = 1
            end
            if( clicked or index.get_input( "ba_invmode_next" )) then
                new_mode = new_mode + 1
                arrow_right_a = 1
            end
            is_hovered, clicked, r_clicked = index.tipping( pic_x - ( 6 + w ), pic_y - 11,
                pen.LAYERS.TIPS, w + 6, 10, mode_data.name.."@"..mode_data.desc, { pos = { tip_x - 44, tip_y }, is_left = mode_data.show_full })
            gonna_reset = gonna_reset or r_clicked
            gonna_highlight = gonna_highlight or is_hovered

            local alpha = gonna_highlight and 1 or 0.3
            if( gonna_reset ) then
                for i,gmod in ipairs( index.D.gmod.gmods ) do
                    if( gmod.is_default ) then
                        new_mode = i
                        break
                    end
                end
            end
            if( index.D.global_mode ~= new_mode ) then
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

                index.play_sound( gonna_reset and "reset" or "click" )
                pen.magic_storage( index.D.main_id, "global_mode", "value_int", new_mode )
            end
            
            pen.new_text( pic_x - ( 3 + w ), pic_y - ( 2 + h ), pen.LAYERS.MAIN, mode_data.name, { alpha = alpha })
            index.D.plate_func( pic_x - ( 4 + w ), pic_y - 9, pen.LAYERS.MAIN_BACK, { w + 2, 6 })
            
            pen.new_image( pic_x - ( 12 + w ), pic_y - 10, pen.LAYERS.MAIN_BACK,
                "data/ui_gfx/keyboard_cursor_right.png", { color = arrow_left_c, alpha = arrow_left_a })
            pen.new_image( pic_x - 2, pic_y - 10, pen.LAYERS.MAIN_BACK,
                "data/ui_gfx/keyboard_cursor.png", { color = arrow_right_c, alpha = arrow_right_a })
        end
    end
end