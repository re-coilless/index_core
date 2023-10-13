dofile_once( "mods/index_core/files/_lib.lua" )

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

    return uid, {pic_x,pic_y}
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

    return uid, {pic_x,pic_y}
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

    return uid, {pic_x,pic_y}
end

function new_generic_mana( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.flight )
    data.memo.mana_shake = data.memo.mana_shake or {}

    local this_data = data.Ability
    if( #this_data > 0 ) then
        local potion_data = {}
        local throw_it_back = nil
        
        local value = {0,0}
        if( this_data[2]) then
            value = { math.min( math.max( this_data[4], 0 ), this_data[3]), this_data[3]}
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
        elseif( #data.Item > 0 ) then
            this_data = data.MaterialInventory
            if( #this_data > 0 ) then
                local barrel_size = EntityGetFirstComponentIncludingDisabled( data.active_item, "MaterialSuckerComponent" )
                barrel_size = barrel_size == nil and this_data[2] or ComponentGetValue2( barrel_size, "barrel_size" )
                if( barrel_size >= 0 ) then
                    value = { math.min( math.max( this_data[3][1], 0 ), barrel_size ), barrel_size }
                    potion_data = { "data/ui_gfx/hud/potion.png", }
                    if( data.fancy_potion_bar ) then
                        table.insert( potion_data, data.pixel )
                        table.insert( potion_data, get_uint_color( GameGetPotionColorUint( data.active_item )))
                        table.insert( potion_data, 0.8 )
                    end
                end
            end
        end
        if( value[1] >= 0 and value[2] > 0 ) then
            local ratio = value[1]/value[2]
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, potion_data[1] or "data/ui_gfx/hud/mana.png" )
            if( potion_data[3] ~= nil ) then
                uid = new_image( gui, uid, pic_x - 40, pic_y + 1, zs.main + 0.001, potion_data[2], math.min( 40*ratio + 0.5, 40 ), 2 )
                colourer( gui, potion_data[3])
            end
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*ratio}, potion_data[2] or "data/ui_gfx/hud/colors_mana_bar.png", throw_it_back, potion_data[4])

            local tip = ""
            if( potion_data[3] ~= nil ) then
                local cnt = 1
                for i,mtr in ipairs( this_data[3][2]) do
                    if( i == 1 or mtr[2] > 5 ) then
                        tip = tip..( i == 1 and "" or "+" )..capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( mtr[1])))
                        cnt = cnt + 1
                        if( cnt > 3 ) then break end
                    end
                end
                
                local v = tostring( math.floor( 100*value[1]/value[2] + 0.5 ))
                tip = tip..( tip == "" and tip or " " )..GameTextGetTranslatedOrNot( data.Item[6]).."@"..GameTextGet( "$item_potion_fullness", v )
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

    return uid, {pic_x,pic_y}
end

function new_generic_reload( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.mana )
    data.memo.reload_shake = data.memo.reload_shake or {}
    data.memo.reload_max = data.memo.reload_max or {}
    
    local this_data = data.Ability
    if( #this_data > 0 and not( this_data[5])) then
        data.memo.reload_max[data.active_item] = ( data.memo.reload_max[data.active_item] or -1 ) < this_data[6] and this_data[6] or data.memo.reload_max[data.active_item]
        if( data.memo.reload_max[data.active_item] > data.reload_threshold ) then
            if( data.memo.reload_max[data.active_item] ~= this_data[6]) then
                if( data.memo.reload_shake[data.active_item] == nil and data.just_fired ) then
                    data.memo.reload_shake[data.active_item] = data.frame_num + 20
                end
            end
            
            local shake_frame = ( data.memo.reload_shake[data.active_item] or data.frame_num ) - data.frame_num
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/reload.png" )
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*this_data[6]/data.memo.reload_max[data.active_item]}, "data/ui_gfx/hud/colors_reload_bar.png", data.memo.reload_shake[data.active_item] ~= nil and 20-shake_frame or nil )
            
            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$hud_wand_reload" )..string.format( "%.2f", this_data[6]/60 ).."s"
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
    if(( this_data[6] or 0 ) == 0 ) then
        data.memo.reload_max[data.active_item] = nil
    end

    return uid, {pic_x,pic_y}
end

function new_generic_delay( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = unpack( xys.reload )
    data.memo.delay_shake = data.memo.delay_shake or {}
    data.memo.delay_max = data.memo.delay_max or {}

    local this_data = data.Ability
    if( #this_data > 0 ) then
        data.memo.delay_max[data.active_item] = ( data.memo.delay_max[data.active_item] or -1 ) < this_data[7] and this_data[7] or data.memo.delay_max[data.active_item]
        if( data.memo.delay_max[data.active_item] > data.delay_threshold ) then
            if( data.memo.delay_max[data.active_item] ~= this_data[7]) then
                if( data.memo.delay_shake[data.active_item] == nil and data.just_fired ) then
                    data.memo.delay_shake[data.active_item] = data.frame_num + 20
                end
            end
            
            local shake_frame = ( data.memo.delay_shake[data.active_item] or data.frame_num ) - data.frame_num
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main, "data/ui_gfx/hud/fire_rate_wait.png" )
            uid = new_vanilla_bar( gui, uid, pic_x, pic_y, {zs.main_back,zs.main}, {40,2,40*this_data[7]/data.memo.delay_max[data.active_item]}, "data/ui_gfx/hud/colors_reload_bar.png", data.memo.delay_shake[data.active_item] ~= nil and 20-shake_frame or nil )
            
            local tip_x, tip_y = unpack( xys.hp )
            local tip = hud_text_fix( "$inventory_castdelay" )..string.format( "%.2f", this_data[7]/60 ).."s"
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
    if(( this_data[7] or 0 ) == 0 ) then
        data.memo.delay_max[data.active_item] = nil
    end

    return uid, {pic_x,pic_y}
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

    return uid, {pic_x,pic_y}
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

    return uid, {pic_x,pic_y}
end