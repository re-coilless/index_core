dofile_once( "mods/index_core/files/_lib.lua" )
if( not( ModIsEnabled( "index_core" ))) then
    self_destruct()
    return
end

ctrl_data = ctrl_data or {} --general global for custom metaframe values
dscrt_btn = dscrt_btn or {} --a table of button states for discrete input (jsut for the sake of being vanilla independent)
dragger_buffer = dragger_buffer or {0,0} --metaframe values that allow for responsive draggables
item_pic_data = item_pic_data or {} --various info on the particular image filepath for icon pics
spell_proj_data = spell_proj_data or {} --various info on the particular projectile filepath of a spell
gonna_drop = gonna_drop or false --trigger for "drop on failure to swap"

slot_going = slot_going or false --a check that makes sure only one slot is being dragged at a time
slot_memo = slot_memo or {} --a table of slot states that enables slot code even if the pointer is outside the box
slot_anim = slot_anim or {} --fancy dragging anim
slot_hover_sfx = slot_hover_sfx or {0,false} --context sensitive hover sfx

mouse_memo = mouse_memo or {} --for getting pointer delta
mouse_memo_world = mouse_memo_world or {} --for getting pointer delta in-world

mtr_probe = mtr_probe or 0 --matter test entity id 
mtr_probe_memo = mtr_probe_memo or {0,0,0,0,0,0,0,0,0,0} --smoothing of the matter displayed

tip_going = {} --a check that makes sure only one tooltip exists per unique id
tip_anim = tip_anim or {generic={0,0,0}} --tooltip anim state
local current_frame = GameGetFrameNum()
for tid,tip_tbl in pairs( tip_anim ) do
    if( current_frame - tip_tbl[2] > 20 ) then
        tip_anim[tid][1] = 0
    else
        tip_anim[tid][3] = math.min( current_frame - tip_tbl[1], 15 )
    end
end

