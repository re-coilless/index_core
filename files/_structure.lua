dofile_once( "mods/index_core/files/_elements.lua" )

local Z_LAYERS = {
    in_world_back = 999,
    in_world = 998,
    in_world_front = 997,

    background = 2, --general background

    main_far_back = 1, --slot background
    main_back = 0.01, --bar background
    main = 0, --slot highlights, bars, perks, effects
    main_front = -0.01,

    icons_back = -0.09,
    icons = -1, --inventory item icons
    icons_front = -1.01, --spell charges

    tips_back = -10100,
    tips = -10101, --tooltips duh 
    tips_front = -10102,
}

local ITEM_TYPES = {
    {
        name = GameTextGetTranslatedOrNot( "$item_wand" ),
        is_quickest = true,
        is_hidden = false,
        paused_pickup = true,

        on_check = function( item_id, data, this_info )
            return this_info.AbilityC ~= nil and ComponentGetValue2( this_info.AbilityC, "use_gun_script" )
        end,
        on_data = function( item_id, data, this_info )
            dofile_once( "data/scripts/gun/gun.lua" )

            --add wand invs to data.inventories, add an ability to do custom code for this + check for is spell
            --insert spells to item list
            --wand slot count should be slot_count - always_casts

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

        on_inventory = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, is_opened, in_hand )
            --do em wands
            return uid, data
        end,
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            --use this for in-world tips too
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, hov_func, is_full, in_hand )
            --do the tooltip (hov_func is the one)
            local w, h = get_pic_dim( this_info.pic )
            uid = new_slot_pic( gui, uid, pic_x + w/4, pic_y + 3*h/4 + 1, slot_z( data, this_info.id, zs.icons ), this_info.pic, 1, 1, math.rad( -45 ))
            return uid
        end,
        
        on_pickup = function( gui, uid, item_id, data, this_info, zs, is_post )
            local func_tbl = {
                function( item_id, data, this_info )
                    --return 1 to pause, -1 to abort, 0 to pickup
                    return 0
                end,
                function( item_id, data, this_info )
                end,
            }
            return func_tbl[ is_post and 2 or 1 ]( item_id, data, this_info )
        end,
        on_gui_world = function( gui, uid, item_id, data, this_info, zs, pic_x, pic_y, no_space, cant_buy )
            return uid
        end,
        on_gui_pause = function( gui, uid, item_id, data, this_info, zs ) --(if no noitapatcher, drop to 20 frames - off by default)
            return uid --return false to continue the pause, nil to cancel, true to pickup
        end,
        ctrl_script = function( item_id, data, this_info, in_hand ) --inventory_man if nil (set enabled + teleport to inv owner xy)
            --this is being executed constantly
        end,
    },
    {
        name = GameTextGetTranslatedOrNot( "$item_potion" ),

        on_check = function( item_id, data, this_info )
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

            local barrel_size = EntityGetFirstComponentIncludingDisabled( item_id, "MaterialSuckerComponent" )
            this_info.matter_info[1] = barrel_size == nil and this_info.matter_info[1] or ComponentGetValue2( barrel_size, "barrel_size" )
            
            this_info.name, this_info.potion_fullness = get_potion_info( item_id, this_info.name, this_info.matter_info[1], math.max( this_info.matter_info[2][1], 0 ), this_info.matter_info[2][2])

            return data, this_info
        end,
        
        on_inventory = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, is_opened, in_hand, is_hovered )
            local w, h = get_pic_dim( data.slot_pic.bg )
            pic_x, pic_y = pic_x + w/2, pic_y + h/2

            local cap_max = this_info.matter_info[1]
            local mtrs = this_info.matter_info[2]
            local content_total = mtrs[1]
            local content_tbl = mtrs[2]
            table.sort( content_tbl, function( a, b )
                return a[2] < b[2]
            end)
            
            local w, h = get_pic_dim( this_info.pic )
            w, h = get_pic_dim( data.slot_pic.bg )
            w, h = w - 4, h - 4
            local k = h/cap_max
            pic_x, pic_y = pic_x - w/2, pic_y + h/2
            local size = k*math.min( content_total, cap_max )
            pic_y = pic_y - size
            if(( 16 - size ) > 0.5 and math.min( content_total/cap_max, 1 ) > 0 ) then
                uid = new_image( gui, uid, pic_x, pic_y - 0.5, zs.main + 0.001, data.pixel, w, 0.5 )
            end
            local alpha = is_hovered and 0.75 or 0.9
            local delta = 0
            for i,m in ipairs( content_tbl ) do
                local sz = math.ceil( 2*math.max( math.min( k*m[2], h ), 0.5 ))/2
                colourer( gui, get_matter_colour( CellFactory_GetName( m[1])))
                if( i == #content_tbl ) then sz = math.max( size - delta, 0 ) end
                uid = new_image( gui, uid, pic_x, pic_y + delta, zs.main + 0.001, data.pixel, w, sz, alpha )
                delta = delta + sz
            end

            return uid, data
        end,
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, hov_func, is_full, in_hand )
            local cap_max = this_info.matter_info[1]
            local content_total = this_info.matter_info[2][1]
            
            local z = slot_z( data, this_info.id, zs.icons )

            local ratio = math.min( content_total/cap_max, 1 )
            local w, h = 0, 0
            uid, w, h = new_slot_pic( gui, uid, pic_x, pic_y, z, this_info.pic, 0.75, 0.8 - 0.5*ratio )
            colourer( gui, uint2color( GameGetPotionColorUint( this_info.id )))
            uid = new_image( gui, uid, pic_x - w/2, pic_y - h/2, z - 0.001, this_info.pic )
            
            return uid
        end,
    },
    {
        name = string.sub( string.lower( GameTextGetTranslatedOrNot( "$hud_title_actionstorage" )), 1, -2 ),

        on_check = function( item_id, data, this_info )
            return EntityHasTag( item_id, "card_action" ) or EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" ) ~= nil
        end,
        on_data = function( item_id, data, this_info )
            local action_comp = EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" )
            this_info.ActionC = action_comp
            this_info.spell_id = ComponentGetValue2( action_comp, "action_id" )
            
            return data, this_info
        end,
        
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, hov_func, is_full, in_hand )
            return uid
        end,
    },
    {
        name = "tablet",

        on_check = function( item_id, data, this_info )
            return EntityGetFirstComponentIncludingDisabled( item_id, "BookComponent" ) ~= nil
        end,
        
        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, hov_func, is_full, in_hand )
            return uid
        end,
    },
    {
        name = GameTextGetTranslatedOrNot( "$mat_item_box2d" ),

        on_check = function( item_id, data, this_info )
            return true
        end,

        on_tooltip = function( gui, uid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
            return uid
        end,
        on_slot = function( gui, uid, item_id, data, this_info, pic_x, pic_y, zs, hov_func, is_full, in_hand )
            uid = new_slot_pic( gui, uid, pic_x, pic_y, slot_z( data, this_info.id, zs.icons ), this_info.pic )
            return uid
        end,
    },
}

local GUI_STRUCT = {
    slot = new_slot,
    full_inv = new_generic_inventory,
    
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
    
    pickup_info = new_pickup_info,
    pickup = new_generic_pickup,
    extra = new_generic_extra,
    custom = {}, --table of string-indexed funcs (sorted alphabetically)
}

--<{> MAGICAL APPEND MARKER <}>--

return { GUI_STRUCT, Z_LAYERS, ITEM_TYPES }