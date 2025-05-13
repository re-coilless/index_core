dofile_once( "mods/index_core/files/_elements.lua" )

local GLOBAL_MODES = {
    {
        name = "FULL",
        desc = "Wand editing with minimal obstructions.",
        is_default = true, allow_wand_editing = true, show_full = true,
        show_fullest = index.G.settings.force_vanilla_fullest,
    },
    {
        name = "MANAGEMENT",
        desc = "Complete inventory management capability.",
        allow_external_inventories = true, show_full = true, show_fullest = true,
    },
    {
        name = "INTERACTIVE",
        desc = "Dragging actions and complete in-world interactivity.",
        can_see = true, allow_shooting = true, allow_advanced_draggables = true,
    },
    {
        name = "CUSTOM_MENU",
        desc = "Completely clears the entire right side and limits interactions.",
        menu_capable = true, is_hidden = true, no_inv_toggle = true,
    },
}

local GLOBAL_MUTATORS, APPLETS = {}, {
    l_state = not( index.G.settings.mute_applets ), l_hover = {},
    r_state = not( index.G.settings.mute_applets ), r_hover = {},

    l = {},
    r = {
        {
            name = "README",
            desc = "The complete user guide.",
            pic = "data/ui_gfx/status_indicators/confusion.png",
            toggle = function( state ) end,
        },
    },
}

