dofile_once( "mods/penman/_penman.lua" )
dofile_once( "data/scripts/lib/utilities.lua" )

type2frame = {
	[0] = { "data/ui_gfx/inventory/item_bg_projectile.png", {90,35,35}}, --ACTION_TYPE_PROJECTILE
	[1] = { "data/ui_gfx/inventory/item_bg_static_projectile.png", {141,63,24}}, --ACTION_TYPE_STATIC_PROJECTILE
	[2] = { "data/ui_gfx/inventory/item_bg_modifier.png", {45,58,114}}, --ACTION_TYPE_MODIFIER
	[3] = { "data/ui_gfx/inventory/item_bg_draw_many.png", {28,109,115}}, --ACTION_TYPE_DRAW_MANY
	[4] = { "data/ui_gfx/inventory/item_bg_material.png", {53,111,68}}, --ACTION_TYPE_MATERIAL
	[5] = { "data/ui_gfx/inventory/item_bg_utility.png", {123,42,116}}, --ACTION_TYPE_UTILITY
	[6] = { "data/ui_gfx/inventory/item_bg_passive.png", {33,47,38}}, --ACTION_TYPE_PASSIVE
	[7] = { "data/ui_gfx/inventory/item_bg_other.png", {113,75,51}}, --ACTION_TYPE_OTHER
}

-- b2n
-- get_sign
-- float_compare
-- t2w
-- uint2color
-- rotate_offset
-- limiter
-- check_bounds
-- table_init
-- magic_copy
-- magic_sorter
-- generic_random
-- get_table_count
-- get_most_often
-- from_tbl_with_id
-- D_extractor
-- D_packer
-- clean_append
-- get_storage
-- edit_component_ultimate
-- edit_component_with_tag_ultimate
-- closest_getter
-- get_hooman_child
-- child_play
-- child_play_full
-- get_child_num
-- lua_callback
-- play_sound
-- active_item_reset
-- get_active_item
-- get_item_owner
-- is_wand_useless
-- get_tinker_state
-- get_phys_mass
-- get_matters
-- world2gui
-- get_text_dim
-- get_pic_dim
-- get_mouse_pos
-- capitalizer
-- space_obliterator
-- font_liner
-- new_font_vanilla_shadow
-- font_extractor
-- font_packer
-- init_metafont
-- test_metafont
-- get_metafont
-- gui_killer
-- colourer
-- new_image
-- new_shaded_image
-- new_button
-- new_dragger
-- new_cutout
-- new_interface

--core backend
function get_button_state( ctrl_comp, btn, frame ) --port this to penman
	return { ComponentGetValue2( ctrl_comp, "mButtonDown"..btn ), ComponentGetValue2( ctrl_comp, "mButtonFrame"..btn ) == frame }
end

function get_discrete_button( entity_id, comp, btn ) --kinda sus
	local id = entity_id..btn
	local state = false
	if( ComponentGetValue2( comp, btn )) then
		if( not( dscrt_btn[id])) then
			state = true
		end
		dscrt_btn[id] = true
	else
		dscrt_btn[id] = false
	end
	
	return state
end

function get_input( vanilla_id, mnee_id, is_continuous, is_dirty ) --definitely replace with mnee
	is_dirty = is_dirty or false
	is_continuous = is_continuous or false
	
	local state = false
	if( ModIsEnabled( "mnee" )) then
		dofile_once( "mods/mnee/lib.lua" )
		state = mnee.mnin_bind( "index_core", mnee_id, is_dirty, not( is_continuous ))
	else
		local kind = ""
		if( type( vanilla_id ) == "table" ) then
			kind = vanilla_id[2]
			vanilla_id = vanilla_id[1]
		end
		state = _G[ "InputIs"..kind..( is_continuous and "Down" or "JustDown" )]( vanilla_id )
	end
	return state
end

