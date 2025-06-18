dofile_once( "mods/index_core/files/_elements.lua" )

local GLOBAL_MODES = {
    {
        name = "FULL", color = pen.PALETTE.W,
        desc = "Wand editing with minimal obstructions.",
        is_default = true, allow_wand_editing = true, show_full = true,
        
        -- menu_capable = false, is_hidden = false, show_fullest = false,
        -- can_see = false, allow_shooting = false, force_inv_open = false,
        -- allow_external_inventories = false, allow_advanced_draggables = false,
    },
    {
        name = "MANAGEMENT", color = pen.PALETTE.VNL.YELLOW,
        desc = "Extended inventory management capability.",
        allow_external_inventories = true, show_full = true, show_fullest = true,
    },
    {
        name = "INTERACTIVE", color = pen.PALETTE.VNL.RUNIC,
        desc = "Dragging actions and in-world interactivity.",
        can_see = true, allow_shooting = true, allow_advanced_draggables = true,
    },
    {
        name = "CUSTOM_MENU", color = pen.PALETTE.VNL.DAMAGE,
        desc = "Clears space to the right and limits interactions.",
        menu_capable = true, is_hidden = true, force_inv_open = true,
    },
}

local GLOBAL_MUTATORS, APPLETS = {}, {
    l_state = not( pen.c.index_settings.mute_applets ), l_hover = {},
    r_state = not( pen.c.index_settings.mute_applets ), r_hover = {},
    l = {}, r = {
        -- {
        --     name = "README", desc = "The complete user guide.",
        --     pic = "data/ui_gfx/status_indicators/confusion.png",
        --     toggle = function( state ) end,
        -- },
    },
}

local BOSS_BARS = { --apocalyptic thanks to Priskip
	["data/entities/animals/boss_alchemist/boss_alchemist.xml"] = {
		pic = "mods/index_core/files/pics/priskips_bossbars/alchemist.png",
		-- in_world = false,
		-- color = pen.PALETTE.VNL.HP,
		-- color_text = pen.PALETTE.VNL.ACTION_OTHER,
		color_bg = { 120, 131, 146, 47/255 }, pos = { 20, 3, 294, 17 },
		-- func = function( pic_x, pic_y, pic_z, entity_id, data ) return length, height end,
		-- func_extra = function( pic_x, pic_y, pic_z, entity_id, data, perc ) end,
	},
	-- ["data/entities/animals/boss_book/book_physics.xml"] = {},
	["data/entities/animals/boss_centipede/boss_centipede.xml"] = {
		pic = "mods/index_core/files/pics/priskips_bossbars/centipede.png",
		color_bg = { 99, 155, 255, 47/255 }, pos = { 13, 6, 324, 17, 2, -3 },
	},
	-- ["data/entities/animals/boss_fish/fish_giga.xml"] = {}
	-- ["data/entities/animals/boss_gate/gate_monster_a.xml"] = {},
	-- ["data/entities/animals/boss_gate/gate_monster_b.xml"] = {},
	-- ["data/entities/animals/boss_gate/gate_monster_c.xml"] = {},
	-- ["data/entities/animals/boss_gate/gate_monster_d.xml"] = {},
	-- ["data/entities/animals/boss_ghost/boss_ghost.xml"] = {},
	-- ["data/entities/animals/boss_limbs/boss_limbs.xml"] = {},
	-- ["data/entities/animals/boss_meat/boss_meat.xml"] = {},
	["data/entities/animals/boss_pit/boss_pit.xml"] = {
		pic = "mods/index_core/files/pics/priskips_bossbars/pit.png",
		color_bg = { 155, 71, 125, 47/255 }, pos = { 31, 3, 295, 17, -1, 0 },
	},
	["data/entities/animals/boss_robot/boss_robot.xml"] = {
		pic = "mods/index_core/files/pics/priskips_bossbars/robot.png",
		color_bg = { 255, 131, 157, 47/255 }, pos = { 48, 5, 288, 15, -3, -2 },
	},
	-- ["data/entities/animals/boss_sky/boss_sky.xml"] = {},
	-- ["data/entities/animals/boss_spirit/islandspirit.xml"] = {},
	["data/entities/animals/boss_wizard/boss_wizard.xml"] = {
		pic = "mods/index_core/files/pics/priskips_bossbars/wizard.png",
		color_bg = { 209, 97, 97, 47/255 }, pos = { 4, 4, 302, 15, 19, -1 },
		func_extra = function( pic_x, pic_y, pic_z, entity_id, data )
			local mode = pen.magic_storage( entity_id, "mode", "value_int" )
			pen.new_image( pic_x - 188.5, pic_y - 9, pic_z, "mods/index_core/files/pics/priskips_bossbars/wizard_"..mode..".png" )
		end,
	},
	-- ["data/entities/animals/maggot_tiny/maggot_tiny.xml"] = {},
	-- ["data/entities/animals/parallel/alchemist/parallel_alchemist.xml"] = {},
	-- ["data/entities/animals/parallel/tentacles/parallel_tentacles.xml"] = {},
	-- ["data/entities/animals/friend.xml"] = {},
	["data/entities/animals/boss_dragon.xml"] = {
		pic = "mods/index_core/files/pics/priskips_bossbars/dragon.png",
		color_bg = { 164, 48, 48, 55/255 }, pos = { 3, 6, 316, 12, 0, -3 },
	},
}

