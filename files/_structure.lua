dofile_once( "mods/index_core/files/_elements.lua" )

local Z_LAYERS = {
    in_world_back = 999,
    in_world = 998,
    in_world_front = 997,
    in_world_ui = 10,
    
    background = 2, --general background

    main_far_back = 1, --slot background
    main_back = 0.01, --bar background
    main = 0, --bars, perks, effects
    main_front = -0.01, --slot highlights

    icons_back = -0.09,
    icons = -1, --inventory item icons
    icons_front = -1.01, --spell charges

    tips_back = -10100,
    tips = -10101, --tooltips duh
    tips_front = -10102,
}

local GLOBAL_MODES = {
    {
        name = "FULL",
        desc = "Wand editing with minimal obstructions.",
        
        is_default = true,
        allow_wand_editing = true,
        show_full = true,
    },
    {
        name = "MANAGEMENT",
        desc = "Complete inventory management capability.",

        allow_external_inventories = true,
        show_full = true,
        show_fullest = true,
    },
    {
        name = "INTERACTIVE",
        desc = "Dragging actions and complete in-world interactivity.",
        
        can_see = true,
        allow_shooting = true,
        allow_advanced_draggables = true,
    },
    {
        name = "CUSTOM_MENU",
        desc = "Completely clears the entire right side and limits interactions.",
        
        menu_capable = true,
        is_hidden = true,
        no_inv_toggle = true,
    },
}

local GLOBAL_MUTATORS = {}
local APPLETS = {
    l_state = true,
    r_state = true,
    l_hover = {},
    r_hover = {},

    l = {},
    r = {
        {
            name = "README", --? menu where all the controls will be described (+ some quick settings and settings refresh button)
            desc = "The complete user guide.",

            pic = function( gui, uid, data, pic_x, pic_y, pic_z, angle )
                uid = new_image( gui, uid, pic_x - 1, pic_y - 1, pic_z, "data/ui_gfx/status_indicators/confusion.png", nil, nil, nil, true, angle )
                local clicked,_,hovered = GuiGetPreviousWidgetInfo( gui )
                return uid, clicked, hovered
            end,
            toggle = function( data, state ) end,
        },
    },
}