local fake_gui, font_gui = nil, nil
local dead_guis = {}
local ctrl_bodies = EntityGetWithTag( "index_ctrl" ) or {}
if( #ctrl_bodies > 0 ) then
    local controller_id = ctrl_bodies[1]
    global_settings = global_settings or {
        player_core_off = ComponentGetValue2( get_storage( controller_id, "player_core_off" ), "value_float" ),
        throw_pos_rad = ComponentGetValue2( get_storage( controller_id, "throw_pos_rad" ), "value_int" ),
        throw_pos_size = ComponentGetValue2( get_storage( controller_id, "throw_pos_size" ), "value_int" ),
        throw_force = ComponentGetValue2( get_storage( controller_id, "throw_force" ), "value_float" ),

        quickest_size = ComponentGetValue2( get_storage( controller_id, "quickest_size" ), "value_int" ),
        inv_spacings = D_extractor( ComponentGetValue2( get_storage( controller_id, "inv_spacings" ), "value_string" ), true ),
        effect_icon_spacing = ComponentGetValue2( get_storage( controller_id, "effect_icon_spacing" ), "value_int" ),
        min_effect_duration = ComponentGetValue2( get_storage( controller_id, "min_effect_duration" ), "value_float" ),
        spell_anim_frames = ComponentGetValue2( get_storage( controller_id, "spell_anim_frames" ), "value_int" ),

        hp_threshold = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_threshold" ), "value_float" ),
        hp_threshold_min = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_threshold_min" ), "value_float" ),
        hp_flashing = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_period" ), "value_int" ),
        hp_flashing_intensity = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_intensity" ), "value_float" ),

        info_radius = ComponentGetValue2( get_storage( controller_id, "info_radius" ), "value_int" ),
        info_threshold = ComponentGetValue2( get_storage( controller_id, "info_threshold" ), "value_float" ),
        info_fading = ComponentGetValue2( get_storage( controller_id, "info_fading" ), "value_int" ),

        loot_marker = ComponentGetValue2( get_storage( controller_id, "loot_marker" ), "value_string" ),
        slot_pic = {
            bg = ComponentGetValue2( get_storage( controller_id, "slot_pic_bg" ), "value_string" ),
            bg_alt = ComponentGetValue2( get_storage( controller_id, "slot_pic_bg_alt" ), "value_string" ),
            hl = ComponentGetValue2( get_storage( controller_id, "slot_pic_hl" ), "value_string" ),
            active = ComponentGetValue2( get_storage( controller_id, "slot_pic_active" ), "value_string" ),
            locked = ComponentGetValue2( get_storage( controller_id, "slot_pic_locked" ), "value_string" ),
        },
        sfxes = {
            click = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_click" ), "value_string" )),
            select = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_select" ), "value_string" )),
            hover = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_hover" ), "value_string" )),
            open = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_open" ), "value_string" )),
            close = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_close" ), "value_string" )),
            error = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_error" ), "value_string" )),
            reset = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_reset" ), "value_string" )),
            move_empty = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_move_empty" ), "value_string" )),
            move_item = D_extractor( ComponentGetValue2( get_storage( controller_id, "sfx_move_item" ), "value_string" )),
        },
        
        always_show_full = ComponentGetValue2( get_storage( controller_id, "always_show_full" ), "value_bool" ),
        no_inv_shooting = ComponentGetValue2( get_storage( controller_id, "no_inv_shooting" ), "value_bool" ),
        do_vanilla_dropping = ComponentGetValue2( get_storage( controller_id, "do_vanilla_dropping" ), "value_bool" ),
        no_action_on_drop = ComponentGetValue2( get_storage( controller_id, "no_action_on_drop" ), "value_bool" ),

        max_perks = ComponentGetValue2( get_storage( controller_id, "max_perk_count" ), "value_int" ),
        short_hp = ComponentGetValue2( get_storage( controller_id, "short_hp" ), "value_bool" ),
        short_gold = ComponentGetValue2( get_storage( controller_id, "short_gold" ), "value_bool" ),
        fancy_potion_bar = ComponentGetValue2( get_storage( controller_id, "fancy_potion_bar" ), "value_bool" ),
        reload_threshold = ComponentGetValue2( get_storage( controller_id, "reload_threshold" ), "value_int" ),

        info_pointer = ComponentGetValue2( get_storage( controller_id, "info_pointer" ), "value_bool" ),
        info_pointer_alpha = ComponentGetValue2( get_storage( controller_id, "info_pointer_alpha" ), "value_int" )*0.1,
        info_mtr_hotkeyed = ComponentGetValue2( get_storage( controller_id, "info_mtr_hotkeyed" ), "value_bool" ),
        info_mtr_static = ComponentGetValue2( get_storage( controller_id, "info_mtr_static" ), "value_bool" ),

        mute_applets = ComponentGetValue2( get_storage( controller_id, "mute_applets" ), "value_bool" ),
        no_wand_scaling = ComponentGetValue2( get_storage( controller_id, "no_wand_scaling" ), "value_bool" ),
        allow_tips_always = ComponentGetValue2( get_storage( controller_id, "allow_tips_always" ), "value_bool" ),
        in_world_pickups = ComponentGetValue2( get_storage( controller_id, "in_world_pickups" ), "value_bool" ),
    }
    global_settings.main_dump = global_settings.main_dump or dofile_once( "mods/index_core/files/_structure.lua" )
    
    local main_x, main_y = EntityGetTransform( controller_id )
    local hooman = EntityGetParent( controller_id )
    if( not( EntityGetIsAlive( hooman ))) then
        return
    end
    local hooman_x, hooman_y = EntityGetTransform( hooman )

    local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
    local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
    local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
    local ctrl_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ControlsComponent" )

    local comp_nuker = { iui_comp, pick_comp, }
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
        if( real_gui == nil ) then
            real_gui = GuiCreate()
        end
        GuiStartFrame( real_gui )

        fake_gui = GuiCreate()
        GuiStartFrame( fake_gui )
        font_gui = GuiCreate()
        GuiStartFrame( font_gui )

        local m_x, m_y = DEBUG_GetMouseWorld()
        local md_x, md_y = m_x - ( mouse_memo_world[1] or m_x ), m_y - ( mouse_memo_world[2] or m_y )
        mouse_memo_world = { m_x, m_y }
        local mui_x, mui_y = world2gui( m_x, m_y )
        local muid_x, muid_y = mui_x - ( mouse_memo[1] or mui_x ), mui_y - ( mouse_memo[2] or mui_y )
        mouse_memo = { mui_x, mui_y }

        local mtr_action = not( global_settings.info_mtr_hotkeyed ) or get_input( { 53--[["`"]], "Key" }, "ad_matter_action", true, true )
        local pointer_mtr = 0
        if( mtr_action ) then
            if( not( EntityGetIsAlive( mtr_probe ))) then
                mtr_probe = EntityLoad( "mods/index_core/files/misc/matter_test.xml", m_x, m_y )
            end
        elseif( EntityGetIsAlive( mtr_probe )) then
            EntityKill( mtr_probe )
            mtr_probe = 0
        end
        if( mtr_probe > 0 ) then
            local jitter_mag = 0.5
            EntityApplyTransform( mtr_probe, m_x + jitter_mag*get_sign( math.random(-1,0)), m_y + jitter_mag*get_sign( math.random(-1,0)))
            
            local mtr_list = {}
            local dmg_comp = EntityGetFirstComponentIncludingDisabled( mtr_probe, "DamageModelComponent" )
            local matter = ComponentGetValue2( dmg_comp, "mCollisionMessageMaterials" )
            local count = ComponentGetValue2( dmg_comp, "mCollisionMessageMaterialCountsThisFrame" )
            for i,v in ipairs( count ) do
                if( v > 0 ) then
                    local id = matter[i]
                    mtr_list[id] = ( mtr_list[id] or 0 ) + v
                end
            end
            local max_id = { 0, 0 }
            for id,cnt in pairs( mtr_list ) do
                if( max_id[2] < cnt ) then
                    max_id[1] = id
                    max_id[2] = cnt
                end
            end
            pointer_mtr = max_id[1]
        end
        table.remove( mtr_probe_memo, 1 )
        table.insert( mtr_probe_memo, pointer_mtr )
        local most_mtr, most_mtr_count = get_most_often( mtr_probe_memo )
        pointer_mtr = most_mtr_count > 5 and most_mtr or 0
        
        local epsilon = global_settings.min_effect_duration

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
            
            local simple_effects = {}
            child_play( hooman, function( parent, child, i )
                local effect_comp = EntityGetFirstComponentIncludingDisabled( child, "GameEffectComponent" ) --maybe don't get disabled
                if( effect_comp ~= nil ) then
                    local is_ing = ComponentGetValue2( effect_comp, "caused_by_ingestion_status_effect" )
                    local is_stain = ComponentGetValue2( effect_comp, "caused_by_stains" )
                    local is_core = is_ing or is_stain
                    if( not( is_core )) then
                        local effect = ComponentGetValue2( effect_comp, "effect" )
                        effect = effect == "CUSTOM" and ComponentGetValue2( effect_comp, "custom_effect_id" ) or effect
                        local effect_id = ComponentGetValue2( effect_comp, "causing_status_effect" ) + 1
                        table.insert( simple_effects, { child, effect_comp, effect_id, effect })
                    end
                end
            end)

            do
                local ing_comp = EntityGetFirstComponentIncludingDisabled( hooman, "IngestionComponent" )
                local ing_perc = 0
                if( ing_comp ~= nil ) then
                    local raw_count = ComponentGetValue2( ing_comp, "ingestion_size" )
                    if( raw_count > 0 ) then
                        ing_perc = math.floor( 100*raw_count/ComponentGetValue2( ing_comp, "ingestion_capacity" ) + 0.5 )
                    end
                end
                
                local ing_frame = ComponentGetValue2( status_comp, "ingestion_effects" )
                local ing_matter = ComponentGetValue2( status_comp, "ingestion_effect_causes" )
                local ing_more = ComponentGetValue2( status_comp, "ingestion_effect_causes_many" )
                for i,duration in ipairs( ing_frame ) do
                    local effect_id = i
                    if( duration ~= 0 ) then
                        local effect_info = get_thresholded_effect( from_tbl_with_id( status_effects, { effect_id }, nil, "real_id" ) or {}, duration )
                        local time = get_effect_duration( duration, effect_info, epsilon )
                        if( effect_info.id ~= nil and time ~= 0 ) then
                            local mtr = GameTextGetTranslatedOrNot( CellFactory_GetUIName( ing_matter[effect_id]))
                            mtr = mtr == "" and "???" or mtr

                            local is_many = ing_more[effect_id] == 1
                            local message = GameTextGet( "$ingestion_status_caused_by"..( is_many and "_many" or "" ), mtr )
                            if( ing_perc >= 100 ) then
                                local hardcoded_cancer_fucking_ass_list = {
                                    INGESTION_MOVEMENT_SLOWER = true,
                                    INGESTION_DAMAGE = true,
                                    INGESTION_EXPLODING = true,
                                }
                                if( hardcoded_cancer_fucking_ass_list[ effect_info.id ]) then
                                    if( GameGetGameEffectCount( hooman, "IRON_STOMACH" ) > 0 ) then 
                                        time = 0
                                    else
                                        time = -1
                                        message = GameTextGetTranslatedOrNot( "$ingestion_status_caused_by_overingestion" )
                                    end
                                end
                            end

                            if( time ~= 0 ) then
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
                if( ing_perc > 0 ) then
                    local stomach_tbl = { 25, 90, 100, 140, 150, 175, }
                    local stomach_step = #stomach_tbl
                    for i = 1,#stomach_tbl do
                        if( ing_perc < stomach_tbl[i]) then
                            stomach_step = i-1
                            break
                        end
                    end
                    
                    table.insert( effect_tbl.ings, 1, {
                        pic = "data/ui_gfx/status_indicators/satiation_0"..stomach_step..".png",
                        txt = ing_perc.."%",
                        desc = GameTextGetTranslatedOrNot( "$status_satiated0"..stomach_step ),
                        tip = GameTextGetTranslatedOrNot( "$statusdesc_satiated0"..stomach_step ),
        
                        amount = math.min( ing_perc/100, 1 ),
                        is_danger = ing_perc > 100 and not( GameHasFlagRun( "PERK_PICKED_IRON_STOMACH" )),
                        is_stomach = true,
                        digestion_delay = math.min( math.floor( 10*ComponentGetValue2( ing_comp, "m_ingestion_cooldown_frames" )/ComponentGetValue2( ing_comp, "ingestion_cooldown_delay_frames" ) + 0.5 )/10, 1 ),
                    })
                end

                local stain_percs = ComponentGetValue2( status_comp, "mStainEffectsSmoothedForUI" )
                for i,duration in ipairs( stain_percs ) do
                    local effect_id = i
                    local perc = get_stain_perc( duration )
                    if( perc > 0 ) then
                        local effect_info = get_thresholded_effect( from_tbl_with_id( status_effects, { effect_id }, nil, "real_id" ) or {}, duration )
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
                        if( #simple_effects > 0 and EntityGetParent( child ) == hooman ) then
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

        local dragger_action = get_input( { 2--[["mouse_right"]], "MouseButton" }, "ab_drag_action", true, true )

        local uid = 0
        local pos_tbl = {}
        local screen_w, screen_h = GuiGetScreenDimensions( real_gui )
        local z_layers, global_modes, global_mutators, applets, item_cats, inv = unpack( global_settings.main_dump )
        local data = {
            the_gui = real_gui,
            a_gui = fake_gui,
            some_guis = dead_guis,

            main_id = controller_id,
            player_id = hooman,
            player_xy = {0,0},

            pointer_world = {m_x,m_y},
            pointer_ui = {mui_x,mui_y},
            pointer_delta = {muid_x,muid_y,math.sqrt( muid_x^2 + muid_y^2 )},
            pointer_delta_world = {md_x,md_y,math.sqrt( md_x^2 + md_y^2 )},
            pointer_matter = pointer_mtr,

            shift_action = get_input( { 225--[["left_shift"]], "Key" }, "aa_shift_action", true, true ),
            drag_action = dragger_action,
            tip_action = get_input( { 226--[["left_alt"]], "Key" }, "ac_tip_action", true, true ),
            matter_action = mtr_action,

            is_opened = ComponentGetValue2( iui_comp, "mActive" ),
            inventory = inv_comp,
            inv_count_quickest = global_settings.quickest_size,
            inv_count_quick = ComponentGetValue2( inv_comp, "quick_inventory_slots" ) - global_settings.quickest_size,
            inv_count_full = { ComponentGetValue2( inv_comp, "full_inventory_slots_x" ), ComponentGetValue2( inv_comp, "full_inventory_slots_y" )},

            memo = ctrl_data,
            frame_num = current_frame,
            pixel = "mods/index_core/files/pics/THE_GOD_PIXEL.png",
            nopixel = "mods/index_core/files/pics/THE_NIL_PIXEL.png",
            global_mode = ComponentGetValue2( get_storage( controller_id, "global_mode" ), "value_int" ),

            gmod = {},
            xys = pos_tbl,
            applets = applets,
            slot_func = inv.slot,
            icon_func = inv.icon,
            tip_func = inv.tooltip,
            plate_func = inv.plate,
            wand_func = inv.wand,

            orbs = GameGetOrbCountThisRun(),
            icon_data = effect_tbl,
            perk_data = perk_tbl,

            active_item = get_active_item( hooman ),
            active_info = {},
            just_fired = get_discrete_button( hooman, ctrl_comp, "mButtonDownFire" ),
            no_mana_4life = tonumber( GlobalsGetValue( "INDEX_FUCKYOURMANA", "0" )) == hooman,
            can_tinker = false,
            sampo = 0,

            inventories_player = { get_hooman_child( hooman, "inventory_quick" ), get_hooman_child( hooman, "inventory_full" )},
            inventories = {},
            inventories_init = {},
            inventories_extra = {},
            slot_state = {},
            item_cats = item_cats,
            item_list = {},

            dragger = {
                swap_now = ComponentGetValue2( get_storage( controller_id, "dragger_swap_now" ), "value_bool" ),
                item_id = ComponentGetValue2( get_storage( controller_id, "dragger_item_id" ), "value_int" ),
                inv_type = ComponentGetValue2( get_storage( controller_id, "dragger_inv_type" ), "value_float" ),
                is_quickest = ComponentGetValue2( get_storage( controller_id, "dragger_is_quickest" ), "value_bool" ),
            },

            player_core_off = global_settings.player_core_off,
            throw_pos_rad = global_settings.throw_pos_rad,
            throw_pos_size = global_settings.throw_pos_size,
            throw_force = global_settings.throw_force,

            inv_spacings = global_settings.inv_spacings,
            effect_icon_spacing = global_settings.effect_icon_spacing,
            min_effect_duration = epsilon,
            spell_anim_frames = global_settings.spell_anim_frames,

            hp_threshold = global_settings.hp_threshold,
            hp_threshold_min = global_settings.hp_threshold_min,
            hp_flashing = global_settings.hp_flashing,
            hp_flashing_intensity = global_settings.hp_flashing_intensity,

            info_radius = global_settings.info_radius,
            info_threshold = global_settings.info_threshold,
            info_fading = global_settings.info_fading,

            loot_marker = global_settings.loot_marker,
            slot_pic = global_settings.slot_pic,
            sfxes = global_settings.sfxes,

            always_show_full = global_settings.always_show_full,
            no_inv_shooting = global_settings.no_inv_shooting,
            do_vanilla_dropping = global_settings.do_vanilla_dropping,
            no_action_on_drop = global_settings.no_action_on_drop,

            max_perks = global_settings.max_perks,
            short_hp = global_settings.short_hp,
            short_gold = global_settings.short_gold,
            fancy_potion_bar = global_settings.fancy_potion_bar,
            reload_threshold = global_settings.reload_threshold,

            info_pointer = global_settings.info_pointer,
            info_pointer_alpha = global_settings.info_pointer_alpha,
            info_mtr_hotkeyed = global_settings.info_mtr_hotkeyed,
            info_mtr_static = global_settings.info_mtr_static,

            no_wand_scaling = global_settings.no_wand_scaling,
            allow_tips_always = global_settings.allow_tips_always,
            in_world_pickups = global_settings.in_world_pickups,
            
            Controls = {},
            DamageModel = {},
            CharacterData = {},
            Wallet = {},
            ItemPickUpper = {},
        }

        data.player_xy = { hooman_x, hooman_y + data.player_core_off }
        data.can_tinker = get_tinker_state( data.player_id, data.player_xy[1], data.player_xy[2])
        if( ctrl_comp ~= nil ) then
            data.Controls = {
                ctrl_comp,

                get_button_state( ctrl_comp, "Inventory", current_frame ),
                get_button_state( ctrl_comp, "Interact", current_frame ),
                get_button_state( ctrl_comp, "Fly", current_frame ),
                get_button_state( ctrl_comp, "RightClick", current_frame ),
                get_button_state( ctrl_comp, "LeftClick", current_frame ),
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
        if( pick_comp ~= nil ) then
            data.ItemPickUpper = {
                pick_comp,

                ComponentGetValue2( pick_comp, "pick_up_any_item_buggy" ),
                ComponentGetValue2( pick_comp, "only_pick_this_entity" ),
            }
        end
        
        data.inventories[ data.inventories_player[1]] = get_inv_info( data.inventories_player[1], { data.inv_count_quickest, data.inv_count_quick }, nil, function( inv_info ) return {( inv_info.inv_slot[2] == -2 ) and "quick" or "quickest" } end )
        data.inventories[ data.inventories_player[2]] = get_inv_info( data.inventories_player[2], data.inv_count_full )
        local more_invs = EntityGetWithTag( "index_inventory" ) or {}
        if( #more_invs > 0 ) then
            for k,i in ipairs( more_invs ) do
                data.inventories[i] = get_inv_info( i )
                table.insert( data.inventories_extra, i )
            end
        end
        
        data = get_items( hooman, data )
        if( data.active_item > 0 ) then
            data.active_info = from_tbl_with_id( data.item_list, data.active_item ) or {}
            if( data.active_info.id ~= nil ) then
                local abil_comp = data.active_info.AbilityC
                if( abil_comp ~= nil ) then
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
        
        data.slot_state = {}
        for i,inv_info in pairs( data.inventories ) do
            if( inv_info.kind[1] == "quick" ) then
                data.slot_state[inv_info.id] = {
                    quickest = table_init( inv_info.size[1], false ),
                    quick = table_init( inv_info.size[2], false ),
                }
            else
                data.slot_state[inv_info.id] = table_init( inv_info.size[1], false )
                for i,slot in ipairs( data.slot_state[inv_info.id]) do
                    data.slot_state[inv_info.id][i] = table_init( inv_info.size[2], false )
                end
            end
        end
        
        local nuke_em = {}
        for i,this_info in ipairs( data.item_list ) do
            data.item_list[i] = set_to_slot( this_info, data )
            if( this_info.inv_slot == nil ) then
                table.insert( nuke_em, i )
            end

            local ctrl_func = cat_callback( data, this_info, "ctrl_script" )
            if( ctrl_func ~= nil ) then
                ctrl_func( this_info.id, data, this_info )
            else
                inventory_man( this_info.id, data, this_info, ( this_info.in_hand or 0 ) > 0 )
            end
        end
        if( #nuke_em > 0 ) then
            for i = #nuke_em,1,-1 do
                table.remove( data.item_list, nuke_em[i])
            end
        end
        
        data.gmod = global_modes[ data.global_mode ]
        data.gmod.gmods = global_modes
        data.gmod.name = GameTextGetTranslatedOrNot( data.gmod.name )
        data.gmod.desc = GameTextGetTranslatedOrNot( data.gmod.desc )
        if( not( data.gmod.allow_advanced_draggables )) then
            data.drag_action = false
        end
        for i,mut in ipairs( global_mutators ) do
            data, z_layers, pos_tbl = mut( data, z_layers, pos_tbl )
        end
        if( data.applets.done == nil ) then
            data.applets.done = true

            local close_applets = {
                name = "CLOSE",
                
                pic = function( gui, uid, data, pic_x, pic_y, pic_z, angle )
                    uid = new_image( gui, uid, pic_x - 1, pic_y - 1, pic_z, "data/ui_gfx/status_indicators/neutralized.png", nil, nil, nil, true, angle )
                    local clicked,_,hovered = GuiGetPreviousWidgetInfo( gui )
                    return uid, clicked, hovered
                end,
                toggle = function( data, state )
                    if( state ) then
                        if( data.is_opened ) then
                            data.applets.r_state = false
                            data.memo.applets_r_drift = data.applets_r_drift
                        else
                            data.applets.l_state = false
                            data.memo.applets_l_drift = data.applets_l_drift
                        end
                    end
                end,
            }
            table.insert( data.applets.l, close_applets )
            table.insert( data.applets.r, close_applets )
        end

        local global_callback = data.gmod.custom_func
        if( global_callback ~= nil ) then
            uid, data, inv = global_callback( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl, inv, false )
        end
        if( not( data.gmod.nuke_default )) then
            if( inv.full_inv ~= nil ) then
                uid, data, pos_tbl.inv_root, pos_tbl.full_inv = inv.full_inv( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( inv.applet_strip ~= nil ) then
                uid, data, pos_tbl.applets_l, pos_tbl.applets_r = inv.applet_strip( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            
            local bars = inv.bars or {}
            if( bars.hp ~= nil ) then
                uid, data, pos_tbl.hp = bars.hp( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( bars.air ~= nil ) then
                uid, data, pos_tbl.air = bars.air( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( bars.flight ~= nil ) then
                uid, data, pos_tbl.flight = bars.flight( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( bars.bossbar ~= nil ) then
                uid, data, pos_tbl.bossbar = bars.bossbar( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            
            local actions = bars.action or {}
            if( actions.mana ~= nil ) then
                uid, data, pos_tbl.mana = actions.mana( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( actions.reload ~= nil ) then
                uid, data, pos_tbl.reload = actions.reload( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( actions.delay ~= nil ) then
                uid, data, pos_tbl.delay = actions.delay( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end

            if( inv.gold ~= nil ) then
                uid, data, pos_tbl.gold = inv.gold( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( inv.orbs ~= nil ) then
                uid, data, pos_tbl.orbs = inv.orbs( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( inv.info ~= nil ) then
                uid, data, pos_tbl.info = inv.info( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end

            local icons = inv.icons or {}
            if( icons.ingestions ~= nil ) then
                uid, data, pos_tbl.ingestions = icons.ingestions( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( icons.stains ~= nil ) then
                uid, data, pos_tbl.stains = icons.stains( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( icons.effects ~= nil ) then
                uid, data, pos_tbl.effects = icons.effects( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( icons.perks ~= nil ) then
                uid, data, pos_tbl.perks = icons.perks( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end

            if( inv.pickup ~= nil ) then
                uid, data = inv.pickup( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl, inv.pickup_info )
            end
            if( inv.modder ~= nil ) then
                uid, data = inv.modder( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
            if( inv.extra ~= nil ) then
                uid, data = inv.extra( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
        end
        if( not( data.gmod.nuke_custom )) then
            for cid,cfunc in magic_sorter( inv.custom ) do
                uid, data, pos_tbl[ cid ] = cfunc( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
            end
        end
        if( global_callback ~= nil ) then
            uid, data, inv = global_callback( fake_gui, uid, screen_w, screen_h, data, z_layers, pos_tbl, inv, true )
        end

        if( data.gmod.allow_shooting ) then
            data.no_inv_shooting = false
        end
        if( data.no_inv_shooting and data.is_opened ) then
            uid = new_button( data.the_gui, uid, 0, 0, -999999, "mods/index_core/files/pics/null_fullhd.png" )
        end

        if( data.inv_toggle and not( data.gmod.no_inv_toggle or false )) then
            data.memo.inv_alpha = data.frame_num + 15
            play_sound( data, data.is_opened and "close" or "open" )
            ComponentSetValue2( iui_comp, "mActive", not( data.is_opened ))
        elseif( data.gmod.no_inv_toggle and not( data.is_opened )) then
            ComponentSetValue2( iui_comp, "mActive", true )
        end

        if( data.do_vanilla_dropping ) then
            if( data.dragger.item_id == 0 ) then
                never_drop = false
            elseif( data.gmod.allow_advanced_draggables or never_drop ) then
                data.dragger.wont_drop = true
            elseif( dragger_action and slot_memo[ data.dragger.item_id ]) then
                never_drop = true
            end
        else
            if( not( gonna_drop )) then
                if( not( dragger_action ) or data.gmod.allow_advanced_draggables ) then
                    data.dragger.wont_drop = true
                elseif( dragger_action and slot_memo[ data.dragger.item_id ]) then
                    gonna_drop = true
                end
            elseif( data.dragger.item_id == 0 ) then
                gonna_drop = false
            else
                uid = new_font_vanilla_shadow( fake_gui, uid, data.pointer_ui[1] + 6, data.pointer_ui[2] - 13, z_layers.tips_front, "[DROP]" )
            end
        end

        if( slot_hover_sfx[2]) then
            slot_hover_sfx[2] = false
        elseif( slot_hover_sfx[1] ~= 0 ) then
            slot_hover_sfx[1] = 0
        end
        
        if( slot_going or data.dragger.item_id ~= 0 ) then
            if( data.dragger.swap_soon ) then
                ComponentSetValue2( get_storage( controller_id, "dragger_swap_now" ), "value_bool", true )
            else
                if( not( slot_going ) or data.dragger.swap_now ) then
                    if( data.dragger.swap_now and data.dragger.item_id > 0 ) then
                        local storage_external = get_storage( controller_id, "dragger_done_externally" )
                        if( ComponentGetValue2( storage_external, "value_bool" )) then
                            ComponentSetValue2( storage_external, "value_bool", false )
                        else
                            if( not( data.dragger.wont_drop or false ) and inv.drop ~= nil ) then
                                inv.drop( data.dragger.item_id, data )
                            else
                                play_sound( data, "error" )
                            end
                        end
                    end
                    gonna_drop = false
                    slot_memo = nil
                    data.dragger = {}
                end
                ComponentSetValue2( get_storage( controller_id, "dragger_swap_now" ), "value_bool", false )
                ComponentSetValue2( get_storage( controller_id, "dragger_item_id" ), "value_int", data.dragger.item_id or 0 )
                ComponentSetValue2( get_storage( controller_id, "dragger_inv_type" ), "value_float", data.dragger.inv_type or 0 )
                ComponentSetValue2( get_storage( controller_id, "dragger_is_quickest" ), "value_bool", data.dragger.is_quickest or false )
            end
            slot_going = false
        end
    end
    
    local storage_reset = get_storage( controller_id, "reset_settings" )
    if( ComponentGetValue2( storage_reset, "value_bool" )) then
        ComponentSetValue2( storage_reset, "value_bool", false )
        global_settings = nil
    end
end

if( fake_gui ~= nil ) then
    GuiDestroy( fake_gui )
    GuiDestroy( font_gui )
    if( #dead_guis > 0 ) then
        for i,gui in ipairs( dead_guis ) do
            GuiDestroy( gui )
        end
    end
else
    real_gui = gui_killer( real_gui )
    if( EntityGetIsAlive( mtr_probe )) then
       EntityKill( mtr_probe )
       mtr_probe_memo = nil
    end
end