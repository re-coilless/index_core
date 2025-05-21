dofile_once( "mods/index_core/files/_elements.lua" )

local GLOBAL_MODES = {
    {
        name = "FULL",
        desc = "Wand editing with minimal obstructions.",
        is_default = true, allow_wand_editing = true, show_full = true,
        show_fullest = pen.c.index_settings.force_vanilla_fullest,
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
    l_state = not( pen.c.index_settings.mute_applets ), l_hover = {},
    r_state = not( pen.c.index_settings.mute_applets ), r_hover = {},

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
            return pen.vld( abil_comp, true ) and ComponentGetValue2( abil_comp, "use_gun_script" )
        end,
        on_info_name = function( item_id, item_comp, default_name )
            local name = index.get_entity_name( item_id, item_comp, EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" ))
            return pen.vld( name ) and name or default_name
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
                reload_time = ComponentObjectGetValue2( info.AbilityC, "gun_config", "reload_time" ) +
                                ComponentObjectGetValue2( info.AbilityC, "gunaction_config", "reload_time" ),
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
            
            local check_func = function( item_info, inv_info ) return item_info.is_spell or false end
            local update_func = function( inv_info, info_old, info_new ) return ( inv_info.in_hand or 0 ) > 0 end
            local sort_func = function( a, b )
                local is_perma, inv_slot = { false, false }, { 0, 0 }
                pen.t.loop({ a, b }, function( i,v )
                    local item_comp = EntityGetFirstComponentIncludingDisabled( v, "ItemComponent" )
                    if( not( pen.vld( item_comp, true ))) then return end
                    is_perma[i] = ComponentGetValue2( item_comp, "permanently_attached" )
                    inv_slot[i] = math.max( ComponentGetValue2( item_comp, "inventory_slot" ), 0 )
                end)
                return ( is_perma[1] and not( is_perma[2])) or ( not( is_perma[2]) and inv_slot[1] < inv_slot[2])
            end
            
            index.D.invs_i[ info.id ] = index.get_inv_info(
                info.id, { info.wand_info.deck_capacity, 1 }, { "full" }, nil, check_func, update_func, nil, sort_func )
            
            return info
        end,
        on_processed_forced = function( info )
            local children = EntityGetAllChildren( info.id )
            if( not( pen.vld( children ))) then return end

            table.sort( children, function( a, b )
                local inv_slot = { 0, 0 }
                pen.t.loop({ a, b }, function( i,v )
                    local item_comp = EntityGetFirstComponentIncludingDisabled( v, "ItemComponent" )
                    if( not( pen.vld( item_comp, true ))) then return end
                    inv_slot[i] = math.max( ComponentGetValue2( item_comp, "inventory_slot" ), 0 )
                end)
                return inv_slot[1] < inv_slot[2]
            end)
            
            local got_normal = false
            if( not( pen.t.loop( children, function( i, child )
                local item_comp = EntityGetFirstComponentIncludingDisabled( child, "ItemComponent" )
                if( not( pen.vld( item_comp, true ))) then return end

                if( got_normal ) then
                    if( ComponentGetValue2( item_comp, "permanently_attached" )) then return true end
                else got_normal = not( ComponentGetValue2( item_comp, "permanently_attached" )) end
            end))) then return end

            pen.t.loop( children, function( i, child )
                local item_comp = EntityGetFirstComponentIncludingDisabled( child, "ItemComponent" )
                if( not( pen.vld( item_comp, true ))) then return end
                ComponentSetValue2( item_comp, "inventory_slot", ComponentGetValue2( item_comp, "inventory_slot" ), -5 )
            end)
        end,

        on_inventory = function( info, pic_x, pic_y, state_tbl )
            if( not( index.D.gmod.allow_wand_editing )) then return end
            if( not( state_tbl.is_quick )) then return end
            if( not( index.D.is_opened )) then return end

            pic_x, pic_y = unpack( pen.vld( index.D.wand_inventory ) and index.D.wand_inventory or index.D.xys.full_inv )
            w, h = index.D.wand_func( pic_x + 2*pen.b2n( state_tbl.in_hand ), pic_y, info, state_tbl.in_hand )
            index.D.wand_inventory = { pic_x, pic_y + h }
        end,
        on_tooltip = index.new_vanilla_wtt,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale )
            local w, h = pen.get_pic_dims( index.D.slot_pic.bg )
            index.new_slot_pic( pic_x - w/8, pic_y + h/8,
                index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, true, hov_scale, true )
            
            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                hov_func( info, "wtt"..info.id, pic_x - 10, pic_y + 5, pen.LAYERS.TIPS ) end
            if( info.wand_info.actions_per_round > 0 and info.charges < 0 ) then
                info.charges = 0

                local was_there = false
                local slot_data = index.D.slot_state[ info.id ]
                for i,col in ipairs( slot_data ) do
                    pen.t.loop( col, function( e, slot )
                        if( not( slot )) then return end
                        local slot_info = pen.t.get( index.D.item_list, slot, nil, nil, {})
                        if( not( slot_info.is_spell )) then return end

                        if( slot_info.charges > 0 ) then
                            info.charges = slot_info.charges; return true
                        elseif( info.charges == 0 and slot_info.charges < 0 ) then
                            local is_mod = slot_info.spell_info.type == 2
                            local is_many = slot_info.spell_info.type == 3
                            if( not( is_mod ) and not( is_many )) then info.charges = -1 end
                        end

                        if( not( was_there )) then was_there = slot_info.charges == 0 end
                    end)

                    if( info.charges > 0 ) then break end
                end

                if( info.charges == 0 and was_there ) then info.charges = 0.1 end
            end

            return info
        end,
        
        on_pickup = function( info, is_post )
            return ({
                function( info ) return 0 end,
                function( info )
                    if( ComponentGetValue2( info.ItemC, "has_been_picked_by_player" )) then return end
                    EntityLoad( "data/entities/particles/image_emitters/wand_effect.xml", unpack( info.xy ))
                    ComponentSetValue2( info.ItemC, "play_spinning_animation", true )
                end,
            })[ is_post and 2 or 1 ]( info )
        end,

        on_gui_world = index.new_vanilla_worldtip,
        -- on_gui_pause = function( info ) --should know if is picked or not
        --     return
        -- end,
    },
    {
        name = GameTextGetTranslatedOrNot( "$item_potion" ),
        is_potion = true,

        on_check = function( item_id )
            if( EntityHasTag( item_id, "not_a_potion" )) then return false end
            return pen.vld( EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" ), true )
        end,
        on_info_name = function( item_id, item_comp, default_name )
            local matter_comp = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" )
            local barrel_size = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialSuckerComponent" )
            barrel_size = pen.vld( barrel_size ) and
                ComponentGetValue2( barrel_size, "barrel_size" ) or ComponentGetValue2( matter_comp, "max_capacity" )
            
            local cap = ""
            local name = index.get_entity_name( item_id, item_comp )
            if( pen.vld( EntityGetFirstComponentIncludingDisabled( item_id, "PotionComponent" ), true )) then
                local v, m = pen.get_matter( ComponentGetValue2( matter_comp, "count_per_material_type" ))
                name, cap = index.get_potion_info( item_id, name, v, barrel_size, m )
            end
            return name..( cap or "" )
        end,
        on_data = function( info, item_list_wip )
            info.is_true_potion = pen.vld( EntityGetFirstComponentIncludingDisabled( info.id, "PotionComponent" ), true )

            info.MatterC = EntityGetFirstComponentIncludingDisabled( info.id, "MaterialInventoryComponent" )
            info.matter_info = {
                may_drink = ComponentGetValue2( info.ItemC, "drinkable" ),
                volume = ComponentGetValue2( info.MatterC, "max_capacity" ),
                matter = { pen.get_matter( ComponentGetValue2( info.MatterC, "count_per_material_type" ))},
            }

            info.SuckerC = EntityGetFirstComponentIncludingDisabled( info.id, "MaterialSuckerComponent" )
            if( pen.vld( info.SuckerC, true )) then
                info.bottle_info = {
                    tag = ComponentGetValue2( info.SuckerC, "suck_tag" ),
                    type = ComponentGetValue2( info.SuckerC, "material_type" ),
                    capacity = ComponentGetValue2( info.SuckerC, "barrel_size" ),
                    speed = ComponentGetValue2( info.SuckerC, "num_cells_sucked_per_frame" ),
                    may_static = ComponentGetValue2( info.SuckerC, "suck_static_materials" )}
                
                info.matter_info.volume = info.bottle_info.capacity
            else info.SuckerC = nil end
            
            info.SprayC = EntityGetFirstComponentIncludingDisabled( item_id, "AudioLoopComponent" )
            if( pen.vld( info.SprayC, true )) then
                info.spray_info = {
                    ComponentGetValue2( info.SprayC, "file" ),
                    ComponentGetValue2( info.SprayC, "event_name" )}
            else info.SprayC = nil end

            if( info.is_true_potion ) then
                info.name, info.fullness = index.get_potion_info(
                    info.id, info.raw_name, math.max( info.matter_info.matter[1], 0 ), info.matter_info.volume, info.matter_info.matter[2]) end
            if( info.matter_info.volume < 0 ) then info.matter_info.volume = info.matter_info.matter[1] end
            
            info.potion_cutout = pen.magic_storage( info.id, "potion_cutout", "value_int" )
            info.potion_cutout = info.potion_cutout or ( 3 - pen.b2n( info.matter_info.volume < info.matter_info.matter[1]))
            
            return info
        end,
        
        on_inventory = function( info, pic_x, pic_y, state_tbl )
            local w, h = pen.get_pic_dims( index.D.slot_pic.bg )
            if( state_tbl.is_full ) then return end

            pic_x, pic_y = pic_x + w/2, pic_y + h/2
            w, h = w - 4, h - 4
            pic_x, pic_y = pic_x - w/2, pic_y + h/2

            local k = h/info.matter_info.volume
            local alpha, delta = state_tbl.is_dragged and 0.7 or 0.9, 0
            local size = k*math.min( info.matter_info.matter[1], info.matter_info.volume )
            for i,m in ipairs( info.matter_info.matter[2]) do
                local sz = math.ceil( 2*math.max( math.min( k*m[2], h ), 0.5 ))/2; delta = delta + sz
                pen.new_pixel( pic_x, pic_y - math.min( delta, h ),
                    pen.LAYERS.MAIN + tonumber( "0.001"..i ), pen.get_color_matter( CellFactory_GetName( m[1])), w, sz, alpha )
                if( delta >= h ) then break end
            end

            if(( h - delta ) > 0.5 and math.min( info.matter_info.matter[1]/info.matter_info.volume, 1 ) > 0 ) then
                pen.new_pixel( pic_x, pic_y - ( delta + 0.5 ), pen.LAYERS.MAIN + 0.001, pen.PALETTE.W, w, 0.5 )
            end
        end,
        on_tooltip = index.new_vanilla_ptt,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale )
            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                hov_func( info, nil, pic_x - 10, pic_y + 10, pen.LAYERS.TIPS ) end
            if( info.matter_info.matter[1] == 0 ) then info.charges = 0 end
            
            local nuke_it = true
            local target_angle = 0
            if( state_tbl.is_dragged ) then
                if( pen.vld( drag_func ) and index.D.drag_action ) then nuke_it, target_angle = unpack( drag_func( info )) end
            elseif( pen.vld( rmb_func ) and state_tbl.is_rmb and index.D.is_opened and state_tbl.is_quick ) then rmb_func( info ) end

            local pic_data = pen.cache({ "index_pic_data", info.pic })
            if( not( nuke_it )) then
                if( pen.vld( pic_data.memo_xy )) then
                    pic_data.memo_xy = pic_data.xy; pic_data.xy = { pic_data.dims[1]/2, -2 }
                    index.M.sucking_drift = ( index.M.sucking_drift or 0 ) - ( pic_data.dims[2]/2 + 2 )
                end
            else
                if( pen.vld( pic_data.memo_xy )) then
                    index.M.sucking_drift = ( index.M.sucking_drift or 0 ) + ( pic_data.dims[2]/2 + 2 )
                    pic_data.xy = pic_data.memo_xy; pic_data.memo_xy = nil
                end
                if( not( pen.vld( index.D.dragger.item_id, true )) or index.D.dragger.item_id == info.id ) then
                    if( EntityGetIsAlive( index.M.john_pouring or 0 )) then
                        EntityKill( index.M.john_pouring ); index.M.john_pouring = nil
                    end
                end
            end
            
            local angle = 0
            if( state_tbl.is_dragged ) then
                angle = math.rad( pen.estimate( "pouring_angle", target_angle, "exp5", 1 ))
                pic_y = pic_y + pen.estimate( "sucking_drift", 0, "exp5", 1 )
            end
            
            local z = index.slot_z( info.id, pen.LAYERS.ICONS )
            local ratio = math.min( info.matter_info.matter[1]/info.matter_info.volume, 1 )
            pic_x, pic_y = index.new_slot_pic( pic_x, pic_y, z, info.pic, false, hov_scale, false, 0.8 - 0.5*ratio, angle )
            pen.new_image( pic_x, pic_y, z - 0.001, info.pic,
                { color = pen.magic_uint( GameGetPotionColorUint( info.id )), s_x = hov_scale, s_y = hov_scale, angle = angle })
            
            return info, info.matter_info.matter[1] ~= 0, true
        end,

        on_action = function( type )
            return ({
                function( info )
                    if( not( info.matter_info.may_drink )) then return end

                    if( info.matter_info.matter[1] > 0 ) then
                        index.play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink" })
                        pen.magic_chugger( info.matter_info.matter[2], index.D.player_id,
                            info.id, info.matter_info.volume, index.D.shift_action and 1 or 0.1 )
                    else index.play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink_empty" }) end
                end,
                function( info )
                    local out = { true, 0 }

                    local x, y = unpack( index.D.player_xy )
                    local p_x, p_y = unpack( index.D.pointer_world )
                    if( RaytraceSurfaces( x, y, p_x, p_y )) then return out end

                    if( not( EntityGetIsAlive( index.M.john_pouring or 0 ))) then
                        index.M.john_pouring = EntityLoad( "mods/index_core/files/misc/potion_nerd.xml", x, y )
                        if( pen.vld( info.spray_info )) then
                            local loop_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "AudioLoopComponent" )
                            ComponentSetValue2( loop_comp, "file", info.spray_info[1])
                            ComponentSetValue2( loop_comp, "event_name", info.spray_info[2])
                        end
                    end
                    EntitySetTransform( index.M.john_pouring, p_x, p_y )

                    local volume = info.matter_info.volume
                    local matter = info.matter_info.matter
                    if( index.D.shift_action ) then
                        out[1], out[2] = false, 45 + 90*( 1 - math.min( matter[1]/volume, 1 ))
                        
                        if( matter[1] == 0 ) then return out end
                        GameEntityPlaySoundLoop( index.M.john_pouring, "spray", 1 )
                        if( index.D.frame_num%5 == 0 ) then pen.magic_chugger( matter[2], index.D.pointer_world, info.id, volume ) end
                    elseif( pen.vld( info.bottle_info )) then
                        out[1] = false

                        local sucker_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "MaterialSuckerComponent" )
                        if( EntityGetName( index.M.john_pouring ) ~= "done" ) then
                            EntitySetName( index.M.john_pouring, "done" )
                            ComponentSetValue2( sucker_comp, "suck_tag", info.bottle_info.tag )
                            ComponentSetValue2( sucker_comp, "material_type", info.bottle_info.type )
                            ComponentSetValue2( sucker_comp, "barrel_size", info.bottle_info.capacity )
                            ComponentSetValue2( sucker_comp, "num_cells_sucked_per_frame", info.bottle_info.speed )
                            ComponentSetValue2( sucker_comp, "suck_static_materials", info.bottle_info.may_static )
                        end

                        local do_sound = false
                        local mtr_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "MaterialInventoryComponent" )
                        pen.hallway( function()
                            if( not( ComponentGetIsEnabled( mtr_comp ))) then return end
                            local total, mttrs = pen.get_matter( ComponentGetValue2( mtr_comp, "count_per_material_type" ))
                            if( total == 0 ) then return end

                            pen.t.loop( mttrs, function( i,m )
                                if( m[2] == 0 ) then return end
                                local name = CellFactory_GetName( mttrs[1])
                                if( matter[1] < volume ) then
                                    local temp = math.min( matter[1] + m[2], volume )
                                    local count = temp - matter[1]; matter[1] = temp
                                    local _,pm = pen.t.get( matter[2], m[1])

                                    do_sound, pm = true, matter[2][ pm or -1 ] or { 0, 0 }
                                    AddMaterialInventoryMaterial( info.id, name, pm[2] + count )
                                end
                                AddMaterialInventoryMaterial( index.M.john_pouring, name, 0 )
                            end)

                            info.matter_info.matter[1] = matter[1]
                        end)
                        
                        EntitySetComponentIsEnabled( index.M.john_pouring, sucker_comp, matter[1] < volume )
                        if( not( do_sound and index.D.frame_num%5 == 0 )) then return out end
                        
                        if( info.bottle_info.type == 0 ) then
                            index.play_sound({ "data/audio/Desktop/materials.bank", "collision/glass_potion/liquid_container_hit" }, p_x, p_y )
                        elseif( info.bottle_info.type == 1 ) then
                            index.play_sound({ "data/audio/Desktop/materials.bank", "collision/snow" }, p_x, p_y )
                        end
                    end

                    return out
                end,
            })[ type ]
        end,
        on_pickup = function( info, is_post )
            return ({
                function( info ) return 0 end,
                function( info )
                    if( info.matter_info.matter[1] == 0 ) then return end
                    if( ComponentGetValue2( info.ItemC, "has_been_picked_by_player" )) then return end
                    local emitter = EntityLoad( "data/entities/particles/image_emitters/potion_effect.xml", unpack( info.xy ))
                    local emit_comp = EntityGetFirstComponentIncludingDisabled( emitter, "ParticleEmitterComponent" )
                    ComponentGetValue2( emit_comp, "emitted_material_name", CellFactory_GetName( info.matter_info.matter[2][1][1]))
                end,
            })[ is_post and 2 or 1 ]( info )
        end,

        on_gui_world = index.new_vanilla_worldtip,
    },
    {
        name = string.sub( string.lower( GameTextGetTranslatedOrNot( "$hud_title_actionstorage" )), 1, -2 ),
        is_spell = true,

        on_check = function( item_id )
            if( EntityHasTag( item_id, "card_action" )) then return true end
            return pen.vld( EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" ), true )
        end,
        on_data = function( info, item_list_wip )
            if( info.is_permanent ) then info.charges = -1 end

            info.ActionC = EntityGetFirstComponentIncludingDisabled( info.id, "ItemActionComponent" )

            info.spell_id = ComponentGetValue2( info.ActionC, "action_id" )
            info.spell_info = pen.get_spell_data( info.spell_id )
            info.pic = info.spell_info.sprite
            
            info.tip_name = pen.capitalizer( GameTextGetTranslatedOrNot( info.spell_info.name ))
            info.name = info.tip_name..( info.charges >= 0 and " ("..info.charges..")" or "" )
            info.desc = index.full_stopper( GameTextGetTranslatedOrNot( info.spell_info.description ))
            info.tip_name = string.upper( info.tip_name )
            
            local parent_id = EntityGetParent( info.id )
            if( pen.vld( parent_id, true ) and pen.vld( index.D.invs[ parent_id ])) then
                parent_id = pen.t.get( item_list_wip, parent_id, nil, nil, {})
                if( parent_id.is_wand ) then info.in_wand = parent_id.id end
            end

            local may_use = pen.vld( info.AbilityC, true )
            may_use = may_use and GameGetGameEffectCount( index.D.player_id, "ABILITY_ACTIONS_MATERIALIZED" ) > 0
            may_use = may_use and ComponentGetValue2( info.AbilityC, "use_entity_file_as_projectile_info_proxy" )
            if( may_use ) then info.inv_cat = 0 end
            return info
        end,
        on_processed = function( info )
            local pic_comp = EntityGetFirstComponentIncludingDisabled( info.id, "SpriteComponent", "item_unidentified" )
            if( pen.vld( pic_comp, true )) then EntityRemoveComponent( info.id, pic_comp ) end
        end,

        on_inv_check = function( info, inv_info )
            return pen.t.get( inv_info.kind, "quickest" ) == 0
        end,
        on_inv_swap = function( info, slot_data )
            if( index.D.active_item == info.id ) then pen.reset_active_item( index.D.player_id ) end
        end,
        on_tooltip = index.new_vanilla_stt,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale )
            local angle, anim_speed = 0, index.D.spell_anim_frames
            local is_considered = state_tbl.is_dragged or state_tbl.is_hov
            if( state_tbl.can_drag ) then
                angle = -math.rad( 5 )
                if( not( is_considered )) then
                    angle = anim_speed == 0 and 0 or angle*math.sin(( index.D.frame_num%anim_speed )*math.pi/anim_speed )
                else angle = 1.5*angle end
            end

            local pic_z = index.slot_z( info.id, pen.LAYERS.ICONS )
            index.new_slot_pic( pic_x, pic_y, pic_z, info.pic, false, hov_scale, false, nil, angle )
            if( is_considered ) then pen.colourer( nil, pen.PALETTE.VNL.DARK_SLOT ) end
            new_spell_frame( pic_x, pic_y,
                pen.LAYERS.ICONS + ( is_considered and 0.001 or -0.005 ), info.spell_info.type, is_considered and 1 or 0.6, angle )

            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( info, nil, pic_x, pic_y, pen.LAYERS.TIPS )
            end

            return info
        end,

        on_gui_world = index.new_vanilla_worldtip,
    },
    {
        name = "tablet",

        on_check = function( item_id )
            return pen.vld( EntityGetFirstComponentIncludingDisabled( item_id, "BookComponent" ), true )
        end,
        
        on_tooltip = index.new_vanilla_ttt,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, false, hov_scale )
            
            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( info, nil, pic_x, pic_y, pen.LAYERS.TIPS )
            end

            return info, true
        end,

        on_gui_world = index.new_vanilla_worldtip,
    },
    {
        name = GameTextGetTranslatedOrNot( "$mat_item_box2d" ),

        on_check = function( item_id ) return true end,
        on_data = function( info, item_list_wip )
            if( not( EntityHasTag( info.id, "this_is_sampo" ))) then return info end
            if( EntityGetRootEntity( info.id ) == index.D.player_id ) then index.D.sampo = info.id end
            info.inv_cat = 0
            return info
        end,
        
        on_tooltip = index.new_vanilla_itt,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, false, hov_scale )

            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( info, nil, pic_x, pic_y, pen.LAYERS.TIPS )
            end
            
            return info
        end,

        on_pickup = function( info, is_post )
            return ({
                function( info )
                    if( pen.vld( EntityGetFirstComponentIncludingDisabled( info.id, "OrbComponent" ), true )) then
                        index.vanilla_pick_up( index.D.player_id, info.id )
                    else return 0 end
                end,
                function() end,
            })[ is_post and 2 or 1 ]( info )
        end,

        on_gui_world = index.new_vanilla_worldtip,
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