local ITEM_CATS = {
    {
        name = GameTextGetTranslatedOrNot( "$item_wand" ),
        is_wand = true,
        is_quickest = true,
        advanced_pic = true,

        on_check = function( item_id )
            local abil_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" )
            return abil_comp ~= nil and ComponentGetValue2( abil_comp, "use_gun_script" )
        end,
        on_data = function( item_id, data, this_info )
            --add wand invs to data.inventories, add an ability to do custom code for this
            --insert spells to item list
            --wand slot count should be slot_count - always_casts
            --charges to upper left (force 0 by making it a string) + marker if the wand can't fire (is empty, not enough mana) for bottom right

            this_info.wand_info = {
                main = {
                    ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "actions_per_round" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "deck_capacity" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "shuffle_deck_when_empty" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "reload_time" ) + ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "reload_time" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "fire_rate_wait" ),

                    ComponentGetValue2( this_info.AbilityC, "mana_max" ),
                    ComponentGetValue2( this_info.AbilityC, "mana_charge_speed" ),
                    ComponentGetValue2( this_info.AbilityC, "mana" ),
                    ComponentGetValue2( this_info.AbilityC, "never_reload" ),
                    math.max( ComponentGetValue2( this_info.AbilityC, "mReloadNextFrameUsable" ) - data.frame_num, 0 ),
                    math.max( ComponentGetValue2( this_info.AbilityC, "mNextFrameUsable" ) - data.frame_num, 0 ),
                },
                misc = {
                    _G[ComponentGetValue2( this_info.AbilityC, "slot_consumption_function" )] or function() return -1 end,

                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "speed_multiplier" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "spread_degrees" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "lifetime_add" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "bounces" ),

                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_critical_chance" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_critical_multiplier" ),

                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_electricity_add" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_explosion_add" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_fire_add" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_melee_add" ),
                    ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_projectile_add" ),
                },
            }
            return data, this_info
        end,

        on_inventory = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, can_drag, is_dragged, in_hand, is_quick, is_full )
            --if is_quick, do em wands
            return uid, data
        end,
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            --use this for in-world tips too
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, clicked, r_clicked, is_hovered, hov_func, action_func, is_full, in_hand, is_usable, is_dragged, hov_scale )
            --do the tooltip (hov_func is the one)
            local w, h = 0,0
            if((( item_pic_data[ this_info.pic ] or {}).xy or {})[3] == nil ) then w, h = get_pic_dim( data.slot_pic.bg ) end
            uid = new_slot_pic( gui, uid, pic_x - w/8, pic_y + h/8, slot_z( data, this_info.id, zs.icons ), this_info.pic, 1, math.rad( -45 ), hov_scale, true )
            return uid--, true
        end,
        
        on_pickup = function( item_id, data, this_info, is_post )
            local func_tbl = {
                function( item_id, data, this_info )
                    return 0
                end,
                function( item_id, data, this_info )
                    if( not( ComponentGetValue2( this_info.ItemC, "has_been_picked_by_player" ))) then
                        EntityLoad( "data/entities/particles/image_emitters/wand_effect.xml", unpack( this_info.xy ))
                        ComponentSetValue2( this_info.ItemC, "play_spinning_animation", true )
                    end
                end,
            }
            return func_tbl[ is_post and 2 or 1 ]( item_id, data, this_info )
        end,

        on_gui_world = function( gui, uid, item_id, data, this_info, zs, pic_x, pic_y, no_space, cant_buy )
            return uid
        end,
        -- on_gui_pause = function( gui, uid, item_id, data, this_info, zs ) --(if no noitapatcher, drop to 20 frames - off by default)
        --     return uid
        -- end,
        on_info_name = function( item_id, item_comp, default_name )
            local name = get_item_name( item_id, item_comp, EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" ))
            return name == "" and default_name or name
        end,
    },
    {
        name = GameTextGetTranslatedOrNot( "$item_potion" ),
        is_potion = true,

        on_check = function( item_id )
            return not( EntityHasTag( item_id, "not_a_potion" )) and EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" ) ~= nil
        end,
        on_data = function( item_id, data, this_info )
            local matter_comp = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" )
            this_info.MatterC = matter_comp
            this_info.matter_info = {
                ComponentGetValue2( matter_comp, "max_capacity" ),
                { get_matters( ComponentGetValue2( matter_comp, "count_per_material_type" ))},
                ComponentGetValue2( this_info.ItemC, "drinkable" ),
            }

            local sucker_comp = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialSuckerComponent" )
            if( sucker_comp ~= nil ) then
                this_info.SuckerC = sucker_comp
                this_info.bottle_info = {
                    ComponentGetValue2( sucker_comp, "barrel_size" ),
                    ComponentGetValue2( sucker_comp, "num_cells_sucked_per_frame" ),
                    ComponentGetValue2( sucker_comp, "material_type" ),
                    ComponentGetValue2( sucker_comp, "suck_tag" ),
                    ComponentGetValue2( sucker_comp, "suck_static_materials" ),
                }
            end
            this_info.matter_info[1] = this_info.bottle_info == nil and this_info.matter_info[1] or this_info.bottle_info[1]

            local loop_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AudioLoopComponent" )
            if( loop_comp ~= nil ) then
                this_info.SprayC = loop_comp
                this_info.spray_info = {
                    ComponentGetValue2( loop_comp, "file" ),
                    ComponentGetValue2( loop_comp, "event_name" ),
                }
            end

            this_info.name, this_info.fullness = get_potion_info( item_id, this_info.name, this_info.matter_info[1], math.max( this_info.matter_info[2][1], 0 ), this_info.matter_info[2][2])
            if( this_info.matter_info[1] < 0 ) then this_info.matter_info[1] = this_info.matter_info[2][1] end

            return data, this_info
        end,
        
        on_inventory = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, can_drag, is_dragged, in_hand, is_quick, is_full )
            local cap_max = this_info.matter_info[1]
            local mtrs = this_info.matter_info[2]
            local content_total = mtrs[1]
            local content_tbl = mtrs[2]
            
            local w, h = get_pic_dim( data.slot_pic.bg )
            if( content_total == 0 ) then
                uid = new_image( gui, uid, pic_x + 2, pic_y + 2, zs.icons_front, "mods/index_core/files/pics/vanilla_no_cards.xml" )
            end
            
            if( not( is_full )) then
                pic_x, pic_y = pic_x + w/2, pic_y + h/2
                w, h = w - 4, h - 4
                pic_x, pic_y = pic_x - w/2, pic_y + h/2

                local k = h/cap_max
                local size = k*math.min( content_total, cap_max )
                local alpha = is_dragged and 0.7 or 0.9
                local delta = 0
                for i,m in ipairs( content_tbl ) do
                    local sz = math.ceil( 2*math.max( math.min( k*m[2], h ), 0.5 ))/2
                    colourer( gui, get_matter_colour( CellFactory_GetName( m[1])))
                    delta = delta + sz
                    uid = new_image( gui, uid, pic_x, pic_y - math.min( delta, h ), zs.main + tonumber( "0.001"..i ), data.pixel, w, sz, alpha )
                    if( delta >= h ) then
                        break
                    end
                end
                if(( h - delta ) > 0.5 and math.min( content_total/cap_max, 1 ) > 0 ) then
                    uid = new_image( gui, uid, pic_x, pic_y - ( delta + 0.5 ), zs.main + 0.001, data.pixel, w, 0.5 )
                end
            end

            return uid, data
        end,
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, clicked, r_clicked, is_hovered, hov_func, action_func, is_full, in_hand, is_usable, is_dragged, hov_scale )
            local cap_max = this_info.matter_info[1]
            local content_total = this_info.matter_info[2][1]

            local nuke_it, target_angle = true, 0
            if( action_func ~= nil ) then
                if( is_dragged ) then
                    if( data.drag_action ) then
                        nuke_it, target_angle = unpack( action_func( item_id, data, this_info, 3 ))
                    end
                elseif( r_clicked and data.is_opened and is_usable ) then
                    action_func( item_id, data, this_info, 2 )
                end
            end
            if( not( nuke_it )) then
                if( item_pic_data[ this_info.pic ].memo_xy == nil ) then
                    item_pic_data[ this_info.pic ].memo_xy = item_pic_data[ this_info.pic ].xy
                    item_pic_data[ this_info.pic ].xy = { item_pic_data[ this_info.pic ].dims[1]/2, -2 }
                    data.memo.sucking_drift = ( data.memo.sucking_drift or 0 ) - ( item_pic_data[ this_info.pic ].dims[2]/2 + 2 )
                end
            else
                if( item_pic_data[ this_info.pic ].memo_xy ~= nil ) then
                    data.memo.sucking_drift = ( data.memo.sucking_drift or 0 ) + ( item_pic_data[ this_info.pic ].dims[2]/2 + 2 )
                    item_pic_data[ this_info.pic ].xy = item_pic_data[ this_info.pic ].memo_xy
                    item_pic_data[ this_info.pic ].memo_xy = nil
                end
                if( data.dragger.item_id == 0 or data.dragger.item_id == item_id ) then
                    if( EntityGetIsAlive( data.memo.john_pouring or 0 )) then
                        EntityKill( data.memo.john_pouring )
                        data.memo.john_pouring = nil
                    end
                end
            end
            
            local angle = 0
            if( is_dragged ) then
                angle = math.rad( simple_anim( data, "pouring_angle", target_angle, 0.2 ))
                pic_y = pic_y + simple_anim( data, "sucking_drift", 0, 0.2 )
            end
            
            local z = slot_z( data, this_info.id, zs.icons )
            local ratio = math.min( content_total/cap_max, 1 )
            uid, pic_x, pic_y = new_slot_pic( gui, uid, pic_x, pic_y, z, this_info.pic, 0.8 - 0.5*ratio, angle, hov_scale )
            colourer( gui, uint2color( GameGetPotionColorUint( this_info.id )))
            uid = new_image( gui, uid, pic_x, pic_y, z - 0.001, this_info.pic, hov_scale, hov_scale, nil, nil, angle )
            
            return uid, true, true
        end,

        on_pickup = function( item_id, data, this_info, is_post )
            local func_tbl = {
                function( item_id, data, this_info ) return 0 end,
                function( item_id, data, this_info )
                    if( not( ComponentGetValue2( this_info.ItemC, "has_been_picked_by_player" ))) then
                        local emitter = EntityLoad( "data/entities/particles/image_emitters/potion_effect.xml", unpack( this_info.xy ))
                        ComponentGetValue2( EntityGetFirstComponentIncludingDisabled( emitter, "ParticleEmitterComponent" ), "emitted_material_name", CellFactory_GetName( this_info.matter_info[2][2][1][1]))
                    end
                end,
            }
            return func_tbl[ is_post and 2 or 1 ]( item_id, data, this_info )
        end,
        on_action = function( item_id, data, this_info, type )
            local func_tbl = {
                function( item_id, data, this_info ) end,
                function( item_id, data, this_info )
                    if( this_info.matter_info[3] ) then
                        if( this_info.matter_info[2][1] > 0 ) then
                            play_sound( data, { "data/audio/Desktop/misc.bank", "misc/potion_drink" })
                            chugger_3000( data.player_id, this_info.id, this_info.matter_info[1], this_info.matter_info[2][2], data.shift_action and 1 or 0.1 )
                        else
                            play_sound( data, { "data/audio/Desktop/misc.bank", "misc/potion_drink_empty" })
                        end
                    end
                end,
                function( item_id, data, this_info )
                    local out = { true, 0 }

                    local x, y = unpack( data.player_xy )
                    local p_x, p_y = unpack( data.pointer_world )
                    if( not( RaytraceSurfaces( x, y, p_x, p_y ))) then
                        if( not( EntityGetIsAlive( data.memo.john_pouring or 0 ))) then
                            data.memo.john_pouring = EntityLoad( "mods/index_core/files/misc/potion_nerd.xml", x, y )
                            if( this_info.spray_info ~= nil ) then
                                local loop_comp = EntityGetFirstComponentIncludingDisabled( data.memo.john_pouring, "AudioLoopComponent" )
                                ComponentSetValue2( loop_comp, "file", this_info.spray_info[1])
                                ComponentSetValue2( loop_comp, "event_name", this_info.spray_info[2])
                            end
                        end
                        EntitySetTransform( data.memo.john_pouring, p_x, p_y )

                        local cap_max = this_info.matter_info[1]
                        local content_total = this_info.matter_info[2][1]
                        if( data.shift_action ) then
                            out[1] = false
                            out[2] = 45 + 90*( 1 - math.min( content_total/cap_max, 1 ))
                            
                            if( content_total > 0 ) then
                                GameEntityPlaySoundLoop( data.memo.john_pouring, "spray", 1 )
                                if( data.frame_num%5 == 0 ) then
                                    chugger_3000( data.pointer_world, this_info.id, cap_max, this_info.matter_info[2][2])
                                end
                            end
                        elseif( this_info.bottle_info ~= nil ) then
                            out[1] = false

                            local sucker_comp = EntityGetFirstComponentIncludingDisabled( data.memo.john_pouring, "MaterialSuckerComponent" )
                            if( EntityGetName( data.memo.john_pouring ) ~= "done" ) then
                                EntitySetName( data.memo.john_pouring, "done" )
                                ComponentSetValue2( sucker_comp, "barrel_size", this_info.bottle_info[1])
                                ComponentSetValue2( sucker_comp, "num_cells_sucked_per_frame", this_info.bottle_info[2])
                                ComponentSetValue2( sucker_comp, "material_type", this_info.bottle_info[3])
                                ComponentSetValue2( sucker_comp, "suck_tag", this_info.bottle_info[4])
                                ComponentSetValue2( sucker_comp, "suck_static_materials", this_info.bottle_info[5])
                            end

                            local do_sound = false
                            local mtr_comp = EntityGetFirstComponentIncludingDisabled( data.memo.john_pouring, "MaterialInventoryComponent" )
                            if( ComponentGetIsEnabled( mtr_comp )) then
                                local total, mttrs = get_matters( ComponentGetValue2( mtr_comp, "count_per_material_type" ))
                                if( total > 0 ) then
                                    for i,mtr in ipairs( mttrs ) do
                                        if( mtr[2] > 0 ) then
                                            local name = CellFactory_GetName( mtr[1])
                                            if( content_total < cap_max ) then
                                                local temp = math.min( content_total + mtr[2], cap_max )
                                                local count = temp - content_total
                                                content_total = temp

                                                local _,pre_mtr = from_tbl_with_id( this_info.matter_info[2][2], mtr[1])
                                                pre_mtr = this_info.matter_info[2][2][ pre_mtr or -1 ] or {0,0}
                                                AddMaterialInventoryMaterial( item_id, name, pre_mtr[2] + count )
                                                
                                                do_sound = true
                                            end
                                            AddMaterialInventoryMaterial( data.memo.john_pouring, name, 0 )
                                        end
                                    end
                                end
                                this_info.matter_info[2][1] = content_total
                            end
                            EntitySetComponentIsEnabled( data.memo.john_pouring, sucker_comp, content_total < cap_max )
                            if( do_sound and data.frame_num%5 == 0 ) then
                                if( this_info.bottle_info[3] == 0 ) then
                                    play_sound( data, { "data/audio/Desktop/materials.bank", "collision/glass_potion/liquid_container_hit" }, p_x, p_y )
                                elseif( this_info.bottle_info[3] == 1 ) then
                                    play_sound( data, { "data/audio/Desktop/materials.bank", "collision/snow" }, p_x, p_y )
                                end
                            end
                        end
                    end

                    return out
                end,
            }
            return func_tbl[ type ]( item_id, data, this_info )
        end,

        on_info_name = function( item_id, item_comp, default_name )
            local matter_comp = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" )
            local barrel_size = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialSuckerComponent" )
            barrel_size = barrel_size == nil and ComponentGetValue2( matter_comp, "max_capacity" ) or ComponentGetValue2( barrel_size, "barrel_size" )
            
            local name, cap = get_potion_info( item_id, get_item_name( item_comp, item_comp ), barrel_size, get_matters( ComponentGetValue2( matter_comp, "count_per_material_type" )))
            return name..( cap or "" )
        end,
    },
    {
        name = string.sub( string.lower( GameTextGetTranslatedOrNot( "$hud_title_actionstorage" )), 1, -2 ),
        is_spell = true,

        on_check = function( item_id )
            return EntityHasTag( item_id, "card_action" ) or EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" ) ~= nil
        end,
        on_data = function( item_id, data, this_info )
            local action_comp = EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" )
            this_info.ActionC = action_comp
            this_info.spell_id = ComponentGetValue2( action_comp, "action_id" )
            
            --pull the info from spell table

            return data, this_info
        end,
        on_processed = function( item_id, data, this_info )
            local pic_comp = EntityGetFirstComponentIncludingDisabled( item_id, "SpriteComponent", "item_unidentified" )
            if( pic_comp ~= nil ) then EntityRemoveComponent( item_id, pic_comp ) end
        end,
        
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, clicked, r_clicked, is_hovered, hov_func, action_func, is_full, in_hand, is_usable, is_dragged, hov_scale )
            return uid
        end,
    },
    {
        name = "tablet",

        on_check = function( item_id )
            return EntityGetFirstComponentIncludingDisabled( item_id, "BookComponent" ) ~= nil
        end,
        
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, clicked, r_clicked, is_hovered, hov_func, action_func, is_full, in_hand, is_usable, is_dragged, hov_scale )
            uid = new_slot_pic( gui, uid, pic_x, pic_y, slot_z( data, this_info.id, zs.icons ), this_info.pic, nil, nil, hov_scale )
            return uid, true
        end,

        on_info_name = function( item_id, item_comp, default_name )
            local name = get_item_name( item_id, item_comp )
            return name == "" and default_name or name
        end,
    },
    {
        name = GameTextGetTranslatedOrNot( "$mat_item_box2d" ),

        on_check = function( item_id )
            return true
        end,
        
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, clicked, r_clicked, is_hovered, hov_func, action_func, is_full, in_hand, is_usable, is_dragged, hov_scale )
            uid = new_slot_pic( gui, uid, pic_x, pic_y, slot_z( data, this_info.id, zs.icons ), this_info.pic, nil, nil, hov_scale )
            return uid
        end,

        on_info_name = function( item_id, item_comp, default_name )
            local name = get_item_name( item_id, item_comp )
            return name == "" and default_name or name
        end,
    },
}

