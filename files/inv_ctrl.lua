dofile_once( "mods/index_core/files/_lib.lua" )

ctrl_data = ctrl_data or {}
dscrt_btn = dscrt_btn or {}
tip_going = false
tip_anim = tip_anim or {0,0,0}
mouse_memo = mouse_memo or {}
mouse_memo_world = mouse_memo_world or {}
mtr_probe = mtr_probe or 0
mtr_probe_memo = mtr_probe_memo or {0,0,0,0,0,0,0,0,0,0}

local current_frame = GameGetFrameNum()
if( current_frame - tip_anim[2] > 20 ) then
    tip_anim[1] = 0
else
    tip_anim[3] = math.min( current_frame - tip_anim[1], 15 )
end

local controller_id = GetUpdatedEntityID()
local hooman = EntityGetParent( controller_id )
if( not( EntityGetIsAlive( hooman ))) then
    return
end

local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
local ctrl_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ControlsComponent" )

--InventoryGuiComponent

local comp_nuker = { iui_comp,  }--pick_comp
for i,comp in ipairs( comp_nuker ) do
    if( comp ~= nil and ComponentGetIsEnabled( comp )) then
        EntitySetComponentIsEnabled( hooman, comp, false )
    end
end

local forced_state = ComponentGetValue2( get_storage( controller_id, "forced_state" ), "value_int" )
local is_going = forced_state > 0
if( forced_state == 0 ) then
    is_going = ComponentGetValue2( ctrl_comp, "enabled" )
end