local ITEM_CATS = {
    {
        name = GameTextGetTranslatedOrNot( "$item_wand" ),
        is_wand = true,
        is_quickest = true,
        do_full_man = true,

        on_check = function( item_id )
            local abil_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" )
            return abil_comp ~= nil and ComponentGetValue2( abil_comp, "use_gun_script" )
        end,
        on_info_name = function( item_id, item_comp, default_name )
            local name = index.get_entity_name( item_id, item_comp, EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" ))
            return name == "" and default_name or name
        end,
        on_data = function( info, item_list_wip )
            info.wand_info = {
                shuffle_deck_when_empty = ComponentObjectGetValue2( info.AbilityC, "gun_config", "shuffle_deck_when_empty" ),
                actions_per_round = ComponentObjectGetValue2( info.AbilityC, "gun_config", "actions_per_round" ),
                deck_capacity = ComponentObjectGetValue2( info.AbilityC, "gun_config", "deck_capacity" ),
                spread_degrees = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "spread_degrees" ),
                mana_max = ComponentGetValue2( info.AbilityC, "mana_max" ),
                mana_charge_speed = ComponentGetValue2( info.AbilityC, "mana_charge_speed" ),
                mana = ComponentGetValue2( info.AbilityC, "mana" ),

                never_reload = ComponentGetValue2( info.AbilityC, "never_reload" ),
                reload_time = ComponentObjectGetValue2( info.AbilityC, "gun_config", "reload_time" ) + ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "reload_time" ),
                delay_time = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "fire_rate_wait" ),
                reload_frame = math.max( ComponentGetValue2( info.AbilityC, "mReloadNextFrameUsable" ) - index.D.frame_num, 0 ),
                delay_frame = math.max( ComponentGetValue2( info.AbilityC, "mNextFrameUsable" ) - index.D.frame_num, 0 ),

                speed_multiplier = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "speed_multiplier" ),
                lifetime_add = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "lifetime_add" ),
                bounces = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "bounces" ),

                crit_chance = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "damage_critical_chance" ),
                crit_mult = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "damage_critical_multiplier" ),

                damage_electricity_add = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "damage_electricity_add" ),
                damage_explosion_add = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "damage_explosion_add" ),
                damage_fire_add = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "damage_fire_add" ),
                damage_melee_add = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "damage_melee_add" ),
                damage_projectile_add = ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "damage_projectile_add" ),
            }
            
            index.D.invs_i[ info.id ] = index.get_inv_info( info.id, { info.wand_info.deck_capacity, 1 }, { "full" }, nil, function( item_info, inv_info ) return item_info.is_spell or false end, function( inv_info, info_old, info_new ) return ( inv_info.in_hand or 0 ) > 0 end, nil, function( a, b )
                local is_perma, inv_slot = {false,false}, {0,0}
                for k = 1,2 do
                    local item_comp = EntityGetFirstComponentIncludingDisabled( k == 1 and a or b, "ItemComponent" )
                    if( item_comp ~= nil ) then
                        is_perma[k] = ComponentGetValue2( item_comp, "permanently_attached" )
                        inv_slot[k] = math.max( ComponentGetValue2( item_comp, "inventory_slot" ), 0 )
                    end
                end
                return ( is_perma[1] and not( is_perma[2])) or ( not( is_perma[2]) and inv_slot[1] < inv_slot[2])
            end)
            
            return info
        end,
        on_processed_forced = function( info )
            local children = EntityGetAllChildren( info.id ) or {}
            if( #children > 0 ) then
                table.sort( children, function( a, b )
                    local inv_slot = {0,0}
                    for k = 1,2 do
                        local item_comp = EntityGetFirstComponentIncludingDisabled( k == 1 and a or b, "ItemComponent" )
                        if( item_comp ~= nil ) then
                            inv_slot[k] = math.max( ComponentGetValue2( item_comp, "inventory_slot" ), 0 )
                        end
                    end
                    return inv_slot[1] < inv_slot[2]
                end)
                
                local got_normal, it_is_time = false, false
                for i,child in ipairs( children ) do
                    local item_comp = EntityGetFirstComponentIncludingDisabled( child, "ItemComponent" )
                    if( item_comp ~= nil ) then
                        if( got_normal ) then
                            if( ComponentGetValue2( item_comp, "permanently_attached" )) then
                                it_is_time = true
                                break
                            end
                        else
                            got_normal = not( ComponentGetValue2( item_comp, "permanently_attached" ))
                        end
                    end
                end

                if( it_is_time ) then
                    for i,child in ipairs( children ) do
                        local item_comp = EntityGetFirstComponentIncludingDisabled( child, "ItemComponent" )
                        if( item_comp ~= nil ) then
                            ComponentSetValue2( item_comp, "inventory_slot", ComponentGetValue2( item_comp, "inventory_slot" ), -5 )
                        end
                    end
                end
            end
        end,

        on_inventory = function( info, pic_x, pic_y, john_bool )
            if( index.D.gmod.allow_wand_editing and john_bool.is_quick and index.D.is_opened ) then
                pic_x, pic_y = unpack( index.D.wand_inventory == nil and index.D.xys.full_inv or index.D.wand_inventory )
                w, h = index.D.wand_func( pic_x + 2*pen.b2n( john_bool.in_hand ), pic_y, info, john_bool.in_hand )
                index.D.wand_inventory = { pic_x, pic_y + h }
            end
        end,
        on_tooltip = new_vanilla_wtt,
        on_slot = function( info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            local w, h = 0,0
            if((( pen.cache({ "index_pic_data", info.pic }) or {}).xy or {})[3] == nil ) then
                w, h = pen.get_pic_dims( index.D.slot_pic.bg ) end
            index.new_slot_pic( pic_x - w/8, pic_y + h/8,
                index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, 1, math.rad( -45 ), hov_scale, true )
            
            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                hov_func( info, nil, pic_x - 10, pic_y + 10, pen.LAYERS.TIPS )
            end
            
            if( info.wand_info.actions_per_round > 0 and info.charges < 0 ) then
                info.charges = 0

                local slot_data, was_there = index.D.slot_state[ info.id ], false
                for i,col in ipairs( slot_data ) do
                    for e,slot in ipairs( col ) do
                        if( slot ) then
                            local slot_info = pen.t.get( index.D.item_list, slot, nil, nil, {})
                            if( slot_info.is_spell ) then
                                if( slot_info.charges > 0 ) then
                                    info.charges = slot_info.charges
                                    break
                                elseif( info.charges == 0 and slot_info.charges < 0 ) then
                                    if( slot_info.spell_info.type ~= 2 and slot_info.spell_info.type ~= 3 ) then
                                        info.charges = -1
                                    end
                                end
                                if( not( was_there )) then was_there = slot_info.charges == 0 end
                            end
                        end
                    end
                    if( info.charges > 0 ) then break end
                end

                if( info.charges == 0 and was_there ) then
                    info.charges = 0.1
                end
            end

            return info
        end,
        
        on_pickup = function( info, is_post )
            local func_tbl = {
                function( info )
                    return 0
                end,
                function( info )
                    if( not( ComponentGetValue2( info.ItemC, "has_been_picked_by_player" ))) then
                        EntityLoad( "data/entities/particles/image_emitters/wand_effect.xml", unpack( info.xy ))
                        ComponentSetValue2( info.ItemC, "play_spinning_animation", true )
                    end
                end,
            }
            return func_tbl[ is_post and 2 or 1 ]( info )
        end,

        on_gui_world = new_vanilla_worldtip,
        -- on_gui_pause = function( info ) --should know the state (if is picked or not)
        --     return
        -- end,
    },
    {
        name = GameTextGetTranslatedOrNot( "$item_potion" ),
        is_potion = true,

        on_check = function( item_id )
            return not( EntityHasTag( item_id, "not_a_potion" )) and EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" ) ~= nil
        end,
        on_info_name = function( item_id, item_comp, default_name )
            local matter_comp = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" )
            local barrel_size = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialSuckerComponent" )
            barrel_size = barrel_size == nil and ComponentGetValue2( matter_comp, "max_capacity" ) or ComponentGetValue2( barrel_size, "barrel_size" )
            
            local v1, v2 = index.get_entity_name( item_id, item_comp )
            local name, cap = v1, ""
            if( EntityGetFirstComponentIncludingDisabled( item_id, "PotionComponent" ) ~= nil ) then
                name, cap = index.get_potion_info( item_id, v1, pen.get_matter( ComponentGetValue2( matter_comp, "count_per_material_type" )), barrel_size )
            end
            return name..( cap or "" )
        end,
        on_data = function( info, item_list_wip )
            info.is_true_potion = EntityGetFirstComponentIncludingDisabled( info.id, "PotionComponent" ) ~= nil

            local matter_comp = EntityGetFirstComponentIncludingDisabled( info.id, "MaterialInventoryComponent" )
            info.MatterC = matter_comp
            info.matter_info = {
                ComponentGetValue2( matter_comp, "max_capacity" ),
                { pen.get_matter( ComponentGetValue2( matter_comp, "count_per_material_type" ))},
                ComponentGetValue2( info.ItemC, "drinkable" ),
            }

            local sucker_comp = EntityGetFirstComponentIncludingDisabled( info.id, "MaterialSuckerComponent" )
            if( sucker_comp ~= nil ) then
                info.SuckerC = sucker_comp
                info.bottle_info = {
                    ComponentGetValue2( sucker_comp, "barrel_size" ),
                    ComponentGetValue2( sucker_comp, "num_cells_sucked_per_frame" ),
                    ComponentGetValue2( sucker_comp, "material_type" ),
                    ComponentGetValue2( sucker_comp, "suck_tag" ),
                    ComponentGetValue2( sucker_comp, "suck_static_materials" ),
                }
            end
            info.matter_info[1] = info.bottle_info == nil and info.matter_info[1] or info.bottle_info[1]

            local loop_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AudioLoopComponent" )
            if( loop_comp ~= nil ) then
                info.SprayC = loop_comp
                info.spray_info = {
                    ComponentGetValue2( loop_comp, "file" ),
                    ComponentGetValue2( loop_comp, "event_name" ),
                }
            end

            if( info.is_true_potion ) then
                info.name, info.fullness = index.get_potion_info(
                    info.id, info.raw_name, math.max( info.matter_info[2][1], 0 ), info.matter_info[1], info.matter_info[2][2])
            end
            if( info.matter_info[1] < 0 ) then info.matter_info[1] = info.matter_info[2][1] end
            
            info.potion_cutout = pen.magic_storage( info.id, "potion_cutout", "value_int" )
            info.potion_cutout = info.potion_cutout or ( 3 - pen.b2n( info.matter_info[1] < info.matter_info[2][1]))

            return info
        end,
        
        on_inventory = function( info, pic_x, pic_y, john_bool )
            local cap_max = info.matter_info[1]
            local mtrs = info.matter_info[2]
            local content_total = mtrs[1]
            local content_tbl = mtrs[2]
            
            local w, h = pen.get_pic_dims( index.D.slot_pic.bg )
            if( not( john_bool.is_full )) then
                pic_x, pic_y = pic_x + w/2, pic_y + h/2
                w, h = w - 4, h - 4
                pic_x, pic_y = pic_x - w/2, pic_y + h/2

                local k = h/cap_max
                local size = k*math.min( content_total, cap_max )
                local alpha = john_bool.is_dragged and 0.7 or 0.9
                local delta = 0
                for i,m in ipairs( content_tbl ) do
                    local sz = math.ceil( 2*math.max( math.min( k*m[2], h ), 0.5 ))/2; delta = delta + sz
                    pen.new_pixel( pic_x, pic_y - math.min( delta, h ),
                        pen.LAYERS.MAIN + tonumber( "0.001"..i ), pen.get_color_matter( CellFactory_GetName( m[1])), w, sz, alpha )
                    if( delta >= h ) then break end
                end
                if(( h - delta ) > 0.5 and math.min( content_total/cap_max, 1 ) > 0 ) then
                    pen.new_pixel( pic_x, pic_y - ( delta + 0.5 ), pen.LAYERS.MAIN + 0.001, pen.PALETTE.W, w, 0.5 )
                end
            end
        end,
        on_tooltip = new_vanilla_ptt,
        on_slot = function( info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                hov_func( info, nil, pic_x - 10, pic_y + 10, pen.LAYERS.TIPS )
            end

            local cap_max = info.matter_info[1]
            local content_total = info.matter_info[2][1]
            if( content_total == 0 ) then info.charges = 0 end

            local nuke_it, target_angle = true, 0
            if( john_bool.is_dragged ) then
                if( drag_func ~= nil and index.D.drag_action ) then
                    nuke_it, target_angle = unpack( drag_func( info ))
                end
            elseif( rmb_func ~= nil and john_bool.is_rmb and index.D.is_opened and john_bool.is_quick ) then
                rmb_func( info )
            end

            local pic_data = pen.cache({ "index_pic_data", info.pic })
            if( not( nuke_it )) then
                if( pic_data.memo_xy == nil ) then
                    pic_data.memo_xy = pic_data.xy
                    pic_data.xy = { pic_data.dims[1]/2, -2 }
                    index.M.sucking_drift = ( index.M.sucking_drift or 0 ) - ( pic_data.dims[2]/2 + 2 )
                end
            else
                if( pic_data.memo_xy ~= nil ) then
                    index.M.sucking_drift = ( index.M.sucking_drift or 0 ) + ( pic_data.dims[2]/2 + 2 )
                    pic_data.xy = pic_data.memo_xy
                    pic_data.memo_xy = nil
                end
                if( index.D.dragger.item_id == 0 or index.D.dragger.item_id == info.id ) then
                    if( EntityGetIsAlive( index.M.john_pouring or 0 )) then
                        EntityKill( index.M.john_pouring )
                        index.M.john_pouring = nil
                    end
                end
            end
            
            local angle = 0
            if( john_bool.is_dragged ) then
                angle = math.rad( pen.estimate( "pouring_angle", target_angle, 0.2 ))
                pic_y = pic_y + pen.estimate( "sucking_drift", 0, 0.2 )
            end
            
            local z = index.slot_z( info.id, pen.LAYERS.ICONS )
            local ratio = math.min( content_total/cap_max, 1 )
            pic_x, pic_y = index.new_slot_pic( pic_x, pic_y, z, info.pic, 0.8 - 0.5*ratio, angle, hov_scale )
            pen.new_image( pic_x, pic_y, z - 0.001, info.pic,
                { color = pen.magic_uint( GameGetPotionColorUint( info.id )), s_x = hov_scale, s_y = hov_scale, angle = angle })
            
            return info, content_total ~= 0, true
        end,

        on_action = function( type )
            local func_tbl = {
                [1] = function( info )
                    if( info.matter_info[3]) then
                        if( info.matter_info[2][1] > 0 ) then
                            index.play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink" })
                            pen.magic_chugger( info.matter_info[2][2],
                                index.D.player_id, info.id, info.matter_info[2][1], index.D.shift_action and 1 or 0.1 )
                        else index.play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink_empty" }) end
                    end
                end,
                [2] = function( info )
                    local out = { true, 0 }

                    local x, y = unpack( index.D.player_xy )
                    local p_x, p_y = unpack( index.D.pointer_world )
                    if( not( RaytraceSurfaces( x, y, p_x, p_y ))) then
                        if( not( EntityGetIsAlive( index.M.john_pouring or 0 ))) then
                            index.M.john_pouring = EntityLoad( "mods/index_core/files/misc/potion_nerd.xml", x, y )
                            if( info.spray_info ~= nil ) then
                                local loop_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "AudioLoopComponent" )
                                ComponentSetValue2( loop_comp, "file", info.spray_info[1])
                                ComponentSetValue2( loop_comp, "event_name", info.spray_info[2])
                            end
                        end
                        EntitySetTransform( index.M.john_pouring, p_x, p_y )

                        local cap_max = info.matter_info[1]
                        local content_total = info.matter_info[2][1]
                        if( index.D.shift_action ) then
                            out[1] = false
                            out[2] = 45 + 90*( 1 - math.min( content_total/cap_max, 1 ))
                            
                            if( content_total > 0 ) then
                                GameEntityPlaySoundLoop( index.M.john_pouring, "spray", 1 )
                                if( index.D.frame_num%5 == 0 ) then
                                    pen.magic_chugger( info.matter_info[2][2], index.D.pointer_world, info.id, cap_max )
                                end
                            end
                        elseif( info.bottle_info ~= nil ) then
                            out[1] = false

                            local sucker_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "MaterialSuckerComponent" )
                            if( EntityGetName( index.M.john_pouring ) ~= "done" ) then
                                EntitySetName( index.M.john_pouring, "done" )
                                ComponentSetValue2( sucker_comp, "barrel_size", info.bottle_info[1])
                                ComponentSetValue2( sucker_comp, "num_cells_sucked_per_frame", info.bottle_info[2])
                                ComponentSetValue2( sucker_comp, "material_type", info.bottle_info[3])
                                ComponentSetValue2( sucker_comp, "suck_tag", info.bottle_info[4])
                                ComponentSetValue2( sucker_comp, "suck_static_materials", info.bottle_info[5])
                            end

                            local do_sound = false
                            local mtr_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "MaterialInventoryComponent" )
                            if( ComponentGetIsEnabled( mtr_comp )) then
                                local total, mttrs = pen.get_matter( ComponentGetValue2( mtr_comp, "count_per_material_type" ))
                                if( total > 0 ) then
                                    for i,mtr in ipairs( mttrs ) do
                                        if( mtr[2] > 0 ) then
                                            local name = CellFactory_GetName( mtr[1])
                                            if( content_total < cap_max ) then
                                                local temp = math.min( content_total + mtr[2], cap_max )
                                                local count = temp - content_total
                                                content_total = temp

                                                local _,pre_mtr = pen.t.get( info.matter_info[2][2], mtr[1])
                                                pre_mtr = info.matter_info[2][2][ pre_mtr or -1 ] or {0,0}
                                                AddMaterialInventoryMaterial( info.id, name, pre_mtr[2] + count )
                                                
                                                do_sound = true
                                            end
                                            AddMaterialInventoryMaterial( index.M.john_pouring, name, 0 )
                                        end
                                    end
                                end
                                info.matter_info[2][1] = content_total
                            end
                            EntitySetComponentIsEnabled( index.M.john_pouring, sucker_comp, content_total < cap_max )
                            if( do_sound and index.D.frame_num%5 == 0 ) then
                                if( info.bottle_info[3] == 0 ) then
                                    index.play_sound(
                                        { "data/audio/Desktop/materials.bank", "collision/glass_potion/liquid_container_hit" }, p_x, p_y )
                                elseif( info.bottle_info[3] == 1 ) then
                                    index.play_sound({ "data/audio/Desktop/materials.bank", "collision/snow" }, p_x, p_y )
                                end
                            end
                        end
                    end

                    return out
                end,
            }
            return func_tbl[ type ]
        end,
        on_pickup = function( info, is_post )
            local func_tbl = {
                function( info ) return 0 end,
                function( info )
                    if( not( ComponentGetValue2( info.ItemC, "has_been_picked_by_player" ))) then
                        local emitter = EntityLoad( "data/entities/particles/image_emitters/potion_effect.xml", unpack( info.xy ))
                        ComponentGetValue2( EntityGetFirstComponentIncludingDisabled( emitter, "ParticleEmitterComponent" ), "emitted_material_name", CellFactory_GetName( info.matter_info[2][2][1][1]))
                    end
                end,
            }
            return func_tbl[ is_post and 2 or 1 ]( info )
        end,

        on_gui_world = new_vanilla_worldtip,
    },
    {
        name = string.sub( string.lower( GameTextGetTranslatedOrNot( "$hud_title_actionstorage" )), 1, -2 ),
        is_spell = true,

        on_check = function( item_id )
            return EntityHasTag( item_id, "card_action" ) or EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" ) ~= nil
        end,
        on_data = function( info, item_list_wip )
            if( info.is_permanent ) then info.charges = -1 end

            local action_comp = EntityGetFirstComponentIncludingDisabled( info.id, "ItemActionComponent" )
            info.ActionC = action_comp

            local spell_id = ComponentGetValue2( action_comp, "action_id" )
            info.spell_info = pen.get_spell_data( spell_id )
            info.pic = info.spell_info.sprite
            info.spell_id = spell_id
            
            info.tip_name = pen.capitalizer( GameTextGetTranslatedOrNot( info.spell_info.name ))
            info.name = info.tip_name..( info.charges >= 0 and " ("..info.charges..")" or "" )
            info.tip_name = string.upper( info.tip_name )
            info.desc = index.full_stopper( GameTextGetTranslatedOrNot( info.spell_info.description ))
            
            local parent_id = EntityGetParent( info.id )
            if( parent_id > 0 and index.D.invs[ parent_id ] ~= nil ) then
                parent_id = pen.t.get( item_list_wip, parent_id, nil, nil, {})
                if( parent_id.is_wand ) then info.in_wand = parent_id.id end
            end

            if( GameGetGameEffectCount( index.D.player_id, "ABILITY_ACTIONS_MATERIALIZED" ) > 0 ) then
                if( info.AbilityC ~= nil and ComponentGetValue2( info.AbilityC, "use_entity_file_as_projectile_info_proxy" )) then
                    info.inv_cat = 0
                end
            end

            return info
        end,
        on_processed = function( info )
            local pic_comp = EntityGetFirstComponentIncludingDisabled( info.id, "SpriteComponent", "item_unidentified" )
            if( pic_comp ~= nil ) then EntityRemoveComponent( info.id, pic_comp ) end
        end,

        on_inv_check = function( info, inv_info )
            return pen.t.get( inv_info.kind, "quickest" ) == 0
        end,
        on_inv_swap = function( info, slot_data )
            if( index.D.active_item == info.id ) then
                pen.reset_active_item( index.D.player_id )
            end
        end,
        on_tooltip = new_vanilla_stt,
        on_slot = function( info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            local angle, is_considered, anim_speed = 0, john_bool.is_dragged or john_bool.is_hov, index.D.spell_anim_frames
            if( john_bool.can_drag ) then
                angle = -math.rad( 5 )*( is_considered and 1.5 or ( anim_speed == 0 and 0 or math.sin(( index.D.frame_num%anim_speed )*math.pi/anim_speed )))
            end
            local pic_z = index.slot_z( info.id, pen.LAYERS.ICONS )
            index.new_slot_pic( pic_x, pic_y, pic_z, info.pic, nil, angle, hov_scale )
            if( is_considered ) then pen.colourer( nil, {185,220,223}) end
            new_spell_frame( pic_x, pic_y,
                pen.LAYERS.ICONS + ( is_considered and 0.001 or -0.005 ), info.spell_info.type, is_considered and 1 or 0.6, angle )

            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( info, nil, pic_x, pic_y, pen.LAYERS.TIPS )
            end

            return info
        end,

        on_gui_world = new_vanilla_worldtip,
    },
    {
        name = "tablet",

        on_check = function( item_id )
            return EntityGetFirstComponentIncludingDisabled( item_id, "BookComponent" ) ~= nil
        end,
        
        on_tooltip = new_vanilla_ttt,
        on_slot = function( info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, nil, nil, hov_scale )
            
            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( info, nil, pic_x, pic_y, pen.LAYERS.TIPS )
            end

            return info, true
        end,

        on_gui_world = new_vanilla_worldtip,
    },
    {
        name = GameTextGetTranslatedOrNot( "$mat_item_box2d" ),

        on_check = function( item_id )
            return true
        end,
        on_data = function( info, item_list_wip )
            if( EntityHasTag( info.id, "this_is_sampo" )) then
                info.inv_cat = 0

                if( EntityGetRootEntity( info.id ) == index.D.player_id ) then
                    index.D.sampo = info.id
                end
            end
            return info
        end,
        
        on_tooltip = new_vanilla_itt,
        on_slot = function( info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, nil, nil, hov_scale )

            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( info, nil, pic_x, pic_y, pen.LAYERS.TIPS )
            end
            
            return info
        end,

        on_pickup = function( info, is_post )
            local func_tbl = {
                function( info )
                    if( pen.vld( EntityGetFirstComponentIncludingDisabled( info.id, "OrbComponent" ), true )) then
                        index.vanilla_pick_up( index.D.player_id, info.id )
                    else return 0 end
                end,
                function() end,
            }
            return func_tbl[ is_post and 2 or 1 ]( info )
        end,

        on_gui_world = new_vanilla_worldtip,
    },
}