local GUI_STRUCT = {
    slot = new_vanilla_slot,
    icon = new_vanilla_icon,
    tooltip = new_vanilla_tooltip,
    plate = new_vanilla_plate,

    full_inv = new_generic_inventory,
    modder = new_generic_modder,
    applet_strip = new_generic_applets,
    
    bars = {
        hp = new_generic_hp,
        air = new_generic_air,
        flight = new_generic_flight,
        action = {
            mana = new_generic_mana,
            reload = new_generic_reload,
            delay = new_generic_delay,
        },
    },

    gold = new_generic_gold,
    orbs = new_generic_orbs,
    info = new_generic_info,
    
    icons = {
        ingestions = new_generic_ingestions,
        stains = new_generic_stains,
        effects = new_generic_effects,
        perks = new_generic_perks,
    },

    pickup = new_generic_pickup,
    pickup_info = new_pickup_info,
    drop = new_generic_drop,

    extra = new_generic_extra,
    custom = {
        aa_readme = function( gui, uid, screen_w, screen_h, data, zs, xys )
            --? menu where all the controls will be described (+ some quick settings and settings refresh button; put README menu in custom)
            return uid, data, {0,0}
        end,
    },
}

--<{> MAGICAL APPEND MARKER <}>--

return { Z_LAYERS, GLOBAL_MODES, GLOBAL_MUTATORS, APPLETS, ITEM_CATS, GUI_STRUCT }