if( is_going and inv_comp ~= nil ) then
    if( gui == nil ) then
		gui = GuiCreate()
	end
	GuiStartFrame( gui )

    local fake_gui = GuiCreate()
    GuiStartFrame( fake_gui )

    local m_x, m_y = DEBUG_GetMouseWorld()
    local md_x, md_y = m_x - ( mouse_memo_world[1] or m_x ), m_y - ( mouse_memo_world[2] or m_y )
    mouse_memo_world = { m_x, m_y }
    local mui_x, mui_y = world2gui( m_x, m_y )
    local muid_x, muid_y = mui_x - ( mouse_memo[1] or mui_x ), mui_y - ( mouse_memo[2] or mui_y )
    mouse_memo = { mui_x, mui_y }
    
    local pointer_mtr = 0
    if( not( EntityGetIsAlive( mtr_probe ))) then
        mtr_probe = EntityLoad( "mods/index_core/files/matter_test.xml", m_x, m_y )
    end
    if( mtr_probe > 0 ) then
        local jitter_mag = 0.5
        EntityApplyTransform( mtr_probe, m_x + jitter_mag*get_sign( math.random(-2,1)), m_y + jitter_mag*get_sign( math.random(-2,1)))
        
        local mtr_list = {}
        local dmg_comp = EntityGetFirstComponentIncludingDisabled( mtr_probe, "DamageModelComponent" )
        local matter = ComponentGetValue2( dmg_comp, "mCollisionMessageMaterials" )
        local count = ComponentGetValue2( dmg_comp, "mCollisionMessageMaterialCountsThisFrame" )
        for i,v in ipairs( count ) do
            if( v > 0 ) then
                local id = matter[i]
                mtr_list[id] = mtr_list[id] and ( mtr_list[id] + v ) or v
            end
        end
        local cells = {}
        for id,cnt in pairs( mtr_list ) do
            table.insert( cells, { id, cnt })
        end
        if( #cells > 0 ) then
            table.sort( cells, function( a, b )
                return a[2] > b[2]
            end)
            pointer_mtr = cells[1][1]
        end
    end
    table.remove( mtr_probe_memo, 1 )
    table.insert( mtr_probe_memo, pointer_mtr )
    local most_mtr, most_mtr_count = get_most_often( mtr_probe_memo )
    pointer_mtr = most_mtr_count > 5 and most_mtr or 0
    
    local epsilon = ComponentGetValue2( get_storage( controller_id, "min_effect_duration" ), "value_float" )

    local perk_tbl, effect_tbl = {}, {ings={},stains={},misc={}}
    local dmg_comp = EntityGetFirstComponentIncludingDisabled( hooman, "DamageModelComponent" )
    local status_comp = EntityGetFirstComponentIncludingDisabled( hooman, "StatusEffectDataComponent" )
    if( status_comp ~= nil ) then
        dofile_once( "data/scripts/status_effects/status_list.lua" )
        if( status_effects[1].real_id == nil ) then
            local id_memo = {}
            local id_num = 1
            for i,e in ipairs( status_effects ) do
                if( id_memo[e.id] == nil ) then
                    id_memo[e.id] = true
                    id_num = id_num + 1
                end
                status_effects[i].real_id = id_num
            end 
        end

        local core_effects = {}
        local simple_effects = {}
        child_play( hooman, function( parent, child, i ) --maybe don't get disabled
            local effect_comp = EntityGetFirstComponentIncludingDisabled( child, "GameEffectComponent" )
            if( effect_comp ~= nil ) then
                local is_ing = ComponentGetValue2( effect_comp, "caused_by_ingestion_status_effect" )
                local is_stain = ComponentGetValue2( effect_comp, "caused_by_stains" )
                local is_core = is_ing or is_stain

                local effect = ComponentGetValue2( effect_comp, "effect" )
                effect = effect == "CUSTOM" and ComponentGetValue2( effect_comp, "custom_effect_id" ) or effect
                local effect_id = ComponentGetValue2( effect_comp, "causing_status_effect" ) + 1
                table.insert( is_core and core_effects or simple_effects, { child, effect_comp, effect_id, effect })
            end
        end)
        if( #core_effects > 0 ) then
            local ing_frame = ComponentGetValue2( status_comp, "ingestion_effects" )
            local ing_matter = ComponentGetValue2( status_comp, "ingestion_effect_causes" )
            local ing_more = ComponentGetValue2( status_comp, "ingestion_effect_causes_many" )
            for i,duration in ipairs( ing_frame ) do
                local effect_id = i
                if( duration ~= 0 ) then
                    local game_effect = from_tbl_with_id( core_effects, effect_id, nil, 3 ) or {}
                    if( #game_effect > 0 ) then
                        local effect_info = get_thresholded_effect( from_tbl_with_id( status_effects, { game_effect[3]}, nil, "real_id" ) or {}, duration )
                        local time = get_effect_duration( duration, effect_info, epsilon )
                        if( effect_info.id ~= nil and time ~= 0 ) then
                            local mtr = GameTextGetTranslatedOrNot( CellFactory_GetUIName( ing_matter[effect_id]))
                            local is_many = ing_more[effect_id] == 1
                            local message = GameTextGet( "$ingestion_status_caused_by"..( is_many and "_many" or "" ), mtr )
                            
                            local effect_data = {
                                pic = effect_info.ui_icon,
                                txt = get_effect_timer( time ),
                                desc = GameTextGetTranslatedOrNot( effect_info.ui_name ),
                                tip = GameTextGetTranslatedOrNot( effect_info.ui_description ).."@"..message,

                                amount = time*60,
                                is_danger = effect_info.is_harmful,
                            }
                            table.insert( effect_tbl.ings, effect_data )
                        end
                    end
                end
            end
            table.sort( effect_tbl.ings, function( a, b )
                return a.amount > b.amount
            end)
            local ing_comp = EntityGetFirstComponentIncludingDisabled( hooman, "IngestionComponent" )
            if( ing_comp ~= nil ) then
                local raw_count = ComponentGetValue2( ing_comp, "ingestion_size" )
                local perc = math.floor( 100*raw_count/ComponentGetValue2( ing_comp, "ingestion_capacity" ) + 0.5 )
                if( raw_count > 0 ) then
                    local stomach_tbl = { 25, 90, 100, 140, 150, 175, }
                    local stomach_step = #stomach_tbl
                    for i = 1,#stomach_tbl do
                        if( perc < stomach_tbl[i]) then
                            stomach_step = i-1
                            break
                        end
                    end
                    
                    table.insert( effect_tbl.ings, 1, {
                        pic = "data/ui_gfx/status_indicators/satiation_0"..stomach_step..".png",
                        txt = perc.."%",
                        desc = GameTextGetTranslatedOrNot( "$status_satiated0"..stomach_step ),
                        tip = GameTextGetTranslatedOrNot( "$statusdesc_satiated0"..stomach_step ),

                        amount = math.min( perc/100, 1 ),
                        is_danger = perc > 100 and not( GameHasFlagRun( "PERK_PICKED_IRON_STOMACH" )),
                        is_stomach = true,
                        digestion_delay = math.min( ComponentGetValue2( ing_comp, "m_ingestion_cooldown_frames" )/ComponentGetValue2( ing_comp, "ingestion_cooldown_delay_frames" ), 1 ),
                    })
                end
            end

            local stain_percs = ComponentGetValue2( status_comp, "mStainEffectsSmoothedForUI" )
            for i,duration in ipairs( stain_percs ) do
                local effect_id = i
                local perc = get_stain_perc( duration )
                if( perc > 0 ) then
                    local game_effect = from_tbl_with_id( core_effects, effect_id, nil, 3 ) or {}
                    if( #game_effect > 0 ) then
                        local effect_info = get_thresholded_effect( from_tbl_with_id( status_effects, { game_effect[3]}, nil, "real_id" ) or {}, duration )
                        if( effect_info.id ~= nil ) then
                            local effect_data = {
                                id = effect_id,

                                pic = effect_info.ui_icon,
                                txt = math.min( perc, 100 ).."%",
                                desc = GameTextGetTranslatedOrNot( effect_info.ui_name ),
                                tip = GameTextGetTranslatedOrNot( effect_info.ui_description ),

                                amount = math.min( perc/100, 1 ),
                                is_danger = effect_info.is_harmful,
                            }
                            table.insert( effect_tbl.stains, effect_data )
                        end
                    end
                end
            end
            table.sort( effect_tbl.stains, function( a, b )
                return a.id > b.id
            end)
            if( dmg_comp ~= nil and ComponentGetIsEnabled( dmg_comp ) and ComponentGetValue2( dmg_comp, "mIsOnFire" )) then
                local fire_info = from_tbl_with_id( status_effects, "ON_FIRE" )
                local perc = math.floor( 100*ComponentGetValue2( dmg_comp, "mFireFramesLeft" )/ComponentGetValue2( dmg_comp, "mFireDurationFrames" ))
                table.insert( effect_tbl.stains, 1, {
                    pic = fire_info.ui_icon,
                    txt = perc.."%",
                    desc = GameTextGetTranslatedOrNot( fire_info.ui_name ),
                    tip = GameTextGetTranslatedOrNot( fire_info.ui_description ),

                    amount = math.min( perc/100, 1 ),
                    is_danger = true,
                })
            end
        end

        child_play_full( hooman, function( child )
            local info_comp = EntityGetFirstComponentIncludingDisabled( child, "UIIconComponent" )
            if( info_comp ~= nil and ComponentGetValue2( info_comp, "display_in_hud" )) then
                local icon_info = {
                    pic = ComponentGetValue2( info_comp, "icon_sprite_file" ),
                    txt = "",
                    desc = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "name" )),
                    tip = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "description" )),
                    count = 1,
                }
                local is_perk = ComponentGetValue2( info_comp, "is_perk" )
                if( is_perk ) then
                    local _, true_id = from_tbl_with_id( perk_tbl, icon_info.pic, nil, "pic" )
                    if( true_id == nil ) then
                        if( EntityGetName( child ) == "fungal_shift_ui_icon" ) then
                            icon_info.tip = GlobalsGetValue( "fungal_memo", "" ).."@"..icon_info.tip
                            icon_info.count = tonumber( GlobalsGetValue( "fungal_shift_iteration", "0" ))
                            icon_info.is_fungal = true
                            
                            local fungal_timer = math.max( tonumber( 60*60*5 + GlobalsGetValue( "fungal_shift_last_frame", "0" )) - current_frame, 0 )
                            if( fungal_timer > 0 ) then
                                icon_info.amount = fungal_timer
                                icon_info.txt = get_effect_timer( icon_info.amount/60 )
                                icon_info.tip = icon_info.tip.."@"..icon_info.txt.." until next Shift window."
                            end
                            
                            table.insert( perk_tbl, 1, icon_info )
                        else
                            dofile_once( "data/scripts/perks/perk_list.lua" )
                            table.insert( perk_tbl, icon_info )
                        end
                    else
                        perk_tbl[true_id].count = perk_tbl[true_id].count + 1
                    end
                else
                    local _, true_id = from_tbl_with_id( effect_tbl.misc, icon_info.pic, nil, "pic" )

                    icon_info.amount = -2
                    if( #simple_effects > 0 and ( EntityGetParent( child ) or 0 ) == hooman ) then
                        local effect = from_tbl_with_id( simple_effects, child ) or {}
                        if( #effect > 0 ) then
                            icon_info.amount = ComponentGetValue2( effect[2], "frames" )
                            if( true_id == nil ) then
                                local effect_info = get_thresholded_effect( from_tbl_with_id( status_effects, { effect[3]}, nil, "real_id" ) or {}, icon_info.amount )
                                if( effect_info.id ~= nil ) then
                                    icon_info.main_info = effect_info
                                    -- icon_info.pic = effect_info.ui_icon
                                    icon_info.desc = GameTextGetTranslatedOrNot( effect_info.ui_name )
                                    icon_info.tip = GameTextGetTranslatedOrNot( effect_info.ui_description )
                                    icon_info.is_danger = effect_info.is_harmful
                                end
                            end
                        end
                    end
                    if( icon_info.amount == -2 ) then
                        local time_comp = EntityGetFirstComponentIncludingDisabled( child, "LifetimeComponent" )
                        if( time_comp ~= nil ) then
                            icon_info.amount = math.max( ComponentGetValue2( time_comp, "kill_frame" ) - current_frame, -1 )
                        end
                    end
                    if( icon_info.amount ~= -2 ) then
                        icon_info.amount = get_effect_duration( icon_info.amount, icon_info.main_info, epsilon )
                    end

                    if( true_id == nil ) then
                        if( icon_info.amount ~= 0 ) then
                            icon_info.time_tbl = {}
                            local time = icon_info.amount/60
                            if( time > 0 ) then
                                table.insert( icon_info.time_tbl, time )
                            end
                        end
                        table.insert( effect_tbl.misc, icon_info )
                    else
                        local time = icon_info.amount/60
                        if( time > 0 ) then
                            table.insert( effect_tbl.misc[true_id].time_tbl, time )
                        end

                        effect_tbl.misc[true_id].count = effect_tbl.misc[true_id].count + 1
                        if( effect_tbl.misc[true_id].amount < icon_info.amount ) then
                            effect_tbl.misc[true_id].amount = icon_info.amount
                        end
                    end
                end
            end
        end)
        table.sort( perk_tbl, function( a, b )
            return a.count > b.count
        end)

        for i,e in ipairs( effect_tbl.misc ) do
            table.sort( e.time_tbl, function( a, b )
                return a > b
            end)
            effect_tbl.misc[1].txt = get_effect_timer( e.time_tbl[1])
            if( #e.time_tbl > 1 ) then
                local tip = GameTextGetTranslatedOrNot( "$menu_replayedit_writinggif_timeremaining" )
                effect_tbl.misc[1].tip = effect_tbl.misc[1].tip.."@"..string.gsub( tip, "%$0 ", get_effect_timer( e.time_tbl[#e.time_tbl], true ))
            end
        end
        table.sort( effect_tbl.misc, function( a, b )
            return a.amount > b.amount
        end)
    end

    --track all full slots in a global (redo if is nil)
    
    local uid = 0
    local pos_tbl = {}
	local screen_w, screen_h = GuiGetScreenDimensions( gui )
    local inv, z_layers, item_types = unpack( dofile_once( "mods/index_core/files/_structure.lua" ))
    local data = {
        the_gui = gui,
        memo = ctrl_data,
        pixel = "mods/index_core/files/pics/THE_GOD_PIXEL.png",
        is_opened = ComponentGetValue2( iui_comp, "mActive" ),

        player_id = hooman,
        frame_num = current_frame,
        orbs = GameGetOrbCountThisRun(),

        pointer_world = {m_x,m_y},
        pointer_ui = {mui_x,mui_y},
        pointer_delta = {muid_x,muid_y,math.sqrt( muid_x^2 + muid_y^2 )},
        pointer_delta_world = {md_x,md_y,math.sqrt( md_x^2 + md_y^2 )},
        pointer_matter = pointer_mtr,

        active_item = get_active_wand( hooman ),
        active_info = {},
        just_fired = get_discrete_button( hooman, ctrl_comp, "mButtonDownFire" ),
        no_mana_4life = tonumber( GlobalsGetValue( "INDEX_FUCKYOUMANA", "0" )) == hooman,
        
        icon_data = effect_tbl,
        perk_data = perk_tbl,

        inv_types = item_types,
        inv_list = {},
        inv_count_quick = ComponentGetValue2( inv_comp, "quick_inventory_slots" ),
        inv_count_full = { ComponentGetValue2( inv_comp, "full_inventory_slots_x" ), ComponentGetValue2( inv_comp, "full_inventory_slots_y" )},

        slot_pic = {
            bg = ComponentGetValue2( get_storage( controller_id, "slot_pic_bg" ), "value_string" ),
            bg_alt = ComponentGetValue2( get_storage( controller_id, "slot_pic_bg_alt" ), "value_string" ),
            hl = ComponentGetValue2( get_storage( controller_id, "slot_pic_hl" ), "value_string" ),
            active = ComponentGetValue2( get_storage( controller_id, "slot_pic_active" ), "value_string" ),
        },
        hide_on_empty = ComponentGetValue2( get_storage( controller_id, "hide_on_empty" ), "value_bool" ),
        short_hp = ComponentGetValue2( get_storage( controller_id, "short_hp" ), "value_bool" ),
        hp_threshold = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_threshold" ), "value_float" ),
        hp_threshold_min = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_threshold_min" ), "value_float" ),
        hp_flashing = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_period" ), "value_int" ),
        hp_flashing_intensity = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_intensity" ), "value_float" ),
        fancy_potion_bar = ComponentGetValue2( get_storage( controller_id, "fancy_potion_bar" ), "value_bool" ),
        reload_threshold = ComponentGetValue2( get_storage( controller_id, "reload_threshold" ), "value_int" ),
        delay_threshold = ComponentGetValue2( get_storage( controller_id, "delay_threshold" ), "value_int" ),
        short_gold = ComponentGetValue2( get_storage( controller_id, "short_gold" ), "value_bool" ),
        info_pointer = ComponentGetValue2( get_storage( controller_id, "info_pointer" ), "value_bool" ),
        info_radius = ComponentGetValue2( get_storage( controller_id, "info_radius" ), "value_int" ),
        info_threshold = ComponentGetValue2( get_storage( controller_id, "info_threshold" ), "value_float" ),
        info_mtr_fading = ComponentGetValue2( get_storage( controller_id, "info_mtr_fading" ), "value_int" ),
        info_mtr_static = ComponentGetValue2( get_storage( controller_id, "info_mtr_static" ), "value_bool" ),
        min_effect_time = epsilon,
        max_perks = ComponentGetValue2( get_storage( controller_id, "max_perk_count" ), "value_int" ),

        Controls = {},
        DamageModel = {},
        CharacterData = {},
        CharacterPlatforming = {},
        Wallet = {},
    }

    if( ctrl_comp ~= nil ) then
        data.Controls = {
            ctrl_comp,

            ComponentGetValue2( ctrl_comp, "mButtonDownInventory" ),
            ComponentGetValue2( ctrl_comp, "mButtonDownInteract" ),
            ComponentGetValue2( ctrl_comp, "mButtonDownFly" ),
        }
    end
    if( dmg_comp ~= nil ) then
        data.DamageModel = {
            dmg_comp,

            ComponentGetValue2( dmg_comp, "max_hp" ),
            ComponentGetValue2( dmg_comp, "hp" ),
            ComponentGetValue2( dmg_comp, "mHpBeforeLastDamage" ),
            math.max( data.frame_num - ComponentGetValue2( dmg_comp, "mLastDamageFrame" ), 0 ),

            ComponentGetValue2( dmg_comp, "air_needed" ),
            ComponentGetValue2( dmg_comp, "air_in_lungs_max" ),
            ComponentGetValue2( dmg_comp, "air_in_lungs" ),   
        }
    end
    local char_comp = EntityGetFirstComponentIncludingDisabled( hooman, "CharacterDataComponent" )
    if( char_comp ~= nil ) then
        local max_flight = ComponentGetValue2( char_comp, "fly_time_max" )*( 2^GameGetGameEffectCount( hooman, "HOVER_BOOST" ))
        data.CharacterData = {
            char_comp,

            ComponentGetValue2( char_comp, "flying_needs_recharge" ),
            max_flight,
            math.min( ComponentGetValue2( char_comp, "mFlyingTimeLeft" ), max_flight ),
        }
    end
    local wallet_comp = EntityGetFirstComponentIncludingDisabled( hooman, "WalletComponent" )
    if( wallet_comp ~= nil ) then
        data.Wallet = {
            wallet_comp,
            
            ComponentGetValue2( wallet_comp, "mHasReachedInf" ),
            ComponentGetValue2( wallet_comp, "money" ),
        }
    end
    data.inv_list = get_inventory_data( hooman, data )
    if( data.active_item > 0 ) then
        data.active_info = from_tbl_with_id( data.inv_list.quick, data.active_item ) or {}
        if( data.active_info.id ~= nil ) then
            local abil_comp = data.active_info.AbilityC
            if( abil_comp ~= nil ) then --reset shot_count on item swap
                data.memo.shot_count = data.memo.shot_count or {}
                local shot_count = ComponentGetValue2( abil_comp, "stat_times_player_has_shot" )
                data.just_fired = data.just_fired or (( data.memo.shot_count[ data.active_item ] or shot_count ) < shot_count )
                if( data.just_fired ) then
                    data.memo.shot_count[ data.active_item ] = shot_count
                end
            end
        else
            data.active_item = 0
        end
    end

    --add and ability to refresh the spell list (on vanilla level) for real time editing
    --test actions materialized
    if( inv.full_inv ~= nil ) then
        uid, pos_tbl.full_inv = inv.full_inv( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    local bars = inv.bars or {}
    if( bars.hp ~= nil ) then
        uid, pos_tbl.hp = bars.hp( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( bars.air ~= nil ) then
        uid, pos_tbl.air = bars.air( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( bars.flight ~= nil ) then
        uid, pos_tbl.flight = bars.flight( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    local actions = bars.action or {}
    if( actions.mana ~= nil ) then
        uid, pos_tbl.mana = actions.mana( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( actions.reload ~= nil ) then
        uid, pos_tbl.reload = actions.reload( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( actions.delay ~= nil ) then
        uid, pos_tbl.delay = actions.delay( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    if( inv.gold ~= nil ) then
        uid, pos_tbl.gold = inv.gold( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( inv.orbs ~= nil ) then
        uid, pos_tbl.orbs = inv.orbs( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( inv.info ~= nil ) then
        uid, pos_tbl.info = inv.info( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    local icons = inv.icons or {}
    if( icons.ingestions ~= nil ) then
        uid, pos_tbl.ingestions = icons.ingestions( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( icons.stains ~= nil ) then
        uid, pos_tbl.stains = icons.stains( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( icons.effects ~= nil ) then
        uid, pos_tbl.effects = icons.effects( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( icons.perks ~= nil ) then
        uid, pos_tbl.perks = icons.perks( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    GuiDestroy( fake_gui )
else
    gui = gui_killer( gui )
    if( EntityGetIsAlive( mtr_probe )) then
       EntityKill( mtr_probe )
       mtr_probe_memo = nil
    end
end