local WAND_STATS = {
	{
		pic = "data/ui_gfx/inventory/icon_gun_actions_per_round.png",
		name = "$inventory_actionspercast", desc = "$inventory_actionspercast_tooltip",

		-- spacer = false,
		-- is_hidden = false,
		-- is_advanced = false,
		bigger_better = true,
		value = function( info, w )
			return w.actions_per_round or 0 end,
		txt = function( value, info, w ) return index.get_vanilla_stat( value, nil, 0 ) end,
		-- func = function( pic_x, pic_y, pic_z, txt, data ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_gun_capacity.png",
		name = "$inventory_capacity", desc = "$inventory_capacity_tooltip",

		bigger_better = true,
		value = function( info, w )
			return w.deck_capacity or 0 end,
		txt = function( value, info, w ) return index.get_vanilla_stat( value, nil, 0 ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_spread_degrees.png",
		name = "$inventory_spread", desc = "$inventory_spread_tooltip",
		
		spacer = true,
		value = function( info, w )
			return w.spread_degrees or 0 end,
		txt = function( value, info, w )
			local v, is_dft = index.get_vanilla_stat( value, nil, 0 )
			return v.."°", is_dft
		end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_mana_max.png",
		name = "$inventory_manamax", desc = "$inventory_manamax_tooltip",

		bigger_better = true,
		value = function( info, w )
			return w.mana_max or 0 end,
		txt = function( value, info, w ) return index.get_vanilla_stat( value, nil, 0 ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_mana_charge_speed.png",
		name = "$inventory_manachargespeed", desc = "$inventory_manachargespeed_tooltip",

		spacer = true,
		bigger_better = true,
		value = function( info, w )
			return w.mana_charge_speed or 0 end,
		txt = function( value, info, w ) return index.get_vanilla_stat( value, nil, 0 ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_fire_rate_wait.png", off_y = 1,
		name = "$inventory_castdelay", desc = "$inventory_castdelay_tooltip",

		value = function( info, w )
			return w.delay_time or 0 end,
		txt = function( value, info, w )
			local v, is_dft = index.get_vanilla_stat( value/60, nil, 0, false, true )
			return v.."s", is_dft
		end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_gun_reload_time.png",
		name = "$inventory_rechargetime", desc = "$inventory_rechargetime_tooltip",
		
		spacer = true,
		value = function( info, w )
			return w.reload_time or 0 end,
		txt = function( value, info, w )
			if( w.never_reload ) then return "Ø", 1 end
			local v, is_dft = index.get_vanilla_stat( value/60, nil, 0, false, true )
			return v.."s", is_dft
		end,
	},

    -- info.wand_info.speed_multiplier
    -- info.wand_info.lifetime_add
    -- info.wand_info.bounces

    -- info.wand_info.crit_chance
    -- info.wand_info.crit_mult

    -- info.wand_info.damage_electricity_add
    -- info.wand_info.damage_explosion_add
    -- info.wand_info.damage_fire_add
    -- info.wand_info.damage_melee_add
    -- info.wand_info.damage_projectile_add
}

local SPELL_STATS = {
	{
		{
			off_x = 0, off_y = 0,
			pic = function( info )
				if(( info.spell_info.meta.state.draw_many or 0 ) == 0 ) then
					return "data/ui_gfx/inventory/icon_gun_charge.png" end
				return "data/ui_gfx/inventory/icon_gun_actions_per_round.png"
			end,
			name = function( info )
				if(( info.spell_info.meta.state.draw_many or 0 ) == 0 ) then
					return "Projectile Count" end
				return "Draw Extra"
			end,
			desc = function( info )
				if(( info.spell_info.meta.state.draw_many or 0 ) == 0 ) then
					return "The number of individual projectiles this spell creates." end
				return "The number of individual spells this card draws after being fired."
			end,

			-- spacer = false,
			-- is_hidden = false,
			value = function( info, c, c_proj )
				return (( info.spell_info.meta.state.draw_many or 0 ) == 0 ) and ( c.proj_count or 0 ) or c.draw_many end,
			txt = function( value, info, c, c_proj ) return index.get_vanilla_stat( value, nil, 0 ) end,
			-- func = function( pic_x, pic_y, pic_z, txt, data ) end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_mana_drain.png",
			name = "$inventory_manadrain", desc = "The amount of mana this spell will consume on cast.",
			
			value = function( info, c, c_proj )
				return info.spell_info.mana or 0 end,
			txt = function( value, info, c, c_proj ) return index.get_vanilla_stat( value, nil, 0 ) end,
		},
		{
			off_y = 1,
			pic = "data/ui_gfx/inventory/icon_fire_rate_wait.png",
			name = "$inventory_mod_castdelay", desc = "The cooldown time after one group of spells has been cast.",

			value = function( info, c, c_proj )
				return c.fire_rate_wait or 0 end,
			txt = function( value, info, c, c_proj )
				local v, is_dft = index.get_vanilla_stat( nil, value/60, 0, false, true )
				return v.."s", is_dft
			end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_reload_time.png",
			name = "$inventory_mod_rechargetime", desc = "The cooldown time after all the spells have been cast.",

			value = function( info, c, c_proj )
				return c.reload_time or 0 end,
			txt = function( value, info, c, c_proj )
				if( info.spell_info.is_chainsaw ) then return "Chainsaw", 1 end
				local v, is_dft = index.get_vanilla_stat( nil, value/60, 0, false, true )
				return v.."s", is_dft
			end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_spread_degrees.png",
			name = "$inventory_mod_spread", desc = "Additional divergence of fired spells from the aiming direction.",
			
			spacer = true,
			value = function( info, c, c_proj )
				return c.spread_degrees or 0 end,
			txt = function( value, info, c, c_proj )
				local v, is_dft = index.get_vanilla_stat( nil, value, 0 )
				return v.."°", is_dft
			end,
		},
	},
	{
		{
			pic = "data/ui_gfx/inventory/icon_damage_projectile.png",
			name = "$inventory_mod_damage", desc = "The combined damage across all infliction types.",
			
			value = function( info, c, c_proj )
				return c_proj.damage.total or 0 end,
			txt = function( value, info, c, c_proj )
				if( c.damage_null_all > 0 ) then return "Ø", 1 end
				return index.get_vanilla_stat( 25*value, 25*( c.damage_total_add or 0 ), 0 )
			end,
		},
		{
			off_y = 1,
			pic = "data/ui_gfx/inventory/icon_damage_critical_chance.png",
			name = "$inventory_mod_critchance", desc = "The likelyhood of the spell delivering a critical hit.",

			value = function( info, c, c_proj )
				return c_proj.crit.chance or 0 end,
			txt = function( value, info, c, c_proj )
				local v, is_dft = index.get_vanilla_stat( value, c.damage_critical_chance, 0, false, true )
				return v.."%", is_dft
			end,
		},
		{
			off_y = 1,
			pic = "data/ui_gfx/inventory/icon_speed_multiplier.png",
			name = "$inventory_mod_speed", desc = "Baseline muzzle velocity.",

			value = function( info, c, c_proj )
				return c_proj.speed or 0 end,
			txt = function( value, info, c, c_proj )
				local added_value = c.speed_multiplier or 1
				local v, is_dft = ( is_dft and "x" or "" )..pen.get_short_num( is_dft and added_value or ( value*added_value )), value == 0
				return v, is_dft and ( added_value == 1 )
			end,
		},
		{
			off_y = -1,
			pic = "data/ui_gfx/inventory/icon_bounces.png",
			name = "$inventory_mod_bounces", desc = "Total amount of times the projectile will persist after hitting the ground.",
			
			value = function( info, c, c_proj )
				return c_proj.bounces or 0 end,
			txt = function( value, info, c, c_proj )
				if( c_proj.inf_bounces ) then return "∞", 1 end
				return index.get_vanilla_stat( value, c.bounces, 0 )
			end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_explosion_radius.png",
			name = "$inventory_mod_explosion_radius", desc = "The size of the created explosion.",

			spacer = true,
			value = function( info, c, c_proj )
				return c_proj.lightning.explosion_radius or c_proj.explosion.explosion_radius or 0 end,
			txt = function( value, info, c, c_proj ) return index.get_vanilla_stat( value, c.explosion_radius, 0 ) end,
		},
	},
    
    -- c.damage_total_add
	-- icon_damage_projectile.png=c.damage_projectile_add
	-- icon_damage_curse.png=c.damage_curse_add
	-- icon_damage_explosion.png=c.damage_explosion_add
	-- icon_damage_slice.png=c.damage_slice_add
	-- icon_damage_melee.png=c.damage_melee_add
	-- icon_damage_ice.png=c.damage_ice_add
	-- icon_damage_electricity.png=c.damage_electricity_add
	-- icon_damage_drill.png=c.damage_drill_add
	-- icon_damage_healing.png=c.damage_healing_add
	-- c.damage_fire_add
	-- c.damage_holy_add
	-- c.damage_physics_add
	-- c.damage_poison_add
	-- c.damage_radioactive_add

	-- c.explosion_damage_to_materials
	-- c.damage_critical_multiplier
	
	-- c.lifetime_add

	-- c_proj.damage.total
	-- c_proj.damage.curse
	-- c_proj.damage.drill
	-- c_proj.damage.electricity
	-- c_proj.damage.explosion
	-- c_proj.damage.fire
	-- c_proj.damage.healing
	-- c_proj.damage.ice
	-- c_proj.damage.melee
	-- c_proj.damage.overeating
	-- c_proj.damage.physics_hit
	-- c_proj.damage.poison
	-- c_proj.damage.projectile
	-- c_proj.damage.radioactive
	-- c_proj.damage.slice
	-- c_proj.damage.holy

	-- c_proj.damage_scaled_by_speed
	-- c_proj.damage_every_x_frames
		
	-- c_proj.lifetime
	
	-- c_proj.on_collision_die
	-- c_proj.on_death_duplicate
	-- c_proj.on_death_explode
	-- c_proj.on_lifetime_out_explode

	-- c_proj.collide_with_entities
	-- c_proj.penetrate_entities
	-- c_proj.dont_collide_with_tag
	-- c_proj.never_hit_player
	-- c_proj.friendly_fire
	-- c_proj.explosion_dont_damage_shooter

	-- c_proj.collide_with_world
	-- c_proj.penetrate_world
	-- c_proj.go_through_this_material
	-- c_proj.ground_penetration_coeff
	-- c_proj.ground_penetration_max_durability
	
	-- c_proj.explosion.damage_mortals
	-- c_proj.explosion.damage
	-- c_proj.explosion.is_digger
	-- c_proj.explosion.explosion_radius
	-- c_proj.explosion.max_durability_to_destroy
	-- c_proj.explosion.ray_energy
	
	-- c_proj.crit.chance
	-- c_proj.crit.damage_multiplier
	
	-- c_proj.lightning.damage_mortals
	-- c_proj.lightning.damage
	-- c_proj.lightning.is_digger
	-- c_proj.lightning.explosion_radius
	-- c_proj.lightning.max_durability_to_destroy
	-- c_proj.lightning.ray_energy
}

local MATTER_DESCS = { -- description for materials (if mode is not hotkeyed, make the desc tip be hotkey openable)
    blood = "Protects from fire and increases crit chance.",

    magic_liquid_charm = "Does stuff.",
    magic_liquid_berserk = "Does stuff.",
}

local ITEM_CATS = {
    {
        id = "WAND",
        name = GameTextGet( "$item_wand" ),
        is_wand = true, is_quickest = true,
        -- deep_processing = true, is_potion = false, is_spell = false,

        on_check = function( item_id )
            local abil_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" )
            return pen.vld( abil_comp, true ) and ComponentGetValue2( abil_comp, "use_gun_script" )
        end,
        on_info_name = function( item_id, item_comp, default_name )
            local name = index.get_entity_name( item_id, item_comp, EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" ))
            return pen.vld( name ) and name or default_name
        end,
        on_data = function( info, wip_item_list )
            local xD = index.D
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
                reload_frame = math.max( ComponentGetValue2( info.AbilityC, "mReloadNextFrameUsable" ) - xD.frame_num, 0 ),
                delay_frame = math.max( ComponentGetValue2( info.AbilityC, "mNextFrameUsable" ) - xD.frame_num, 0 ),

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
            local update_func = function( inv_info, info_old, info_new ) return pen.vld( inv_info.in_hand, true ) end
            local sort_func = function( a, b )
                local inv_slot = { 0, 0 }
                local is_perma = { false, false }
                pen.t.loop({ a, b }, function( i,v )
                    local item_comp = EntityGetFirstComponentIncludingDisabled( v, "ItemComponent" )
                    if( not( pen.vld( item_comp, true ))) then return end
                    is_perma[i] = ComponentGetValue2( item_comp, "permanently_attached" )
                    inv_slot[i] = math.max( ComponentGetValue2( item_comp, "inventory_slot" ), 0 )
                end)
                return ( is_perma[1] and not( is_perma[2])) or ( not( is_perma[2]) and inv_slot[1] < inv_slot[2])
            end
            
            xD.invs_i[ info.id ] = index.get_inv_info(
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

        on_tooltip = index.new_vanilla_wtt,
        on_inventory = function( info, pic_x, pic_y, state_tbl, slot_dims )
            local xD = index.D
            if( not( xD.is_opened )) then return end
            if( not( state_tbl.is_quick )) then return end
            if( not( xD.gmod.allow_wand_editing )) then return end
            pic_x, pic_y = unpack( pen.vld( xD.xys.wands ) and xD.xys.wands or xD.xys.full_inv )
            w, h = xD.wand_func( pic_x - 3*pen.b2n( state_tbl.in_hand ), pic_y + 2, info, state_tbl.in_hand )
            xD.xys.wands = { pic_x, pic_y + h }
        end,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale, slot_dims )
            local xD, xM = index.D, index.M
            local w, h = unpack( slot_dims )
            index.new_slot_pic( pic_x - w/8, pic_y + h/8,
                index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, true, hov_scale, true )
            
            local is_active = pen.vld( hov_func ) and state_tbl.is_hov and state_tbl.is_opened
            index.pinning({ "slot", info.id }, is_active, hov_func, { info, "slot", pic_x - 10, pic_y + 7, pen.LAYERS.TIPS, true })

            if( info.wand_info.actions_per_round > 0 and info.charges < 0 ) then
                info.charges = 0

                local is_empty = false
                for i,col in ipairs( xD.slot_state[ info.id ]) do
                    pen.t.loop( col, function( e, slot )
                        if( not( slot )) then return end
                        local spell_info = pen.t.get( xD.item_list, slot, nil, nil, {})
                        if( not( spell_info.is_spell )) then return end

                        if( spell_info.charges > 0 ) then
                            info.charges = spell_info.charges; return true
                        elseif( info.charges == 0 and spell_info.charges < 0 ) then
                            local is_mod = spell_info.spell_info.type == 2
                            local is_many = spell_info.spell_info.type == 3
                            if( not( is_mod ) and not( is_many )) then info.charges = -1 end
                        end

                        if( not( is_empty )) then is_empty = spell_info.charges == 0 end
                    end)

                    if( info.charges > 0 ) then break end
                end

                if( info.charges == 0 and is_empty ) then info.charges = 0.1 end
            end

            return info
        end,

        on_gui_world = index.new_vanilla_worldtip,
        -- on_gui_pause = function( info ) --should know if is picked or not
        --     return
        -- end,
        on_pickup = function( info, is_post )
            return ({
                function( info ) return 0 end,
                function( info )
                    if( ComponentGetValue2( info.ItemC, "has_been_picked_by_player" )) then return end
                    --EntityLoad( "data/entities/particles/image_emitters/wand_effect.xml", unpack( info.xy ))
                    ComponentSetValue2( info.ItemC, "play_spinning_animation", true )
                end,
            })[ is_post and 2 or 1 ]( info )
        end,
    },
    {
        id = "POTION",
        name = GameTextGet( "$item_potion" ),
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
            
            local name, cap = index.get_entity_name( item_id, item_comp ), ""
            if( pen.vld( EntityGetFirstComponentIncludingDisabled( item_id, "PotionComponent" ), true )) then
                local v, m = pen.get_matter( ComponentGetValue2( matter_comp, "count_per_material_type" ))
                name, cap = index.get_potion_info( item_id, name, v, barrel_size, m )
            end
            return name..( cap or "" )
        end,
        on_data = function( info, wip_item_list )
            info.is_true_potion = pen.vld( EntityGetFirstComponentIncludingDisabled( info.id, "PotionComponent" ), true )

            info.MatterC = EntityGetFirstComponentIncludingDisabled( info.id, "MaterialInventoryComponent" )
            info.matter_info = {
                may_drink = ComponentGetValue2( info.ItemC, "drinkable" ),
                volume = ComponentGetValue2( info.MatterC, "max_capacity" ),
                matter = { pen.get_matter( ComponentGetValue2( info.MatterC, "count_per_material_type" ))}}
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
                info.name, info.fullness = index.get_potion_info( info.id, info.raw_name,
                    math.max( info.matter_info.matter[1], 0 ), info.matter_info.volume, info.matter_info.matter[2]) end
            if( info.matter_info.volume < 0 ) then info.matter_info.volume = info.matter_info.matter[1] end
            
            info.potion_cutout = pen.magic_storage( info.id, "index_off", "value_float" )
            info.potion_cutout = math.floor( info.potion_cutout or ( 3 - pen.b2n( info.matter_info.volume < info.matter_info.matter[1])) + 0.5 )
            
            return info
        end,
        
        on_tooltip = index.new_vanilla_ptt,
        on_inventory = function( info, pic_x, pic_y, state_tbl, slot_dims )
            local w, h = unpack( slot_dims )
            if( state_tbl.is_full ) then return end

            pic_x, pic_y = pic_x + w/2, pic_y + h/2
            w, h = w - 4, h - 4
            pic_x, pic_y = pic_x - w/2, pic_y + h/2

            local k = h/info.matter_info.volume
            local alpha, delta = state_tbl.is_dragged and 0.7 or 0.9, 0
            local size = k*math.min( info.matter_info.matter[1], info.matter_info.volume )
            for i,m in ipairs( info.matter_info.matter[2]) do
                local sz = math.ceil( 2*math.max( math.min( k*m[2], h ), 0.5 ))/2; delta = delta + sz
                pen.new_pixel( pic_x, pic_y - math.min( delta, h ), pen.LAYERS.MAIN + tonumber( "0.001"..i ),
                    pen.get_color_matter( CellFactory_GetName( m[1])), w, sz, alpha )
                if( delta >= h ) then break end
            end

            if(( h - delta ) > 0.5 and math.min( info.matter_info.matter[1]/info.matter_info.volume, 1 ) > 0 ) then
                pen.new_pixel( pic_x, pic_y - ( delta + 0.5 ), pen.LAYERS.MAIN + 0.001, pen.PALETTE.W, w, 0.5 )
            end
        end,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale, slot_dims )
            local xD, xM = index.D, index.M
            local pic_data = pen.cache({ "index_pic_data", info.pic })
            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                hov_func( info, "slot", pic_x - 10, pic_y + 7, pen.LAYERS.TIPS ) end
            if( info.matter_info.matter[1] == 0 ) then info.charges = 0 end

            local is_done = true
            local target_angle = 0
            if( state_tbl.is_dragged ) then
                local w, h = unpack( slot_dims )
                pen.c.dragger_data[ info.id ].off = { -w/2, -h/2 }
                if( pen.vld( drag_func ) and xD.drag_action ) then is_done, target_angle = unpack( drag_func( info )) end
            elseif( pen.vld( rmb_func ) and state_tbl.is_rmb and state_tbl.is_quick ) then rmb_func( info ) end
            if( is_done ) then _,pic_data.dims[2] = pen.get_pic_dims( info.pic ) end
            
            local target_off = 0
            if( not( is_done )) then
                if( not( xD.shift_action )) then
                    target_off = pic_data.dims[2]/2
                else pic_data.dims[2] = pen.estimate( "index_pdrift", { 0, pic_data.dims[2]}, "exp5", 0.5 ) end
            elseif( not( pen.vld( xD.dragger.item_id, true )) or xD.dragger.item_id == info.id ) then
                if( EntityGetIsAlive( xM.john_pouring or 0 )) then EntityKill( xM.john_pouring ); xM.john_pouring = nil end
            end
            
            local angle = 0
            if( state_tbl.is_dragged ) then
                angle = math.rad( pen.estimate( "index_pangle", target_angle, "exp5", 1 ))
                pic_y = pic_y + pen.estimate( "index_sdrift", target_off, "exp5", 1 )
            end
            
            local pic_z = index.slot_z( info.id, pen.LAYERS.ICONS )
            local ratio = math.min( info.matter_info.matter[1]/info.matter_info.volume, 1 )
            pic_x, pic_y = index.new_slot_pic( pic_x, pic_y, pic_z, info.pic, false, hov_scale, false, 0.8 - 0.5*ratio, angle )
            pen.new_image( pic_x, pic_y, pic_z - 0.01, info.pic,
                { color = pen.magic_uint( GameGetPotionColorUint( info.id )), s_x = hov_scale, s_y = hov_scale, angle = angle })
            return info, info.matter_info.matter[1] ~= 0, true
        end,

        on_action = function( type )
            return ({
                function( info )
                    local xD = index.D
                    if( not( info.matter_info.may_drink )) then return end
                    if( info.matter_info.matter[1] > 0 ) then
                        index.play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink" })
                        pen.magic_chugger( info.matter_info.matter[2],
                            xD.player_id, info.id, info.matter_info.volume, xD.shift_action and 1 or 0.1 )
                    else index.play_sound({ "data/audio/Desktop/misc.bank", "misc/potion_drink_empty" }) end
                end,
                function( info )
                    local xD, xM = index.D, index.M
                    local out = { true, 0 }
                    
                    local x, y = unpack( xD.player_xy )
                    local p_x, p_y = unpack( xD.pointer_world )
                    if( RaytraceSurfaces( x, y, p_x, p_y )) then return out end
                    
                    if( not( EntityGetIsAlive( xM.john_pouring or 0 ))) then
                        xM.john_pouring = EntityLoad( "mods/index_core/files/misc/potion_nerd.xml", x, y )
                        if( pen.vld( info.spray_info )) then
                            local loop_comp = EntityGetFirstComponentIncludingDisabled( xM.john_pouring, "AudioLoopComponent" )
                            ComponentSetValue2( loop_comp, "file", info.spray_info[1])
                            ComponentSetValue2( loop_comp, "event_name", info.spray_info[2])
                        end
                    end
                    EntitySetTransform( xM.john_pouring, p_x, p_y )

                    local volume = info.matter_info.volume
                    local matter = info.matter_info.matter
                    if( xD.shift_action ) then
                        out[1], out[2] = false, 45 + 90*( 1 - math.min( matter[1]/volume, 1 ))
                        
                        if( matter[1] == 0 ) then return out end
                        GameEntityPlaySoundLoop( xM.john_pouring, "spray", 1 )
                        if( xD.frame_num%5 == 0 ) then pen.magic_chugger( matter[2], xD.pointer_world, info.id, volume ) end
                    elseif( pen.vld( info.bottle_info )) then
                        out[1] = false
                        
                        local sucker_comp = EntityGetFirstComponentIncludingDisabled( xM.john_pouring, "MaterialSuckerComponent" )
                        if( EntityGetName( xM.john_pouring ) ~= "done" ) then
                            EntitySetName( xM.john_pouring, "done" )
                            ComponentSetValue2( sucker_comp, "suck_tag", info.bottle_info.tag )
                            ComponentSetValue2( sucker_comp, "material_type", info.bottle_info.type )
                            ComponentSetValue2( sucker_comp, "barrel_size", info.bottle_info.capacity )
                            ComponentSetValue2( sucker_comp, "num_cells_sucked_per_frame", info.bottle_info.speed )
                            ComponentSetValue2( sucker_comp, "suck_static_materials", info.bottle_info.may_static )
                        end

                        local do_sound = false
                        local mtr_comp = EntityGetFirstComponentIncludingDisabled( xM.john_pouring, "MaterialInventoryComponent" )
                        pen.hallway( function()
                            if( not( ComponentGetIsEnabled( mtr_comp ))) then return end
                            local total, mttrs = pen.get_matter( ComponentGetValue2( mtr_comp, "count_per_material_type" ))
                            if( total == 0 ) then return end
                            
                            pen.t.loop( mttrs, function( i,m )
                                if( m[2] == 0 ) then return end
                                local name = CellFactory_GetName( m[1])
                                if( matter[1] < volume ) then
                                    local temp = math.min( matter[1] + m[2], volume )
                                    local count = temp - matter[1]; matter[1] = temp
                                    local _,pm = pen.t.get( matter[2], m[1])

                                    do_sound, pm = true, matter[2][ pm or -1 ] or { 0, 0 }
                                    AddMaterialInventoryMaterial( info.id, name, pm[2] + count )
                                end
                                AddMaterialInventoryMaterial( xM.john_pouring, name, 0 )
                            end)

                            info.matter_info.matter[1] = matter[1]
                        end)
                        
                        EntitySetComponentIsEnabled( xM.john_pouring, sucker_comp, matter[1] < volume )
                        if( not( do_sound and xD.frame_num%5 == 0 )) then return out end
                        
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

        on_gui_world = index.new_vanilla_worldtip,
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
    },
    {
        id = "SPELL",
        name = string.sub( string.lower( GameTextGet( "$hud_title_actionstorage" )), 1, -2 ),
        is_spell = true,

        on_check = function( item_id )
            if( EntityHasTag( item_id, "card_action" )) then return true end
            return pen.vld( EntityGetFirstComponentIncludingDisabled( item_id, "ItemActionComponent" ), true )
        end,
        on_data = function( info, wip_item_list )
            local xD = index.D
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
            if( pen.vld( parent_id, true ) and pen.vld( xD.invs[ parent_id ])) then
                parent_id = pen.t.get( wip_item_list, parent_id, nil, nil, {})
                if( parent_id.is_wand ) then info.in_wand = parent_id.id end
            end

            local may_use = pen.vld( info.AbilityC, true )
            may_use = may_use and GameGetGameEffectCount( xD.player_id, "ABILITY_ACTIONS_MATERIALIZED" ) > 0
            may_use = may_use and ComponentGetValue2( info.AbilityC, "use_entity_file_as_projectile_info_proxy" )
            if( may_use ) then info.inv_cat = 0 end
            return info
        end,
        on_processed = function( info )
            local pic_comp = EntityGetFirstComponentIncludingDisabled( info.id, "SpriteComponent", "item_unidentified" )
            if( pen.vld( pic_comp, true )) then EntityRemoveComponent( info.id, pic_comp ) end
        end,

        on_tooltip = index.new_vanilla_stt,
        on_slot_check = function( info, inv_info )
            return pen.t.get( inv_info.kind, "quickest" ) == 0
        end,
        on_swap = function( info, slot_data )
            local xD = index.D
            if( xD.active_item == info.id ) then pen.reset_active_item( xD.player_id ) end
        end,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale, slot_dims )
            local xD, xM = index.D, index.M
            local angle, anim_speed = 0, xD.spell_anim_frames
            local is_considered = state_tbl.is_dragged or state_tbl.is_hov
            if( state_tbl.can_drag ) then
                angle = -math.rad( 5 )
                if( not( is_considered )) then
                    angle = anim_speed == 0 and 0 or angle*math.sin(( xD.frame_num%anim_speed )*math.pi/anim_speed )
                else angle = 1.5*angle end
            end
            
            local pic_z = index.slot_z( info.id, pen.LAYERS.ICONS )
            index.new_slot_pic( pic_x, pic_y, pic_z, info.pic, false, hov_scale, false, nil, angle )
            if( is_considered ) then pen.colourer( nil, pen.PALETTE.VNL.DARK_SLOT ) end
            index.new_spell_frame( pic_x, pic_y,
                pen.LAYERS[ is_considered and "ICONS" or "ICONS_FRONT" ], info.spell_info.type, is_considered and 0.6 or 1 )

            local is_active = pen.vld( hov_func ) and state_tbl.is_hov and state_tbl.is_opened
            index.pinning({ "slot", info.id }, is_active, hov_func, { info, "slot", pic_x - 10, pic_y + 7, pen.LAYERS.TIPS, true })

            return info, ( state_tbl.is_hov and state_tbl.can_drag ) and 1 or nil
        end,

        on_gui_world = index.new_vanilla_worldtip,
    },
    {
        id = "TABLET",
        name = GameTextGet( "$index_cat_tablet" ),

        on_check = function( item_id )
            return pen.vld( EntityGetFirstComponentIncludingDisabled( item_id, "BookComponent" ), true )
        end,
        
        on_tooltip = index.new_vanilla_ttt,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale, slot_dims )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, false, hov_scale )
            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                hov_func( info, "slot", pic_x - 10, pic_y + 7, pen.LAYERS.TIPS ) end
            return info, true
        end,

        on_gui_world = index.new_vanilla_worldtip,
    },
    {
        id = "ITEM",
        name = GameTextGet( "$mat_item_box2d" ),

        on_check = function( item_id ) return true end,
        on_data = function( info, wip_item_list )
            local xD = index.D
            if( not( EntityHasTag( info.id, "this_is_sampo" ))) then return info end
            if( EntityGetRootEntity( info.id ) == xD.player_id ) then xD.sampo = info.id end
            info.inv_cat = 0
            return info
        end,
        
        on_tooltip = index.new_vanilla_itt,
        on_slot = function( info, pic_x, pic_y, state_tbl, rmb_func, drag_func, hov_func, hov_scale, slot_dims )
            index.new_slot_pic( pic_x, pic_y, index.slot_z( info.id, pen.LAYERS.ICONS ), info.pic, false, hov_scale )
            if( state_tbl.is_opened and state_tbl.is_hov and pen.vld( hov_func )) then
                hov_func( info, "slot", pic_x - 10, pic_y + 7, pen.LAYERS.TIPS ) end
            return info
        end,

        on_gui_world = index.new_vanilla_worldtip,
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
    },
}

local GUI_STRUCT = {
    slot = index.new_vanilla_slot,
    icon = index.new_vanilla_icon,
    tooltip = pen.new_tooltip,
    box = index.new_vanilla_box,
    wand = index.new_vanilla_wand,

    gmodder = index.new_generic_gmod,
    logger = index.new_generic_logger,
    full_inv = index.new_generic_inventory,
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
        aa_readme = function( screen_w, screen_h, xys ) --allow appending to README
            --? menu where all the controls will be described (+ some quick settings and settings refresh button; put README menu in custom)
            return { 0, 0 }
        end,
    },
}

--<{> MAGICAL APPEND MARKER <}>--

return {
    GLOBAL_MODES, GLOBAL_MUTATORS, APPLETS,
    BOSS_BARS, WAND_STATS, SPELL_STATS, MATTER_DESCS,
    ITEM_CATS, GUI_STRUCT
}