local GUI_STRUCT = {
    slot = index.new_vanilla_slot,
    icon = index.new_vanilla_icon,
    tooltip = pen.new_tooltip,
    box = index.new_vanilla_box,
    wand = index.new_vanilla_wand,

    full_inv = index.new_generic_inventory,
    modder = index.new_generic_modder,
    applet_strip = index.new_generic_applets,
    
    bars = {
        hp = index.new_generic_hp,
        air = index.new_generic_air,
        flight = index.new_generic_flight,
        bossbar = index.new_generic_bossbar,
        action = {
            mana = index.new_generic_mana,
            reload = index.new_generic_reload,
            delay = index.new_generic_delay,
        },
    },

    gold = index.new_generic_gold,
    orbs = index.new_generic_orbs,
    info = index.new_generic_info,
    
    icons = {
        ingestions = index.new_generic_ingestions,
        stains = index.new_generic_stains,
        effects = index.new_generic_effects,
        perks = index.new_generic_perks,
    },

    pickup = index.new_generic_pickup,
    pickup_info = index.new_pickup_info,
    drop = index.new_generic_drop,

    extra = index.new_generic_extra,
    custom = {
        aa_readme = function( screen_w, screen_h, xys )
            --? menu where all the controls will be described (+ some quick settings and settings refresh button; put README menu in custom)
            return { 0, 0 }
        end,
    },
}

--<{> MAGICAL APPEND MARKER <}>--

return { GLOBAL_MODES, GLOBAL_MUTATORS, APPLETS, ITEM_CATS, GUI_STRUCT }