function self_destruct()
	local ctrl_bodies = EntityGetWithTag( "index_ctrl" ) or {}
	if( #ctrl_bodies > 0 ) then
		local controller_id = ctrl_bodies[1]
		local hooman = EntityGetRootEntity( controller_id )
		
		local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
		local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
		EntitySetComponentIsEnabled( hooman, iui_comp, true )
		EntitySetComponentIsEnabled( hooman, pick_comp, true )

		EntityKill( get_hooman_child( hooman, "index_ctrl" ))
		EntityRemoveComponent( GetUpdatedEntityID(), GetUpdatedComponentID())
	end
end

--ESC backend
function cat_callback( data, this_info, name, input, sos )
	do_default_callback = false

	local func_local = this_info[ name ]
	if( input == nil ) then
		local func_main = data.item_cats[ this_info.cat ]
		if( func_main ~= nil ) then
			return func_local == nil and func_main[ name ] or func_local
		end
	else
		local out = nil
		if( func_local ~= nil ) then
			out = { func_local( unpack( input ))}
		else
			do_default_callback = true
		end
		if( do_default_callback ) then
			local func_main = data.item_cats[ this_info.cat ][ name ]
			if( func_main ~= nil ) then
				out = { func_main( unpack( input ))}
			end
		end

		out = ( out == nil ) and sos or out
		if( out ) then
			return unpack( out )
		end
	end
end

function clean_my_gun()
	ACTION_DRAW_RELOAD_TIME_INCREASE = 0
	ACTION_MANA_DRAIN_DEFAULT = 10
	ACTION_UNIDENTIFIED_SPRITE_DEFAULT = "data/ui_gfx/gun_actions/unidentified.png"

	reflecting = false
	current_action = nil

	first_shot   = true
	reloading    = false
	start_reload = false
	got_projectiles = false

	state_from_game = nil

	discarded       	= { }
	deck 				= { }
	hand 				= { }

	c                   = { }
	current_projectile  = nil
	current_reload_time =  0
	shot_effects        = { }

	active_extra_modifiers	= { }

	mana = 0.0

	state_shuffled         = false
	state_cards_drawn      = 0
	state_discarded_action = false
	state_destroyed_action = false

	playing_permanent_card = false

	use_game_log = false

	gun = {}
	ConfigGun_Init( gun )
	current_reload_time = 0

	dont_draw_actions = false
	force_stop_draws = false
	shot_structure = {}
	recursion_limit = 2

	root_shot = nil
end

function get_action_data( data, spell_id )
	data.memo.spell_data = data.memo.spell_data or {}
	if( data.memo.spell_data[ spell_id ] == nil or data.memo.spell_data[ spell_id ].hold_up ) then
		dofile_once( "data/scripts/gun/gun.lua" )
		dofile_once( "data/scripts/gun/gun_enums.lua" )
		dofile_once( "data/scripts/gun/gun_actions.lua" )
		clean_my_gun()

		local spell_info = from_tbl_with_id( actions, spell_id )
		data.memo.spell_data[ spell_id ] = magic_copy( spell_info )
		if( spell_info.action ~= nil ) then
			add_projectile_old = add_projectile
			add_projectile = function( path )
				table.insert( c.projs, { 1, path })
			end
			add_projectile_trigger_timer_old = add_projectile_trigger_timer
			add_projectile_trigger_timer = function( path, delay, draw_count )
				c.draw_many = c.draw_many + draw_count
				table.insert( c.projs, { 2, path, draw_count, delay })
			end
			add_projectile_trigger_hit_world_old = add_projectile_trigger_hit_world
			add_projectile_trigger_hit_world = function( path, draw_count )
				c.draw_many = c.draw_many + draw_count
				table.insert( c.projs, { 3, path, draw_count })
			end
			add_projectile_trigger_death_old = add_projectile_trigger_death
			add_projectile_trigger_death = function( path, draw_count )
				c.draw_many = c.draw_many + draw_count
				table.insert( c.projs, { 4, path, draw_count })
			end
			draw_actions_old = draw_actions
			draw_actions = function( draw_count )
				c.draw_many = c.draw_many + draw_count
			end
			dont_draw_actions, reflecting = true, true
			current_reload_time, shot_effects = 0, {}
			ACTION_DRAW_RELOAD_TIME_INCREASE = 1e9

			SetRandomSeed( 0, 0 )
			ConfigGunShotEffects_Init( shot_effects )
			local metadata = create_shot()
			c, metadata.state_proj = metadata.state, {damage={},explosion={},crit={},lightning={}}
			set_current_action( spell_info )
			c.draw_many = 0
			c.projs = {}
			
			pcall( spell_info.action )
			if( spell_info.tip_data ~= nil ) then spell_info.tip_data() end
			if( math.abs( current_reload_time ) > 1e6 ) then
				data.memo.spell_data[ spell_id ].is_chainsaw = true
				current_reload_time = current_reload_time + ACTION_DRAW_RELOAD_TIME_INCREASE
			end
			metadata.state.reload_time, metadata.shot_effects = current_reload_time, magic_copy( shot_effects )
			
			local total_dmg_add, dmg_tbl = 0, {
				"damage_projectile_add", "damage_curse_add", "damage_explosion_add", "damage_slice_add", "damage_poison_add",
				"damage_melee_add", "damage_ice_add", "damage_electricity_add", "damage_drill_add", "damage_radioactive_add",
				"damage_healing_add", "damage_fire_add", "damage_holy_add", "damage_physics_add", "damage_explosion",
			}
			for i,dmg in ipairs( dmg_tbl ) do
				total_dmg_add = total_dmg_add + ( c[dmg] or 0 )
			end
			c.damage_total_add = total_dmg_add
			
			local is_gonna = false
			c.proj_count = #c.projs
			if( c.proj_count > 0 ) then
				local nxml = dofile_once( "mods/index_core/nxml.lua" )
				local xml = nxml.parse( ModTextFileGetContent( c.projs[1][2]))
				local xml_kid = xml:first_of( "ProjectileComponent" )
				if( xml_kid == nil ) then
					xml_kid = xml:first_of( "Base" )
					if( xml_kid ~= nil ) then
						xml_kid = xml_kid:first_of( "ProjectileComponent" )
					end
				end
				if( xml_kid ) then
					metadata.state_proj = {
						damage = {
							curse = 0,
							drill = 0,
							electricity = 0,
							explosion = 0,
							fire = 0,
							healing = 0,
							ice = 0,
							melee = 0,
							overeating = 0,
							physics_hit = 0,
							poison = 0,
							projectile = tonumber( xml_kid.attr.damage or 0 ),
							radioactive = 0,
							slice = 0,
							holy = 0,
						},
						explosion = {},
						crit = {},
						lightning = {},
						laser = {},
						damage_scaled_by_speed = tonumber( xml_kid.attr.damage_scaled_by_speed or 0 ) > 0,
						damage_every_x_frames = tonumber( xml_kid.attr.damage_every_x_frames or -1 ),
						
						lifetime = tonumber( xml_kid.attr.lifetime or -1 ),

						speed = math.floor(( tonumber( xml_kid.attr.speed_min or xml_kid.attr.speed_max or 0 ) + tonumber( xml_kid.attr.speed_max or xml_kid.attr.speed_min or 0 ))/2 + 0.5 ),

						inf_bounces = tonumber( xml_kid.attr.bounce_always or 0 ) > 0,
						bounces = tonumber( xml_kid.attr.bounces_left or 0 ),
						
						on_collision_die = tonumber( xml_kid.attr.on_collision_die or 1 ) > 0,
						on_death_duplicate = tonumber( xml_kid.attr.on_death_duplicate_remaining or 0 ) > 0,
						on_death_explode = tonumber( xml_kid.attr.on_death_explode or 0 ) > 0,
						on_lifetime_out_explode = tonumber( xml_kid.attr.on_lifetime_out_explode or 0 ) > 0,

						collide_with_entities = tonumber( xml_kid.attr.collide_with_entities or 1 ) > 0,
						penetrate_entities = tonumber( xml_kid.attr.penetrate_entities or 0 ) > 0,
						dont_collide_with_tag = xml_kid.attr.dont_collide_with_tag or "",
						never_hit_player = tonumber( xml_kid.attr.never_hit_player or 0 ) > 0,
						friendly_fire = tonumber( xml_kid.attr.friendly_fire or 0 ) > 0,
						explosion_dont_damage_shooter = tonumber( xml_kid.attr.explosion_dont_damage_shooter or 0 ) > 0,

						collide_with_world = tonumber( xml_kid.attr.collide_with_world or 1 ) > 0,
						penetrate_world = tonumber( xml_kid.attr.penetrate_world or 0 ) > 0,
						go_through_this_material = xml_kid.attr.go_through_this_material or "",
						ground_penetration_coeff = tonumber( xml_kid.attr.ground_penetration_coeff or 0 ),
						ground_penetration_max_durability = tonumber( xml_kid.attr.ground_penetration_max_durability_to_destroy or 0 ),
					}

					local dmg_kid = xml_kid:first_of( "damage_by_type" )
					if( dmg_kid ) then
						metadata.state_proj.damage["curse"] = tonumber( dmg_kid.attr.curse or 0 )
						metadata.state_proj.damage["drill"] = tonumber( dmg_kid.attr.drill or 0 )
						metadata.state_proj.damage["electricity"] = tonumber( dmg_kid.attr.electricity or 0 )
						metadata.state_proj.damage["explosion"] = tonumber( dmg_kid.attr.explosion or 0 )
						metadata.state_proj.damage["fire"] = tonumber( dmg_kid.attr.fire or 0 )
						metadata.state_proj.damage["healing"] = tonumber( dmg_kid.attr.healing or 0 )
						metadata.state_proj.damage["ice"] = tonumber( dmg_kid.attr.ice or 0 )
						metadata.state_proj.damage["melee"] = tonumber( dmg_kid.attr.melee or 0 )
						metadata.state_proj.damage["overeating"] = tonumber( dmg_kid.attr.overeating or 0 )
						metadata.state_proj.damage["physics_hit"] = tonumber( dmg_kid.attr.physics_hit or 0 )
						metadata.state_proj.damage["poison"] = tonumber( dmg_kid.attr.poison or 0 )
						metadata.state_proj.damage["projectile"] = metadata.state_proj.damage.projectile + tonumber( dmg_kid.attr.projectile or 0 )
						metadata.state_proj.damage["radioactive"] = tonumber( dmg_kid.attr.radioactive or 0 )
						metadata.state_proj.damage["slice"] = tonumber( dmg_kid.attr.slice or 0 )
						metadata.state_proj.damage["holy"] = tonumber( dmg_kid.attr.holy or 0 )
					end
					local exp_kid = xml_kid:first_of( "config_explosion" )
					if( exp_kid ) then
						metadata.state_proj.explosion = {
							damage_mortals = tonumber( exp_kid.attr.damage_mortals or 1 ) > 0,
							damage = tonumber( exp_kid.attr.damage or 0 ),
							is_digger = tonumber( exp_kid.attr.is_digger or 0 ) > 0,
							explosion_radius = tonumber( exp_kid.attr.explosion_radius or 0 ),
							max_durability_to_destroy = tonumber( exp_kid.attr.max_durability_to_destroy or 0 ),
							ray_energy = tonumber( exp_kid.attr.ray_energy or 0 ),
						}
					end
					local crit_kid = xml_kid:first_of( "damage_critical" )
					if( crit_kid ) then
						metadata.state_proj.crit = {
							chance = tonumber( crit_kid.attr.chance or 0 ),
							damage_multiplier = tonumber( crit_kid.attr.damage_multiplier or 1 ),
						}
					end

					xml_kid = xml:first_of( "LightningComponent" )
					if( xml_kid == nil ) then
						xml_kid = xml:first_of( "Base" )
						if( xml_kid ~= nil ) then
							xml_kid = xml_kid:first_of( "LightningComponent" )
						end
					end
					if( xml_kid ) then
						local lght_kid = xml_kid:first_of( "config_explosion" )
						if( lght_kid ) then
							metadata.state_proj.lightning = {
								damage_mortals = tonumber( lght_kid.attr.damage_mortals or 1 ) > 0,
								damage = tonumber( lght_kid.attr.damage or 0 ),
								is_digger = tonumber( lght_kid.attr.is_digger or 0 ) > 0,
								explosion_radius = tonumber( lght_kid.attr.explosion_radius or 0 ),
								max_durability_to_destroy = tonumber( lght_kid.attr.max_durability_to_destroy or 0 ),
								ray_energy = tonumber( lght_kid.attr.ray_energy or 0 ),
							}
						end
					end

					xml_kid = xml:first_of( "LaserEmitterComponent" )
					if( xml_kid == nil ) then
						xml_kid = xml:first_of( "Base" )
						if( xml_kid ~= nil ) then
							xml_kid = xml_kid:first_of( "LaserEmitterComponent" )
						end
					end
					if( xml_kid ) then
						local laser_kid = xml_kid:first_of( "laser" )
						if( laser_kid ) then
							metadata.state_proj.laser = {
								max_length = tonumber( laser_kid.attr.max_length or 0 ),
								beam_radius = tonumber( laser_kid.attr.beam_radius or 0 ),
								damage_to_entities = tonumber( laser_kid.attr.damage_to_entities or 0 ),
								damage_to_cells = tonumber( laser_kid.attr.damage_to_cells or 0 ),
								max_cell_durability_to_destroy = tonumber( laser_kid.attr.max_cell_durability_to_destroy or 0 ),
							}
						end
					end
					
					local total_dmg = 0
					for field,dmg in pairs( metadata.state_proj.damage ) do
						total_dmg = total_dmg + dmg
					end
					if( metadata.state_proj.explosion.damage_mortals ) then
						total_dmg = total_dmg + ( metadata.state_proj.explosion.damage or 0 )
					end
					if( metadata.state_proj.lightning.damage_mortals ) then
						total_dmg = total_dmg + ( metadata.state_proj.lightning.damage or 0 )
					end
					metadata.state_proj.damage["total"] = total_dmg
				end
			end

			ACTION_DRAW_RELOAD_TIME_INCREASE, c = 0, nil
			add_projectile = add_projectile_old
			add_projectile_trigger_timer = add_projectile_trigger_timer_old
			add_projectile_trigger_hit_world = add_projectile_trigger_hit_world_old
			add_projectile_trigger_death = add_projectile_trigger_death_old
			draw_actions = draw_actions_old
			clean_my_gun()

			data.memo.spell_data[ spell_id ].meta = magic_copy( metadata )
			data.memo.spell_data[ spell_id ].hold_up = is_gonna
		end
	end
	return data, data.memo.spell_data[ spell_id ]
end

function chugger_3000( mouth_id, cup_id, total_vol, mtr_list, perc ) --kinda sus
	perc = perc or 0.1
	
	local gonna_pour = type( mouth_id ) == "table"
	if( gonna_pour ) then
		perc = 9/total_vol
	end
	
	local to_drink = total_vol*perc
	local min_vol = math.ceil( to_drink*perc )
	if( #mtr_list > 0 ) then
		for i = #mtr_list,1,-1 do
			local mtr = mtr_list[i]
			if( mtr[2] > 0 ) then
				local count = math.floor( mtr[2]*perc )
				if( i == 1 ) then count = to_drink end
				count = math.min( math.max( count, min_vol ), mtr[2])

				local name = CellFactory_GetName( mtr[1])
				if( gonna_pour ) then
					local temp = to_drink - 1
					for i = 1,count do
						local off_x, off_y = -1.5 + temp%3, -1.5 + math.floor( temp/3 )%4
						GameCreateParticle( name, mouth_id[1] + off_x, mouth_id[2] + off_y, 1, 0, 0, false, false, false )
						temp = temp - 1
					end
				else
					EntityIngestMaterial( mouth_id, mtr[1], count )
				end
				AddMaterialInventoryMaterial( cup_id, name, math.floor( mtr[2] - count + 0.5 ))

				to_drink = to_drink - count
				if( to_drink <= 0 ) then
					break
				end
			end
		end
	end
end

--Inventory pipeline
function get_valid_inventories( inv_type, is_quickest )
	local inv_ids = {}
	if( math.floor( inv_type ) == 0 ) then
		table.insert( inv_ids, "full" )
	end
	if( math.ceil( inv_type ) == 0 ) then
		table.insert( inv_ids, "quick" )
		table.insert( inv_ids, "quickest" )
	end
	if( inv_type == -1 ) then
		table.insert( inv_ids, is_quickest and "quickest" or "quick" )
	end

	return inv_ids
end

function get_inv_info( inv_id, slot_count, kind, kind_func, check_func, update_func, gui_func, sort_func )
	local storage_kind = get_storage( inv_id, "index_kind" )
	if( storage_kind ~= nil ) then
		kind = D_extractor( ComponentGetValue2( storage_kind, "value_string" ))
	end
	local storage_kind_func = get_storage( inv_id, "index_kind_func" )
	if( storage_kind_func ~= nil ) then
		kind_func = dofile( ComponentGetValue2( storage_kind_func, "value_string" ))
	end
	local storage_size = get_storage( inv_id, "index_size" )
	if( storage_size ~= nil ) then
		slot_count = D_extractor( ComponentGetValue2( storage_size, "value_string" ), true )
	end
	local storage_gui = get_storage( inv_id, "index_gui" )
	if( storage_gui ~= nil ) then
		gui_func = dofile_once( ComponentGetValue2( storage_gui, "value_string" ))
	end
	local storage_check = get_storage( inv_id, "index_check" )
	if( storage_check ~= nil ) then
		check_func = dofile_once( ComponentGetValue2( storage_check, "value_string" ))
	end
	local storage_update = get_storage( inv_id, "index_update" )
	if( storage_update ~= nil ) then
		update_func = dofile_once( ComponentGetValue2( storage_update, "value_string" ))
	end
	local storage_sort = get_storage( inv_id, "index_sort" )
	if( storage_sort ~= nil ) then
		sort_func = dofile_once( ComponentGetValue2( storage_sort, "value_string" ))
	end
	
	local inv_ts = {
		inventory_full = { "full" },
		inventory_quick = { "quick", slot_count[1] > 0 and "quickest" or nil },
	}
	return {
		id = inv_id,
		kind = kind or inv_ts[ EntityGetName( inv_id )] or { "universal" },
		kind_func = kind_func,
		size = slot_count,
		func = gui_func,
		check = check_func,
		update = update_func,
		sort = sort_func,
	}
end

function is_inv_empty( slot_state )
	local is_empty = true
	for i,col in pairs( slot_state ) do
		for e,slot in ipairs( col ) do
			if( slot ) then
				is_empty = false
				break
			end
		end
	end

	return is_empty
end

function inv_check( data, this_info, inv_info )
	if(( this_info.id or 0 ) < 0 ) then
		return true
	end
	if( this_info.id == inv_info.inv_id ) then
		return false
	end

	local kind_memo = inv_info.kind
	local inv_data = inv_info.full or data.inventories[ inv_info.inv_id ]
	inv_info.kind = inv_data.kind_func ~= nil and inv_data.kind_func( inv_info ) or inv_data.kind
	
	local val = (( from_tbl_with_id( inv_info.kind, "universal" ) ~= 0 ) or #from_tbl_with_id( get_valid_inventories( this_info.inv_type, this_info.is_quickest ), inv_info.kind ) > 0 ) and ( inv_data.check == nil or inv_data.check( this_info, inv_info ))
	if( val ) then
		val = cat_callback( data, this_info, "on_inv_check", {
			data, this_info, inv_info
		}, { val })
	end
	
	inv_info.kind = kind_memo
	return val
end

function slot_swap_check( data, item_in, item_out, slot_data )
	local inv_memo, slot_memo = item_out.inv_id, item_out.inv_slot
	item_out.inv_id, item_out.inv_slot = item_out.inv_id or slot_data.inv_id, item_out.inv_slot or slot_data.inv_slot
	local val = inv_check( data, item_in, item_out ) and inv_check( data, item_out, item_in )
	item_out.inv_id, item_out.inv_slot = inv_memo, slot_memo
	return val
end

function inventory_boy( item_id, data, this_info, in_hand )
	local in_wand = ( this_info.in_wand or 0 ) > 0
	if( in_wand or in_hand == nil ) then
		local wand_id = in_wand and this_info.in_wand or item_id
		in_hand = get_item_owner( wand_id ) > 0
	end
	
	local hooman = EntityGetRootEntity( item_id )
	local is_free = hooman == item_id
	local comps = EntityGetAllComponents( item_id ) or {}
	if( #comps > 0 ) then
		for i,comp in ipairs( comps ) do
			local world_check, inv_check, hand_check = false, false, false
			if( not( ComponentHasTag( comp, "not_enabled_in_wand" ) and in_wand )) then
				world_check = ComponentHasTag( comp, "enabled_in_world" ) and is_free
				inv_check = ComponentHasTag( comp, "enabled_in_inventory" ) and not( is_free )
				hand_check = ComponentHasTag( comp, "enabled_in_hand" ) and in_hand
			end
			EntitySetComponentIsEnabled( item_id, comp, world_check or inv_check or hand_check )
		end
	end

	if( not( is_free )) then
		if( not( in_hand ) or get_active_item( get_item_owner( item_id )) ~= item_id ) then
			if( in_hand ) then hooman = EntityGetParent( item_id ) end
			local x, y = EntityGetTransform( hooman )
			EntitySetTransform( item_id, x, y )
			EntityApplyTransform( item_id, x, y )
		end
	end
end

function inventory_man( item_id, data, this_info, in_hand, force_full )
	force_full = force_full or false
	child_play_full( item_id, function( child, params )
		inventory_boy( child, unpack( params ))
		if( not( force_full ) and data.inventories[ child ] ~= nil ) then
			return true
		end
	end, { data, this_info, in_hand })
end

function set_to_slot( this_info, data, is_player )
	if( is_player == nil ) then
		local parent_id = EntityGetParent( this_info.id )
		is_player = data.inventories_player[1] == parent_id or data.inventories_player[2] == parent_id
	end
	
	local valid_invs = get_valid_inventories( this_info.inv_type, this_info.is_quickest )
	local slot_num = { ComponentGetValue2( this_info.ItemC, "inventory_slot" )}
	local is_hidden = slot_num[1] == -1 and slot_num[2] == -1
	if( not( is_hidden )) then
		if( slot_num[2] == -5 ) then
			if( this_info.is_hidden ) then
				slot_num = {-1,-1}
			else
				local inv_list = nil
				if( is_player ) then
					inv_list = data.inventories_player
				else
					inv_list = { this_info.inv_id }
				end
				for _,inv_id in ipairs( inv_list ) do
					local inv_dt = data.inventories[ inv_id ]
					if( from_tbl_with_id( inv_dt.kind, "universal" ) ~= 0 or #from_tbl_with_id( valid_invs, inv_dt.kind ) > 0 ) then
						for i,slot in pairs( data.slot_state[ inv_id ]) do
							for k,s in ipairs( slot ) do
								if( not( s )) then
									local is_fancy = type( i ) == "string"
									if( not( is_fancy and from_tbl_with_id( valid_invs, i ) == 0 )) then
										local temp_slot = is_fancy and { k, i == "quickest" and -1 or -2 } or { i, k }
										if( inv_check( data, this_info, { inv_id = inv_id, inv_slot = temp_slot, full = inv_dt, })) then
											if( temp_slot[2] < 0 ) then
												temp_slot[2] = temp_slot[2] + 1
											end
											
											local parent_check = EntityGetParent( this_info.id )
											if( parent_check > 0 and inv_id ~= parent_check) then
												EntityRemoveFromParent( this_info.id )
												EntityAddChild( inv_id, this_info.id )
											end

											slot_num = temp_slot
											data.slot_state[ inv_id ][i][k] = this_info.id
											break
										end
									end
								end
							end
							if( slot_num[2] ~= -5 ) then
								break
							end
						end
					end
					if( slot_num[2] ~= -5 ) then
						break
					end
				end
				if( slot_num[2] == -5 ) then
					return this_info
				end
			end

			slot_num[1], slot_num[2] = slot_num[1] - 1, slot_num[2] - 1
			ComponentSetValue2( this_info.ItemC, "inventory_slot", slot_num[1], slot_num[2])
		elseif( slot_num[2] == -1 ) then
			data.slot_state[ this_info.inv_id ].quickest[ slot_num[1] + 1 ] = this_info.id
			this_info.inv_kind = "quickest"
		elseif( slot_num[2] == -2 ) then
			data.slot_state[ this_info.inv_id ].quick[ slot_num[1] + 1 ] = this_info.id
			this_info.inv_kind = "quick"
		elseif( slot_num[2] >= 0 ) then
			data.slot_state[ this_info.inv_id ][ slot_num[1] + 1 ][ slot_num[2] + 1 ] = this_info.id
			this_info.inv_kind = this_info.inv_kind[1]
		end

		slot_num[1], slot_num[2] = slot_num[1] + 1, slot_num[2] < 0 and slot_num[2] or slot_num[2] + 1
	end
	
	this_info.inv_slot = slot_num
	return this_info
end

function slot_swap( data, item_in, slot_data )
	local reset = { 0, 0 }

	local parent1 = EntityGetParent( item_in )
	local parent2 = slot_data.inv_id
	local tbl = { parent1, parent2 }
	local idata = {
		from_tbl_with_id( data.item_list, item_in, nil, nil, {}),
		from_tbl_with_id( data.item_list, slot_data.id, nil, nil, {}),
	}
	for i = 1,2 do
		local p = tbl[i]
		if( p > 0 ) then
			local p_info = data.inventories[p] or {}
			if( p_info.update ~= nil ) then
				if( p_info.update( data, from_tbl_with_id( data.item_list, p, nil, nil, p_info ), idata[(i+1)%2+1], idata[i%2+1])) then
					table.insert( reset, get_item_owner( p, true ))
				end
			end
		end
	end
	if( parent1 ~= parent2 ) then
		reset[1] = get_item_owner( item_in )
		EntityRemoveFromParent( item_in )
		EntityAddChild( parent2, item_in )
		if( slot_data.id > 0 ) then
			reset[2] = get_item_owner( slot_data.id )
			EntityRemoveFromParent( slot_data.id )
			EntityAddChild( parent1, slot_data.id )
		end
	end
	
	local item_comp1 = EntityGetFirstComponentIncludingDisabled( item_in, "ItemComponent" )
	local slot1 = { ComponentGetValue2( item_comp1, "inventory_slot" )}
	local slot2 = slot_data.inv_slot
	ComponentSetValue2( item_comp1, "inventory_slot", slot2[1] - 1, slot2[2] < 0 and slot2[2] or slot2[2] - 1 )
	if( slot_data.id > 0 ) then
		local item_comp2 = EntityGetFirstComponentIncludingDisabled( slot_data.id, "ItemComponent" )
		ComponentSetValue2( item_comp2, "inventory_slot", unpack( slot1 ))
	end
	
	for i = 1,2 do
		local this_info = idata[i]
		if(( this_info.id or 0 ) > 0 ) then
			cat_callback( data, this_info, "on_inv_swap", { data, this_info, slot_data })
		end
	end
	for i,deadman in pairs( reset ) do
		if( deadman > 0 ) then
			active_item_reset( deadman )
		end
	end
end

function check_item_name( name )
	return pen.vld( name ) and ( string.find( name, "%$" ) ~= nil or string.find( name, "%w_%w" ) == nil )
end

function get_entity_name( entity_id, item_comp, abil_comp )
	local name = item_comp == nil and "" or ComponentGetValue2( item_comp, "item_name" )

	local info_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "UIInfoComponent" )
	if( info_comp ~= nil ) then
		local temp = ComponentGetValue2( info_comp, "name" )
		name = check_item_name( temp ) and temp or name
	elseif( abil_comp ~= nil ) then
		local temp = ComponentGetValue2( abil_comp, "ui_name" )
		name = check_item_name( temp ) and temp or name
	end
	if( not( check_item_name( name ))) then
		local temp = EntityGetName( entity_id )
		name = check_item_name( temp ) and temp or name
	end

	return check_item_name( name ) and string.gsub( GameTextGetTranslatedOrNot( name ), "(%s*)%$0(%s*)", "" ) or "", name
end

function get_potion_info( entity_id, name, max_count, total_count, matters )
	local info = ""
	
	local cnt = 1
	for i,mtr in ipairs( matters ) do
		if( i == 1 or mtr[2] > 5 ) then
			info = info..( i == 1 and "" or "+" )..capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( mtr[1])))
			cnt = cnt + 1
			if( cnt > 3 ) then break end
		end
	end
	
	local v = nil
	if( max_count > 0 ) then
		v = GameTextGet( "$item_potion_fullness", tostring( math.floor( 100*total_count/max_count + 0.5 )))
	end

	if( string.sub(name,1,1) == "$" ) then
		name = capitalizer( GameTextGet( name, ( info == "" and GameTextGetTranslatedOrNot( "$item_potion_empty" ) or info )))
	else
		name = string.gsub( GameTextGetTranslatedOrNot( name ), " %(%)", "" )
	end
	return info..( info == "" and info or " " )..name, v
end

function get_item_data( item_id, data, inventory_data, item_list )
	local this_info = { id = item_id, }
	if( inventory_data ~= nil ) then
		this_info.inv_id = inventory_data.id
		this_info.inv_kind = inventory_data.kind
	end
	
	local item_comp = EntityGetFirstComponentIncludingDisabled( item_id, "ItemComponent" )
	if( item_comp == nil ) then
		return data, {}
	end
	
	local abil_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" )
	if( abil_comp ~= nil ) then
		this_info.AbilityC = abil_comp
		-- this_info.charges = {
		-- 	ComponentGetValue2( abil_comp, "shooting_reduces_amount_in_inventory" ),
		-- 	ComponentGetValue2( abil_comp, "max_amount_in_inventory" ),
		-- 	ComponentGetValue2( abil_comp, "amount_in_inventory" ),
		-- }
		this_info.pic = ComponentGetValue2( abil_comp, "sprite_file" )
		this_info.is_throwing = ComponentGetValue2( abil_comp, "throw_as_item" )
		if( this_info.is_throwing ) then
			local comps = EntityGetComponentIncludingDisabled( item_id, "LuaComponent" ) or {}
			if( #comps > 0 ) then
				for i,comp in ipairs( comps ) do
					local path = ComponentGetValue2( comp, "script_kick" ) or ""
					if( path ~= "" ) then
						this_info.is_kicking = true
						break
					end
				end
			end
		end
		this_info.uses_rmb = EntityHasTag( item_id, "index_has_rbm" ) or this_info.is_throwing
	end
	if( item_comp ~= nil ) then
		this_info.ItemC = item_comp

		local invs = { QUICK=-1, TRUE_QUICK=-0.5, ANY=0, FULL=0.5, }
		local storage_inv = get_storage( item_id, "preferred_inventory" )
		local inv_name = storage_inv == nil and ComponentGetValue2( item_comp, "preferred_inventory" ) or ComponentGetValue2( storage_inv, "value_string" )
		this_info.inv_type = invs[inv_name] or 0
		
		local ui_pic = ComponentGetValue2( item_comp, "ui_sprite" ) or ""
		if( ui_pic ~= "" ) then
			this_info.pic = ui_pic
		end

		this_info.desc = full_stopper( GameTextGetTranslatedOrNot( ComponentGetValue2( item_comp, "ui_description" )))
		-- this_info.is_stackable = ComponentGetValue2( item_comp, "is_stackable" )
		this_info.is_consumable = ComponentGetValue2( item_comp, "is_consumable" )
		
		this_info.is_frozen = ComponentGetValue2( item_comp, "is_frozen" )
		this_info.is_permanent = ComponentGetValue2( item_comp, "permanently_attached" )
		this_info.is_locked = this_info.is_permanent
		if( EntityHasTag( item_id, "index_unlocked" )) then
			this_info.is_locked = false
		elseif( EntityHasTag( item_id, "index_locked" )) then
			this_info.is_locked = true
		end

		local storage_charges = get_storage( item_id, "current_charges" )
		this_info.charges = storage_charges == nil and ComponentGetValue2( item_comp, "uses_remaining" ) or ComponentGetValue2( storage_charges, "value_int" )

		local callback_list = {
			-- "on_check",
			-- "on_info_name",
			"on_data",
			"on_processed",
			"on_processed_forced",
			"ctrl_script",

			"on_inv_check",
			"on_inv_swap",
			"on_inventory",
			"on_tooltip",
			"on_slot",

			"on_equip",
			"on_action",
			"on_pickup",
			"on_drop",

			"on_gui_pause",
			"on_gui_world",
		}
		data.memo.cbk_tbl = data.memo.cbk_tbl or {}
		data.memo.cbk_tbl[ item_id ] = data.memo.cbk_tbl[ item_id ] or {}
		for k,callback in ipairs( callback_list ) do
			if( data.memo.cbk_tbl[ item_id ][ callback ] == nil ) then
				local storage = get_storage( item_id, callback )
				if( storage ~= nil ) then
					data.memo.cbk_tbl[ item_id ][ callback ] = dofile_once( ComponentGetValue2( storage, callback ))
				end
			end
			this_info[ callback ] = data.memo.cbk_tbl[ item_id ][ callback ]
		end
	end
	
	for k,cat in ipairs( data.item_cats ) do
		if( cat.on_check( item_id )) then
			this_info.cat = k
			this_info.is_wand = cat.is_wand or false
			this_info.is_potion = cat.is_potion or false
			this_info.is_spell = cat.is_spell or false
			this_info.is_quickest = cat.is_quickest or false
			this_info.is_hidden = cat.is_hidden or false
			this_info.do_full_man = cat.do_full_man or false
			this_info.advanced_pic = cat.advanced_pic or false
			break
		end
	end
	this_info.name, this_info.raw_name = get_entity_name( item_id, item_comp, abil_comp )
	if( this_info.cat == nil ) then
		return data, {}
	elseif(( this_info.name or "" ) == "" ) then
		this_info.name = data.item_cats[ this_info.cat ].name
	end
	this_info.name = capitalizer( this_info.name )
	
	dofile_once( "data/scripts/gun/gun.lua" )
	dofile_once( "data/scripts/gun/gun_enums.lua" )
	dofile_once( "data/scripts/gun/gun_actions.lua" )
	data, this_info = cat_callback( data, this_info, "on_data", {
		item_id, data, this_info, item_list or {}
	}, { data, this_info })
	
	local wand_id = ( this_info.in_wand or false ) and this_info.in_wand or item_id
	this_info.in_hand = get_item_owner( wand_id )
	
	return data, this_info
end

function get_items( hooman, data )
	local item_tbl = {}
	for k = 1,2 do
		local tbl = { "inventories", "inventories_init" }
		for i,inv_info in pairs( data[ tbl[k]]) do
			if( k == 2 ) then
				data.inventories[i] = inv_info
			end
			
			child_play( inv_info.id, function( parent, child, j )
				local new_info = nil
				data, new_info = get_item_data( child, data, inv_info, item_tbl )
				if( new_info.id ~= nil ) then
					if( not( EntityHasTag( new_info.id, "index_processed" ))) then
						cat_callback( data, new_info, "on_processed", { new_info.id, data, new_info })
						
						ComponentSetValue2( new_info.ItemC, "inventory_slot", -5, -5 )
						EntityAddTag( new_info.id, "index_processed" )
					end
					cat_callback( data, new_info, "on_processed_forced", { new_info.id, data, new_info })

					new_info.pic = register_item_pic( data, new_info, new_info.advanced_pic )
					table.insert( item_tbl, new_info )
				end
			end, inv_info.sort )
		end
	end

	data.item_list = item_tbl
	return data
end

function vanilla_pick_up( hooman, item_id )
	local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
	if( pick_comp ~= nil ) then
		EntitySetComponentIsEnabled( hooman, pick_comp, true )
		GamePickUpInventoryItem( hooman, item_id, true )
		EntitySetComponentIsEnabled( hooman, pick_comp, true )
	end
end

function pick_up_item( hooman, data, this_info, do_the_sound, is_silent )
	local entity_id = this_info.id
	local gonna_pause, is_shopping = 0, this_info.cost ~= nil

	local callback = cat_callback( data, this_info, "on_pickup" )
	if( callback ~= nil ) then
		gonna_pause = callback( entity_id, data, this_info, false )
	end
	if( gonna_pause == 0 ) then
		if( not( is_silent or false )) then
			this_info.name = this_info.name or GameTextGetTranslatedOrNot( ComponentGetValue2( this_info.ItemC, "item_name" ))
			GamePrint( GameTextGet( "$log_pickedup", this_info.name ))
			if( do_the_sound or is_shopping ) then
				play_sound( data, { "data/audio/Desktop/event_cues.bank", is_shopping and "event_cues/shop_item/create" or "event_cues/pick_item_generic/create" })
			end
		end

		local _,slot = ComponentGetValue2( this_info.ItemC, "inventory_slot" )
		EntityAddChild( data.inventories_player[ slot < 0 and 1 or 2 ], entity_id )

		if( is_shopping ) then
			if( not( data.Wallet[2])) then
				data.Wallet[3] = data.Wallet[3] - this_info.cost
				ComponentSetValue2( data.Wallet[1], "money", data.Wallet[3])
			end

			local comps = EntityGetAllComponents( entity_id ) or {}
			if( #comps > 0 ) then
				for i,comp in ipairs( comps ) do
					if( ComponentHasTag( comp, "shop_cost" )) then
						EntityRemoveComponent( entity_id, comp )
					end
				end
			end
		end

		this_info.xy = { EntityGetTransform( entity_id )}
		lua_callback( entity_id, { "script_item_picked_up", "item_pickup" }, { entity_id, hooman, this_info.name })
		if( callback ~= nil ) then
			callback( entity_id, data, this_info, true )
		end
		if( EntityGetIsAlive( entity_id )) then
			ComponentSetValue2( this_info.ItemC, "has_been_picked_by_player", true )
			ComponentSetValue2( this_info.ItemC, "mFramePickedUp", data.frame_num )

			inventory_man( entity_id, data, this_info, false )
		end
	elseif( gonna_pause == 1 ) then
		--engage the pause
	end
end

function drop_item( h_x, h_y, this_info, data, throw_force, do_action )
	local this_item = this_info.id
	local has_no_cancer = not( this_info.is_kicking or false )
	if( not( has_no_cancer )) then
		local owner_id = get_item_owner( this_item, true )
		local ctrl_comp = EntityGetFirstComponentIncludingDisabled( owner_id, "ControlsComponent" )
		if( ctrl_comp ~= nil ) then
			local inv_comp = active_item_reset( owner_id )
			ComponentSetValue2( inv_comp, "mSavedActiveItemIndex", get_child_num( this_info.inv_id, this_item ))
			ComponentSetValue2( ctrl_comp, "mButtonFrameThrow", data.frame_num + 1 )
		else
			has_no_cancer = true
		end
	end
	if( has_no_cancer ) then EntityRemoveFromParent( this_item ) end

	local p_d_x, p_d_y = data.pointer_world[1] - h_x, data.pointer_world[2] - h_y
	local p_delta = math.min( math.sqrt( p_d_x^2 + p_d_y^2 ), 50 )/10
	local angle = math.atan2( p_d_y, p_d_x )
	local from_x, from_y = 0, 0
	if(( this_info.in_hand or 0 ) > 0 ) then
		from_x, from_y = EntityGetTransform( this_item )
		active_item_reset( this_info.in_hand )
	else
		data.throw_pos_rad = data.throw_pos_rad + data.throw_pos_size
		from_x, from_y = h_x + math.cos( angle )*data.throw_pos_rad, h_y + math.sin( angle )*data.throw_pos_rad
		local is_hit, hit_x, hit_y = RaytraceSurfaces( h_x, h_y, from_x, from_y )
		if( is_hit ) then data.throw_pos_rad = math.sqrt(( h_x - hit_x )^2 + ( h_y - hit_y )^2 ) end
		data.throw_pos_rad = data.throw_pos_rad - data.throw_pos_size
		from_x, from_y = h_x + math.cos( angle )*data.throw_pos_rad, h_y + math.sin( angle )*data.throw_pos_rad
	end
	local extra_v_force = 0
	local vel_comp = EntityGetFirstComponentIncludingDisabled( this_item, "VelocityComponent" )
	if( vel_comp ~= nil ) then
		extra_v_force = ComponentGetValue2( vel_comp, "gravity_y" )/4
	end
	local force = p_delta*throw_force
	local force_x, force_y = math.cos( angle )*force, math.sin( angle )*force
	force_y = force_y - math.max( 0.25*math.abs( force_y ), ( extra_v_force + throw_force )/2 )
	local to_x, to_y = from_x + force_x, from_y + force_y

	EntitySetTransform( this_item, from_x, from_y, nil, 1, 1 )
	-- EntityApplyTransform( this_item, from_x, from_y )
	if( has_no_cancer ) then inventory_man( this_item, data, this_info, false ) end
	
	local pic_comps = EntityGetComponentIncludingDisabled( this_item, "SpriteComponent", "enabled_in_world" ) or {}
	if( #pic_comps > 0 ) then
		for i,comp in ipairs( pic_comps ) do
			ComponentSetValue2( comp, "z_index", -1 + ( i - 1 )*0.0001 )
			EntityRefreshSprite( this_item, comp )
		end
	end
	ComponentSetValue2( this_info.ItemC, "inventory_slot", -5, -5 )
	ComponentSetValue2( this_info.ItemC, "play_hover_animation", false )
	ComponentSetValue2( this_info.ItemC, "has_been_picked_by_player", true )
	ComponentSetValue2( this_info.ItemC, "next_frame_pickable", data.frame_num + 30 )

	if( p_delta > 2 ) then
		local shape_comp = EntityGetFirstComponentIncludingDisabled( this_item, "PhysicsImageShapeComponent" )
		if( shape_comp ~= nil ) then
			local phys_mult = 1.75
			local throw_comp = EntityGetFirstComponentIncludingDisabled( this_item, "PhysicsThrowableComponent" )
			if( throw_comp ~= nil ) then phys_mult = phys_mult*ComponentGetValue2( throw_comp, "throw_force_coeff" ) end
			
			local mass = get_phys_mass( this_item )
			PhysicsApplyForce( this_item, phys_mult*force_x*mass, phys_mult*force_y*mass )
			PhysicsApplyTorque( this_item, phys_mult*5*mass )
		elseif( vel_comp ~= nil ) then
			ComponentSetValue2( vel_comp, "mVelocity", force_x, force_y )
		end
	end

	if( has_no_cancer and do_action ) then
		lua_callback( this_item, { "script_throw_item", "throw_item" }, { from_x, from_y, to_x, to_y })
	end
end

--GUI backend
function slot_z( data, id, z, state )
	if( state == nil ) then state = data.dragger.item_id == id end
	return state and z-2 or z
end

function full_stopper( text )
	if( not( pen.vld( text ))) then return "" end
	
	if( string.find( text, "%p$" ) == nil ) then text = text.."." end
	return text
end

function check_dragger_buffer( data, id )
	if( data.frame_num - dragger_buffer[2] > 2 ) then
		dragger_buffer = {0,0}
	end
	
	local will_do = true
	local will_force = false
	local will_update = true
	if( dragger_buffer[1] ~= 0 ) then
		will_do = dragger_buffer[1] == id
		will_update = will_do
		if( will_do ) then
			will_force = true
		end
	end
	return will_do, will_force, will_update
end

function hud_text_fix( key )
	local txt = tostring( GameTextGetTranslatedOrNot( key ))
	local _, pos = string.find( txt, ":", 1, true )
	if( pos ~= nil ) then
		txt = string.sub( txt, 1, pos-1 )
	end
	return txt..":@"
end

function hud_num_fix( a, b, zeros )
	zeros = zeros or 0
	a = string.format( "%."..zeros.."f", a )
	b = string.format( "%."..zeros.."f", b )
	return a.."/"..b
end

function get_tip_width( text, min_width, max_width, k ) --port to penman
	min_width, max_width, k = min_width or 121, max_width or 251, k or 1
	if( string.find( text, "[\n@]" ) ~= nil ) then k = 2*k end

	local l = math.min( k*#text, 500 )
	local w = math.min( math.max( math.floor( 6.5*l^0.6 + 0.5 ), math.max( min_width, 121 )), max_width )
	return 2*math.floor(( w + 1 )/2 + 0.5 ) - 1
end

function get_stain_perc( perc )
	local some_cancer = 14/99
	return math.max( math.floor( 100*( perc - some_cancer )/( 1 - some_cancer ) + 0.5 ), 0 )
end

function get_effect_timer( secs, no_units )
	if(( secs or -1 ) < 0 ) then
		return ""
	else
		local is_tiny = secs < 1
		secs = string.format( "%."..b2n( is_tiny ).."f", secs )
		if( not( no_units or false )) then
			secs = string.gsub( GameTextGet( "$inventory_seconds", secs ), " ", "" )
		end
		return is_tiny and string.sub( secs, 2 ) or secs
	end
end

function get_matter_colour( matter )
	local color_probe = EntityLoad( "mods/index_core/files/misc/matter_color.xml" )
	AddMaterialInventoryMaterial( color_probe, matter, 1000 )
	local color = uint2color( GameGetPotionColorUint( color_probe ))
	EntityKill( color_probe )
	return color
end

--thanks to Nathan for The Math; port to penman
function sine_anim( framecount, target_scale, delay, delay_scale, frame ) --y=c\sin x-\ln\left(e^{b\sin x+a}+f\right)+d [0.4;3.6;-0.2;3.2;2]
    framecount, delay, frame = 2*framecount, delay > 0 and ( delay + 1 ) or 0, frame or GameGetFrameNum()
    local i = frame%( framecount + delay )
    if( delay > 0 and i > framecount ) then
        delay_scale = 1 + ( target_scale < 1 and 1 or -1 )*( delay_scale or 0.05 )
        frame = framecount > delay and frame%framecount or math.max(( frame - framecount ), 0 )%( 2*delay )
        return sine_anim( delay/2, delay_scale, 0, nil, frame )
    else
        return 1 - ( 1 - target_scale )*math.abs( math.sin( i*math.pi/framecount ))
    end
end

function simple_anim( data, name, target, speed, min_delta ) --kidna sus
	speed = speed or 0.1
	min_delta = min_delta or 1
	
	data.memo[name] = data.memo[name] or 0
	local delta = target - data.memo[name]
	data.memo[name] = data.memo[name] + limiter( limiter( speed*delta, min_delta, true ), delta )
	return data.memo[name]
end

function get_short_num( num, no_subzero, force_sign ) --port to penman
	no_subzero = no_subzero or false
	force_sign = force_sign or false

	if( num < 0 and not( no_subzero )) then
		return "∞"
	elseif( no_subzero ~= 1 ) then
		num = math.max( num, 0 )
	end
	local real_num = num
	num = math.abs( num )
	if( num < 999e12 ) then
		if( num < 10 ) then
			num = string.gsub( string.format( "%.3f", real_num ), "%.*0+$", "" )
		else
			local sstr = string.format( "%.0f", real_num )

			local ender = { 12, "T" }
			if( num < 10^4 ) then
				ender = { 0, "" }
			elseif( num < 10^6 ) then
				ender = { 3, "K" }
			elseif( num < 10^9 ) then
				ender = { 6, "M" }
			elseif( num < 10^12 ) then
				ender = { 9, "B" }
			end

			num = string.sub( sstr, 1, #sstr - ender[1])..ender[2]
		end
	elseif( num < 9e99 ) then
		num = tostring( string.format("%e", real_num ))
		local _, pos = string.find( num, "+", 1, true )
		num = string.sub( num, string.find( num, "^%-*%d" )).."e"..string.sub( 100 + tonumber( string.sub( num, pos+1, #num )), 2 )
	else
		return "∞"
	end

	if( force_sign ) then num = ( real_num > 0 and "+" or "" )..num end
	return num
end

function get_tiny_num( num, no_subzero ) --port to penman
	no_subzero = no_subzero or false
	
	if( num < 0 and not( no_subzero )) then
		return "∞"
	else
		num = math.max( num, 0 )
	end
	if( num < 100000 ) then
		local sstr = string.format( "%.0f", num )
		
		local ender = { 3, "K" }
		if( num < 10^3 ) then ender = { 0, "" } end
		num = string.sub( sstr, 1, #sstr - ender[1])..ender[2]
	else
		num = "∞"
	end
	return num
end

function get_effect_duration( duration, effect_info, eps )
	effect_info = effect_info or {}
	duration = duration - 60*( effect_info.ui_timer_offset_normalized or 0 )
	if( math.abs( duration*60 ) <= eps ) then
		duration = 0
	end
	return duration < 0 and -1 or duration
end

function get_thresholded_effect( effects, v )
	if( #effects < 2 ) then
		return effects[1] or {}
	end
	table.sort( effects, function( a, b )
		return ( a.min_threshold_normalized or 0 ) < ( b.min_threshold_normalized or 0 )
	end)

	local final_id = #effects
	for i,effect in ipairs( effects ) do
		if( v < 60*( effect.min_threshold_normalized or 0 )) then
			final_id = math.max( i-1, 1 )
			break
		end
	end
	return effects[final_id]
end

function swap_anim( item_id, end_x, end_y, data )
	local anim_info, anim_id = from_tbl_with_id( slot_anim, item_id )
	if( anim_info ~= 0 and anim_info.id ~= nil ) then
		local delta = data.frame_num - anim_info.frame
		local stop_it = false
		if( delta > 10 ) then
			stop_it = true
		elseif( delta > 1 ) then
			delta = delta - 1
			local k = 3.35
			local v = k*math.sin( delta*math.pi/k )/( math.pi*delta )/delta
			local d_x = v*( end_x - anim_info.x )
			local d_y = v*( end_y - anim_info.y )
			end_x, end_y = end_x - d_x, end_y - d_y
		else
			end_x, end_y = anim_info.x, anim_info.y
		end
		if( stop_it ) then
			table.remove( slot_anim, anim_id )
		end
	end

	return end_x, end_y
end

function register_item_pic( data, this_info, is_advanced )
	if( this_info.pic == nil ) then
		return
	end
	
	local forced_update = EntityHasTag( this_info.id, "index_pic_update" )
	item_pic_data[ this_info.pic ] = item_pic_data[ this_info.pic ] or {xy={0,0}, xml_xy={0,0}}
	if( item_pic_data[ this_info.pic ].dims == nil or forced_update ) then
		item_pic_data[ this_info.pic ].dims = { get_pic_dim( this_info.pic )}

		local is_xml = false
		if( not( forced_update )) then
			is_xml = string.sub( this_info.pic, -4 ) == ".xml" and is_advanced
		else
			EntityRemoveTag( this_info.id, "index_update" )
		end

		local storage_anim = get_storage( this_info.id, "index_pic_anim" )
		if( storage_anim ~= nil ) then
			item_pic_data[ this_info.pic ].anim = D_extractor( ComponentGetValue2( storage_anim, "value_string" ))
		end
		
		local storage_off = get_storage( this_info.id, "index_pic_offset" )
		if( storage_off ~= nil ) then
			item_pic_data[ this_info.pic ].xy = D_extractor( ComponentGetValue2( storage_off, "value_string" ), true )
		elseif( not( is_xml )) then
			if( is_advanced ) then
				local pic_comp = EntityGetFirstComponentIncludingDisabled( this_info.id, "SpriteComponent", "item" )
				if( pic_comp == nil ) then
					pic_comp = EntityGetFirstComponentIncludingDisabled( this_info.id, "SpriteComponent", "enabled_in_hand" )
				end
				if( pic_comp ~= nil ) then
					item_pic_data[ this_info.pic ].xy = { ComponentGetValue2( pic_comp, "offset_x" ), ComponentGetValue2( pic_comp, "offset_y" )}
				end
			else
				item_pic_data[ this_info.pic ].xy = { item_pic_data[ this_info.pic ].dims[1]/2, item_pic_data[ this_info.pic ].dims[2]/2 }
			end
		end
		
		if( is_xml ) then
			local nxml = dofile_once( "mods/index_core/nxml.lua" )
			local xml = nxml.parse( ModTextFileGetContent( this_info.pic ))
			local xml_kid = xml:first_of( "RectAnimation" )
			if( xml_kid.attr.has_offset ) then
				item_pic_data[ this_info.pic ].xml_xy = { -xml_kid.attr.offset_x, -xml_kid.attr.offset_y }
			else
				item_pic_data[ this_info.pic ].xml_xy = { -xml.attr.offset_x, -xml.attr.offset_y }
			end
			item_pic_data[ this_info.pic ].dims = { xml_kid.attr.frame_width, xml_kid.attr.frame_height }
			if( xml_kid.attr.shrink_by_one_pixel ) then
				item_pic_data[ this_info.pic ].dims[1] = item_pic_data[ this_info.pic ].dims[1] + 1
				item_pic_data[ this_info.pic ].dims[2] = item_pic_data[ this_info.pic ].dims[2] + 1
			end
		end
	end

	return this_info.pic
end

--GUI frontend
function new_anim_looped( core_path, delay, duration )
	local num = math.floor( GameGetFrameNum()/tonumber( delay ))%tonumber( duration ) + 1
	return core_path..num..".png"
end

function new_dragger_shell( id, info, pic_x, pic_y, pic_w, pic_h, data )
	local clicked, r_clicked, hovered = false, false, false
	if( not( slot_going )) then
		local will_do, will_force, will_update = check_dragger_buffer( data, id )
		if( will_do ) then
			local new_x, new_y, has_begun = 0, 0, true
			if( will_force or check_bounds( data.pointer_ui, {pic_x,pic_y}, {-pic_w,pic_w,-pic_h,pic_h}) or slot_memo[id]) then
				if( dragger_buffer[1] == 0 ) then
					dragger_buffer = { id, data.frame_num }
				end
				
				if( data.dragger.item_id == 0 ) then
					data.dragger.item_id = id
				end
				if( data.dragger.item_id == id ) then
					new_x, new_y, has_begun, clicked, r_clicked, hovered = new_dragger( data.the_gui, pic_x, pic_y )
					if( slot_memo[id] and not( has_begun )) then
						data.dragger.swap_soon = true
						table.insert( slot_anim, {
							id = id,
							x = data.memo.dragger_x,
							y = data.memo.dragger_y,
							frame = data.frame_num,
						})
					end

					data.memo.dragger_x, data.memo.dragger_y = new_x, new_y
					data.dragger.inv_type = info.inv_type
					data.dragger.is_quickest = info.is_quickest
					pic_x, pic_y = new_x, new_y
					
					slot_memo[id] = hovered and has_begun
					if( slot_memo[id]) then
						dragger_buffer[2] = data.frame_num
					end
					slot_going = true
				end
			end
		end
	end

	return data, pic_x, pic_y, clicked, r_clicked, hovered
end

function new_vanilla_plate( gui, uid, pic_x, pic_y, pic_z, dims, alpha )
	alpha = alpha or 1
	uid = new_image( gui, uid, pic_x, pic_y, pic_z, "mods/index_core/files/pics/vanilla_plate.xml", dims[1], dims[2], alpha )

	uid = new_image( gui, uid, pic_x - 2, pic_y - 2, pic_z, "mods/index_core/files/pics/vanilla_plate_a1.xml", nil, nil, alpha )
	uid = new_image( gui, uid, pic_x + dims[1], pic_y - 2, pic_z, "mods/index_core/files/pics/vanilla_plate_a2.xml", nil, nil, alpha )
	uid = new_image( gui, uid, pic_x + dims[1], pic_y + dims[2], pic_z, "mods/index_core/files/pics/vanilla_plate_a3.xml", nil, nil, alpha )
	uid = new_image( gui, uid, pic_x - 2, pic_y + dims[2], pic_z, "mods/index_core/files/pics/vanilla_plate_a4.xml", nil, nil, alpha )

	local steps = {10,4,2,1}
	local temp = 0
	while( temp < dims[1]) do
		local delta = dims[1] - temp
		local pic_id = 4
		for i,step in ipairs( steps ) do
			if( delta >= step ) then
				pic_id = i
				break
			end
		end
		uid = new_image( gui, uid, pic_x + temp, pic_y - 2, pic_z, "mods/index_core/files/pics/vanilla_plate_b"..pic_id..".xml", nil, nil, alpha )
		uid = new_image( gui, uid, pic_x + temp, pic_y + dims[2], pic_z, "mods/index_core/files/pics/vanilla_plate_c"..pic_id..".xml", nil, nil, alpha )
		temp = temp + steps[pic_id]
	end

	temp = 0
	while( temp < dims[2]) do
		local delta = dims[2] - temp
		local pic_id = 4
		for i,step in ipairs( steps ) do
			if( delta >= step ) then
				pic_id = i
				break
			end
		end
		uid = new_image( gui, uid, pic_x - 2, pic_y + temp, pic_z, "mods/index_core/files/pics/vanilla_plate_d"..pic_id..".xml", nil, nil, alpha )
		uid = new_image( gui, uid, pic_x + dims[1], pic_y + temp, pic_z, "mods/index_core/files/pics/vanilla_plate_e"..pic_id..".xml", nil, nil, alpha )
		temp = temp + steps[pic_id]
	end

	return uid
end

function new_vanilla_bar( gui, uid, pic_x, pic_y, zs, dims, bar_pic, shake_frame, bar_alpha )
	local will_shake = shake_frame ~= nil
	if( will_shake ) then
		if( shake_frame < 0 ) then
			pic_x = pic_x - 20*math.sin( shake_frame*math.pi/6.666 )/shake_frame
		else
			pic_x = pic_x + 2.5*math.sin( shake_frame*math.pi/5 )
		end
	end
	
	local w, h = get_pic_dim( bar_pic )
	uid = new_image( gui, uid, pic_x - dims[1], pic_y + 1, zs[2], bar_pic, dims[3]/w, dims[2]/h, bar_alpha )
	
	local pic = "mods/index_core/files/pics/vanilla_bar_bg_"
	for i = 1,2 do
		local new_z = zs[1] + ( i == 1 and 0.001 or 0 )
		uid = new_image( gui, uid, pic_x, pic_y, new_z, pic..i..".xml", 1, dims[2] + 2 )
		uid = new_image( gui, uid, pic_x - ( dims[1] + 1 ), pic_y, new_z, pic..i..".xml", 1, dims[2] + 2 )
		uid = new_image( gui, uid, pic_x - dims[1], pic_y, new_z, pic..i..".xml", dims[1], 1 )
		uid = new_image( gui, uid, pic_x - dims[1], pic_y + dims[2] + 1, new_z, pic..i..".xml", dims[1], 1 )
	end
	if( will_shake ) then
		uid = new_image( gui, uid, pic_x - ( dims[1] + 1 ), pic_y, zs[1] - 0.001, "data/ui_gfx/hud/colors_reload_bar_bg_flash.png", dims[1]/2 + 1, dims[2]/2 + 1 )
	end
	uid = new_image( gui, uid, pic_x - dims[1], pic_y + 1, zs[1], pic.."0.xml", dims[1], dims[2])

	return uid
end

--ass
function new_vanilla_tooltip( gui, uid, tid, z, text, extra_func, is_triggered, is_right, is_up, is_fancy )
	tid = tid or "generic"

	if( is_triggered == nil ) then
		_, _, is_triggered = GuiGetPreviousWidgetInfo( gui )
	end
	if( is_triggered ) then
		if( not( tip_going[tid] or false )) then
			tip_going[tid] = true
			tip_anim[tid] = tip_anim[tid] or {0,0,0}
			
			local frame_num = GameGetFrameNum()
			tip_anim[tid][2] = frame_num
			if( tip_anim[tid][1] == 0 ) then
				tip_anim[tid][1] = frame_num
				return uid
			end
			local anim_frame = tip_anim[tid][3]
			
			if( type( text ) ~= "table" ) then
				text = { text }
			end
			extra_func = extra_func or ""
			if( type( extra_func ) ~= "table" ) then
				extra_func = { extra_func }
			end
			
			local w, h = GuiGetScreenDimensions( gui )
			local pic_x, pic_y = get_mouse_pos()
			local p_off_x = is_right and -5 or 5
			local p_off_y = is_up and -5 or 5
			pic_x, pic_y = text[2] or ( pic_x + p_off_x ), text[3] or ( pic_y + p_off_y )
			
			local edge_spacing, dims = 3, {0,0}
			if( text[1] ~= "" ) then text[1], dims = font_liner( text[1], w*0.9, h - 2 ) end
			
			local x_offset, y_offset = text[4] or ( dims[1] + edge_spacing ), text[5] or dims[2]
			x_offset, y_offset = x_offset + edge_spacing - 1, y_offset + edge_spacing
			if( is_right or is_up ) then
				if( is_right ) then
					pic_x = pic_x - x_offset - 1
				end
				if( is_up ) then
					pic_y = pic_y - y_offset + 9 + edge_spacing
				end
			end
			if( is_right ) then
				if( pic_x < 0 ) then
					pic_x = 1
				end
			elseif( w < pic_x + x_offset + 1 ) then
				pic_x = w - x_offset - 1
			end
			if( is_up ) then
				if( pic_y < 0 ) then
					pic_y = 1
				end
			elseif( h < pic_y + y_offset + 1 ) then
				pic_y = h - y_offset - 1
			end

			local inter_alpha = math.sin( math.min( anim_frame, 10 )*math.pi/20 )
			if( type( extra_func[1] ) == "function" ) then
				uid = extra_func[1]( gui, uid, pic_x + 2, pic_y + 2, z, inter_alpha, extra_func[2])
			else
				uid = pen.new_text( gui, uid, pic_x + 3, pic_y + 1, z, text[1], { is_shadow = true, alpha = inter_alpha })
			end
			
			anim_frame = anim_frame + 1
			local inter_size = 30*math.sin( anim_frame*0.3937 )/anim_frame
			pic_x, pic_y = pic_x + 0.5*inter_size, pic_y + 0.5*inter_size
			x_offset, y_offset = x_offset - inter_size, y_offset - inter_size
			inter_alpha = math.max( 1 - inter_alpha/6, 0.1 )

			is_fancy = is_fancy or false
			local gui_core = "mods/index_core/files/pics/vanilla_tooltip_"
			uid = new_image( gui, uid, pic_x, pic_y, z + 0.01, gui_core.."0.xml", x_offset, y_offset, 1.15*inter_alpha )
			local lines = {{0,-1,x_offset-1,1},{-1,0,1,y_offset-1},{1,y_offset,x_offset-1,1},{x_offset,1,1,y_offset-1}}
			for i,line in ipairs( lines ) do
				uid = new_image( gui, uid, pic_x + line[1], pic_y + line[2], z, gui_core..( is_fancy and "1_alt.xml" or "1.xml" ), line[3], line[4], inter_alpha )
			end
			local dots = {{-1,-1},{x_offset-1,-1},{x_offset,y_offset},{-1,y_offset-1}, {x_offset,0},{0,y_offset}}
			for i,dot in ipairs( dots ) do
				uid = new_image( gui, uid, pic_x + dot[1], pic_y + dot[2], z, gui_core..( is_fancy and "2_alt.xml" or "2.xml" ), 1, 1, inter_alpha )
			end
			local shadow_core = "mods/index_core/files/pics/tooltip_shadow_"
			local shadows = {
				{-2,-2,1,1},{4,-2,-1,1},{3,3,-1,-1},{-2,4,1,-1},
				{1.5,-2,x_offset-1.5,1},{4,2,-1,y_offset-1.5},{-0.5,3,1.5-x_offset,-1},{-2,0,1,1.5-y_offset},
			}
			for k = 1,2 do
				for e = 1,4 do
					local i = e + ( k - 1 )*4
					local name = e%2 == 0 and ( k > 1 and "B_alt.png" or "A_alt.png" ) or ( k > 1 and "B.png" or "A.png" )
					uid = new_image( gui, uid, pic_x + dots[e][1] + shadows[i][1], pic_y + dots[e][2] + shadows[i][2], z + 0.011, shadow_core..name, 0.5*shadows[i][3], 0.5*shadows[i][4], inter_alpha )
				end
			end
		end
	end
	
	return uid, is_triggered
end

function new_vanilla_hp( gui, uid, pic_x, pic_y, pic_zs, data, entity_id, this_data, params )
	params = params or {}
    local dmg_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "DamageModelComponent" )
    if( dmg_comp == nil ) then return uid,0,0,0,0,0 end
    this_data = this_data or {
        dmg_comp,

        ComponentGetValue2( dmg_comp, "max_hp" ),
        ComponentGetValue2( dmg_comp, "hp" ),
        ComponentGetValue2( dmg_comp, "mHpBeforeLastDamage" ),
        math.max( data.frame_num - ComponentGetValue2( dmg_comp, "mLastDamageFrame" ), 0 ),
    }

    local red_shift, length, height = 0, 0, params.height or 4
    local max_hp, hp = this_data[2], this_data[3]
    if( max_hp > 0 ) then
        length = math.floor( 157.8 - 307.1/( 1 + ( math.min( math.max( max_hp, 0 ), 40 )/0.38 )^( 0.232 )) + 0.5 )
        length = ( params.length_mult or 1 )*( length < 5 and 40 or length )
        hp = math.min( math.max( hp, 0 ), max_hp )

		if( params.centered ) then pic_x = pic_x + length/2 end

        local low_hp = math.max( math.min( max_hp/4, params.low_hp or data.hp_threshold ), params.low_hp_min or data.hp_threshold_min )
        local pic = params.pic_hp or "data/ui_gfx/hud/colors_health_bar.png"
        if( hp < low_hp ) then
            local perc = ( low_hp - hp )/low_hp
            local freq = ( params.hp_flashing or data.hp_flashing )*( 1.5 - perc )
            
            data.memo.hp_flashing = data.memo.hp_flashing or {}
            data.memo.hp_flashing[ entity_id ] = data.memo.hp_flashing[ entity_id ] or {}
            if( freq ~= data.memo.hp_flashing[ entity_id ][1] or -1 ) then
                local freq_old = data.memo.hp_flashing[ entity_id ][1] or 1
                data.memo.hp_flashing[ entity_id ] = { freq, freq*( data.memo.hp_flashing[ entity_id ][2] or 1 )/freq_old }
            end
            if( data.memo.hp_flashing[ entity_id ][2] > 4*freq ) then
                data.memo.hp_flashing[ entity_id ][2] = data.memo.hp_flashing[ entity_id ][2] - 4*freq
            end
            red_shift = 0.5*( math.sin((( data.memo.hp_flashing[ entity_id ][2] + freq )*math.pi )/( 2*freq )) + 1 )
            data.memo.hp_flashing[ entity_id ][2] = data.memo.hp_flashing[ entity_id ][2] + 1

            if( red_shift > 0.5 ) then
                uid = new_image( gui, uid, pic_x - ( length + 1 ), pic_y, pic_zs[1] - 0.001, params.pic_dmg or "data/ui_gfx/hud/colors_health_bar_bg_low_hp.png", ( length + 2 )/2, height/2 + 1 )
            else
                pic = params.pic_bg or "data/ui_gfx/hud/colors_health_bar_damage.png"
            end
            red_shift = red_shift*perc
        end

		local delay = 30 --params.damage_fading
        if( this_data[5] <= delay ) then
            local last_hp = math.min( math.max( this_data[4], 0 ), max_hp )
            uid = new_image( gui, uid, pic_x - length, pic_y + 1, pic_zs[2] + 0.001, "data/ui_gfx/hud/colors_health_bar_damage.png", 0.5*length*last_hp/max_hp, height/2, ( delay - this_data[5])/delay )
        end
        
        max_hp = math.min( math.floor( max_hp*25 + 0.5 ), 9e99 )
        hp = math.min( math.floor( hp*25 + 0.5 ), 9e99 )
        uid = new_vanilla_bar( gui, uid, pic_x, pic_y, pic_zs, { length, height, length*hp/max_hp }, pic )
    end

    return uid, length, height, max_hp, hp, red_shift
end

function new_pickup_info( gui, uid, screen_h, screen_w, data, pickup_info, zs, xys )
	pickup_info.color = pickup_info.color or {}

	if(( pickup_info.desc or "" ) ~= "" ) then
		if( type( pickup_info.desc ) ~= "table" ) then
			pickup_info.desc = { pickup_info.desc, false }
		end
		if( pickup_info.desc[1] ~= "" ) then
			local is_elaborate = type( pickup_info.desc[2]) == "string" and pickup_info.desc[2] ~= ""
			local pic_x, pic_y = unpack( xys.pickup_info or { screen_w/2, screen_h - 44 })
			local clr = ( pickup_info.desc[2] == true ) and {208,70,70} or {255,255,178}
			uid = pen.new_text( gui, uid, pic_x, pic_y, zs.in_world_ui, pickup_info.desc[1], {
				is_centered_x = true, is_shadow = true, color = pickup_info.color[1] or clr })
			if( is_elaborate ) then
				uid = pen.new_text( gui, uid, pic_x, pic_y + 12, zs.in_world_ui, pickup_info.desc[2], {
					is_centered_x = true, is_shadow = true, color = pickup_info.color[2] or {207,207,207}})
			end
		end
	end
	if( pickup_info.id > 0 and not( data.is_opened ) and ( data.in_world_pickups or EntityHasTag( pickup_info.id, "index_txt" ))) then
		if(( pickup_info.txt or "" ) ~= "" ) then
			local x, y = EntityGetTransform( pickup_info.id )
			local pic_x, pic_y = world2gui( x, y )
			uid = pen.new_text( gui, uid, pic_x + 2, pic_y + 3, zs.in_world_front, pickup_info.txt, {
				is_centered_x = true, is_shadow = true, color = {207,207,207}})
		end
	end

	return uid
end

function tipping( gui, uid, tid, tip_func, pos, tip, zs, is_right, is_up, is_debugging )
	if( type( zs ) ~= "table" ) then
		zs = {zs}
	end
	local clicked, r_clicked, is_hovered = false, false, false
	uid, clicked, r_clicked, is_hovered = new_interface( gui, uid, pos, zs[1], is_debugging )
	if( zs[2] ~= nil and is_hovered ) then
		uid = new_image( gui, uid, pos[1], pos[2], zs[2], "data/ui_gfx/hud/colors_reload_bar_bg_flash.png", pos[3]/2, pos[4]/2, 0.5 )
	end

	is_right = is_right or false
	tip_func = tip_func or new_vanilla_tooltip
	local out = { tip_func( gui, uid, tid, zs[1], { tip[1], tip[2], tip[3], tip[4], tip[5] }, nil, is_hovered, is_right, is_up )}
	table.insert( out, clicked )
	table.insert( out, r_clicked )
	return unpack( out )
end

function new_vanilla_worldtip( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, zs, no_space, cant_buy, tip_func )
	-- if( not( cant_buy )) then
		pic_x, pic_y = unpack( data.xys.hp )
		pic_x, pic_y = pic_x - 43, pic_y - 1
		uid = tip_func( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, zs.tips, true )
	-- end
	return uid
end

function new_vanilla_wtt( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world, is_advanced )
	is_advanced = is_advanced or false
	if( this_info.wand_info == nil ) then
		return uid
	end
	
	--[[
		this_info.wand_info.speed_multiplier
		this_info.wand_info.lifetime_add
		this_info.wand_info.bounces

		this_info.wand_info.crit_chance
		this_info.wand_info.crit_mult
		
		this_info.wand_info.damage_electricity_add
		this_info.wand_info.damage_explosion_add
		this_info.wand_info.damage_fire_add
		this_info.wand_info.damage_melee_add
		this_info.wand_info.damage_projectile_add
	]]
	
	--slot (has no alt mode but will stay open if alt is held)
	--inventory (stats have tooltips, advanced stats replace the desc)
	
	local scale = 2--data.no_wand_scaling and 1 or 2
	local spell_list, got_spells = {permas={},normies={}}, false
	if( not( is_advanced )) then
		local spells = EntityGetAllChildren( item_id ) or {}
		if( #spells > 0 ) then
			for i,spell in ipairs( spells ) do
				local kid_info = from_tbl_with_id( data.item_list, spell, nil, nil, {})
				if( kid_info.id == nil ) then
					_,kid_info = get_item_data( spell, data, data.this_info, data.item_list )
				end
				if( kid_info.id ~= nil ) then
					got_spells = true
					table.insert( spell_list[ kid_info.is_permanent and "permas" or "normies" ], kid_info )
				end
			end

			for field,tbl in pairs( spell_list ) do
				table.sort( spell_list[ field ], function( a, b )
					local inv_slot = {0,0}
					for k = 1,2 do
						local item_comp = k == 1 and a.ItemC or b.ItemC
						if( item_comp ~= nil ) then inv_slot[k] = ComponentGetValue2( item_comp, "inventory_slot" ) end
					end
					return inv_slot[1] < inv_slot[2]
				end)
			end
		end
	end

	this_info.tt_spacing = {
		{ get_text_dim( this_info.name )},
		{ 71, 57, 0 },
		{ 0, 0 },
		{},
		{ 0, 0 },
		{},
	}
	this_info.tt_spacing[1][1] = this_info.tt_spacing[1][1] + ( this_info.wand_info.shuffle_deck_when_empty and 8 or 0 ) + 3
	if( is_advanced and pen.vld( this_info.desc )) then
		this_info.done_desc, this_info.tt_spacing[3] = font_liner( this_info.desc, math.floor( get_tip_width( this_info.desc )*0.5 ), -1 )
		this_info.tt_spacing[3] = { this_info.tt_spacing[3][1] + 4, this_info.tt_spacing[3][2] - 1 }
		if( this_info.tt_spacing[2][2] < this_info.tt_spacing[3][2]) then
			this_info.tt_spacing[2][3] = ( this_info.tt_spacing[3][2] - this_info.tt_spacing[2][2])/2
			this_info.tt_spacing[2][2] = this_info.tt_spacing[3][2]
		end
	end
	this_info.tt_spacing[6][1] = math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1] + this_info.tt_spacing[3][1])
	this_info.tt_spacing[6][1] = math.ceil( this_info.tt_spacing[6][1]/9 )*9 + 3
	this_info.tt_spacing[2][1] = this_info.tt_spacing[6][1] - this_info.tt_spacing[3][1]
	if( item_pic_data[ this_info.pic ] and item_pic_data[ this_info.pic ].dims ) then
		local dims = { scale*item_pic_data[ this_info.pic ].dims[1], scale*item_pic_data[ this_info.pic ].dims[2]}
		local drift = { -scale*item_pic_data[ this_info.pic ].xy[2], dims[1]/2 + scale*item_pic_data[ this_info.pic ].xml_xy[1]}
		if( this_info.tt_spacing[2][2] < dims[1]) then
			this_info.tt_spacing[2][3] = this_info.tt_spacing[2][3] + ( dims[1] - this_info.tt_spacing[2][2])/2
			this_info.tt_spacing[2][2] = dims[1]
		end
		this_info.tt_spacing[4] = { this_info.tt_spacing[2][1] + drift[1] - 15, this_info.tt_spacing[2][2]/2 + drift[2]}
		local total_size = this_info.tt_spacing[4][1] + dims[2] + scale*item_pic_data[ this_info.pic ].xml_xy[2]
		if( total_size > this_info.tt_spacing[2][1] - 1 ) then
			this_info.tt_spacing[4][1] = this_info.tt_spacing[4][1] - ( total_size - this_info.tt_spacing[2][1] + 1 )
		end
	else
		register_item_pic( data, this_info, this_info.advanced_pic )
	end
	if( got_spells ) then
		local p_size, n_size = 0, 0
		if( #spell_list.permas > 0 ) then
			p_size = 9*math.ceil( 9*( #spell_list.permas + 1 )/( this_info.tt_spacing[2][1] - 1 ))
		end
		if( #spell_list.permas > 0 and #spell_list.normies > 0 ) then p_size = p_size + 1 end
		if( #spell_list.normies > 0 ) then
			n_size = 9*math.ceil( 9*( #spell_list.normies )/( this_info.tt_spacing[2][1] - 1 ))
		end
		this_info.tt_spacing[5] = { p_size, n_size }
	end
	this_info.tt_spacing[6][2] = math.max( this_info.tt_spacing[3][2], this_info.tt_spacing[2][2] + ( got_spells and ( this_info.tt_spacing[5][1] + this_info.tt_spacing[5][2] + 4 ) or 0 )) + 14

	uid = data.tip_func( gui, uid, tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[6][1] + 2, this_info.tt_spacing[6][2] + 2 }, { function( gui, uid, pic_x, pic_y, pic_z, inter_alpha, this_data )
		if( not( is_advanced ) and this_info.is_frozen ) then
			uid = new_shaded_image( gui, uid, pic_x - 4, pic_y - 4, pic_z - 0.1, "mods/index_core/files/pics/frozen_marker.png", {9,9}, nil, nil, inter_alpha )
		end

		pic_x = pic_x + 2
		if( this_info.wand_info.shuffle_deck_when_empty ) then
			uid = new_image( gui, uid, pic_x - 1, pic_y + 1, pic_z, "data/ui_gfx/inventory/icon_gun_shuffle.png", nil, nil, inter_alpha )
			colourer( gui, {0,0,0})
			uid = new_image( gui, uid, pic_x - 1, pic_y + 2, pic_z + 0.01, "data/ui_gfx/inventory/icon_gun_shuffle.png", nil, nil, inter_alpha )
		end
		uid = pen.new_text( gui, uid, pic_x + ( this_info.wand_info.shuffle_deck_when_empty and 8 or 0 ), pic_y, pic_z, this_info.name, {
			is_shadow = true, color = {255,255,178}, alpha = inter_alpha })
		
		local orig_y = pic_y
		pic_y = pic_y + 13
		uid = new_image( gui, uid, pic_x - 2, pic_y - 3, pic_z, "mods/index_core/files/pics/vanilla_tooltip_1.xml", this_info.tt_spacing[6][1], 1, 0.5*inter_alpha )
		if( this_info.done_desc ) then
			uid = new_image( gui, uid, pic_x + this_info.tt_spacing[2][1] - 2, pic_y - 2, pic_z, "mods/index_core/files/pics/vanilla_tooltip_1.xml", 1, this_info.tt_spacing[6][2] - 10, 0.5*inter_alpha )
			uid = pen.new_text( gui, uid, pic_x + this_info.tt_spacing[2][1] + 1, pic_y - 1, pic_z, this_info.done_desc, {
				is_shadow = true, alpha = inter_alpha })
		end

		local function get_generic_stat( v, v_add, dft, allow_inf )
			v, v_add, allow_inf = v or dft, v_add or 0, allow_inf or false
			local is_dft = v == dft
			return get_short_num( is_dft and v_add or ( v + v_add ), ( is_dft or not( allow_inf )) and 1 or nil, is_dft ), is_dft and (v_add==0)
		end
		local stats_tbl = {
			{
				pic = "data/ui_gfx/inventory/icon_gun_actions_per_round.png",
				name = "$inventory_actionspercast",
				bigger_better = true,

				v = function( w_info ) return w_info.actions_per_round or 0 end,
				value = function( v ) return get_generic_stat( v, nil, 0 ) end,
				tip = 0,
			},
			{
				pic = "data/ui_gfx/inventory/icon_gun_capacity.png",
				name = "$inventory_capacity",
				bigger_better = true,

				v = function( w_info ) return w_info.deck_capacity or 0 end,
				value = function( v ) return get_generic_stat( v, nil, 0 ) end,
				tip = 0,
			},
			{
				pic = "data/ui_gfx/inventory/icon_spread_degrees.png",
				name = "$inventory_spread",
				extra_step = 2,

				v = function( w_info ) return w_info.spread_degrees or 0 end,
				value = function( v ) return get_generic_stat( v, nil, 0 ) end,
				custom_func = function( gui, uid, pic_x, pic_y, pic_z, txt, data )
					local dims = {}
					uid, dims = pen.new_text( gui, uid, pic_x, pic_y, pic_z, txt, data )
					colourer( gui, data.color )
					uid = new_image( gui, uid, pic_x + dims[1], pic_y, pic_z, "mods/index_core/files/fonts/vanilla_shadow/degree.png", nil, nil, color[4])
					return uid
				end,
				tip = 0,
			},
			{
				pic = "data/ui_gfx/inventory/icon_mana_max.png",
				name = "$inventory_manamax",
				bigger_better = true,
				
				v = function( w_info ) return w_info.mana_max or 0 end,
				value = function( v ) return get_generic_stat( v, nil, 0 ) end,
				tip = 0,
			},
			{
				pic = "data/ui_gfx/inventory/icon_mana_charge_speed.png",
				name = "$inventory_manachargespeed",
				bigger_better = true,
				
				v = function( w_info ) return w_info.mana_charge_speed or 0 end,
				value = function( v ) return get_generic_stat( v, nil, 0 ) end,
				tip = 0,
			},
			{
				pic = "data/ui_gfx/inventory/icon_fire_rate_wait.png", off_y = 1,
				name = "$inventory_castdelay",

				v = function( w_info ) return w_info.delay_time or 0 end,
				value = function( v )
					local v, is_dft = get_generic_stat(( v or 0 )/60, nil, 0, false, true )
					return v.."s", is_dft
				end,
				tip = 0,
			},
			{
				pic = "data/ui_gfx/inventory/icon_gun_reload_time.png",
				name = "$inventory_rechargetime",
				extra_step = 2,

				v = function( w_info )
					if( w_info.never_reload ) then
						return "Ø", true
					else
						return w_info.reload_time or 0
					end
				end,
				value = function( v )
					local v, is_dft = get_generic_stat(( v or 0 )/60, nil, 0, false, true )
					return v.."s", is_dft
				end,
				tip = 0,
			},
		}
		local stat_x, stat_y = pic_x, pic_y + this_info.tt_spacing[2][3] --allow adding custom displayed params to wands (with a spacer)
		for i,stat in ipairs( stats_tbl ) do
			local v, is_special = stat.v( this_info.wand_info )
			local done_v, is_default = v, false
			if( type( v ) ~= "string" ) then done_v, is_default = stat.value( v ) end

			local alpha = ( is_default and 0.5 or 1 )*inter_alpha
			uid = new_image( gui, uid, stat_x, stat_y + ( stat.off_y or 0 ), pic_z, stat.pic, nil, nil, alpha )

			local clr = {170,170,170,alpha}
			if( data.active_item ~= item_id and data.active_info.wand_info ~= nil ) then
				local is_better = nil
				local old_v, old_is_special = stat.v( data.active_info.wand_info )
				if( is_special ~= nil or old_is_special ~= nil ) then
					is_better = is_special or not( old_is_special )
				elseif( type( old_v ) ~= "string" ) then
					if( old_v > v ) then
						is_better = true
					elseif( old_v < v ) then
						is_better = false
					end

					if( is_better ~= nil and stat.bigger_better ) then
						is_better = not( is_better )
					end
				end
				if( is_better ~= nil ) then
					clr = is_better and {70,208,70,inter_alpha} or {208,70,70,inter_alpha}
				end
			end

			stat.custom_func = stat.custom_func or pen.new_text
			uid = stat.custom_func( gui, uid, stat_x + 9, stat_y - 1, pic_z, done_v, { color = clr })
			-- stat.desc or ""
			
			stat_y = stat_y + 8 + ( stat.extra_step or 0 )
		end

		if( #this_info.tt_spacing[4] > 0 ) then
			uid = new_image( gui, uid, pic_x + this_info.tt_spacing[4][1], pic_y + this_info.tt_spacing[4][2], pic_z + 0.001, this_info.pic, scale, scale, inter_alpha, false, -math.rad( 90 ))
		end

		pic_y = pic_y + this_info.tt_spacing[2][2] + 5
		if( got_spells ) then
			uid = new_image( gui, uid, pic_x - 2, pic_y - 3, pic_z, "mods/index_core/files/pics/vanilla_tooltip_1.xml", this_info.tt_spacing[2][1], 1, 0.5*inter_alpha )

			local spell_x = pic_x
			for i = 0,1 do
				local tbl, counter = spell_list[ i == 0 and "permas" or "normies" ], 0
				if( i == 0 and #tbl > 0 ) then
					uid = new_image( gui, uid, spell_x, pic_y + 1, pic_z, "data/ui_gfx/inventory/icon_gun_permanent_actions.png", nil, nil, inter_alpha )
					counter = counter + 1
				end
				for k,spell in ipairs( tbl ) do
					uid = new_image( gui, uid, spell_x + 9*counter, pic_y, pic_z, spell.pic, 0.5, 0.5, inter_alpha )
					if( counter%2 == i ) then colourer( gui, {185,220,223}) end
					uid = new_image( gui, uid, spell_x + 9*counter - 1, pic_y - 1, pic_z + 0.001, data.slot_pic.bg_alt, 0.5, 0.5, inter_alpha, true )
					local _, _, is_hovered = GuiGetPreviousWidgetInfo( gui )
					if( is_hovered ) then
						uid = cat_callback( data, spell, "on_tooltip", {
							gui, uid, "wtt_spell", spell.id, data, spell, spell_x + 9*counter - 2, pic_y + 10, pic_z - 1
						}, { uid })
					end
					
					counter = counter + 1
					if( 9*( counter + 1 ) > this_info.tt_spacing[2][1]) then
						pic_y, counter = pic_y + 9, 0
					end
				end
				if( #tbl > 0 ) then pic_y = pic_y + 10 end
			end
		end

		if( is_advanced ) then
			-- uid = new_font_vanilla_shadow( gui, uid, pic_x - 3, orig_y + this_info.tt_spacing[6][2] + 3, pic_z, "hold "..get_binding_keys( "index_core", "az_tip_action", true ).."...", {170,170,170,inter_alpha})
		end

		return uid
	end, this_info }, true, in_world )

	return uid
end

function new_vanilla_ptt( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
	if( this_info.matter_info == nil ) then
		return uid
	end
	
	local total_cap, scale = this_info.matter_info[2][1], 1.5
	local new_desc, extra_desc = this_info.desc, ""
	if( this_info.matter_info[3] and total_cap > 0 ) then
		new_desc = new_desc.."@"..GameTextGet( "$item_description_potion_usage", "[RMB]" )
	end
	if( total_cap > 0 ) then
		new_desc = new_desc.."@ @"..GameTextGetTranslatedOrNot( "$inventory_capacity" ).." = "..total_cap.."/"..this_info.matter_info[1]
		for i,m in ipairs( this_info.matter_info[2][2]) do
			local count = 100*m[2]/total_cap
			extra_desc = extra_desc..( i > 1 and "@\t" or "\t" )..capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( m[1])))..": "..( count < 1 and "<" or "" )..math.max( math.floor( count + 0.5 ), 1 ).."%"
		end
	end

	this_info.tt_spacing = {
		{ get_text_dim( this_info.name )},
		{},
		{ get_pic_dim( this_info.pic )},
		{ 0, 0 },
		{},
	}
	this_info.done_desc, this_info.tt_spacing[2] = font_liner( new_desc, get_tip_width( new_desc, this_info.tt_spacing[1][1], 500, 2 ), -1 )
	if( extra_desc ~= "" ) then extra_desc, this_info.tt_spacing[4] = font_liner( extra_desc, 999, -1 ) end
	this_info.tt_spacing[3][1], this_info.tt_spacing[3][2] = scale*this_info.tt_spacing[3][1], scale*this_info.tt_spacing[3][2]
	local size_x = math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1], this_info.tt_spacing[4][1]) + 5
	local size_y = math.max( this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + this_info.tt_spacing[4][2] + ( extra_desc ~= "" and 11 or 5 ), this_info.tt_spacing[3][2] + 3 )
	this_info.tt_spacing[5] = { size_x, size_y }

	uid = data.tip_func( gui, uid, tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[5][1] + 5 + this_info.tt_spacing[3][1], this_info.tt_spacing[5][2] + 2 }, { function( gui, uid, pic_x, pic_y, pic_z, inter_alpha, this_data )
		pic_x = pic_x + 2
		uid = new_font_vanilla_shadow( gui, uid, pic_x, pic_y, pic_z, this_info.name, do_magic and {121,201,153,inter_alpha} or {255,255,178,inter_alpha})
		uid = new_font_vanilla_shadow( gui, uid, pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z, this_info.done_desc, {255,255,255,inter_alpha})
		uid = new_font_vanilla_shadow( gui, uid, pic_x + 1, pic_y + this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + 9, pic_z, extra_desc, {255,255,255,inter_alpha})
		
		local icon_x, icon_y = pic_x + this_info.tt_spacing[5][1], pic_y + ( this_info.tt_spacing[5][2] - this_info.tt_spacing[3][2])/2
		if( total_cap > 0 ) then
			local _,line_dims = font_liner( "\t", 999 )
			local line_w, line_h = line_dims[1] - 3, line_dims[2]
			for i,m in ipairs( this_info.matter_info[2][2]) do
				local t_x, t_y = pic_x + 1 + line_w, pic_y + this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + line_h*(i-1) + 9
				local perc = math.max( line_w*m[2]/total_cap, 1 )
				colourer( gui, get_matter_colour( CellFactory_GetName( m[1])))
				uid = new_image( gui, uid, t_x, t_y, pic_z + tonumber( "0.0001"..i ), data.pixel, -perc, line_h, inter_alpha )
				if( line_w - perc > 0.25 ) then
					uid = new_image( gui, uid, t_x - perc, t_y, pic_z + tonumber( "0.0001"..i ), data.pixel, -0.5, line_h, 0.75*inter_alpha )
				end
			end
			uid = new_vanilla_plate( gui, uid, pic_x + 2, pic_y + this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + 10, pic_z + 0.001, {line_w-2,line_h*#this_info.matter_info[2][2]-2}, inter_alpha )
			
			local cut = scale*this_info.potion_cutout
			local step = ( this_info.tt_spacing[3][2] - 2*cut )*math.max( math.min( 1 - total_cap/this_info.matter_info[1], 1 ), 0 ) + cut
			uid = new_cutout( gui, uid, icon_x, icon_y + step, this_info.tt_spacing[3][1], this_info.tt_spacing[3][2] - cut, function( gui, uid, v )
				colourer( gui, get_matter_colour( v[6]))
				return new_image( gui, uid, 0, -step, v[1], v[2], v[3], v[4], v[5])
			end, { pic_z - 1, this_info.pic, scale, scale, 0.8*inter_alpha, CellFactory_GetName( this_info.matter_info[2][2][1][1])})
		end
		uid = new_image( gui, uid, icon_x, icon_y, pic_z, this_info.pic, scale, scale, inter_alpha )

		return uid
	end, this_info }, true, in_world )

	return uid
end

function new_vanilla_stt( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
	if( this_info.spell_info == nil ) then
		return uid
	end
	
	--the pinned tip check should be within the tip code itself
	--hold alt to display advanced tooltip (list every damage type, additional info, all the shit is in frames)
	--hold alt to pin current tooltip in-place (allows hovering + works for wand ones too)
	--on alt add stuff to both columns with a spacer

	--[[
		c.damage_total_add
		icon_damage_projectile.png=c.damage_projectile_add
		icon_damage_curse.png=c.damage_curse_add
		icon_damage_explosion.png=c.damage_explosion_add
		icon_damage_slice.png=c.damage_slice_add
		icon_damage_melee.png=c.damage_melee_add
		icon_damage_ice.png=c.damage_ice_add
		icon_damage_electricity.png=c.damage_electricity_add
		icon_damage_drill.png=c.damage_drill_add
		icon_damage_healing.png=c.damage_healing_add
		c.damage_fire_add
		c.damage_holy_add
		c.damage_physics_add
		c.damage_poison_add
		c.damage_radioactive_add

		--c.explosion_damage_to_materials
		c.damage_critical_multiplier
		
		c.lifetime_add

		c_proj.damage.total
		c_proj.damage.curse
		c_proj.damage.drill
		c_proj.damage.electricity
		c_proj.damage.explosion
		c_proj.damage.fire
		c_proj.damage.healing
		c_proj.damage.ice
		c_proj.damage.melee
		c_proj.damage.overeating
		c_proj.damage.physics_hit
		c_proj.damage.poison
		c_proj.damage.projectile
		c_proj.damage.radioactive
		c_proj.damage.slice
		c_proj.damage.holy

		c_proj.damage_scaled_by_speed
		c_proj.damage_every_x_frames
			
		c_proj.lifetime
		
		c_proj.on_collision_die
		c_proj.on_death_duplicate
		c_proj.on_death_explode
		c_proj.on_lifetime_out_explode

		c_proj.collide_with_entities
		c_proj.penetrate_entities
		c_proj.dont_collide_with_tag
		c_proj.never_hit_player
		c_proj.friendly_fire
		c_proj.explosion_dont_damage_shooter

		c_proj.collide_with_world
		c_proj.penetrate_world
		c_proj.go_through_this_material
		c_proj.ground_penetration_coeff
		c_proj.ground_penetration_max_durability
		
		c_proj.explosion.damage_mortals
		c_proj.explosion.damage
		c_proj.explosion.is_digger
		c_proj.explosion.explosion_radius
		c_proj.explosion.max_durability_to_destroy
		c_proj.explosion.ray_energy
		
		c_proj.crit.chance
		c_proj.crit.damage_multiplier
		
		c_proj.lightning.damage_mortals
		c_proj.lightning.damage
		c_proj.lightning.is_digger
		c_proj.lightning.explosion_radius
		c_proj.lightning.max_durability_to_destroy
		c_proj.lightning.ray_energy
	]]
	
	this_info.tt_spacing = {
		{ get_text_dim( this_info.tip_name )},
		{},
	}
	this_info.tt_spacing[1][1] = this_info.tt_spacing[1][1] + 9 + ( this_info.charges >= 0 and 33 or 0 )
	this_info.done_desc, this_info.tt_spacing[2] = font_liner( this_info.desc, get_tip_width( this_info.desc, this_info.tt_spacing[1][1]), -1 )
	local size_x = math.max( math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1]) + 6, 121 )
	local size_y = this_info.tt_spacing[2][2] + 60
	this_info.tt_spacing[3] = { size_x, size_y }

	uid = data.tip_func( gui, uid, tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[3][1], this_info.tt_spacing[3][2]}, { function( gui, uid, pic_x, pic_y, pic_z, inter_alpha, this_data )
		pic_x, pic_y = pic_x + 2, pic_y + 2
		colourer( gui, type2frame[ this_info.spell_info.type ][2])
		uid = new_image( gui, uid, pic_x, pic_y, pic_z - 0.001, "data/ui_gfx/inventory/icon_action_type.png", nil, nil, 0.75*inter_alpha )
		uid = new_image( gui, uid, pic_x, pic_y, pic_z, "data/ui_gfx/inventory/icon_action_type.png", nil, nil, inter_alpha )
		colourer( gui, {0,0,0})
		uid = new_image( gui, uid, pic_x, pic_y + 1, pic_z + 0.001, "data/ui_gfx/inventory/icon_action_type.png", nil, nil, inter_alpha )
		uid = new_font_vanilla_shadow( gui, uid, pic_x + 9, pic_y - 1, pic_z, this_info.tip_name, {255,255,178,inter_alpha})
		
		--inventory_actiontype
		-- inventory_actiontype_projectile
		-- inventory_actiontype_staticprojectile
		-- inventory_actiontype_modifier
		-- inventory_actiontype_drawmany
		-- inventory_actiontype_material
		-- inventory_actiontype_other
		-- inventory_actiontype_utility
		-- inventory_actiontype_passive

		-- inventory_usesremaining

		if( this_info.charges >= 0 ) then --on hover - this_info.charges.."/"..this_info.max_uses
			uid = new_image( gui, uid, pic_x + this_info.tt_spacing[3][1] - 13, pic_y, pic_z, "data/ui_gfx/inventory/icon_action_max_uses.png", nil, nil, inter_alpha )
			local charges = get_tiny_num( this_info.charges )
			uid = new_font_vanilla_shadow( gui, uid, pic_x + this_info.tt_spacing[3][1] - 14 - get_text_dim( charges ), pic_y - 1, pic_z, charges, {170,170,170,inter_alpha})
		end

		uid = new_image( gui, uid, pic_x - 2, pic_y + 9, pic_z, "mods/index_core/files/pics/vanilla_tooltip_1.xml", this_info.tt_spacing[3][1] - 2, 1, 0.5*inter_alpha )
		uid = new_font_vanilla_shadow( gui, uid, pic_x, pic_y + 11, pic_z, this_info.done_desc, {255,255,255,inter_alpha})
		pic_y = pic_y + 13 + this_info.tt_spacing[2][2]
		uid = new_image( gui, uid, pic_x - 2, pic_y, pic_z, "mods/index_core/files/pics/vanilla_tooltip_1.xml", this_info.tt_spacing[3][1] - 2, 1, 0.5*inter_alpha )
		uid = new_image( gui, uid, pic_x - 3 + math.floor( this_info.tt_spacing[3][1]/2 ), pic_y + 1, pic_z, "mods/index_core/files/pics/vanilla_tooltip_1.xml", 1, 43, 0.5*inter_alpha )

		local function get_generic_stat( v, v_add, dft, allow_inf )
			v, v_add, allow_inf = v or dft, v_add or 0, allow_inf or false
			local is_dft = v == dft
			return get_short_num( is_dft and v_add or ( v + v_add ), ( is_dft or not( allow_inf )) and 1 or nil, is_dft ), is_dft and (v_add==0)
		end
		local c, c_proj = this_info.spell_info.meta.state, this_info.spell_info.meta.state_proj
		local no_draw = ( c.draw_many or 0 ) == 0
		local stats_tbl = {
			{
				{
					pic = no_draw and "data/ui_gfx/inventory/icon_gun_charge.png" or "data/ui_gfx/inventory/icon_gun_actions_per_round.png",
					name = no_draw and "Projectile Count" or "Draw Extra",
					
					v = no_draw and ( c.proj_count or 0 ) or c.draw_many,
					value = function( v ) return get_generic_stat( v, nil, 0 ) end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_mana_drain.png",
					name = "$inventory_manadrain",
					
					v = this_info.spell_info.mana,
					value = function( v ) return get_generic_stat( v, nil, 0 ) end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_fire_rate_wait.png", off_y = 1,
					name = "$inventory_mod_castdelay",

					v = c.fire_rate_wait,
					value = function( v )
						local v, is_dft = get_generic_stat( nil, ( v or 0 )/60, 0, false, true )
						return v.."s", is_dft
					end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_reload_time.png",
					name = "$inventory_mod_rechargetime",

					v = ( this_info.spell_info.is_chainsaw or false ) and "Chainsaw" or c.reload_time,
					value = function( v )
						local v, is_dft = get_generic_stat( nil, ( v or 0 )/60, 0, false, true )
						return v.."s", is_dft
					end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_spread_degrees.png",
					name = "$inventory_mod_spread",
					
					v = c.spread_degrees,
					value = function( v ) return get_generic_stat( nil, v, 0 ) end,
					custom_func = function( gui, uid, pic_x, pic_y, pic_z, txt, color )
						local shift = 0
						uid, shift = new_font_vanilla_shadow( gui, uid, pic_x, pic_y, pic_z, txt, color )
						colourer( gui, color )
						uid = new_image( gui, uid, pic_x + shift, pic_y, pic_z, "mods/index_core/files/fonts/vanilla_shadow/degree.png", nil, nil, color[4])
						return uid
					end,
					tip = 0,
				},
			},
			{
				{
					pic = "data/ui_gfx/inventory/icon_damage_projectile.png",
					name = "$inventory_mod_damage",
					
					v = ( c.damage_null_all > 0 ) and "Ø" or c_proj.damage.total,
					value = function( v ) return get_generic_stat( 25*( v or 0 ), 25*( c.damage_total_add or 0 ), 0 ) end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_damage_critical_chance.png", off_y = 1,
					name = "$inventory_mod_critchance",

					v = c_proj.crit.chance,
					value = function( v )
						local v, is_dft = get_generic_stat( v, c.damage_critical_chance, 0, false, true )
						return v.."%", is_dft
					end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_speed_multiplier.png", off_y = 1,
					name = "$inventory_mod_speed",

					v = c_proj.speed,
					value = function( v )
						local v_add = c.speed_multiplier
						v, v_add, allow_inf = v or 0, v_add or 1
						local is_dft = v == 0
						return ( is_dft and "x" or "" )..get_short_num( is_dft and v_add or ( v*v_add )), is_dft and ( v_add == 1 )
					end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_bounces.png", off_y = -1,
					name = "$inventory_mod_bounces",
					
					v = ( c_proj.inf_bounces or false ) and "∞" or c_proj.bounces,
					value = function( v ) return get_generic_stat( v, c.bounces, 0 ) end,
					tip = 0,
				},
				{
					pic = "data/ui_gfx/inventory/icon_explosion_radius.png",
					name = "$inventory_mod_explosion_radius",

					v = c_proj.lightning.explosion_radius or c_proj.explosion.explosion_radius,
					value = function( v ) return get_generic_stat( v, c.explosion_radius, 0 ) end,
					tip = 0,
				},
			},
		}
		for k,column in ipairs( stats_tbl ) do
			local stat_x, stat_y = pic_x + ( k > 1 and math.floor( this_info.tt_spacing[3][1]/2 ) or 0 ), pic_y + 3
			for i,stat in ipairs( column ) do
				--add custom stats to both columns (with a spacer)

				local v, is_default = stat.v, false
				if( type( v or 0 ) ~= "string" ) then v, is_default = stat.value( v ) end
				local alpha = ( is_default and 0.5 or 1 )*inter_alpha
				uid = new_image( gui, uid, stat_x, stat_y + ( stat.off_y or 0 ), pic_z, stat.pic, nil, nil, alpha )
				stat.custom_func = stat.custom_func or new_font_vanilla_shadow
				uid = stat.custom_func( gui, uid, stat_x + 9, stat_y - 1, pic_z, v, {170,170,170,alpha})
				-- stat.desc or ""

				stat_y = stat_y + 8
			end
		end

		pic_y = pic_y - this_info.tt_spacing[2][2] + this_info.tt_spacing[3][2] - 13
		if( not( in_world )) then
			-- uid = new_font_vanilla_shadow( gui, uid, pic_x - 3, pic_y, pic_z, "hold "..get_binding_keys( "index_core", "az_tip_action", true ).."...", {170,170,170,inter_alpha})
		end
		if( this_info.spell_info.price > 0 ) then
			local price = get_short_num( this_info.spell_info.price )
			uid = new_font_vanilla_shadow( gui, uid, pic_x + this_info.tt_spacing[3][1] - 8 - get_text_dim( price ), pic_y, pic_z, price, {255,255,178,inter_alpha})
			uid = new_font_vanilla_shadow( gui, uid, pic_x + this_info.tt_spacing[3][1] - 7, pic_y, pic_z, "$", {255,255,255,inter_alpha})
		end

		return uid
	end, this_info }, true, in_world )
	
	return uid
end

function new_vanilla_ttt( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world )
	return new_vanilla_itt( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world, true )
end

function new_vanilla_itt( gui, uid, tid, item_id, data, this_info, pic_x, pic_y, pic_z, in_world, do_magic )
	if( not( pen.vld( this_info.name ) and pen.vld( this_info.desc ) and pen.vld( this_info.pic ))) then
		return uid
	end
	
	this_info.tt_spacing = {
		{ get_text_dim( this_info.name )},
		{},
		{ get_pic_dim( this_info.pic )},
		{},
	}
	this_info.done_desc, this_info.tt_spacing[2] = font_liner( this_info.desc, get_tip_width( this_info.desc, this_info.tt_spacing[1][1], 500, 2 ), -1 )
	this_info.tt_spacing[3][1], this_info.tt_spacing[3][2] = 1.5*this_info.tt_spacing[3][1], 1.5*this_info.tt_spacing[3][2]
	local size_x = math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1]) + 5
	local size_y = math.max( this_info.tt_spacing[1][2] + 5 + this_info.tt_spacing[2][2], this_info.tt_spacing[3][2] + 3 )
	this_info.tt_spacing[4] = { size_x, size_y }

	uid = data.tip_func( gui, uid, tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[4][1] + 5 + this_info.tt_spacing[3][1], this_info.tt_spacing[4][2] + 2 }, { function( gui, uid, pic_x, pic_y, pic_z, inter_alpha, this_data )
		pic_x = pic_x + 2
		uid = new_font_vanilla_shadow( gui, uid, pic_x, pic_y, pic_z, this_info.name, do_magic and {121,201,153,inter_alpha} or {255,255,178,inter_alpha})
		if( do_magic ) then
			local storage_rune = get_storage( this_info.id, "runic_cypher" )
			if( storage_rune == nil ) then
				storage_rune = EntityAddComponent( this_info.id, "VariableStorageComponent",
				{
					name = "runic_cypher",
					value_float = "0",
				})
			end
			local runic_state = ComponentGetValue2( storage_rune, "value_float" )
			if( runic_state ~= 1 ) then
				uid = pen.new_text( gui, uid, pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z,
					table.concat({ "{>runic>{", this_info.done_desc, "}<runic<}" }), {
					fully_featured = true, color = pen.PALETTE.VNL.RUNIC, alpha = inter_alpha*( 1 - runic_state )})
			end
			if( runic_state >= 0 ) then
				uid = pen.new_text( gui, uid, pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z + 0.001,
					this_info.done_desc, { fully_featured = true, is_shadow = true, alpha = inter_alpha*runic_state })
				ComponentSetValue2( storage_rune, "value_float", simple_anim( data, "runic"..this_info.id, 1, 0.01, 0.001 ))
			end
		else
			uid = new_font_vanilla_shadow( gui, uid, pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z, this_info.done_desc, {255,255,255,inter_alpha})
		end
		uid = new_image( gui, uid, pic_x + this_info.tt_spacing[4][1], pic_y + ( this_info.tt_spacing[4][2] - this_info.tt_spacing[3][2])/2, pic_z, this_info.pic, 1.5, 1.5, inter_alpha )
		
		return uid
	end, this_info }, true, in_world )

	return uid
end

function new_slot_pic( gui, uid, pic_x, pic_y, z, pic, alpha, angle, hov_scale, fancy_shadow )
	angle = angle or 0
	scale_up = scale_up or false
	item_pic_data[ pic ] = item_pic_data[ pic ] or {
		xy = { 0, 0 },
		xml_xy = { 0, 0 },
	}
	
	local w, h = unpack( item_pic_data[ pic ].dims or {get_pic_dim( pic )})
	local off_x, off_y = 0, 0
	if( item_pic_data[ pic ].xy[3] == nil ) then
		if( item_pic_data[ pic ].xy[1] ~= 0 or item_pic_data[ pic ].xy[2] ~= 0 ) then
			local x, y = unpack( item_pic_data[ pic ].xy )
			x, y = rotate_offset( x, y, angle )
			off_x, off_y = x, y
		end
	else
		angle = 0
		off_x, off_y = w/2, h/2
	end
	if( item_pic_data[ pic ].anim ) then
		pic = new_anim_looped( unpack( item_pic_data[ pic ].anim ))
	end
	
	local extra_scale = hov_scale or 1
	pic_x, pic_y = pic_x - extra_scale*off_x, pic_y - extra_scale*off_y
	uid = new_image( gui, uid, pic_x, pic_y, z - 0.002, pic, extra_scale, extra_scale, alpha, false, angle )

	if( fancy_shadow ~= false ) then
		fancy_shadow = fancy_shadow or false
		local sign = fancy_shadow and 1 or -1
		local scale_x, scale_y = 1/w + 1, 1/h + 1
		colourer( gui, {0,0,0})
		off_x, off_y = rotate_offset( sign*0.5, sign*0.5, angle )
		uid = new_image( gui, uid, pic_x + extra_scale*off_x, pic_y + extra_scale*off_y, z, pic, extra_scale*scale_x, extra_scale*scale_y, 0.25, false, angle )
	end
	
	return uid, pic_x, pic_y
end

function new_spell_frame( gui, uid, pic_x, pic_y, pic_z, spell_type, alpha, angle )
	local off_x, off_y = rotate_offset( 10, 10, angle or 0 )
	return new_image( gui, uid, pic_x - off_x, pic_y - off_y, pic_z, type2frame[ spell_type ][1], nil, nil, alpha, nil, angle )
end

function new_vanilla_icon( gui, uid, pic_x, pic_y, pic_z, icon_info, kind )
	if( icon_info == nil or icon_info.pic == "" ) then
		return uid, 0, 0
	end

	local pic_off_x, pic_off_y = 0, 0
	if( kind == 2 ) then
		pic_off_x, pic_off_y = 0.5, 0.5
	elseif( kind == 4 ) then
		pic_off_x, pic_off_y = -2.5, 0
	end

    local w, h = get_pic_dim( icon_info.pic )
	-- if( kind == 2 ) then GuiColorSetForNextWidget( gui, 0.3, 0.3, 0.3, 1 ) end
	uid = new_image( gui, uid, pic_x + pic_off_x, pic_y + pic_off_y, pic_z, icon_info.pic, nil, nil, 1, true )
	local _, _, is_hovered = GuiGetPreviousWidgetInfo( gui )

	if( kind == 2 and icon_info.amount > 0 ) then
		-- local step = math.floor( h*( 1 - math.min( icon_info.amount, 1 )) + 0.5 )
		-- uid = new_cutout( gui, uid, pic_x + pic_off_x, pic_y + pic_off_y + step, w, h, function( gui, uid, v )
		-- 	return new_image( gui, uid, 0, -step, v[1], v[2])
		-- end, { pic_z - 0.002, icon_info.pic })
		
		local scale = 10*icon_info.amount
		local pos = 10*( 1 - icon_info.amount )
		local pixel = "mods/index_core/files/pics/THE_GOD_PIXEL.png"
		GuiColorSetForNextWidget( gui, 0.7, 0.7, 0.7, 1 )
		uid = new_image( gui, uid, pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 1, pic_z - 0.001, pixel, 10, pos, 0.15 )
		uid = new_image( gui, uid, pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 1 + pos, pic_z + 0.004, pixel, 10, scale, 0.25 )

		GuiColorSetForNextWidget( gui, 0, 0, 0, 1 )
		uid = new_image( gui, uid, pic_x + pic_off_x - 0.5, pic_y + pic_off_y + 1 + pos, pic_z + 0.004, pixel, 1, scale, 0.15 )
		GuiColorSetForNextWidget( gui, 0, 0, 0, 1 )
		uid = new_image( gui, uid, pic_x + pic_off_x + 10.5, pic_y + pic_off_y + 1 + pos, pic_z + 0.004, pixel, 1, scale, 0.15 )
		GuiColorSetForNextWidget( gui, 0, 0, 0, 1 )
		uid = new_image( gui, uid, pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 11, pic_z + 0.004, pixel, 10, 1, 0.15 )
	end

	local txt_off_x, txt_off_y = 0, 0
	if( kind == 2 ) then
		txt_off_x, txt_off_y = 1, 1
	elseif( kind == 4 ) then
		txt_off_x, txt_off_y = 1, 2
	end

	local tip_x, tip_y = pic_x - 3, pic_y
	if( icon_info.txt ~= "" ) then
		icon_info.txt = space_obliterator( icon_info.txt )
		local t_x, t_h = get_text_dim( icon_info.txt )
		t_x = t_x - txt_off_x
		uid = new_font_vanilla_shadow( gui, uid, pic_x - ( t_x + 1 ), pic_y + 1 + txt_off_y, pic_z, icon_info.txt, {255,255,255,is_hovered and 1 or 0.5})
		tip_x = tip_x - t_x
	end
	if(( icon_info.count or 0 ) > 1 ) then
		uid = new_font_vanilla_shadow( gui, uid, pic_x + 15, pic_y + 1 + txt_off_y, pic_z, "x"..icon_info.count, {255,255,255,is_hovered and 1 or 0.5})
	end
	if( kind == 4 ) then
		pic_y = pic_y - 3
	end
	if( icon_info.desc ~= "" and is_hovered and tip_anim["generic"][1] > 0 ) then
		icon_info.desc = space_obliterator( icon_info.desc )
		local anim = math.sin( math.min( tip_anim["generic"][3], 10 )*math.pi/20 )
		local dims = { get_text_dim( icon_info.desc )}
		uid = new_font_vanilla_shadow( gui, uid, pic_x - dims[1] + w, pic_y + h + 3, pic_z, icon_info.desc, icon_info.is_danger and {224,96,96,anim} or {255,255,255,anim})
		
		local bg_x = pic_x - ( dims[1] + 2 ) + w
		uid = new_vanilla_plate( gui, uid, bg_x, pic_y + h + 4, pic_z + 0.01, { dims[1] + 3, dims[2] - 1 }, anim*0.9 )
		
		h = h + dims[2] + ( kind == 4 and 2 or 4 ) + ( kind == 1 and 1 or 0 ) + 3
	end
	if( icon_info.tip ~= "" ) then
		local is_func = type( icon_info.tip ) == "function"
		local v = { is_func and "" or space_obliterator( icon_info.tip ), tip_x, tip_y + ( kind == 4 and 1 or 0 ), }
		if( is_func ) then
			v[4] = math.min( #icon_info.other_perks, 10 )*14-1
			v[5] = 14*math.max( math.ceil(( #icon_info.other_perks )/10 ), 1 )
		end
		uid = new_vanilla_tooltip( gui, uid, nil, pic_z - 5, v, { icon_info.tip, icon_info.other_perks }, is_hovered, true, true )
	end

	if( kind == 1 ) then
		uid = new_image( gui, uid, pic_x, pic_y, pic_z + 0.002, "data/ui_gfx/status_indicators/bg_ingestion.png" )
		
		local d_frame = icon_info.digestion_delay
		if( icon_info.is_stomach and d_frame > 0 ) then
			uid = new_image( gui, uid, pic_x + 1, pic_y + 1 + 10*( 1 - d_frame ), pic_z + 0.001, "mods/index_core/files/pics/vanilla_stomach_bg.xml", 10, math.ceil( 20*d_frame )/2, 0.3 )
		end
	end

	return uid, w, h
end

function new_vanilla_slot( gui, uid, pic_x, pic_y, zs, data, slot_data, this_info, is_active, can_drag, is_full, is_quick )
	local slot_pics = {
		bg_alt = slot_data.pic_bg_alt or data.slot_pic.bg_alt,
		bg = slot_data.pic_bg or data.slot_pic.bg,
		active = slot_data.pic_active or data.slot_pic.active,
		hl = slot_data.pic_hl or data.slot_pic.hl,
		locked = slot_data.pic_locked or data.slot_pic.locked,
	}
	local slot_sfxes = {
		select = slot_data.sfx_select or data.sfxes.select,
		move_item = slot_data.sfx_move_item or data.sfxes.move_item,
		move_empty = slot_data.sfx_move_empty or data.sfxes.move_empty,
		hover = slot_data.sfx_hover or data.sfxes.hover,
	}
	local cat_tbl = {
		on_equip = cat_callback( data, this_info, "on_equip" ),
		on_action = cat_callback( data, this_info, "on_action" ),
		on_slot = cat_callback( data, this_info, "on_slot" ),
		on_tooltip = cat_callback( data, this_info, "on_tooltip" ),
	}
	if( cat_tbl.on_action ~= nil ) then
		cat_tbl.on_rmb = cat_tbl.on_action( 1 )
		cat_tbl.on_drag = cat_tbl.on_action( 2 )
	end

	if( this_info.id > 0 and data.dragger.item_id == this_info.id ) then
		colourer( data.the_gui, {150,150,150})
	end
	local pic_bg, clicked, r_clicked, is_hovered = ( is_full == true ) and data.slot_pic.bg_alt or data.slot_pic.bg, false, false, false
	local w, h = get_pic_dim( pic_bg )
	uid = new_image( data.the_gui, uid, pic_x, pic_y, zs.main_far_back, pic_bg, nil, nil, nil, true )
	clicked, r_clicked, is_hovered = GuiGetPreviousWidgetInfo( data.the_gui )
	local might_swap = not( data.is_opened ) and is_quick and is_hovered
	if(( clicked or slot_data.force_equip ) and this_info.id > 0 ) then
		local do_default = might_swap or slot_data.force_equip
		if( cat_tbl.on_equip ~= nil ) then
			if( cat_tbl.on_equip( this_info.id, data, this_info )) then
				play_sound( data, slot_sfxes.select )
				do_default = false
			end
		end
		if( do_default and ( this_info.in_hand or 0 ) == 0 ) then
			play_sound( data, slot_sfxes.select )
			local inv_comp = active_item_reset( get_item_owner( this_info.id, true ))
			ComponentSetValue2( inv_comp, "mSavedActiveItemIndex", get_child_num( slot_data.inv_id, this_info.id ))
		end
	end
	
	local no_action, dragger_hovered = cat_tbl.on_drag == nil, false
	pic_x, pic_y = pic_x + w/2, pic_y + h/2
	if(( is_full ~= true ) and is_active ) then
		uid = new_image( gui, uid, pic_x, pic_y, zs[( not( data.is_opened ) or can_drag ) and "main_front" or "icons_front" ] + 0.0001, data.slot_pic.active )
	end
	if( data.dragger.item_id > 0 ) then
		local no_hov_for_ya = true
		if( check_bounds( data.pointer_ui, {pic_x,pic_y}, {-w/2,w/2,-h/2,h/2})) then
			data.dragger.wont_drop = true
			if( can_drag ) then
				local dragged_data = from_tbl_with_id( data.item_list, data.dragger.item_id )
				if( slot_swap_check( data, dragged_data, this_info, slot_data )) then
					no_hov_for_ya = false
					if( data.dragger.swap_now ) then
						if( this_info.id > 0 ) then
							table.insert( slot_anim, {
								id = this_info.id,
								x = pic_x,
								y = pic_y - 10,
								frame = data.frame_num,
							})
						end
						play_sound( data, slot_sfxes[ this_info.id > 0 and "move_item" or "move_empty" ])
						slot_swap( data, data.dragger.item_id, slot_data )
						data.dragger.item_id = -1
					end
					if( slot_memo[ data.dragger.item_id ] and data.dragger.item_id ~= this_info.id ) then
						dragger_hovered = true
						uid = new_image( gui, uid, pic_x - w/2, pic_y - w/2, zs.main_front + 0.001, data.slot_pic.hl )
					end
				end
			end
		end
		if( no_hov_for_ya ) then
			is_hovered = false
		end
	end
	if((( this_info.id > 0 and is_hovered ) or dragger_hovered ) and not( slot_hover_sfx[2])) then
		local slot_uid = tonumber( slot_data.inv_id ).."|"..slot_data.inv_slot[1]..":"..slot_data.inv_slot[2]
		if( slot_hover_sfx[1] ~= slot_uid ) then
			slot_hover_sfx[1] = slot_uid
			play_sound( data, slot_sfxes.hover )
		end
		slot_hover_sfx[2] = true
	end
	
	local slot_x, slot_y = pic_x - w/2, pic_y - h/2
	if( can_drag ) then
		if( this_info.id > 0 and not( data.dragger.swap_now or slot_going )) then
			data, pic_x, pic_y = new_dragger_shell( this_info.id, this_info, pic_x, pic_y, w/2, h/2, data )
		end
	elseif( data.is_opened ) then
		if( is_full == true ) then
			colourer( gui, {150,150,150})
			uid = new_image( gui, uid, slot_x - 0.5, slot_y - 0.5, zs.icons_front + 0.001, data.slot_pic.bg_alt, 21/20, 21/20, 0.75 )
		else
			uid = new_image( gui, uid, slot_x, slot_y, zs.icons_front + 0.001, data.slot_pic.locked )
		end
	end
	
	if( this_info.id > 0 ) then
		local is_dragged = slot_memo[ data.dragger.item_id ] and data.dragger.item_id == this_info.id
		local suppress_charges, suppress_action = false, false
		if( cat_tbl.on_slot ~= nil ) then
			if( no_action and is_dragged ) then
				pic_x, pic_y = pic_x + 10, pic_y + 10
			end
			
			pic_x, pic_y = swap_anim( this_info.id, pic_x, pic_y, data )
			uid, this_info, suppress_charges, suppress_action = cat_tbl.on_slot( gui, uid, this_info.id, data, this_info, pic_x, pic_y, zs, {
				is_lmb = clicked,
				is_rmb = r_clicked,
				is_hov = is_hovered,
				is_full = is_full,
				is_active = is_active,
				is_quick = is_quick,
				can_drag = can_drag,
				is_dragged = is_dragged,
				is_opened = data.is_opened or data.allow_tips_always,
			}, cat_tbl.on_rmb, cat_tbl.on_drag, cat_tbl.on_tooltip, might_swap and 1.2 or 1 )
		end
		if( not( suppress_action or false )) then
			if( is_dragged ) then
				if( cat_tbl.on_drag ~= nil and data.drag_action ) then
					cat_tbl.on_drag( this_info.id, data, this_info )
				end
			elseif( cat_tbl.on_rmb ~= nil and r_clicked and data.is_opened and is_quick ) then
				cat_tbl.on_rmb( this_info.id, data, this_info )
			end
		end
		if( not( suppress_charges or false )) then
			slot_x, slot_y = slot_x + 2, slot_y + 2
			if( this_info.charges > -1 ) then
				local shift = ( is_full == true ) and 1 or 0
				if( this_info.charges == 0 ) then
					if( this_info.is_consumable ) then
						EntityKill( this_info.id )
					else
						local cross_x, cross_y = slot_x - 2*shift, slot_y - 2*shift
						uid = new_image( gui, uid, cross_x, cross_y, zs.icons_front, "mods/index_core/files/pics/vanilla_no_cards.xml" )
						colourer( gui, {0,0,0})
						uid = new_image( gui, uid, cross_x + 0.5, cross_y + 0.5, zs.icons_front + 0.001, "mods/index_core/files/pics/vanilla_no_cards.xml", nil, nil, 0.75 )
					end
				else
					uid = pen.new_text( gui, uid, slot_x + ( 1 - shift ), slot_y, zs.icons_front,
						math.floor( this_info.charges ), { is_huge = false })
					uid = pen.new_text( gui, uid, slot_x + ( 1 - shift ) + 0.5, slot_y + 0.5, zs.icons_front + 0.0001,
						math.floor( this_info.charges ), { is_huge = false, color = pen.PALETTE.B, alpha = 0.75 })
				end
			end
		end
	end
	
	return uid, data, w-1, h-1, clicked, r_clicked, is_hovered
end

function slot_setup( gui, uid, pic_x, pic_y, zs, data, slot_data, can_drag, is_full, is_quick )
	local this_info = slot_data.idata or {}
	if( not( slot_data.id )) then
		slot_data.id = -1
		this_info = { id = slot_data.id, in_hand = 0 }
	elseif( this_info.id == nil ) then
		this_info = from_tbl_with_id( data.item_list, slot_data.id )
	end
	if( slot_data.id > 0 ) then
		if( EntityHasTag( this_info.id, "index_unlocked" )) then
			can_drag = true
		elseif( this_info.is_locked ) then
			can_drag = false
		end
	elseif( EntityHasTag( data.dragger.item_id, "index_unlocked" )) then
		local inv_info = from_tbl_with_id( data.item_list, slot_data.inv_id, nil, nil, {})
		if( inv_info.id == nil or not( inv_info.is_frozen )) then
			can_drag = true
		end
	end
	
	local w, h, clicked, r_clicked, is_hovered = false, false, false
	uid, data, w, h, clicked, r_clicked, is_hovered = data.slot_func( gui, uid, pic_x, pic_y, zs, data, slot_data, this_info, this_info.in_hand > 0, can_drag, is_full, is_quick )
	if( this_info.cat ~= nil ) then
		uid, data = cat_callback( data, this_info, "on_inventory", {
			gui, uid, this_info.id, data, this_info, pic_x, pic_y, zs, {
				can_drag = can_drag,
				is_dragged = data.dragger.item_id > 0 and data.dragger.item_id == this_info.id,
				in_hand = this_info.in_hand > 0,
				is_quick = is_quick,
				is_full = is_full,
			}
		}, { uid, data })
	end
	
	return uid, data, w, h
end

function new_vanilla_wand( gui, uid, pic_x, pic_y, zs, data, this_info, in_hand, can_tinker )
	local step_x, step_y = 0, 0
	local scale = data.no_wand_scaling and 1 or 1.5
	local extra_step = ( this_info.wand_info.shuffle_deck_when_empty or this_info.wand_info.actions_per_round > 1 ) and 3 or 0
	this_info.w_spacing = {
		extra_step - 1, 0,
		19*this_info.wand_info.deck_capacity + 4, 0,
	}
	if( item_pic_data[ this_info.pic ]) then
		local drift = this_info.w_spacing[1]
		this_info.w_spacing[2] = drift
		if( item_pic_data[ this_info.pic ].xy ) then
			drift = drift + scale*item_pic_data[ this_info.pic ].xy[1]
		end
		if( item_pic_data[ this_info.pic ].xml_xy ) then
			drift = drift - scale*item_pic_data[ this_info.pic ].xml_xy[1]
		end
		this_info.w_spacing[1] = drift

		if( item_pic_data[ this_info.pic ].dims ) then
			this_info.w_spacing[2] = this_info.w_spacing[2] + scale*item_pic_data[ this_info.pic ].dims[1] + 1
			local min_val = math.ceil( math.max( this_info.w_spacing[1] + this_info.w_spacing[2] - extra_step, 25 )/19 )*19
			if( this_info.w_spacing[2] < min_val ) then
				this_info.w_spacing[1] = drift + ( min_val - this_info.w_spacing[2])/2
				this_info.w_spacing[2] = min_val
			end
		end

		drift = scale*item_pic_data[ this_info.pic ].dims[2] - 18
		if( drift > 0 ) then
			this_info.w_spacing[4] = drift
		end
	end

	step_x, step_y = this_info.w_spacing[2] + this_info.w_spacing[3], 19 + this_info.w_spacing[4]
	uid = data.tip_func( gui, uid, this_info.id, zs.main_far_back, { "", pic_x, pic_y, step_x, step_y }, { function( gui, uid, pic_x, pic_y, pic_z, inter_alpha, this_info )
		local is_shuffle, is_multi = this_info.wand_info.shuffle_deck_when_empty, this_info.wand_info.actions_per_round > 1
		if( is_shuffle or is_multi ) then
			if( is_shuffle ) then
				uid = new_image( gui, uid, pic_x, pic_y, pic_z, "data/ui_gfx/inventory/icon_gun_shuffle.png", nil, nil, inter_alpha )
				colourer( gui, pen.PALETTE.B )
				uid = new_image( gui, uid, pic_x + 0.5, pic_y + 0.5, pic_z + 0.001, "data/ui_gfx/inventory/icon_gun_shuffle.png", nil, nil, inter_alpha*0.75 )
			end
			if( is_multi ) then
				local multi_y = pic_y + this_info.w_spacing[4]
				uid = new_image( gui, uid, pic_x, multi_y + 11, pic_z, "data/ui_gfx/inventory/icon_gun_actions_per_round.png", nil, nil, inter_alpha )
				colourer( gui, pen.PALETTE.B )
				uid = new_image( gui, uid, pic_x + 0.5, multi_y + 10.5, pic_z + 0.001, "data/ui_gfx/inventory/icon_gun_actions_per_round.png", nil, nil, inter_alpha*0.75 )
				uid = pen.new_text( gui, uid, pic_x + 9, multi_y + 10, pic_z, this_info.wand_info.actions_per_round, {
					color = pen.PALETTE.VNL.GREY, alpha = inter_alpha })
				uid = pen.new_text( gui, uid, pic_x + 9.5, multi_y + 9.5, pic_z + 0.001, this_info.wand_info.actions_per_round, {
					color = pen.PALETTE.SHADOW, alpha = 0.5*inter_alpha })
			end
		end

		local drift, section_off = this_info.w_spacing[1], this_info.w_spacing[2]
		uid = new_slot_pic( gui, uid, pic_x + drift, pic_y + 9 + this_info.w_spacing[4]/2, pic_z + 0.005, this_info.pic, inter_alpha, 0, scale, true )
		local clicked, r_clicked, is_hovered = false, false, false
		uid, clicked, r_clicked, is_hovered = new_interface( gui, uid, { pic_x, pic_y, section_off, 18 + this_info.w_spacing[4]}, pic_z - 0.001 )
		pic_x = pic_x + section_off
		if( this_info.is_frozen ) then
			uid = new_shaded_image( gui, uid, pic_x - 5, pic_y + step_y - 7, pic_z - 0.01, "mods/index_core/files/pics/frozen_marker.png", {9,9}, nil, nil, inter_alpha, true )
			uid = new_vanilla_tooltip( gui, uid, nil, pic_z - 5, GameTextGetTranslatedOrNot( "$inventory_info_frozen_description" ))
		end
		if( is_hovered ) then
			uid = cat_callback( data, this_info, "on_tooltip", {
				gui, uid, nil, this_info.id, data, this_info, pic_x + 1, pic_y - 2, zs.tips, false, true
			}, { uid })
		end
		uid = new_image( gui, uid, pic_x, pic_y - 1, pic_z, "mods/index_core/files/pics/vanilla_tooltip_1.xml", 1, step_y + 1, 0.5*inter_alpha )
		
		local slot_count = this_info.wand_info.deck_capacity
		if( slot_count > 26 ) then
			--arrows (small bouncing of slot row post scroll based on the direction scrolled)
			--use temp cutouts for transition
		end

		if( can_tinker == nil ) then
			can_tinker = not( this_info.is_frozen )
			if( can_tinker ) then
				can_tinker = data.can_tinker or EntityHasTag( this_info.id, "index_unlocked" )
			end
		end

		local counter = 1
		local slot_x, slot_y = pic_x + 2, pic_y - 1 + this_info.w_spacing[4]
		local slot_data = data.slot_state[ this_info.id ]
		for i,col in ipairs( slot_data ) do
			for e,slot in ipairs( col ) do
				local idata = nil
				if( slot ) then
					idata = from_tbl_with_id( data.item_list, slot )
					if( idata.is_permanent ) then
						uid = new_image( gui, uid, slot_x + 1, slot_y + 12, zs.icons_front, "data/ui_gfx/inventory/icon_gun_permanent_actions.png" )
						colourer( gui, {0,0,0})
						uid = new_image( gui, uid, slot_x + 1.5, slot_y + 11.5, zs.icons_front + 0.0001, "data/ui_gfx/inventory/icon_gun_permanent_actions.png", nil, nil, 0.75 )
					end
				end
				
				if( counter%2 == 0 and slot_count > 2 ) then colourer( data.the_gui, {185,220,223}) end
				uid, data, w, h = slot_setup( gui, uid, slot_x, slot_y, zs, data, {
					inv_id = this_info.id,
					id = slot,
					inv_slot = {i,e},
					idata = idata,
				}, can_tinker, true, false )
				slot_x, slot_y = slot_x, slot_y + h
				counter = counter + 1
			end
			slot_x, slot_y = slot_x + w, pic_y - 1 + this_info.w_spacing[4]
		end

		return uid
	end, this_info }, true, nil, nil, in_hand )

	return uid, step_x + 7, step_y + 7
end