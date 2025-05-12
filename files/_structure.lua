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
        advanced_pic = true,

        on_check = function( item_id )
            local abil_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" )
            return abil_comp ~= nil and ComponentGetValue2( abil_comp, "use_gun_script" )
        end,
        on_info_name = function( item_id, item_comp, default_name )
            local name = index.get_entity_name( item_id, item_comp, EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" ))
            return name == "" and default_name or name
        end,
        on_data = function( item_id, this_info, item_list_wip )
            this_info.wand_info = {
                shuffle_deck_when_empty = ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "shuffle_deck_when_empty" ),
                actions_per_round = ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "actions_per_round" ),
                deck_capacity = ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "deck_capacity" ),
                spread_degrees = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "spread_degrees" ),
                mana_max = ComponentGetValue2( this_info.AbilityC, "mana_max" ),
                mana_charge_speed = ComponentGetValue2( this_info.AbilityC, "mana_charge_speed" ),
                mana = ComponentGetValue2( this_info.AbilityC, "mana" ),

                never_reload = ComponentGetValue2( this_info.AbilityC, "never_reload" ),
                reload_time = ComponentObjectGetValue2( this_info.AbilityC, "gun_config", "reload_time" ) + ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "reload_time" ),
                delay_time = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "fire_rate_wait" ),
                reload_frame = math.max( ComponentGetValue2( this_info.AbilityC, "mReloadNextFrameUsable" ) - index.D.frame_num, 0 ),
                delay_frame = math.max( ComponentGetValue2( this_info.AbilityC, "mNextFrameUsable" ) - index.D.frame_num, 0 ),

                speed_multiplier = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "speed_multiplier" ),
                lifetime_add = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "lifetime_add" ),
                bounces = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "bounces" ),

                crit_chance = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_critical_chance" ),
                crit_mult = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_critical_multiplier" ),

                damage_electricity_add = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_electricity_add" ),
                damage_explosion_add = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_explosion_add" ),
                damage_fire_add = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_fire_add" ),
                damage_melee_add = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_melee_add" ),
                damage_projectile_add = ComponentObjectGetValue2( this_info.AbilityC, "gunaction_config", "damage_projectile_add" ),
            }
            
            index.D.invs_i[ item_id ] = index.get_inv_info( item_id, { this_info.wand_info.deck_capacity, 1 }, { "full" }, function( item_info, inv_info ) return item_info.is_spell or false end, function( inv_info, info_old, info_new ) return ( inv_info.in_hand or 0 ) > 0 end, nil, function( a, b )
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
            
            return this_info
        end,
        on_processed_forced = function( item_id, this_info )
            local children = EntityGetAllChildren( item_id ) or {}
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

        on_inventory = function( item_id, this_info, pic_x, pic_y, john_bool )
            if( index.D.gmod.allow_wand_editing and john_bool.is_quick and index.D.is_opened ) then
                pic_x, pic_y = unpack( index.D.wand_inventory == nil and index.D.xys.full_inv or index.D.wand_inventory )
                w, h = index.D.wand_func( pic_x + 2*pen.b2n( john_bool.in_hand ), pic_y, this_info, john_bool.in_hand )
                index.D.wand_inventory = { pic_x, pic_y + h }
            end
        end,
        on_tooltip = new_vanilla_wtt,
        on_slot = function( item_id, this_info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            local w, h = 0,0
            if((( pen.cache({ "index_pic_data", this_info.pic }) or {}).xy or {})[3] == nil ) then
                w, h = pen.get_pic_dims( index.D.slot_pic.bg ) end
            index.new_slot_pic( pic_x - w/8, pic_y + h/8, index.slot_z( this_info.id, pen.LAYERS.ICONS ), this_info.pic, 1, math.rad( -45 ), hov_scale, true )
            
            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                hov_func( nil, item_id, this_info, pic_x - 10, pic_y + 10, pen.LAYERS.TIPS )
            end
            
            if( this_info.wand_info.actions_per_round > 0 and this_info.charges < 0 ) then
                this_info.charges = 0

                local slot_data, was_there = index.D.slot_state[ item_id ], false
                for i,col in ipairs( slot_data ) do
                    for e,slot in ipairs( col ) do
                        if( slot ) then
                            local slot_info = pen.t.get( index.D.item_list, slot, nil, nil, {})
                            if( slot_info.is_spell ) then
                                if( slot_info.charges > 0 ) then
                                    this_info.charges = slot_info.charges
                                    break
                                elseif( this_info.charges == 0 and slot_info.charges < 0 ) then
                                    if( slot_info.spell_info.type ~= 2 and slot_info.spell_info.type ~= 3 ) then
                                        this_info.charges = -1
                                    end
                                end
                                if( not( was_there )) then was_there = slot_info.charges == 0 end
                            end
                        end
                    end
                    if( this_info.charges > 0 ) then break end
                end

                if( this_info.charges == 0 and was_there ) then
                    this_info.charges = 0.1
                end
            end

            return this_info
        end,
        
        on_pickup = function( item_id, this_info, is_post )
            local func_tbl = {
                function( item_id, this_info )
                    return 0
                end,
                function( item_id, this_info )
                    if( not( ComponentGetValue2( this_info.ItemC, "has_been_picked_by_player" ))) then
                        EntityLoad( "data/entities/particles/image_emitters/wand_effect.xml", unpack( this_info.xy ))
                        ComponentSetValue2( this_info.ItemC, "play_spinning_animation", true )
                    end
                end,
            }
            return func_tbl[ is_post and 2 or 1 ]( item_id, this_info )
        end,

        on_gui_world = new_vanilla_worldtip,
        -- on_gui_pause = function( item_id, this_info ) --should know the state (if is picked or not)
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
        on_data = function( item_id, this_info, item_list_wip )
            this_info.is_true_potion = EntityGetFirstComponentIncludingDisabled( item_id, "PotionComponent" ) ~= nil

            local matter_comp = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialInventoryComponent" )
            this_info.MatterC = matter_comp
            this_info.matter_info = {
                ComponentGetValue2( matter_comp, "max_capacity" ),
                { pen.get_matter( ComponentGetValue2( matter_comp, "count_per_material_type" ))},
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

            if( this_info.is_true_potion ) then
                this_info.name, this_info.fullness = index.get_potion_info( item_id, this_info.raw_name, math.max( this_info.matter_info[2][1], 0 ), this_info.matter_info[1], this_info.matter_info[2][2])
            end
            if( this_info.matter_info[1] < 0 ) then this_info.matter_info[1] = this_info.matter_info[2][1] end
            
            this_info.potion_cutout = pen.magic_storage( item_id, "potion_cutout", "value_int" )
                or ( 3 - pen.b2n( this_info.matter_info[1] < this_info.matter_info[2][1]))

            return this_info
        end,
        
        on_inventory = function( item_id, this_info, pic_x, pic_y, john_bool )
            local cap_max = this_info.matter_info[1]
            local mtrs = this_info.matter_info[2]
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
        on_slot = function( item_id, this_info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                hov_func( nil, item_id, this_info, pic_x - 10, pic_y + 10, pen.LAYERS.TIPS )
            end

            local cap_max = this_info.matter_info[1]
            local content_total = this_info.matter_info[2][1]
            if( content_total == 0 ) then this_info.charges = 0 end

            local nuke_it, target_angle = true, 0
            if( john_bool.is_dragged ) then
                if( drag_func ~= nil and index.D.drag_action ) then
                    nuke_it, target_angle = unpack( drag_func( item_id, this_info ))
                end
            elseif( rmb_func ~= nil and john_bool.is_rmb and index.D.is_opened and john_bool.is_quick ) then
                rmb_func( item_id, this_info )
            end

            local pic_data = pen.cache({ "index_pic_data", this_info.pic })
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
                if( index.D.dragger.item_id == 0 or index.D.dragger.item_id == item_id ) then
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
            
            local z = index.slot_z( this_info.id, pen.LAYERS.ICONS )
            local ratio = math.min( content_total/cap_max, 1 )
            pic_x, pic_y = index.new_slot_pic( pic_x, pic_y, z, this_info.pic, 0.8 - 0.5*ratio, angle, hov_scale )
            pen.new_image( pic_x, pic_y, z - 0.001, this_info.pic,
                { color = pen.magic_uint( GameGetPotionColorUint( this_info.id )), s_x = hov_scale, s_y = hov_scale, angle = angle })
            
            return this_info, content_total ~= 0, true
        end,

        on_action = function( type )
            local func_tbl = {
                [1] = function( item_id, this_info )
                    if( this_info.matter_info[3]) then
                        if( this_info.matter_info[2][1] > 0 ) then
                            play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink" })
                            pen.magic_chugger( this_info.matter_info[2][2], index.D.player_id, this_info.id, this_info.matter_info[2][1], index.D.shift_action and 1 or 0.1 )
                        else play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink_empty" }) end
                    end
                end,
                [2] = function( item_id, this_info )
                    local out = { true, 0 }

                    local x, y = unpack( index.D.player_xy )
                    local p_x, p_y = unpack( index.D.pointer_world )
                    if( not( RaytraceSurfaces( x, y, p_x, p_y ))) then
                        if( not( EntityGetIsAlive( index.M.john_pouring or 0 ))) then
                            index.M.john_pouring = EntityLoad( "mods/index_core/files/misc/potion_nerd.xml", x, y )
                            if( this_info.spray_info ~= nil ) then
                                local loop_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "AudioLoopComponent" )
                                ComponentSetValue2( loop_comp, "file", this_info.spray_info[1])
                                ComponentSetValue2( loop_comp, "event_name", this_info.spray_info[2])
                            end
                        end
                        EntitySetTransform( index.M.john_pouring, p_x, p_y )

                        local cap_max = this_info.matter_info[1]
                        local content_total = this_info.matter_info[2][1]
                        if( index.D.shift_action ) then
                            out[1] = false
                            out[2] = 45 + 90*( 1 - math.min( content_total/cap_max, 1 ))
                            
                            if( content_total > 0 ) then
                                GameEntityPlaySoundLoop( index.M.john_pouring, "spray", 1 )
                                if( index.D.frame_num%5 == 0 ) then
                                    pen.magic_chugger( this_info.matter_info[2][2], index.D.pointer_world, this_info.id, cap_max )
                                end
                            end
                        elseif( this_info.bottle_info ~= nil ) then
                            out[1] = false

                            local sucker_comp = EntityGetFirstComponentIncludingDisabled( index.M.john_pouring, "MaterialSuckerComponent" )
                            if( EntityGetName( index.M.john_pouring ) ~= "done" ) then
                                EntitySetName( index.M.john_pouring, "done" )
                                ComponentSetValue2( sucker_comp, "barrel_size", this_info.bottle_info[1])
                                ComponentSetValue2( sucker_comp, "num_cells_sucked_per_frame", this_info.bottle_info[2])
                                ComponentSetValue2( sucker_comp, "material_type", this_info.bottle_info[3])
                                ComponentSetValue2( sucker_comp, "suck_tag", this_info.bottle_info[4])
                                ComponentSetValue2( sucker_comp, "suck_static_materials", this_info.bottle_info[5])
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

                                                local _,pre_mtr = pen.t.get( this_info.matter_info[2][2], mtr[1])
                                                pre_mtr = this_info.matter_info[2][2][ pre_mtr or -1 ] or {0,0}
                                                AddMaterialInventoryMaterial( item_id, name, pre_mtr[2] + count )
                                                
                                                do_sound = true
                                            end
                                            AddMaterialInventoryMaterial( index.M.john_pouring, name, 0 )
                                        end
                                    end
                                end
                                this_info.matter_info[2][1] = content_total
                            end
                            EntitySetComponentIsEnabled( index.M.john_pouring, sucker_comp, content_total < cap_max )
                            if( do_sound and index.D.frame_num%5 == 0 ) then
                                if( this_info.bottle_info[3] == 0 ) then
                                    play_sound({ "data/audio/Desktop/materials.bank", "collision/glass_potion/liquid_container_hit" }, p_x, p_y )
                                elseif( this_info.bottle_info[3] == 1 ) then
                                    play_sound({ "data/audio/Desktop/materials.bank", "collision/snow" }, p_x, p_y )
                                end
                            end
                        end
                    end

                    return out
                end,
            }
            return func_tbl[ type ]
        end,
        on_pickup = function( item_id, this_info, is_post )
            local func_tbl = {
                function( item_id, this_info ) return 0 end,
                function( item_id, this_info )
                    if( not( ComponentGetValue2( this_info.ItemC, "has_been_picked_by_player" ))) then
                        local emitter = EntityLoad( "data/entities/particles/image_emitters/potion_effect.xml", unpack( this_info.xy ))
                        ComponentGetValue2( EntityGetFirstComponentIncludingDisabled( emitter, "ParticleEmitterComponent" ), "emitted_material_name", CellFactory_GetName( this_info.matter_info[2][2][1][1]))
                    end
                end,
            }
            return func_tbl[ is_post and 2 or 1 ]( item_id, this_info )
        end,

        on_gui_world = new_vanilla_worldtip,
    },
    {
        name = string.sub( string.lower( GameTextGetTranslatedOrNot( "$hud_title_actionstorage" )), 1, -2 ),
        is_spell = true,

        on_check = function( item_id )
            return EntityHasTag( item_id, "card_action" ) or EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" ) ~= nil
        end,
        on_data = function( item_id, this_info, item_list_wip )
            if( this_info.is_permanent ) then
                this_info.charges = -1
            end

            local action_comp = EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" )
            this_info.ActionC = action_comp

            local spell_id = ComponentGetValue2( action_comp, "action_id" )
            this_info.spell_info = pen.get_spell_data( spell_id )
            this_info.pic = this_info.spell_info.sprite
            this_info.spell_id = spell_id
            
            this_info.tip_name = pen.capitalizer( GameTextGetTranslatedOrNot( this_info.spell_info.name ))
            this_info.name = this_info.tip_name..( this_info.charges >= 0 and " ("..this_info.charges..")" or "" )
            this_info.tip_name = string.upper( this_info.tip_name )
            this_info.desc = index.full_stopper( GameTextGetTranslatedOrNot( this_info.spell_info.description ))
            
            local parent_id = EntityGetParent( item_id )
            if( parent_id > 0 and index.D.invs[ parent_id ] ~= nil ) then
                parent_id = pen.t.get( item_list_wip, parent_id, nil, nil, {})
                if( parent_id.is_wand ) then this_info.in_wand = parent_id.id end
            end

            if( GameGetGameEffectCount( index.D.player_id, "ABILITY_ACTIONS_MATERIALIZED" ) > 0 ) then
                if( this_info.AbilityC ~= nil and ComponentGetValue2( this_info.AbilityC, "use_entity_file_as_projectile_info_proxy" )) then
                    this_info.inv_cat = 0
                end
            end

            return this_info
        end,
        on_processed = function( item_id, this_info )
            local pic_comp = EntityGetFirstComponentIncludingDisabled( item_id, "SpriteComponent", "item_unidentified" )
            if( pic_comp ~= nil ) then EntityRemoveComponent( item_id, pic_comp ) end
        end,

        on_inv_check = function( this_info, inv_info )
            return pen.t.get( inv_info.kind, "quickest" ) == 0
        end,
        on_inv_swap = function( this_info, slot_data )
            if( index.D.active_item == this_info.id ) then
                pen.reset_active_item( index.D.player_id )
            end
        end,
        on_tooltip = new_vanilla_stt,
        on_slot = function( item_id, this_info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            local angle, is_considered, anim_speed = 0, john_bool.is_dragged or john_bool.is_hov, index.D.spell_anim_frames
            if( john_bool.can_drag ) then
                angle = -math.rad( 5 )*( is_considered and 1.5 or ( anim_speed == 0 and 0 or math.sin(( index.D.frame_num%anim_speed )*math.pi/anim_speed )))
            end
            local pic_z = index.slot_z( this_info.id, pen.LAYERS.ICONS )
            index.new_slot_pic( pic_x, pic_y, pic_z, this_info.pic, nil, angle, hov_scale )
            if( is_considered ) then pen.colourer( nil, {185,220,223}) end
            new_spell_frame( pic_x, pic_y, pen.LAYERS.ICONS + ( is_considered and 0.001 or -0.005 ), this_info.spell_info.type, is_considered and 1 or 0.6, angle )

            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( nil, item_id, this_info, pic_x, pic_y, pen.LAYERS.TIPS )
            end

            return this_info
        end,

        on_gui_world = new_vanilla_worldtip,
    },
    {
        name = "tablet",

        on_check = function( item_id )
            return EntityGetFirstComponentIncludingDisabled( item_id, "BookComponent" ) ~= nil
        end,
        
        on_tooltip = new_vanilla_ttt,
        on_slot = function( item_id, this_info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( this_info.id, pen.LAYERS.ICONS ), this_info.pic, nil, nil, hov_scale )
            
            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( nil, item_id, this_info, pic_x, pic_y, pen.LAYERS.TIPS )
            end

            return this_info, true
        end,

        on_gui_world = new_vanilla_worldtip,
    },
    {
        name = GameTextGetTranslatedOrNot( "$mat_item_box2d" ),

        on_check = function( item_id )
            return true
        end,
        on_data = function( item_id, this_info, item_list_wip )
            if( EntityHasTag( item_id, "this_is_sampo" )) then
                this_info.inv_cat = 0

                if( EntityGetRootEntity( item_id ) == index.D.player_id ) then
                    index.D.sampo = item_id
                end
            end
            return this_info
        end,
        
        on_tooltip = new_vanilla_itt,
        on_slot = function( item_id, this_info, pic_x, pic_y, john_bool, rmb_func, drag_func, hov_func, hov_scale )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( this_info.id, pen.LAYERS.ICONS ), this_info.pic, nil, nil, hov_scale )

            if( john_bool.is_opened and john_bool.is_hov and hov_func ~= nil ) then
                pic_x, pic_y = pic_x - 10, pic_y + 10
                hov_func( nil, item_id, this_info, pic_x, pic_y, pen.LAYERS.TIPS )
            end
            
            return this_info
        end,

        on_pickup = function( item_id, this_info, is_post )
            local func_tbl = {
                function( item_id, this_info )
                    if( EntityGetFirstComponentIncludingDisabled( item_id, "OrbComponent" ) ~= nil ) then
                        index.vanilla_pick_up( index.D.player_id, item_id )
                    else return 0 end
                end,
                function() end,
            }
            return func_tbl[ is_post and 2 or 1 ]( item_id, this_info )
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