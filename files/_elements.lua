dofile_once( "mods/index_core/files/_lib.lua" )

function new_generic_hp( gui, uid, screen_w, screen_h, data, zs, xys )
    local pic_x, pic_y = screen_w - 41, 20

    local this_data = data.DamageModel
    if( ComponentGetIsEnabled( this_data[1])) then
        local max_hp = this_data[2]
        if( max_hp > 0 ) then
            local length = math.floor( 163.8 - 210.02/( 1 + ( math.min( math.max( max_hp, 0 ), 40 )/11.77 )^( 0.335 )) + 0.5 )
            length = length < 5 and 40 or length

            local pic = "mods/index_core/files/pics/vanilla_bar_bg_"
            uid = new_image( gui, uid, pic_x - length, pic_y + 1, zs.main_back, pic.."0.xml", length, 4 )
            for i = 1,2 do
                local new_z = zs.main_back + ( i == 1 and 0.001 or 0 )
                uid = new_image( gui, uid, pic_x, pic_y, new_z, pic..i..".xml", 1, 6 )
                uid = new_image( gui, uid, pic_x - ( length + 1 ), pic_y, new_z, pic..i..".xml", 1, 6 )
                uid = new_image( gui, uid, pic_x - length, pic_y, new_z, pic..i..".xml", length, 1 )
                uid = new_image( gui, uid, pic_x - length, pic_y + 5, new_z, pic..i..".xml", length, 1 )
            end
            
            local hp = math.min( math.max( this_data[3], 0 ), max_hp )
            local low_hp = math.max( math.min( max_hp/4, 1 ), 0.2 )
            pic = "data/ui_gfx/hud/colors_health_bar.png"
            if( hp < low_hp ) then
                local freq = 10*( 1.5 - ( low_hp - hp )/low_hp )
                local blinking = 0.5*( math.sin((( data.frame_num + freq )*math.pi )/( 2*freq )) + 1 )
                if( blinking > 0.5 ) then
                    uid = new_image( gui, uid, pic_x - ( length + 1 ), pic_y, zs.main_back - 0.001, "data/ui_gfx/hud/colors_health_bar_bg_low_hp.png", ( length + 2 )/2, 3 )
                else
                    pic = "data/ui_gfx/hud/colors_health_bar_damage.png"
                end
            end
            uid = new_image( gui, uid, pic_x - length, pic_y + 1, zs.main, pic, 0.5*length*hp/max_hp, 2 )
            uid = new_image( gui, uid, pic_x + 3, pic_y - 1, zs.main_back, "data/ui_gfx/hud/health.png" )
            uid = new_font_vanilla_small( gui, uid, pic_x + 13, pic_y, zs.main_back, math.floor( hp*25 + 0.5 ), { 255, 255, 255, 0.9 })

            local damage_delta = data.frame_num - this_data[5]
            if( damage_delta < 31 ) then
                hp = math.min( math.max( this_data[4], 0 ), max_hp )
                uid = new_image( gui, uid, pic_x - length, pic_y + 1, zs.main + 0.001, "data/ui_gfx/hud/colors_health_bar_damage.png", 0.5*length*hp/max_hp, 2, ( 30 - damage_delta )/30 )
            end

            pic_y = pic_y + 10
        end
    end

    return uid, {pic_x,pic_y}
end

function new_generic_flight( gui, uid, screen_w, screen_h, data, zs, xys )
    -- data/ui_gfx/hud/jetpack.png
    -- data/ui_gfx/hud/colors_flying_bar.png

    return uid, {pic_x,pic_y}
end

function new_generic_air( gui, uid, screen_w, screen_h, data, zs, xys )
    -- o2
    -- data/ui_gfx/hud/colors_mana_bar.png

    return uid, {pic_x,pic_y}
end

function new_generic_mana( gui, uid, screen_w, screen_h, data, zs, xys )
    -- data/ui_gfx/hud/mana.png
    -- data/ui_gfx/hud/potion.png
    -- data/ui_gfx/hud/colors_mana_bar.png

    return uid, {pic_x,pic_y}
end

function new_generic_delay( gui, uid, screen_w, screen_h, data, zs, xys )
    -- data/ui_gfx/hud/fire_rate_wait.png
    -- data/ui_gfx/hud/colors_mana_bar.png

    return uid, {pic_x,pic_y}
end

function new_generic_recharge( gui, uid, screen_w, screen_h, data, zs, xys )
    -- data/ui_gfx/hud/reload.png
    -- data/ui_gfx/hud/colors_reload_bar.png
    -- data/ui_gfx/hud/colors_reload_bar_bg_flash.png

    return uid, {pic_x,pic_y}
end

function new_generic_gold( gui, uid, screen_w, screen_h, data, zs, xys )
    -- data/ui_gfx/hud/money.png

    return uid, {pic_x,pic_y}
end

function new_generic_orbs( gui, uid, screen_w, screen_h, data, zs, xys )
    -- data/ui_gfx/hud/orbs.png

    return uid, {pic_x,pic_y}
end