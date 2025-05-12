dofile_once( "mods/mnee/lib.lua" )
dofile_once( "mods/penman/_libman.lua" )

index = index or {}
index.G = index.G or {} --persistent table
index.D = index.D or {} --data table
index.M = index.M or {} --al cases of this have to be made through pen.animate

-- index.get_status_data
-- index.get_inv_info (merge kind and kind_func?)
-- index.get_items
-- index.set_to_slot
-- index.cat_callback
-- index.inventory_man

-- _structure.lua
-- _elements.lua

--completetly redo the image handling to rely on penman
--make sure the minimum z_layers offsets are 0.01
--transition to globals

--make index.new_vanilla_hp prettier
--min hp bar length must be of a typical bar size (reduce the internal size instead)
--use this for spell type color https://davidmathlogic.com/colorblind/#%23000000-%23E69F00-%2356B4E9-%23009E73-%23F0E442-%230072B2-%23D55E00-%23CC79A7

------------------------------------------------------		[BACKEND]		------------------------------------------------------

---A wrapper for M-Nee bind.
---@param mnee_id string
---@param is_continuous boolean
---@param is_clean boolean
---@return boolean
function index.get_input( mnee_id, is_continuous, is_clean )
	return mnee.mnin( "bind", { "index_core", mnee_id }, { pressed = not( is_continuous ), dirty = not( is_clean )})
end

--A wrapper for Penman sound player.
---@param sfx table
---@param x? number
---@param y? number
function index.play_sound( sfx, x, y ) end
--A wrapper for Penman sound player.
---@param sfx string
---@param x? number
---@param y? number
function index.play_sound( sfx, x, y )
	if( x == nil ) then x, y = unpack( index.D.player_xy ) end
	pen.play_sound( type( sfx ) == "table" and sfx or index.D.sfxes[ sfx ], x, y )
end

---Resets the game to vanilla state if the mod was disabled (only works with local install).
function index.self_destruct()
	pen.gui_builder( false )

	local controller_id = ( EntityGetWithTag( "index_ctrl" ) or {})[1]
	if( pen.vld( controller_id, true )) then
		local hooman = EntityGetRootEntity( controller_id )
		EntitySetComponentIsEnabled( hooman, EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" ), true )
		EntitySetComponentIsEnabled( hooman, EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" ), true )
		EntityKill( controller_id )
	end

	EntityRemoveComponent( GetUpdatedEntityID(), GetUpdatedComponentID())
end

---Makes sure all the internal parameters used by vanilla wand system are reset to their default states.
function index.clean_my_gun()
	ACTION_MANA_DRAIN_DEFAULT, ACTION_DRAW_RELOAD_TIME_INCREASE = 10, 0
	ACTION_UNIDENTIFIED_SPRITE_DEFAULT = "data/ui_gfx/gun_actions/unidentified.png"

	mana, state_cards_drawn = 0, 0
	c, shot_effects, gun = {}, {}, {}
	deck, hand, discarded = {}, {}, {}
	reflecting, current_action, state_from_game = false, nil, nil
	current_reload_time, current_projectile, active_extra_modifiers = 0, nil, {}
	reloading, first_shot, start_reload, got_projectiles = false, true, false, false
	state_shuffled, state_discarded_action, state_destroyed_action, playing_permanent_card = false, false, false, false

	use_game_log = false
	ConfigGun_Init( gun )
	current_reload_time = 0
	shot_structure, recursion_limit = {}, 2
	force_stop_draws, dont_draw_actions, root_shot = false, false, nil
end

---Returns a table of all detected status effects, stains, ingestions and perks.
---@param hooman entity_id
---@return table effects, table perks
function index.get_status_data( hooman ) --document the nuances of the returned tables
	local perk_tbl, effect_tbl = {}, { ings = {}, stains = {}, misc = {}}

	dofile_once( "data/scripts/status_effects/status_list.lua" )
    if( status_effects[1].real_id == nil ) then
        local id_memo, id_num = {}, 1
        for i,e in ipairs( status_effects ) do
            if( id_memo[ e.id ] == nil ) then id_memo[ e.id ], id_num = true, id_num + 1 end
            status_effects[i].real_id = id_num
        end
    end
    
    local simple_effects = {}
    pen.child_play( hooman, function( parent, child, i ) --allow devs to specify whether disabled GameEffect should count for being displayed
        local effect_comp = EntityGetFirstComponentIncludingDisabled( child, "GameEffectComponent" )
        if( not( pen.vld( effect_comp, true ))) then return end
		local is_stain = ComponentGetValue2( effect_comp, "caused_by_stains" )
		local is_ing = ComponentGetValue2( effect_comp, "caused_by_ingestion_status_effect" )
		if( is_ing or is_stain ) then return end

		local effect = ComponentGetValue2( effect_comp, "effect" )
		effect = effect == "CUSTOM" and ComponentGetValue2( effect_comp, "custom_effect_id" ) or effect
		local effect_id = ComponentGetValue2( effect_comp, "causing_status_effect" ) + 1
		table.insert( simple_effects, { child, effect_comp, effect_id, effect })
    end)

	local ing_perc = 0
	local ing_comp = EntityGetFirstComponentIncludingDisabled( hooman, "IngestionComponent" )
	if( ing_comp ~= nil ) then
		local raw_count = ComponentGetValue2( ing_comp, "ingestion_size" )
		local total_cap = ComponentGetValue2( ing_comp, "ingestion_capacity" )
		if( raw_count > 0 ) then ing_perc = math.floor( 100*raw_count/total_cap + 0.5 ) end
	end
	
	local status_comp = EntityGetFirstComponentIncludingDisabled( hooman, "StatusEffectDataComponent" )

	local ing_frame = ComponentGetValue2( status_comp, "ingestion_effects" )
	local ing_matter = ComponentGetValue2( status_comp, "ingestion_effect_causes" )
	local ing_many = ComponentGetValue2( status_comp, "ingestion_effect_causes_many" )
	pen.t.loop( ing_frame, function( effect_id, duration )
		if( duration == 0 ) then return end
		
		local raw_info = pen.t.get( status_effects, { effect_id }, "real_id" )
		local effect_info = index.get_thresholded_effect( raw_info or {}, duration )
		local time = index.get_effect_duration( duration, effect_info )
		if( effect_info.id == nil or time == 0 ) then return end
		
		local is_many = ing_many[ effect_id ] == 1
		local mtr = GameTextGetTranslatedOrNot( CellFactory_GetUIName( ing_matter[ effect_id ]))
		local message = GameTextGet( "$ingestion_status_caused_by"..( is_many and "_many" or "" ), mtr == "" and "???" or mtr )
		if( ing_perc >= 100 ) then
			local hardcoded_cancer_fucking_ass_list = {
				INGESTION_MOVEMENT_SLOWER = 1,
				INGESTION_EXPLODING = 1,
				INGESTION_DAMAGE = 1,
			}
			if( hardcoded_cancer_fucking_ass_list[ effect_info.id ]) then
				if( GameGetGameEffectCount( hooman, "IRON_STOMACH" ) == 0 ) then
					message, time = GameTextGetTranslatedOrNot( "$ingestion_status_caused_by_overingestion" ), -1
				else time = 0 end
			end
		end
		
		if( time == 0 ) then return end
		table.insert( effect_tbl.ings, {
			pic = effect_info.ui_icon,
			txt = index.get_effect_timer( time ),
			desc = GameTextGetTranslatedOrNot( effect_info.ui_name ),
			tip = GameTextGetTranslatedOrNot( effect_info.ui_description ).."@"..message,

			amount = time*60,
			is_danger = effect_info.is_harmful,
		})
	end)
	table.sort( effect_tbl.ings, function( a, b ) return a.amount > b.amount end)
	if( ing_perc > 0 ) then
		local stomach_step = 6
		pen.t.loop({ 25, 90, 100, 140, 150, 175 }, function( i, stomach_step )
			if( ing_perc < stomach_step ) then stomach_step = i-1; return true end
		end)
		
		local delay = ComponentGetValue2( ing_comp, "m_ingestion_cooldown_frames" )
		local total_delay = ComponentGetValue2( ing_comp, "ingestion_cooldown_delay_frames" )
		table.insert( effect_tbl.ings, 1, {
			txt = ing_perc.."%",
			desc = GameTextGetTranslatedOrNot( "$status_satiated0"..stomach_step ),
			pic = "data/ui_gfx/status_indicators/satiation_0"..stomach_step..".png",
			tip = GameTextGetTranslatedOrNot( "$statusdesc_satiated0"..stomach_step ),

			is_stomach = true,
			digestion_delay = math.min( math.floor( 10*delay/total_delay + 0.5 )/10, 1 ),

			amount = math.min( ing_perc/100, 1 ),
			is_danger = ing_perc > 100 and not( GameHasFlagRun( "PERK_PICKED_IRON_STOMACH" )),
		})
	end

	local stain_percs = ComponentGetValue2( status_comp, "mStainEffectsSmoothedForUI" )
	pen.t.loop( stain_percs, function( effect_id, duration )
		local perc = index.get_stain_perc( duration )
		if( perc == 0 ) then return end
		local effect_info = index.get_thresholded_effect( pen.t.get( status_effects, { effect_id }, "real_id" ) or {}, duration )
		if( not( pen.vld( effect_info.id ))) then return end

		table.insert( effect_tbl.stains, {
			id = effect_id,
			
			pic = effect_info.ui_icon,
			txt = math.min( perc, 100 ).."%",
			desc = GameTextGetTranslatedOrNot( effect_info.ui_name ),
			tip = GameTextGetTranslatedOrNot( effect_info.ui_description ),

			amount = math.min( perc/100, 1 ),
			is_danger = effect_info.is_harmful,
		})
	end)
	table.sort( effect_tbl.stains, function( a, b ) return a.id > b.id end)

	local dmg_comp = EntityGetFirstComponentIncludingDisabled( hooman, "DamageModelComponent" )
	if( pen.vld( dmg_comp, true ) and ComponentGetIsEnabled( dmg_comp ) and ComponentGetValue2( dmg_comp, "mIsOnFire" )) then
		local fire_info = pen.t.get( status_effects, "ON_FIRE" )
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

	local frame_num = GameGetFrameNum()
    pen.child_play_full( hooman, function( child )
        local info_comp = EntityGetFirstComponentIncludingDisabled( child, "UIIconComponent" )
        if( not( pen.vld( info_comp, true ))) then return end
		if( not( ComponentGetValue2( info_comp, "display_in_hud" ))) then return end
		local icon_info = {
			pic = ComponentGetValue2( info_comp, "icon_sprite_file" ),
			txt = "",
			desc = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "name" )),
			tip = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "description" )),
			count = 1,
		}

		local is_perk = ComponentGetValue2( info_comp, "is_perk" )
		if( is_perk ) then
			-- dofile_once( "data/scripts/perks/perk_list.lua" )
			local _,true_id = pen.t.get( perk_tbl, icon_info.pic, "pic" )
			if( true_id == nil ) then
				if( EntityGetName( child ) == "fungal_shift_ui_icon" ) then
					icon_info.tip = GlobalsGetValue( "fungal_memo", "" ).."@"..icon_info.tip
					icon_info.count = tonumber( GlobalsGetValue( "fungal_shift_iteration", "0" ))
					icon_info.is_fungal = true
					
					local raw_timer = tonumber( GlobalsGetValue( "fungal_shift_last_frame", "0" ))
					local fungal_timer = math.max( 60*60*5 + raw_timer - frame_num, 0 )
					if( fungal_timer > 0 ) then
						icon_info.amount = fungal_timer
						icon_info.txt = index.get_effect_timer( icon_info.amount/60 )
						icon_info.tip = icon_info.tip.."@"..icon_info.txt.." until next Shift window."
					end
					
					table.insert( perk_tbl, 1, icon_info )
				else table.insert( perk_tbl, icon_info ) end
			else perk_tbl[ true_id ].count = perk_tbl[ true_id ].count + 1 end
		else
			icon_info.amount = -2
			local _,true_id = pen.t.get( effect_tbl.misc, icon_info.pic, "pic" )

			pen.hallway( function()
				if( pen.vld( true_id )) then return end
				if( not( pen.vld( simple_effects ))) then return end
				if( EntityGetParent( child ) ~= hooman ) then return end

				local effect = pen.t.get( simple_effects, child )
				if( not( pen.vld( effect ))) then return end

				icon_info.amount = ComponentGetValue2( effect[2], "frames" )
				local effect_info = index.get_thresholded_effect( pen.t.get( status_effects, { effect[3]}, "real_id" ) or {}, icon_info.amount )
				if( not( pen.vld( effect_info.id ))) then return end

				icon_info.main_info = effect_info
				-- icon_info.pic = effect_info.ui_icon
				icon_info.desc = GameTextGetTranslatedOrNot( effect_info.ui_name )
				icon_info.tip = GameTextGetTranslatedOrNot( effect_info.ui_description )
				icon_info.is_danger = effect_info.is_harmful
			end)
			
			if( icon_info.amount == -2 ) then
				local time_comp = EntityGetFirstComponentIncludingDisabled( child, "LifetimeComponent" )
				if( pen.vld( time_comp, true )) then
					icon_info.amount = math.max( ComponentGetValue2( time_comp, "kill_frame" ) - frame_num, -1 )
				end
			end
			if( icon_info.amount ~= -2 ) then
				icon_info.amount = index.get_effect_duration( icon_info.amount, icon_info.main_info )
			end

			if( pen.vld( true_id )) then
				local time = icon_info.amount/60
				if( time > 0 ) then table.insert( effect_tbl.misc[true_id].time_tbl, time ) end
				effect_tbl.misc[true_id].count = effect_tbl.misc[true_id].count + 1
				if( effect_tbl.misc[true_id].amount < icon_info.amount ) then
					effect_tbl.misc[true_id].amount = icon_info.amount
				end
			else
				icon_info.time_tbl = {}
				if( icon_info.amount ~= 0 ) then
					local time = icon_info.amount/60
					if( time > 0 ) then table.insert( icon_info.time_tbl, time ) end
				end
				table.insert( effect_tbl.misc, icon_info )
			end
		end
    end)
    table.sort( perk_tbl, function( a, b )
        return a.count > b.count
    end)
    
	pen.t.loop( effect_tbl.misc, function( i, e )
		table.sort( e.time_tbl, function( a, b ) return a > b end)
        effect_tbl.misc[1].txt = index.get_effect_timer( e.time_tbl[1])
        if( #e.time_tbl <= 1 ) then return end
		local tip = GameTextGetTranslatedOrNot( "$menu_replayedit_writinggif_timeremaining" )
		effect_tbl.misc[1].tip = effect_tbl.misc[1].tip.."@"..string.gsub( tip, "%$0 ", index.get_effect_timer( e.time_tbl[#e.time_tbl], true ))
	end)
    table.sort( effect_tbl.misc, function( a, b )
        return a.amount > b.amount
    end)

	return effect_tbl, perk_tbl
end

function index.get_action_data( spell_id )
	dofile_once( "data/scripts/gun/gun.lua" )
	dofile_once( "data/scripts/gun/gun_enums.lua" )
	dofile_once( "data/scripts/gun/gun_actions.lua" )
	return pen.cache({ "index_spell_data", spell_id }, function()
		index.clean_my_gun()

		local spell_data = pen.t.clone( pen.t.get( actions, spell_id, nil, nil, {}))
		if( spell_data.action == nil ) then return spell_data end
		
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

		ACTION_DRAW_RELOAD_TIME_INCREASE = 1e9
		current_reload_time, shot_effects = 0, {}
		dont_draw_actions, reflecting = true, true

		SetRandomSeed( 0, 0 )
		ConfigGunShotEffects_Init( shot_effects )
		local metadata = create_shot()
		c, metadata.state_proj = metadata.state, {damage={},explosion={},crit={},lightning={}}
		set_current_action( spell_data )
		c.draw_many = 0
		c.projs = {}
		
		pcall( spell_data.action )
		if( spell_data.tip_data ~= nil ) then spell_data.tip_data() end
		if( math.abs( current_reload_time ) > 1e6 ) then
			spell_data.is_chainsaw = true
			current_reload_time = current_reload_time + ACTION_DRAW_RELOAD_TIME_INCREASE
		end
		metadata.state.reload_time, metadata.shot_effects = current_reload_time, pen.t.clone( shot_effects )
		
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
			local xml = pen.lib.nxml.parse( pen.magic_read( c.projs[1][2]))
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

					speed = math.floor((
						tonumber( xml_kid.attr.speed_min or xml_kid.attr.speed_max or 0 )
						+ tonumber( xml_kid.attr.speed_max or xml_kid.attr.speed_min or 0 )
					)/2 + 0.5 ),

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
					metadata.state_proj.damage["projectile"] = metadata.state_proj.damage.projectile
						+ tonumber( dmg_kid.attr.projectile or 0 )
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
		index.clean_my_gun()

		spell_data.meta = pen.t.clone( metadata )
		return spell_data
	end, { reset_count = 0 })
end

function index.chugger_3000( mouth_id, cup_id, total_vol, mtr_list, perc )
	if( not( pen.vld( mtr_list ))) then return end

	local gonna_pour = type( mouth_id ) == "table"
	if( gonna_pour ) then
		perc = 9/total_vol
	else perc = perc or 0.1 end
	
	local to_drink = total_vol*perc
	local min_vol = math.ceil( to_drink*perc )
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
			else EntityIngestMaterial( mouth_id, mtr[1], count ) end
			AddMaterialInventoryMaterial( cup_id, name, math.floor( mtr[2] - count + 0.5 ))

			to_drink = to_drink - count
			if( to_drink <= 0 ) then break end
		end
	end
end

--Inventory pipeline
function index.cat_callback( this_info, name, input, fallback, do_default )
	local func_local = this_info[ name ]
	if( input ~= nil ) then
		local out = fallback or {}
		local is_real = pen.vld( func_local )
		if( is_real ) then out = { func_local( unpack( input ))} end
		if( is_real or do_default ) then
			local func_main = index.D.item_cats[ this_info.cat ][ name ]
			if( func_main ~= nil ) then out = { func_main( unpack( input ))} end
		end
		return unpack( out )
	else return func_local or index.D.item_cats[ this_info.cat ][ name ] end
end

function index.get_valid_invs( inv_type, is_quickest )
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

function index.get_inv_info( inv_id, slot_count, kind, kind_func, check_func, update_func, gui_func, sort_func )
	local kind_data = pen.magic_storage( inv_id, "index_kind", "value_string" )
	if( kind_data ~= nil ) then kind = pen.t.pack( kind_data ) end
	local kind_path = pen.magic_storage( inv_id, "index_kind_func", "value_string" )
	if( kind_path ~= nil ) then kind_func = dofile( kind_path ) end
	local size_data = pen.magic_storage( inv_id, "index_size", "value_string" )
	if( size_data ~= nil ) then slot_count = pen.t.pack( size_data, true ) end
	local gui_path = pen.magic_storage( inv_id, "index_gui", "value_string" )
	if( gui_path ~= nil ) then gui_func = dofile_once( gui_path ) end
	local check_path = pen.magic_storage( inv_id, "index_check", "value_string" )
	if( check_path ~= nil ) then check_func = dofile_once( check_path ) end
	local update_path = pen.magic_storage( inv_id, "index_update", "value_string" )
	if( update_path ~= nil ) then update_func = dofile_once( update_path ) end
	local sort_path = pen.magic_storage( inv_id, "index_sort", "value_string" )
	if( sort_path ~= nil ) then sort_func = dofile_once( sort_path ) end
	
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

function index.is_inv_empty( slot_state )
	for i,col in pairs( slot_state ) do
		for e,slot in ipairs( col ) do
			if( slot ) then return false end
		end
	end
	return true
end

function index.inv_check( this_info, inv_info )
	if(( this_info.id or 0 ) < 0 ) then return true end
	if( this_info.id == inv_info.inv_id ) then return false end

	local kind_memo = inv_info.kind
	local inv_data = inv_info.full or index.D.invs[ inv_info.inv_id ]
	inv_info.kind = inv_data.kind_func ~= nil and inv_data.kind_func( inv_info ) or inv_data.kind
	
	local val = (( pen.t.get( inv_info.kind, "universal" ) ~= 0 ) or #pen.t.get( index.get_valid_invs( this_info.inv_type, this_info.is_quickest ), inv_info.kind ) > 0 ) and ( inv_data.check == nil or inv_data.check( this_info, inv_info ))
	if( val ) then
		val = index.cat_callback( this_info, "on_inv_check", { this_info, inv_info }, { val })
	end
	
	inv_info.kind = kind_memo
	return val
end

function index.slot_swap_check( item_in, item_out, slot_data )
	local inv_memo = item_out.inv_id
	index.G.slot_memo = item_out.inv_slot
	item_out.inv_id, item_out.inv_slot = item_out.inv_id or slot_data.inv_id, item_out.inv_slot or slot_data.inv_slot
	local val = index.inv_check( item_in, item_out ) and index.inv_check( item_out, item_in )
	item_out.inv_id, item_out.inv_slot = inv_memo, index.G.slot_memo
	return val
end

function index.inventory_boy( item_id, this_info, in_hand )
	local in_wand = ( this_info.in_wand or 0 ) > 0
	if( in_wand or in_hand == nil ) then
		local wand_id = in_wand and this_info.in_wand or item_id
		in_hand = pen.get_item_owner( wand_id ) > 0
	end
	
	local hooman = EntityGetRootEntity( item_id )
	local is_free = hooman == item_id
	pen.t.loop( EntityGetAllComponents( item_id ), function( i, comp )
		local world_check, inv_check, hand_check = false, false, false
		if( not( ComponentHasTag( comp, "not_enabled_in_wand" ) and in_wand )) then
			world_check = ComponentHasTag( comp, "enabled_in_world" ) and is_free
			inv_check = ComponentHasTag( comp, "enabled_in_inventory" ) and not( is_free )
			hand_check = ComponentHasTag( comp, "enabled_in_hand" ) and in_hand
		end
		EntitySetComponentIsEnabled( item_id, comp, world_check or inv_check or hand_check )
	end)

	if( is_free ) then return end
	if( not( in_hand ) or pen.get_active_item( pen.get_item_owner( item_id )) ~= item_id ) then
		if( in_hand ) then hooman = EntityGetParent( item_id ) end
		local x, y = EntityGetTransform( hooman )
		EntitySetTransform( item_id, x, y )
		EntityApplyTransform( item_id, x, y )
	end
end

function index.inventory_man( item_id, this_info, in_hand, force_full )
	pen.child_play_full( item_id, function( child, params )
		index.inventory_boy( child, unpack( params ))
		if( not( force_full ) and index.D.invs[ child ] ~= nil ) then
			return true
		end
	end, { this_info, in_hand })
end

function index.set_to_slot( this_info, is_player )
	if( is_player == nil ) then
		local parent_id = EntityGetParent( this_info.id )
		is_player = index.D.invs_p.q == parent_id or index.D.invs_p.f == parent_id
	end
	
	local slot_num = { ComponentGetValue2( this_info.ItemC, "inventory_slot" )}
	local is_hidden = slot_num[1] == -1 and slot_num[2] == -1
	if( not( is_hidden )) then
		local valid_invs = index.get_valid_invs( this_info.inv_type, this_info.is_quickest )
		if( slot_num[2] == -5 ) then
			if( not( this_info.is_hidden )) then
				local inv_list = is_player and index.D.invs_p or { this_info.inv_id }
				pen.t.loop( inv_list, function( _,inv_id )
					local inv_dt = index.D.invs[ inv_id ]
					local is_universal = pen.t.get( inv_dt.kind, "universal" ) ~= 0
					local is_valid = #pen.t.get( valid_invs, inv_dt.kind ) > 0
					if( not( is_universal or is_valid )) then return end
					
					for i,slot in pairs( index.D.slot_state[ inv_id ]) do
						pen.t.loop( slot, function( k, s )
							if( s ) then return end
							local is_fancy = type( i ) == "string"
							if( is_fancy and pen.t.get( valid_invs, i ) == 0 ) then return end
							local temp_slot = is_fancy and { k, i == "quickest" and -1 or -2 } or { i, k }
							if( index.inv_check( this_info, { inv_id = inv_id, inv_slot = temp_slot, full = inv_dt })) then
								if( temp_slot[2] < 0 ) then temp_slot[2] = temp_slot[2] + 1 end
								
								local parent_check = EntityGetParent( this_info.id )
								if( parent_check > 0 and inv_id ~= parent_check) then
									EntityRemoveFromParent( this_info.id )
									EntityAddChild( inv_id, this_info.id )
								end

								slot_num = temp_slot
								index.D.slot_state[ inv_id ][i][k] = this_info.id
								return true
							end
						end)
						if( slot_num[2] ~= -5 ) then break end
					end

					if( slot_num[2] ~= -5 ) then return true end
				end)
				if( slot_num[2] == -5 ) then return this_info end
			else slot_num = { -1, -1 } end
			slot_num[1], slot_num[2] = slot_num[1] - 1, slot_num[2] - 1
			ComponentSetValue2( this_info.ItemC, "inventory_slot", slot_num[1], slot_num[2])
		elseif( slot_num[2] == -1 ) then
			index.D.slot_state[ this_info.inv_id ].quickest[ slot_num[1] + 1 ] = this_info.id
			this_info.inv_kind = "quickest"
		elseif( slot_num[2] == -2 ) then
			index.D.slot_state[ this_info.inv_id ].quick[ slot_num[1] + 1 ] = this_info.id
			this_info.inv_kind = "quick"
		elseif( slot_num[2] >= 0 ) then
			index.D.slot_state[ this_info.inv_id ][ slot_num[1] + 1 ][ slot_num[2] + 1 ] = this_info.id
			this_info.inv_kind = this_info.inv_kind[1]
		end

		slot_num[1], slot_num[2] = slot_num[1] + 1, slot_num[2] < 0 and slot_num[2] or slot_num[2] + 1
	end

	this_info.inv_slot = slot_num
	return this_info
end

function index.slot_swap( item_in, slot_data )
	local reset = { 0, 0 }

	local parent1 = EntityGetParent( item_in )
	local parent2 = slot_data.inv_id
	local tbl = { parent1, parent2 }
	local idata = {
		pen.t.get( index.D.item_list, item_in, nil, nil, {}),
		pen.t.get( index.D.item_list, slot_data.id, nil, nil, {}),
	}
	for i = 1,2 do
		local p = tbl[i]
		if( p > 0 ) then
			local p_info = index.D.invs[p] or {}
			if( p_info.update ~= nil ) then
				if( p_info.update( pen.t.get( index.D.item_list, p, nil, nil, p_info ), idata[(i+1)%2+1], idata[i%2+1])) then
					table.insert( reset, pen.get_item_owner( p, true ))
				end
			end
		end
	end
	if( parent1 ~= parent2 ) then
		reset[1] = pen.get_item_owner( item_in )
		EntityRemoveFromParent( item_in )
		EntityAddChild( parent2, item_in )
		if( slot_data.id > 0 ) then
			reset[2] = pen.get_item_owner( slot_data.id )
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
			index.cat_callback( this_info, "on_inv_swap", { this_info, slot_data })
		end
	end
	for i,deadman in pairs( reset ) do
		if( deadman > 0 ) then
			pen.reset_active_item( deadman )
		end
	end
end

function index.check_item_name( name )
	return pen.vld( name ) and ( string.find( name, "%$" ) ~= nil or string.find( name, "%w_%w" ) == nil )
end

function index.get_entity_name( entity_id, item_comp, abil_comp )
	local name = item_comp == nil and "" or ComponentGetValue2( item_comp, "item_name" )

	local info_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "UIInfoComponent" )
	if( info_comp ~= nil ) then
		local temp = ComponentGetValue2( info_comp, "name" )
		name = index.check_item_name( temp ) and temp or name
	elseif( abil_comp ~= nil ) then
		local temp = ComponentGetValue2( abil_comp, "ui_name" )
		name = index.check_item_name( temp ) and temp or name
	end
	if( not( index.check_item_name( name ))) then
		local temp = EntityGetName( entity_id )
		name = index.check_item_name( temp ) and temp or name
	end

	return index.check_item_name( name ) and string.gsub( GameTextGetTranslatedOrNot( name ), "(%s*)%$0(%s*)", "" ) or "", name
end

function index.get_potion_info( entity_id, name, max_count, total_count, matters )
	local info = ""
	
	local cnt = 1
	for i,mtr in ipairs( matters ) do --pen.t.loop_concat
		if( i == 1 or mtr[2] > 5 ) then
			info = info..( i == 1 and "" or "+" )..pen.capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( mtr[1])))
			cnt = cnt + 1
			if( cnt > 3 ) then break end
		end
	end
	
	local v = nil
	if( max_count > 0 ) then
		v = GameTextGet( "$item_potion_fullness", tostring( math.floor( 100*total_count/max_count + 0.5 )))
	end

	if( string.sub( name, 1, 1 ) == "$" ) then
		name = pen.capitalizer( GameTextGet( name, ( info == "" and GameTextGetTranslatedOrNot( "$item_potion_empty" ) or info )))
	else name = string.gsub( GameTextGetTranslatedOrNot( name ), " %(%)", "" ) end
	return info..( info == "" and info or " " )..name, v
end

function index.get_item_data( item_id, inventory_data, item_list )
	local this_info = { id = item_id }
	if( inventory_data ~= nil ) then
		this_info.inv_id = inventory_data.id
		this_info.inv_kind = inventory_data.kind
	end
	
	local item_comp = EntityGetFirstComponentIncludingDisabled( item_id, "ItemComponent" )
	if( item_comp == nil ) then return {} end
	
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
			pen.t.loop( EntityGetComponentIncludingDisabled( item_id, "LuaComponent" ), function( i, comp )
				local path = ComponentGetValue2( comp, "script_kick" ) or ""
				if( path ~= "" ) then
					this_info.is_kicking = true
					return true
				end
			end)
		end
		this_info.uses_rmb = EntityHasTag( item_id, "index_has_rbm" ) or this_info.is_throwing
	end
	if( item_comp ~= nil ) then
		this_info.ItemC = item_comp

		local invs = { QUICK = -1, TRUE_QUICK = -0.5, ANY = 0, FULL = 0.5 }
		local inv_name = pen.magic_storage( item_id, "preferred_inventory", "value_string" )
			or ComponentGetValue2( item_comp, "preferred_inventory" )
		this_info.inv_type = invs[inv_name] or 0
		
		local ui_pic = ComponentGetValue2( item_comp, "ui_sprite" )
		if( pen.vld( ui_pic )) then this_info.pic = ui_pic end
		
		this_info.desc = index.full_stopper( GameTextGetTranslatedOrNot( ComponentGetValue2( item_comp, "ui_description" )))
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

		this_info.charges = pen.magic_storage( item_id, "current_charges", "value_int" )
			or ComponentGetValue2( item_comp, "uses_remaining" )

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
		index.M.cbk_tbl = index.M.cbk_tbl or {} --cache this
		index.M.cbk_tbl[ item_id ] = index.M.cbk_tbl[ item_id ] or {}
		for k,callback in ipairs( callback_list ) do
			if( index.M.cbk_tbl[ item_id ][ callback ] == nil ) then
				local func_path = pen.magic_storage( item_id, callback, "value_string" )
				if( func_path ~= nil ) then index.M.cbk_tbl[ item_id ][ callback ] = dofile_once( func_path ) end
			end
			this_info[ callback ] = index.M.cbk_tbl[ item_id ][ callback ]
		end
	end
	
	for k,cat in ipairs( index.D.item_cats ) do
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
	this_info.name, this_info.raw_name = index.get_entity_name( item_id, item_comp, abil_comp )
	if( this_info.cat == nil ) then
		return {}
	elseif(( this_info.name or "" ) == "" ) then
		this_info.name = index.D.item_cats[ this_info.cat ].name
	end
	this_info.name = pen.capitalizer( this_info.name )
	
	dofile_once( "data/scripts/gun/gun.lua" )
	dofile_once( "data/scripts/gun/gun_enums.lua" )
	dofile_once( "data/scripts/gun/gun_actions.lua" )
	this_info = index.cat_callback( this_info, "on_data", {
		item_id, this_info, item_list or {}
	}, { this_info })
	
	local wand_id = ( this_info.in_wand or false ) and this_info.in_wand or item_id
	this_info.in_hand = pen.get_item_owner( wand_id )
	return this_info
end

function index.get_items( hooman )
	local item_tbl = {}
	for k = 1,2 do
		local tbl = { "invs", "invs_i" }
		for i,inv_info in pairs( index.D[ tbl[k]]) do
			if( k == 2 ) then index.D.invs[i] = inv_info end
			pen.child_play( inv_info.id, function( parent, child, j )
				local new_info = index.get_item_data( child, inv_info, item_tbl )
				if( new_info.id ~= nil ) then
					if( not( EntityHasTag( new_info.id, "index_processed" ))) then
						index.cat_callback( new_info, "on_processed", { new_info.id, new_info })
						ComponentSetValue2( new_info.ItemC, "inventory_slot", -5, -5 )
						EntityAddTag( new_info.id, "index_processed" )
					end
					index.cat_callback( new_info, "on_processed_forced", { new_info.id, new_info })
					index.register_item_pic( new_info, new_info.advanced_pic )
					table.insert( item_tbl, new_info )
				end
			end, inv_info.sort )
		end
	end

	index.D.item_list = item_tbl
end

function index.vanilla_pick_up( hooman, item_id )
	local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
	if( pick_comp ~= nil ) then
		EntitySetComponentIsEnabled( hooman, pick_comp, true )
		GamePickUpInventoryItem( hooman, item_id, true )
		EntitySetComponentIsEnabled( hooman, pick_comp, true )
	end
end

function index.pick_up_item( hooman, this_info, do_the_sound, is_silent )
	local entity_id = this_info.id
	local gonna_pause, is_shopping = 0, this_info.cost ~= nil

	local callback = index.cat_callback( this_info, "on_pickup" )
	if( callback ~= nil ) then
		gonna_pause = callback( entity_id, this_info, false )
	end
	if( gonna_pause == 0 ) then
		if( not( is_silent or false )) then
			this_info.name = this_info.name or GameTextGetTranslatedOrNot( ComponentGetValue2( this_info.ItemC, "item_name" ))
			GamePrint( GameTextGet( "$log_pickedup", this_info.name ))
			if( do_the_sound or is_shopping ) then
				play_sound({ "data/audio/Desktop/event_cues.bank", is_shopping and "event_cues/shop_item/create" or "event_cues/pick_item_generic/create" })
			end
		end

		local _,slot = ComponentGetValue2( this_info.ItemC, "inventory_slot" )
		EntityAddChild( index.D.invs_p[ slot < 0 and "q" or "f" ], entity_id )

		if( is_shopping ) then
			if( not( index.D.Wallet.money_always )) then
				index.D.Wallet.money = index.D.Wallet.money - this_info.cost
				ComponentSetValue2( index.D.Wallet.comp, "money", index.D.Wallet.money )
			end
			
			pen.t.loop( EntityGetAllComponents( entity_id ), function( i, comp )
				if( ComponentHasTag( comp, "shop_cost" )) then EntityRemoveComponent( entity_id, comp ) end
			end)
		end

		this_info.xy = { EntityGetTransform( entity_id )}
		pen.lua_callback( entity_id, { "script_item_picked_up", "item_pickup" }, { entity_id, hooman, this_info.name })
		if( callback ~= nil ) then
			callback( entity_id, this_info, true )
		end
		if( EntityGetIsAlive( entity_id )) then
			ComponentSetValue2( this_info.ItemC, "has_been_picked_by_player", true )
			ComponentSetValue2( this_info.ItemC, "mFramePickedUp", index.D.frame_num )

			index.inventory_man( entity_id, this_info, false )
		end
	elseif( gonna_pause == 1 ) then
		--engage the pause
	end
end

function index.drop_item( h_x, h_y, this_info, throw_force, do_action )
	local this_item = this_info.id
	local has_no_cancer = not( this_info.is_kicking or false )
	if( not( has_no_cancer )) then
		local owner_id = pen.get_item_owner( this_item, true )
		local ctrl_comp = EntityGetFirstComponentIncludingDisabled( owner_id, "ControlsComponent" )
		if( ctrl_comp ~= nil ) then
			local inv_comp = pen.reset_active_item( owner_id )
			ComponentSetValue2( inv_comp, "mSavedActiveItemIndex", pen.get_item_num( this_info.inv_id, this_item ))
			ComponentSetValue2( ctrl_comp, "mButtonFrameThrow", index.D.frame_num + 1 )
		else has_no_cancer = true end
	end
	if( has_no_cancer ) then EntityRemoveFromParent( this_item ) end

	local p_d_x, p_d_y = index.D.pointer_world[1] - h_x, index.D.pointer_world[2] - h_y
	local p_delta = math.min( math.sqrt( p_d_x^2 + p_d_y^2 ), 50 )/10
	local angle = math.atan2( p_d_y, p_d_x )
	local from_x, from_y = 0, 0
	if(( this_info.in_hand or 0 ) > 0 ) then
		from_x, from_y = EntityGetTransform( this_item )
		pen.reset_active_item( this_info.in_hand )
	else
		index.D.throw_pos_rad = index.D.throw_pos_rad + index.D.throw_pos_size
		from_x, from_y = h_x + math.cos( angle )*index.D.throw_pos_rad, h_y + math.sin( angle )*index.D.throw_pos_rad
		local is_hit, hit_x, hit_y = RaytraceSurfaces( h_x, h_y, from_x, from_y )
		if( is_hit ) then index.D.throw_pos_rad = math.sqrt(( h_x - hit_x )^2 + ( h_y - hit_y )^2 ) end
		index.D.throw_pos_rad = index.D.throw_pos_rad - index.D.throw_pos_size
		from_x, from_y = h_x + math.cos( angle )*index.D.throw_pos_rad, h_y + math.sin( angle )*index.D.throw_pos_rad
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
	if( has_no_cancer ) then index.inventory_man( this_item, this_info, false ) end
	
	pen.t.loop( EntityGetComponentIncludingDisabled( this_item, "SpriteComponent", "enabled_in_world" ), function( i, comp )
		ComponentSetValue2( comp, "z_index", -1 + ( i - 1 )*0.0001 )
		EntityRefreshSprite( this_item, comp )
	end)
	
	ComponentSetValue2( this_info.ItemC, "inventory_slot", -5, -5 )
	ComponentSetValue2( this_info.ItemC, "play_hover_animation", false )
	ComponentSetValue2( this_info.ItemC, "has_been_picked_by_player", true )
	ComponentSetValue2( this_info.ItemC, "next_frame_pickable", index.D.frame_num + 30 )

	if( p_delta > 2 ) then
		local shape_comp = EntityGetFirstComponentIncludingDisabled( this_item, "PhysicsImageShapeComponent" )
		if( shape_comp ~= nil ) then
			local phys_mult = 1.75
			local throw_comp = EntityGetFirstComponentIncludingDisabled( this_item, "PhysicsThrowableComponent" )
			if( throw_comp ~= nil ) then phys_mult = phys_mult*ComponentGetValue2( throw_comp, "throw_force_coeff" ) end
			
			local mass = pen.get_mass( this_item )
			PhysicsApplyForce( this_item, phys_mult*force_x*mass, phys_mult*force_y*mass )
			PhysicsApplyTorque( this_item, phys_mult*5*mass )
		elseif( vel_comp ~= nil ) then
			ComponentSetValue2( vel_comp, "mVelocity", force_x, force_y )
		end
	end

	if( has_no_cancer and do_action ) then
		pen.lua_callback( this_item, { "script_throw_item", "throw_item" }, { from_x, from_y, to_x, to_y })
	end
end

--GUI backend
function index.slot_z( id, z )
	return index.D.dragger.item_id == id and z-2 or z
end

function index.full_stopper( text )
	if( not( pen.vld( text ))) then return "" end
	if( string.find( text, "%p$" ) == nil ) then text = text.."." end
	return text
end

function index.check_dragger_buffer( id ) --kinda sus
	index.M.dragger_buffer = index.M.dragger_buffer or {0,0}
	if( GameGetFrameNum() - index.M.dragger_buffer[2] > 2 ) then
		index.M.dragger_buffer = {0,0}
	end
	
	local will_do = true
	local will_force = false
	local will_update = true
	if( index.M.dragger_buffer[1] ~= 0 ) then
		will_do = index.M.dragger_buffer[1] == id
		will_update, will_force = will_do, will_do
	end
	return will_do, will_force, will_update
end

function index.hud_text_fix( key )
	local txt = tostring( GameTextGetTranslatedOrNot( key ))
	local _,pos = string.find( txt, ":", 1, true )
	if( pos ~= nil ) then txt = string.sub( txt, 1, pos-1 ) end
	return txt..":@"
end

function index.hud_num_fix( a, b, zeros )
	zeros = zeros or 0
	return table.concat({
		string.format( "%."..zeros.."f", a ),
		"/",
		string.format( "%."..zeros.."f", b ),
	})
end

function index.get_stain_perc( perc )
	local some_cancer = 14/99
	return math.max( math.floor( 100*( perc - some_cancer )/( 1 - some_cancer ) + 0.5 ), 0 )
end

function index.get_effect_timer( secs, no_units )
	if(( secs or -1 ) >= 0 ) then --maybe ignore 0?
		local is_tiny = secs < 1
		secs = string.format( "%."..pen.b2n( is_tiny ).."f", secs )
		if( not( no_units or false )) then
			secs = string.gsub( GameTextGet( "$inventory_seconds", secs ), " ", "" )
		end
		return is_tiny and string.sub( secs, 2 ) or secs
	else return "" end
end

function index.get_effect_duration( duration, effect_info, eps )
	duration = duration - 60*(( effect_info or {}).ui_timer_offset_normalized or 0 )
	if( math.abs( duration*60 ) <= ( eps or index.G.settings.min_effect_duration )) then duration = 0 end
	return duration < 0 and -1 or duration
end

function index.get_thresholded_effect( effects, v )
	if( #effects < 2 ) then return effects[1] or {} end
	table.sort( effects, function( a, b )
		return ( a.min_threshold_normalized or 0 ) < ( b.min_threshold_normalized or 0 )
	end)
	
	local final_id = #effects
	for i,effect in ipairs( effects ) do
		if( v < 60*( effect.min_threshold_normalized or 0 )) then
			final_id = math.max( i-1, 1 ); break
		end
	end
	return effects[ final_id ]
end

function index.swap_anim( item_id, end_x, end_y ) --pen.animate
	local anim_info, anim_id = pen.t.get( index.G.slot_anim, item_id )
	if( anim_info ~= 0 and anim_info.id ~= nil ) then
		local delta = index.D.frame_num - anim_info.frame
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
		else end_x, end_y = anim_info.x, anim_info.y end
		if( stop_it ) then table.remove( index.G.slot_anim, anim_id ) end
	end

	return end_x, end_y
end

function index.register_item_pic( this_info, is_advanced ) --leave xml getting to penman
	if( not( pen.vld( this_info.pic ))) then return end
	
	local forced_update = EntityHasTag( this_info.id, "index_update" )
	pen.cache({ "index_pic_data", this_info.pic }, function()
		local data = { xy = { 0, 0 }, xml_xy = { 0, 0 }}

		local is_xml = string.find( this_info.pic, "%.xml$" ) ~= nil and is_advanced
		if( forced_update ) then EntityRemoveTag( this_info.id, "index_update" ) end
		local anim_data = pen.magic_storage( this_info.id, "index_pic_anim", "value_string" ) --this should contain the anim anme and nothing else
		if( pen.vld( anim_data )) then data.anim = pen.t.pack( anim_data ) end
		
		if( is_xml ) then
			local xml = pen.lib.nxml.parse( pen.magic_read( this_info.pic ))
			local xml_kid = xml:first_of( "RectAnimation" )
			if( xml_kid.attr.has_offset ) then
				data.xml_xy = { -xml_kid.attr.offset_x, -xml_kid.attr.offset_y }
			else data.xml_xy = { -xml.attr.offset_x, -xml.attr.offset_y } end
			
			data.dims = { xml_kid.attr.frame_width, xml_kid.attr.frame_height }
			if( xml_kid.attr.shrink_by_one_pixel ) then
				data.dims[1], data.dims[2] = data.dims[1] + 1, data.dims[2] + 1
			end
		else data.dims = { pen.get_pic_dims( this_info.pic )} end

		local off_data = pen.magic_storage( this_info.id, "index_pic_offset", "value_string" )
		if( pen.vld( off_data )) then
			data.xy = pen.t.pack( off_data )
		elseif( not( is_xml )) then
			if( is_advanced ) then
				local pic_comp = EntityGetFirstComponentIncludingDisabled( this_info.id, "SpriteComponent", "item" )
					or EntityGetFirstComponentIncludingDisabled( this_info.id, "SpriteComponent", "enabled_in_hand" )
				if( pen.vld( pic_comp, true )) then
					data.xy = { ComponentGetValue2( pic_comp, "offset_x" ), ComponentGetValue2( pic_comp, "offset_y" )}
				end
			else data.xy = { data.dims[1]/2, data.dims[2]/2 } end
		end
	end, { reset_count = 0, reset_now = forced_update })
end

--GUI frontend
function index.new_dragger_shell( id, info, pic_x, pic_y, pic_w, pic_h )
	if( index.G.slot_state ) then return pic_x, pic_y end
	local will_do, will_force, will_update = index.check_dragger_buffer( id )
	if( not( will_do )) then return pic_x, pic_y end
	local is_within = pen.check_bounds( index.D.pointer_ui, { -pic_w, pic_w, -pic_h, pic_h }, { pic_x, pic_y })
	if( not( will_force or is_within or index.G.slot_memo[ id ])) then return pic_x, pic_y end
	local new_x, new_y, drag_state = 0, 0, 0
	if( dragger_buffer[1] == 0 ) then dragger_buffer = { id, index.D.frame_num } end
	if( index.D.dragger.item_id == 0 ) then index.D.dragger.item_id = id end

	local clicked, r_clicked, hovered = false, false, false
	if( index.D.dragger.item_id == id ) then
		new_x, new_y, drag_state, clicked, r_clicked, hovered = pen.new_dragger( id, pic_x, pic_y )
		if( index.G.slot_memo[ id ] and drag_state > 0 ) then
			index.D.dragger.swap_soon = true
			table.insert( index.G.slot_anim, {
				id = id,
				x = index.M.dragger_x,
				y = index.M.dragger_y,
				frame = index.D.frame_num,
			})
		end

		index.M.dragger_x, index.M.dragger_y = new_x, new_y
		index.D.dragger.inv_type = info.inv_type
		index.D.dragger.is_quickest = info.is_quickest
		pic_x, pic_y = new_x, new_y
		
		index.G.slot_memo[ id ] = hovered and has_begun
		if( index.G.slot_memo[ id ]) then dragger_buffer[2] = index.D.frame_num end
		index.G.slot_state = true
	end
	return pic_x, pic_y, clicked, r_clicked, hovered
end

function index.new_vanilla_box( pic_x, pic_y, pic_z, dims, alpha )
	pen.new_image( pic_x, pic_y, pic_z,
		"mods/index_core/files/pics/vanilla_box.xml", { s_x = dims[1], s_y = dims[2], alpha = alpha })

	local temp = 0
	local steps = { 10, 4, 2, 1 }
	pen.new_image( pic_x - 2, pic_y - 2, pic_z,
		"mods/index_core/files/pics/vanilla_box_a1.xml", { alpha = alpha })
	pen.new_image( pic_x + dims[1], pic_y - 2, pic_z,
		"mods/index_core/files/pics/vanilla_box_a2.xml", { alpha = alpha })
	pen.new_image( pic_x + dims[1], pic_y + dims[2], pic_z,
		"mods/index_core/files/pics/vanilla_box_a3.xml", { alpha = alpha })
	pen.new_image( pic_x - 2, pic_y + dims[2], pic_z,
		"mods/index_core/files/pics/vanilla_box_a4.xml", { alpha = alpha })

	while( temp < dims[1]) do
		local pic_id = 4
		local delta = dims[1] - temp
		for i,step in ipairs( steps ) do
			if( delta >= step ) then pic_id = i; break end
		end
		pen.new_image( pic_x + temp, pic_y - 2, pic_z,
			"mods/index_core/files/pics/vanilla_box_b"..pic_id..".xml", { alpha = alpha })
		pen.new_image( pic_x + temp, pic_y + dims[2], pic_z,
			"mods/index_core/files/pics/vanilla_box_c"..pic_id..".xml", { alpha = alpha })
		temp = temp + steps[ pic_id ]
	end
	temp = 0
	while( temp < dims[2]) do
		local pic_id = 4
		local delta = dims[2] - temp
		for i,step in ipairs( steps ) do
			if( delta >= step ) then pic_id = i; break end
		end
		pen.new_image( pic_x - 2, pic_y + temp, pic_z,
			"mods/index_core/files/pics/vanilla_box_d"..pic_id..".xml", { alpha = alpha })
		pen.new_image( pic_x + dims[1], pic_y + temp, pic_z,
			"mods/index_core/files/pics/vanilla_box_e"..pic_id..".xml", { alpha = alpha })
		temp = temp + steps[ pic_id ]
	end
end

function index.new_vanilla_bar( pic_x, pic_y, pic_z, dims, color, shake_frame, alpha )
	if( shake_frame ~= nil ) then
		if( shake_frame < 0 ) then
			pic_x = pic_x - 20*math.sin( shake_frame*math.pi/6.666 )/shake_frame
		else pic_x = pic_x + 2.5*math.sin( shake_frame*math.pi/5 ) end
		pen.new_pixel( pic_x - ( dims[1] + 1 ), pic_y, pic_z - 0.005, pen.PALETTE.VNL.WARNING, dims[1] + 2, dims[2] + 2 )
	end
	
	pen.new_pixel( pic_x - dims[1], pic_y + 1, pic_z - 0.01, color, dims[3], dims[2], alpha )

	pen.new_pixel( pic_x, pic_y, pic_z, pen.PALETTE.VNL.BROWN, 1, dims[2] + 2, 0.75 )
	pen.new_pixel( pic_x - dims[1], pic_y, pic_z, pen.PALETTE.VNL.BROWN, dims[1], 1, 0.75 )
	pen.new_pixel( pic_x - ( dims[1] + 1 ), pic_y, pic_z, pen.PALETTE.VNL.BROWN, 1, dims[2] + 2, 0.75 )
	pen.new_pixel( pic_x - dims[1], pic_y + dims[2] + 1, pic_z, pen.PALETTE.VNL.BROWN, dims[1], 1, 0.75 )

	pen.new_image( pic_x - dims[1], pic_y + 1, pic_z + 0.01,
		"mods/index_core/files/pics/vanilla_bar_bg.xml", { s_x = dims[1], s_y = dims[2]})
end

function index.new_vanilla_hp( pic_x, pic_y, pic_z, entity_id, data )
    local dmg_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "DamageModelComponent" )
    if( not( pen.vld( dmg_comp, true ))) then return 0,0,0,0,0 end
	
	data = data or {}
    data.dmg_data = data.dmg_data or {
        comp = dmg_comp,
		hp = ComponentGetValue2( dmg_comp, "hp" ),
        hp_max = ComponentGetValue2( dmg_comp, "max_hp" ),
        hp_last = ComponentGetValue2( dmg_comp, "mHpBeforeLastDamage" ),
        hp_frame = math.max( index.D.frame_num - ComponentGetValue2( dmg_comp, "mLastDamageFrame" ), 0 ),
    }

    local max_hp, hp = data.dmg_data.hp_max, data.dmg_data.hp
	local red_shift, length, height = 0, 0, data.height or 4
	pen.hallway( function()
		if( max_hp <= 0 ) then return end

		length = math.floor( 157.8 - 307.1/( 1 + ( math.min( math.max( max_hp, 0 ), 40 )/0.38 )^( 0.232 )) + 0.5 )
        length = ( data.length_mult or 1 )*( length < 5 and 40 or length )
        hp = math.min( math.max( hp, 0 ), max_hp )

		if( data.centered ) then pic_x = pic_x + length/2 end

        local low_hp = math.max( math.min( max_hp/4, data.low_hp or index.D.hp_threshold ), data.low_hp_min or index.D.hp_threshold_min )
        local pic = data.color_hp or pen.PALETTE.VNL.HP
        if( hp < low_hp ) then
            local perc = ( low_hp - hp )/low_hp
            local freq = ( data.hp_flashing or index.D.hp_flashing )*( 1.5 - perc )
            
            index.M.hp_flashing = index.M.hp_flashing or {}
            index.M.hp_flashing[ entity_id ] = index.M.hp_flashing[ entity_id ] or {}
            if( freq ~= index.M.hp_flashing[ entity_id ][1] or -1 ) then
                local freq_old = index.M.hp_flashing[ entity_id ][1] or 1
                index.M.hp_flashing[ entity_id ] = { freq, freq*( index.M.hp_flashing[ entity_id ][2] or 1 )/freq_old }
            end
            if( index.M.hp_flashing[ entity_id ][2] > 4*freq ) then
                index.M.hp_flashing[ entity_id ][2] = index.M.hp_flashing[ entity_id ][2] - 4*freq
            end
            red_shift = 0.5*( math.sin((( index.M.hp_flashing[ entity_id ][2] + freq )*math.pi )/( 2*freq )) + 1 )
            index.M.hp_flashing[ entity_id ][2] = index.M.hp_flashing[ entity_id ][2] + 1

            if( red_shift > 0.5 ) then
                pen.new_pixel( pic_x - ( length + 1 ), pic_y,
					pic_z - 0.005, data.color_bg or pen.PALETTE.VNL.HP_LOW, length + 2, height + 2 )
			else pic = data.color_dmg or pen.PALETTE.VNL.DAMAGE end
            red_shift = red_shift*perc
        end

		local delay = 30 --data.damage_fading
        if( data.dmg_data.hp_frame <= delay ) then
            local last_hp = math.min( math.max( data.dmg_data.hp_last, 0 ), max_hp )
            pen.new_pixel( pic_x - length, pic_y + 1,
				pic_z - 0.009, pen.PALETTE.VNL.DAMAGE, length*last_hp/max_hp, height, ( delay - data.dmg_data.hp_frame )/delay )
        end
        
		hp = math.min( math.floor( hp*25 + 0.5 ), 9e99 )
        max_hp = math.min( math.floor( max_hp*25 + 0.5 ), 9e99 )
        index.new_vanilla_bar( pic_x, pic_y, pic_z, { length, height, length*hp/max_hp }, pic )
	end)
    return length, height, max_hp, hp, red_shift
end

function index.new_pickup_info( screen_h, screen_w, pickup_info, xys )
	pickup_info.color = pickup_info.color or {}

	if(( pickup_info.desc or "" ) ~= "" ) then
		if( type( pickup_info.desc ) ~= "table" ) then
			pickup_info.desc = { pickup_info.desc, false }
		end
		if( pickup_info.desc[1] ~= "" ) then
			local is_elaborate = type( pickup_info.desc[2]) == "string" and pickup_info.desc[2] ~= ""
			local pic_x, pic_y = unpack( xys.pickup_info or { screen_w/2, screen_h - 44 })
			local clr = ( pickup_info.desc[2] == true ) and {208,70,70} or {255,255,178}
			pen.new_text( pic_x, pic_y, pen.LAYERS.WORLD_UI, pickup_info.desc[1], {
				is_centered_x = true, has_shadow = true, color = pickup_info.color[1] or clr })
			if( is_elaborate ) then
				pen.new_text( pic_x, pic_y + 12, pen.LAYERS.WORLD_UI, pickup_info.desc[2], {
					is_centered_x = true, has_shadow = true, color = pickup_info.color[2] or {207,207,207}})
			end
		end
	end
	if( pickup_info.id > 0 and not( index.D.is_opened ) and ( index.D.in_world_pickups or EntityHasTag( pickup_info.id, "index_txt" ))) then
		if(( pickup_info.txt or "" ) ~= "" ) then
			local x, y = EntityGetTransform( pickup_info.id )
			local pic_x, pic_y = pen.world2gui( x, y )
			pen.new_text( pic_x + 2, pic_y + 3, pen.LAYERS.WORLD_FRONT, pickup_info.txt, {
				is_centered_x = true, has_shadow = true, color = {207,207,207}})
		end
	end
end

function index.tipping( pic_x, pic_y, pic_z, s_x, s_y, text, data, func )
	data = data or {}
	local clicked, r_clicked = false, false
	pic_z = pen.get_hybrid_table( pic_z or { pen.LAYERS.TIPS, pen.LAYERS.MAIN_DEEP })
	clicked, r_clicked, data.is_active = pen.new_interface( pic_x, pic_y, s_x, s_y, pic_z[1], data )
	if( pic_z[2] ~= nil and data.is_active ) then pen.new_pixel( pic_x, pic_y, pic_z[2], pen.PALETTE.VNL.YELLOW, s_x, s_y, 0.75 ) end
	( func or index.D.tip_func )( text, data, func )
	return data.is_active, clicked, r_clicked
end

function index.new_vanilla_worldtip( tid, item_id, this_info, pic_x, pic_y, no_space, cant_buy, tip_func )
	-- if( not( cant_buy )) then return end
	pic_x, pic_y = unpack( index.D.xys.hp )
	pic_x, pic_y = pic_x - 43, pic_y - 1
	tip_func( tid, item_id, this_info, pic_x, pic_y, pen.LAYERS.TIPS, true )
end

function index.new_vanilla_wtt( tid, item_id, this_info, pic_x, pic_y, pic_z, in_world, is_advanced )
	if( this_info.wand_info == nil ) then return end
	
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
	
	local scale = 2--index.D.no_wand_scaling and 1 or 2
	local spell_list, got_spells = {permas={},normies={}}, false
	if( not( is_advanced )) then
		local spells = EntityGetAllChildren( item_id ) or {}
		if( #spells > 0 ) then
			for i,spell in ipairs( spells ) do
				local kid_info = pen.t.get( index.D.item_list, spell, nil, nil, {})
				if( kid_info.id == nil ) then kid_info = index.get_item_data( spell, index.D.this_info, index.D.item_list ) end
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
		{ pen.get_text_dims( this_info.name, true )},
		{ 71, 57, 0 },
		{ 0, 0 },
		{},
		{ 0, 0 },
		{},
	}
	this_info.tt_spacing[1][1] = this_info.tt_spacing[1][1] + ( this_info.wand_info.shuffle_deck_when_empty and 8 or 0 ) + 3
	if( is_advanced and pen.vld( this_info.desc )) then
		_,this_info.tt_spacing[3] = pen.liner( this_info.desc,
			math.floor( unpack( pen.get_tip_dims( this_info.desc ))*0.5 ), -1 )
		this_info.tt_spacing[3] = { this_info.tt_spacing[3][1] + 4, this_info.tt_spacing[3][2] - 1 }
		if( this_info.tt_spacing[2][2] < this_info.tt_spacing[3][2]) then
			this_info.tt_spacing[2][3] = ( this_info.tt_spacing[3][2] - this_info.tt_spacing[2][2])/2
			this_info.tt_spacing[2][2] = this_info.tt_spacing[3][2]
		end
	end
	this_info.tt_spacing[6][1] = math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1] + this_info.tt_spacing[3][1])
	this_info.tt_spacing[6][1] = math.ceil( this_info.tt_spacing[6][1]/9 )*9 + 3
	this_info.tt_spacing[2][1] = this_info.tt_spacing[6][1] - this_info.tt_spacing[3][1]

	local pic_data = pen.cache({ "index_pic_data", this_info.pic })
	if( pic_data and pic_data.dims ) then
		local dims = { scale*pic_data.dims[1], scale*pic_data.dims[2]}
		local drift = { -scale*pic_data.xy[2], dims[1]/2 + scale*pic_data.xml_xy[1]}
		if( this_info.tt_spacing[2][2] < dims[1]) then
			this_info.tt_spacing[2][3] = this_info.tt_spacing[2][3] + ( dims[1] - this_info.tt_spacing[2][2])/2
			this_info.tt_spacing[2][2] = dims[1]
		end
		this_info.tt_spacing[4] = { this_info.tt_spacing[2][1] + drift[1] - 15, this_info.tt_spacing[2][2]/2 + drift[2]}
		local total_size = this_info.tt_spacing[4][1] + dims[2] + scale*pic_data.xml_xy[2]
		if( total_size > this_info.tt_spacing[2][1] - 1 ) then
			this_info.tt_spacing[4][1] = this_info.tt_spacing[4][1] - ( total_size - this_info.tt_spacing[2][1] + 1 )
		end
	else index.register_item_pic( this_info, this_info.advanced_pic ) end
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

	index.D.tip_func( tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[6][1] + 2, this_info.tt_spacing[6][2] + 2 }, { function( pic_x, pic_y, pic_z, inter_alpha, this_data )
		if( not( is_advanced ) and this_info.is_frozen ) then
			pen.new_image( pic_x - 4, pic_y - 4, pic_z - 0.1,
				"mods/index_core/files/pics/frozen_marker.png", { has_shadow = true, alpha = inter_alpha })
		end

		pic_x = pic_x + 2
		if( this_info.wand_info.shuffle_deck_when_empty ) then
			pen.new_image( pic_x - 1, pic_y + 1, pic_z,
				"data/ui_gfx/inventory/icon_gun_shuffle.png", { alpha = inter_alpha })
			pen.new_image( pic_x - 1, pic_y + 2, pic_z + 0.01,
				"data/ui_gfx/inventory/icon_gun_shuffle.png", { color = {0,0,0}, alpha = inter_alpha })
		end
		pen.new_text( pic_x + ( this_info.wand_info.shuffle_deck_when_empty and 8 or 0 ), pic_y, pic_z, this_info.name, {
			has_shadow = true, color = {255,255,178}, alpha = inter_alpha })
		
		local orig_y = pic_y
		pic_y = pic_y + 13
		pen.new_image( pic_x - 2, pic_y - 3, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = this_info.tt_spacing[6][1], s_y = 1, alpha = 0.5*inter_alpha })
		if( pen.vld( this_info.desc )) then
			pen.new_image( pic_x + this_info.tt_spacing[2][1] - 2, pic_y - 2, pic_z,
				"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = 1, s_y = this_info.tt_spacing[6][2] - 10, alpha = 0.5*inter_alpha })
			pen.new_text( pic_x + this_info.tt_spacing[2][1] + 1, pic_y - 1, pic_z, this_info.desc, {
				has_shadow = true, alpha = inter_alpha })
		end

		local function get_generic_stat( v, v_add, dft, allow_inf )
			v, v_add, allow_inf = v or dft, v_add or 0, allow_inf or false
			local is_dft = v == dft
			return pen.get_short_num( is_dft and v_add or ( v + v_add ), ( is_dft or not( allow_inf )) and 1 or nil, is_dft ), is_dft and (v_add==0)
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
				custom_func = function( pic_x, pic_y, pic_z, txt ) --remove this (use ° symbol)
					local dims = pen.new_text( pic_x, pic_y, pic_z, txt )
					pen.new_image( pic_x + dims[1], pic_y, pic_z,
						"mods/index_core/files/fonts/vanilla_shadow/degree.png" )
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
			pen.new_image( stat_x, stat_y + ( stat.off_y or 0 ), pic_z, stat.pic, { alpha = alpha })

			local clr = {170,170,170}
			if( index.D.active_item ~= item_id and index.D.active_info.wand_info ~= nil ) then
				local is_better = nil
				local old_v, old_is_special = stat.v( index.D.active_info.wand_info )
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
					clr, alpha = is_better and {70,208,70} or {208,70,70}, inter_alpha
				end
			end

			stat.custom_func = stat.custom_func or pen.new_text
			stat.custom_func( stat_x + 9, stat_y - 1, pic_z, done_v, { color = clr, alpha = alpha })
			-- stat.desc or ""
			
			stat_y = stat_y + 8 + ( stat.extra_step or 0 )
		end

		if( #this_info.tt_spacing[4] > 0 ) then
			pen.new_image( pic_x + this_info.tt_spacing[4][1], pic_y + this_info.tt_spacing[4][2], pic_z + 0.001,
				this_info.pic, { s_x = scale, s_y = scale, alpha = inter_alpha, angle = -math.rad( 90 )})
		end

		pic_y = pic_y + this_info.tt_spacing[2][2] + 5
		if( got_spells ) then
			pen.new_image( pic_x - 2, pic_y - 3, pic_z,
				"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = this_info.tt_spacing[2][1], s_y = 1, alpha = 0.5*inter_alpha })

			local spell_x = pic_x
			for i = 0,1 do
				local tbl, counter = spell_list[ i == 0 and "permas" or "normies" ], 0
				if( i == 0 and #tbl > 0 ) then
					pen.new_image( spell_x, pic_y + 1, pic_z,
						"data/ui_gfx/inventory/icon_gun_permanent_actions.png", { alpha = inter_alpha })
					counter = counter + 1
				end
				local is_hovered = false
				for k,spell in ipairs( tbl ) do
					pen.new_image( spell_x + 9*counter, pic_y, pic_z,
						spell.pic, { s_x = 0.5, s_y = 0.5, alpha = inter_alpha })
					if( counter%2 == i ) then pen.colourer( nil, {185,220,223}) end
					_,_,is_hovered = pen.new_image( spell_x + 9*counter - 1, pic_y - 1, pic_z + 0.001,
						index.D.slot_pic.bg_alt, { s_x = 0.5, s_y = 0.5, alpha = inter_alpha, can_click = true })
					if( is_hovered ) then
						index.cat_callback( spell, "on_tooltip", {
							"wtt_spell", spell.id, spell, spell_x + 9*counter - 2, pic_y + 10, pic_z - 1 })
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
			-- pen.new_shadowed_text( pic_x - 3, orig_y + this_info.tt_spacing[6][2] + 3, pic_z, "hold "..get_binding_keys( "index_core", "az_tip_action", true ).."...", { color = {170,170,170}, alpha = inter_alpha })
		end
	end, this_info }, true, in_world )
end

function index.new_vanilla_ptt( tid, item_id, this_info, pic_x, pic_y, pic_z, in_world )
	if( this_info.matter_info == nil ) then return end
	
	local total_cap, scale = this_info.matter_info[2][1], 1.5
	local new_desc, extra_desc = this_info.desc, ""
	if( this_info.matter_info[3] and total_cap > 0 ) then
		new_desc = new_desc.."@"..GameTextGet( "$item_description_potion_usage", "[RMB]" )
	end
	if( total_cap > 0 ) then
		new_desc = new_desc.."@ @"..GameTextGetTranslatedOrNot( "$inventory_capacity" ).." = "..total_cap.."/"..this_info.matter_info[1]
		for i,m in ipairs( this_info.matter_info[2][2]) do
			local count = 100*m[2]/total_cap
			extra_desc = extra_desc..( i > 1 and "@\t" or "\t" )..pen.capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( m[1])))..": "..( count < 1 and "<" or "" )..math.max( math.floor( count + 0.5 ), 1 ).."%"
		end
	end

	this_info.tt_spacing = {
		{ pen.get_text_dims( this_info.name, true )},
		{},
		{ pen.get_pic_dims( this_info.pic )},
		{ 0, 0 },
		{},
	}
	_,this_info.tt_spacing[2] = pen.liner( new_desc, unpack( pen.get_tip_dims( new_desc, this_info.tt_spacing[1][1], 500 )), -1 )
	if( extra_desc ~= "" ) then _,this_info.tt_spacing[4] = pen.liner( extra_desc, 999, -1 ) end
	this_info.tt_spacing[3][1], this_info.tt_spacing[3][2] = scale*this_info.tt_spacing[3][1], scale*this_info.tt_spacing[3][2]
	local size_x = math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1], this_info.tt_spacing[4][1]) + 5
	local size_y = math.max( this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + this_info.tt_spacing[4][2] + ( extra_desc ~= "" and 11 or 5 ), this_info.tt_spacing[3][2] + 3 )
	this_info.tt_spacing[5] = { size_x, size_y }

	index.D.tip_func( tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[5][1] + 5 + this_info.tt_spacing[3][1], this_info.tt_spacing[5][2] + 2 }, { function( pic_x, pic_y, pic_z, inter_alpha, this_data )
		pic_x = pic_x + 2
		pen.new_shadowed_text( pic_x, pic_y, pic_z, this_info.name, { color = do_magic and {121,201,153} or {255,255,178}, alpha = inter_alpha })
		pen.new_shadowed_text( pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z, new_desc, { alpha = inter_alpha })
		pen.new_shadowed_text( pic_x + 1, pic_y + this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + 9, pic_z, extra_desc, { alpha = inter_alpha })
		
		local icon_x, icon_y = pic_x + this_info.tt_spacing[5][1], pic_y + ( this_info.tt_spacing[5][2] - this_info.tt_spacing[3][2])/2
		if( total_cap > 0 ) then
			local _,line_dims = pen.liner( "\t", 999 )
			local line_w, line_h = line_dims[1] - 3, line_dims[2]
			for i,m in ipairs( this_info.matter_info[2][2]) do
				local t_x, t_y = pic_x + 1 + line_w, pic_y + this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + line_h*(i-1) + 9
				local perc = math.max( line_w*m[2]/total_cap, 1 )
				pen.new_pixel( t_x, t_y, pic_z + tonumber( "0.0001"..i ),
					pen.get_color_matter( CellFactory_GetName( m[1])), -perc, line_h, inter_alpha )
				if( line_w - perc > 0.25 ) then
					pen.new_pixel( t_x - perc, t_y, pic_z + tonumber( "0.0001"..i ), pen.PALETTE.W, -0.5, line_h, 0.75*inter_alpha )
				end
			end
			index.new_vanilla_box( pic_x + 2, pic_y + this_info.tt_spacing[1][2] + this_info.tt_spacing[2][2] + 10, pic_z + 0.001, {line_w-2,line_h*#this_info.matter_info[2][2]-2}, inter_alpha )
			
			local cut = scale*this_info.potion_cutout
			local step = ( this_info.tt_spacing[3][2] - 2*cut )*math.max( math.min( 1 - total_cap/this_info.matter_info[1], 1 ), 0 ) + cut
			pen.new_cutout( icon_x, icon_y + step, this_info.tt_spacing[3][1], this_info.tt_spacing[3][2] - cut, function( v )
				pen.new_image( 0, -step, v[1],
					v[2], { color = pen.get_color_matter( v[6]), s_x = v[3], s_y = v[4], alpha = v[5]})
			end, { pic_z - 1, this_info.pic, scale, scale, 0.8*inter_alpha, CellFactory_GetName( this_info.matter_info[2][2][1][1])})
		end
		pen.new_image( icon_x, icon_y, pic_z, this_info.pic, { s_x = scale, s_y = scale, alpha = inter_alpha })
	end, this_info }, true, in_world )
end

function index.new_vanilla_stt( tid, item_id, this_info, pic_x, pic_y, pic_z, in_world )
	if( this_info.spell_info == nil ) then return end
	
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
	
	this_info.tt_spacing = {{}, {}}
	this_info.tip_name,this_info.tt_spacing[1] = pen.liner( this_info.tip_name, 221 )
	this_info.tt_spacing[1][1] = this_info.tt_spacing[1][1] + 9 + ( this_info.charges >= 0 and 33 or 0 )
	_,this_info.tt_spacing[2] = pen.liner( this_info.desc, unpack( pen.get_tip_dims( this_info.desc, this_info.tt_spacing[1][1])), -1 )
	local size_x = math.max( math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1]) + 6, 121 )
	local size_y = this_info.tt_spacing[2][2] + 60
	this_info.tt_spacing[3] = { size_x, size_y }

	index.D.tip_func( tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[3][1], this_info.tt_spacing[3][2]}, { function( pic_x, pic_y, pic_z, inter_alpha, this_data )
		pic_x, pic_y = pic_x + 2, pic_y + 2
		pen.new_image( pic_x, pic_y, pic_z - 0.001,
			"data/ui_gfx/inventory/icon_action_type.png", { color = index.FRAMER[ this_info.spell_info.type ][2], alpha = 0.75*inter_alpha })
		pen.new_image( pic_x, pic_y, pic_z,
			"data/ui_gfx/inventory/icon_action_type.png", { alpha = inter_alpha })
		pen.new_image( pic_x, pic_y + 1, pic_z + 0.001,
			"data/ui_gfx/inventory/icon_action_type.png", { color = {0,0,0}, alpha = inter_alpha })
		pen.new_shadowed_text( pic_x + 9, pic_y - 1, pic_z, this_info.tip_name[1], { color = {255,255,178}, alpha = inter_alpha })
		
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
			pen.new_image( pic_x + this_info.tt_spacing[3][1] - 13, pic_y, pic_z,
				"data/ui_gfx/inventory/icon_action_max_uses.png", { alpha = inter_alpha })
			local charges = pen.get_tiny_num( this_info.charges )
			pen.new_shadowed_text( pic_x + this_info.tt_spacing[3][1] - 14 - pen.get_text_dims( charges, true ), pic_y - 1, pic_z, charges, { color = {170,170,170}, alpha = inter_alpha })
		end

		pen.new_image( pic_x - 2, pic_y + 9, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = this_info.tt_spacing[3][1] - 2, s_y = 1, alpha = 0.5*inter_alpha })
		pen.new_shadowed_text( pic_x, pic_y + 11, pic_z, this_info.desc, { alpha = inter_alpha })
		pic_y = pic_y + 13 + this_info.tt_spacing[2][2]
		pen.new_image( pic_x - 2, pic_y, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = this_info.tt_spacing[3][1] - 2, s_y = 1, alpha = 0.5*inter_alpha })
		pen.new_image( pic_x - 3 + math.floor( this_info.tt_spacing[3][1]/2 ), pic_y + 1, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = 1, s_y = 43, alpha = 0.5*inter_alpha })

		local function get_generic_stat( v, v_add, dft, allow_inf )
			v, v_add, allow_inf = v or dft, v_add or 0, allow_inf or false
			local is_dft = v == dft
			return pen.get_short_num( is_dft and v_add or ( v + v_add ), ( is_dft or not( allow_inf )) and 1 or nil, is_dft ), is_dft and (v_add==0)
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
					custom_func = function( pic_x, pic_y, pic_z, txt )
						local dims = pen.new_shadowed_text( pic_x, pic_y, pic_z, txt )
						pen.new_image( pic_x + dims[1], pic_y, pic_z,
							"mods/index_core/files/fonts/vanilla_shadow/degree.png" )
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
						return ( is_dft and "x" or "" )..pen.get_short_num( is_dft and v_add or ( v*v_add )), is_dft and ( v_add == 1 )
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
				pen.new_image( stat_x, stat_y + ( stat.off_y or 0 ), pic_z, stat.pic, { alpha = alpha })
				stat.custom_func = stat.custom_func or pen.new_shadowed_text
				stat.custom_func( stat_x + 9, stat_y - 1, pic_z, v, { color = {170,170,170}, alpha = alpha })
				-- stat.desc or ""

				stat_y = stat_y + 8
			end
		end

		pic_y = pic_y - this_info.tt_spacing[2][2] + this_info.tt_spacing[3][2] - 13
		if( not( in_world )) then
			-- pen.new_shadowed_text( pic_x - 3, pic_y, pic_z, "hold "..get_binding_keys( "index_core", "az_tip_action", true ).."...", { color = {170,170,170}, alpha = inter_alpha })
		end
		if( this_info.spell_info.price > 0 ) then
			local price = pen.get_short_num( this_info.spell_info.price )
			pen.new_shadowed_text( pic_x + this_info.tt_spacing[3][1] - 8 - pen.get_text_dims( price, true ), pic_y, pic_z, price, { color = {255,255,178}, alpha = inter_alpha })
			pen.new_shadowed_text( pic_x + this_info.tt_spacing[3][1] - 7, pic_y, pic_z, "$", { alpha = inter_alpha })
		end
	end, this_info }, true, in_world )
end

function index.new_vanilla_ttt( tid, item_id, this_info, pic_x, pic_y, pic_z, in_world )
	return new_vanilla_itt( tid, item_id, this_info, pic_x, pic_y, pic_z, in_world, true )
end

function index.new_vanilla_itt( tid, item_id, this_info, pic_x, pic_y, pic_z, in_world, do_magic )
	if( not( pen.vld( this_info.pic ))) then return end
	if( not( pen.vld( this_info.name ))) then return end
	if( not( pen.vld( this_info.desc ))) then return end
	
	this_info.tt_spacing = {
		{ pen.get_text_dims( this_info.name, true )},
		{},
		{ pen.get_pic_dims( this_info.pic )},
		{},
	}
	_,this_info.tt_spacing[2] = pen.liner( this_info.desc,
		unpack( pen.get_tip_dims( this_info.desc, this_info.tt_spacing[1][1], 500 )), -1 )
	this_info.tt_spacing[3][1], this_info.tt_spacing[3][2] = 1.5*this_info.tt_spacing[3][1], 1.5*this_info.tt_spacing[3][2]
	local size_x = math.max( this_info.tt_spacing[1][1], this_info.tt_spacing[2][1]) + 5
	local size_y = math.max( this_info.tt_spacing[1][2] + 5 + this_info.tt_spacing[2][2], this_info.tt_spacing[3][2] + 3 )
	this_info.tt_spacing[4] = { size_x, size_y }

	index.D.tip_func( tid, pic_z, { "", pic_x, pic_y, this_info.tt_spacing[4][1] + 5 + this_info.tt_spacing[3][1], this_info.tt_spacing[4][2] + 2 }, { function( pic_x, pic_y, pic_z, inter_alpha, this_data )
		pic_x = pic_x + 2
		pen.new_shadowed_text( pic_x, pic_y, pic_z, this_info.name, { color = do_magic and {121,201,153} or {255,255,178}, alpha = inter_alpha })
		if( do_magic ) then
			local storage_rune = pen.magic_storage( this_info.id, "runic_cypher" )
			if( storage_rune == nil ) then
				storage_rune = EntityAddComponent( this_info.id, "VariableStorageComponent",
				{
					name = "runic_cypher",
					value_float = "0",
				})
			end
			local runic_state = ComponentGetValue2( storage_rune, "value_float" )
			if( runic_state ~= 1 ) then
				pen.new_text( pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z,
					table.concat({ "{>runic>{", this_info.desc, "}<runic<}" }), {
					fully_featured = true, color = pen.PALETTE.VNL.RUNIC, alpha = inter_alpha*( 1 - runic_state )})
			end
			if( runic_state >= 0 ) then
				pen.new_text( pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z + 0.001,
					this_info.desc, { fully_featured = true, has_shadow = true, alpha = inter_alpha*runic_state })
				ComponentSetValue2( storage_rune, "value_float", pen.estimate( "runic"..this_info.id, 1, 0.01, 0.001 ))
			end
		else pen.new_shadowed_text( pic_x, pic_y + this_info.tt_spacing[1][2] + 5, pic_z, this_info.desc, { alpha = inter_alpha }) end
		pic_x, pic_y = pic_x + this_info.tt_spacing[4][1], pic_y + ( this_info.tt_spacing[4][2] - this_info.tt_spacing[3][2])/2
		pen.new_image( pic_x, pic_y, pic_z, this_info.pic, { s_x = 1.5, s_y = 1.5, alpha = inter_alpha })
	end, this_info }, true, in_world )
end

function index.new_slot_pic( pic_x, pic_y, pic_z, pic, alpha, angle, hov_scale, fancy_shadow )
	angle = angle or 0
	scale_up = scale_up or false
	
	local pic_data = pen.cache({ "index_pic_data", pic }) or {
		xy = { 0, 0 },
		xml_xy = { 0, 0 },
	}
	
	local w, h = unpack( pic_data.dims or { pen.get_pic_dims( pic )})
	local off_x, off_y = 0, 0
	if( pic_data.xy[3] == nil ) then
		if( pic_data.xy[1] ~= 0 or pic_data.xy[2] ~= 0 ) then
			local x, y = unpack( pic_data.xy )
			x, y = pen.rotate_offset( x, y, angle )
			off_x, off_y = x, y
		end
	else angle, off_x, off_y = 0, w/2, h/2 end
	
	local extra_scale = hov_scale or 1
	pic_x, pic_y = pic_x - extra_scale*off_x, pic_y - extra_scale*off_y
	pen.new_image( pic_x, pic_y, pic_z - 0.002, --pass item_pic_data[ pic ].anim as anim
		pic, { s_x = extra_scale, s_y = extra_scale, alpha = alpha, angle = angle })

	if( fancy_shadow ~= false ) then
		fancy_shadow = fancy_shadow or false
		local sign = fancy_shadow and 1 or -1
		local scale_x, scale_y = 1/w + 1, 1/h + 1
		off_x, off_y = pen.rotate_offset( sign*0.5, sign*0.5, angle )
		pen.new_image( pic_x + extra_scale*off_x, pic_y + extra_scale*off_y, pic_z,
			pic, { color = {0,0,0}, s_x = extra_scale*scale_x, s_y = extra_scale*scale_y, alpha = 0.25, angle = angle })
	end
	
	return pic_x, pic_y
end

function index.new_spell_frame( pic_x, pic_y, pic_z, spell_type, alpha, angle )
	local off_x, off_y = pen.rotate_offset( 10, 10, angle or 0 )
	return pen.new_image( pic_x - off_x, pic_y - off_y, pic_z, index.FRAMER[ spell_type ][1], { alpha = alpha, angle = angle })
end

function index.new_vanilla_icon( pic_x, pic_y, pic_z, icon_info, kind )
	if( not( pen.vld( icon_info ))) then return 0, 0 end
	if( not( pen.vld( icon_info.pic ))) then return 0, 0 end

	local pic_off_x, pic_off_y = 0, 0
	if( kind == 2 ) then
		pic_off_x, pic_off_y = 0.5, 0.5
	elseif( kind == 4 ) then
		pic_off_x, pic_off_y = -2.5, 0
	end

    local w, h = pen.get_pic_dims( icon_info.pic )
	-- if( kind == 2 ) then GuiColorSetForNextWidget( gui, 0.3, 0.3, 0.3, 1 ) end
	local _,_,is_hovered = pen.new_image( pic_x + pic_off_x, pic_y + pic_off_y, pic_z, icon_info.pic, { can_click = true })

	if( is_hovered and kind == 4 ) then
		pen.new_pixel( pic_x + pic_off_x + 2, pic_y + pic_off_y + 1, pic_z + 0.001, pen.PALETTE.VNL.YELLOW, 13, 13, 0.75 )
	elseif( kind == 2 and icon_info.amount > 0 ) then
		-- local step = math.floor( h*( 1 - math.min( icon_info.amount, 1 )) + 0.5 )
		-- pen.new_cutout( pic_x + pic_off_x, pic_y + pic_off_y + step, w, h, function( v )
		-- 	return pen.new_image( 0, -step, v[1], v[2])
		-- end, { pic_z - 0.002, icon_info.pic })
		
		local scale = 10*icon_info.amount
		local pos = 10*( 1 - icon_info.amount )
		if( pos > 0 ) then
			pen.new_pixel( pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 1, pic_z - 0.001, pen.PALETTE.VNL.GREY, 10, pos, 0.25 ) end
		pen.new_pixel( pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 1 + pos, pic_z + 0.004, pen.PALETTE.W, 10, scale, 0.4 )
		
		pen.new_pixel( pic_x + pic_off_x - 0.5, pic_y + pic_off_y + 1 + pos, pic_z + 0.004, pen.PALETTE.B, 1, scale, 0.15 )
		pen.new_pixel( pic_x + pic_off_x + 10.5, pic_y + pic_off_y + 1 + pos, pic_z + 0.004, pen.PALETTE.B, 1, scale, 0.15 )
		pen.new_pixel( pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 11, pic_z + 0.004, pen.PALETTE.B, 10, 1, 0.15 )
	end

	local txt_off_x, txt_off_y = 0, 0
	if( kind == 2 ) then
		txt_off_x, txt_off_y = 1, 1
	elseif( kind == 4 ) then
		txt_off_x, txt_off_y = 1, 2
	end

	local tip_x, tip_y = pic_x - 5, pic_y
	if( pen.vld( icon_info.txt )) then
		icon_info.txt = pen.despacer( icon_info.txt )
		local t_x, t_h = pen.get_text_dims( icon_info.txt, true )
		t_x = t_x - txt_off_x
		pen.new_shadowed_text( pic_x - ( t_x + 1 ), pic_y + 1 + txt_off_y, pic_z, icon_info.txt,
			{ color = is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W, alpha = is_hovered and 1 or 0.5 })
		tip_x = tip_x - t_x
	end
	if(( icon_info.count or 0 ) > 1 ) then
		pen.new_shadowed_text( pic_x + 15, pic_y + 1 + txt_off_y, pic_z, "x"..icon_info.count,
			{ color = is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W, alpha = is_hovered and 1 or 0.5 })
	end

	if( kind == 4 ) then pic_y = pic_y - 3 end
	if( pen.vld( icon_info.tip )) then
		local dims, text = {}, ""
		if( type( icon_info.tip ) == "function" ) then
			dims = {
				14*math.min( #icon_info.other_perks, 10 ) - 1,
				14*math.max( math.ceil(( #icon_info.other_perks )/10 ), 1 )
			}
		else text = pen.despacer( icon_info.tip ) end
		index.D.tip_func( text, { pos = { tip_x, tip_y + ( kind == 4 and 1 or 0 )},
			dims = dims, is_active = is_hovered, is_left = true, is_over = false })
		--do { icon_info.tip, icon_info.other_perks } here
	end
	if( pen.vld( icon_info.desc ) and is_hovered ) then --add unique anim
		icon_info.desc = pen.despacer( icon_info.desc )
		local dims = { pen.get_text_dims( icon_info.desc, true )}
		local anim = pen.animate( 1, pen.c.ttips[ "dft" ].anim[3], { ease_out = "wav1.5", frames = 15 })
		pen.new_shadowed_text( pic_x - dims[1] + w, pic_y + h + 3, pic_z,
			icon_info.desc, { color = icon_info.is_danger and pen.PALETTE.VNL.WARNING or pen.PALETTE.W, alpha = anim })
		
		local bg_x = pic_x - ( dims[1] + 2 ) + w
		index.new_vanilla_box( bg_x, pic_y + h + 4, pic_z + 0.01, { dims[1] + 3, dims[2] - 1 }, anim )
		h = h + dims[2] + ( kind == 4 and 2 or 4 ) + ( kind == 1 and 1 or 0 ) + 3
	end

	if( kind == 1 ) then
		pen.new_image( pic_x, pic_y, pic_z + 0.002, "data/ui_gfx/status_indicators/bg_ingestion.png" )
		
		local d_frame = icon_info.digestion_delay
		if( icon_info.is_stomach and d_frame > 0 ) then
			pen.new_image( pic_x + 1, pic_y + 1 + 10*( 1 - d_frame ), pic_z + 0.001,
				"mods/index_core/files/pics/vanilla_stomach_bg.xml", { s_x = 10, s_y = math.ceil( 20*d_frame )/2, alpha = 0.3 })
		end
	end

	return w, h
end

function index.new_vanilla_slot( pic_x, pic_y, slot_data, this_info, is_active, can_drag, is_full, is_quick )
	local slot_pics = {
		bg_alt = slot_data.pic_bg_alt or index.D.slot_pic.bg_alt,
		bg = slot_data.pic_bg or index.D.slot_pic.bg,
		active = slot_data.pic_active or index.D.slot_pic.active,
		hl = slot_data.pic_hl or index.D.slot_pic.hl,
		locked = slot_data.pic_locked or index.D.slot_pic.locked,
	}
	local slot_sfxes = {
		select = slot_data.sfx_select or index.D.sfxes.select,
		move_item = slot_data.sfx_move_item or index.D.sfxes.move_item,
		move_empty = slot_data.sfx_move_empty or index.D.sfxes.move_empty,
		hover = slot_data.sfx_hover or index.D.sfxes.hover,
	}
	local cat_tbl = {
		on_equip = index.cat_callback( this_info, "on_equip" ),
		on_action = index.cat_callback( this_info, "on_action" ),
		on_slot = index.cat_callback( this_info, "on_slot" ),
		on_tooltip = index.cat_callback( this_info, "on_tooltip" ),
	}
	if( cat_tbl.on_action ~= nil ) then
		cat_tbl.on_rmb = cat_tbl.on_action( 1 )
		cat_tbl.on_drag = cat_tbl.on_action( 2 )
	end

	if( this_info.id > 0 and index.D.dragger.item_id == this_info.id ) then
		pen.colourer( nil, {150,150,150})
	end
	local pic_bg = ( is_full == true ) and index.D.slot_pic.bg_alt or index.D.slot_pic.bg
	local w, h = pen.get_pic_dims( pic_bg )
	local clicked, r_clicked, is_hovered = pen.new_image( pic_x, pic_y, pen.LAYERS.MAIN_DEEP, pic_bg, { can_click = true })
	local might_swap = not( index.D.is_opened ) and is_quick and is_hovered
	if(( clicked or slot_data.force_equip ) and this_info.id > 0 ) then
		local do_default = might_swap or slot_data.force_equip
		if( cat_tbl.on_equip ~= nil ) then
			if( cat_tbl.on_equip( this_info.id, this_info )) then
				play_sound( slot_sfxes.select )
				do_default = false
			end
		end
		if( do_default and ( this_info.in_hand or 0 ) == 0 ) then
			play_sound( slot_sfxes.select )
			local inv_comp = pen.reset_active_item( pen.get_item_owner( this_info.id, true ))
			ComponentSetValue2( inv_comp, "mSavedActiveItemIndex", pen.get_item_num( slot_data.inv_id, this_info.id ))
		end
	end
	
	local no_action, dragger_hovered = cat_tbl.on_drag == nil, false
	pic_x, pic_y = pic_x + w/2, pic_y + h/2
	if(( is_full ~= true ) and is_active ) then
		pen.new_image( pic_x, pic_y,
			pen.LAYERS[( not( index.D.is_opened ) or can_drag ) and "MAIN_FRONT" or "ICONS_FRONT" ] + 0.0001, index.D.slot_pic.active )
	end
	if( index.D.dragger.item_id > 0 ) then
		local no_hov_for_ya = true
		if( pen.check_bounds( index.D.pointer_ui, { -w/2, w/2, -h/2, h/2 }, { pic_x, pic_y })) then
			index.D.dragger.wont_drop = true
			if( can_drag ) then
				local dragged_data = pen.t.get( index.D.item_list, index.D.dragger.item_id )
				if( index.slot_swap_check( dragged_data, this_info, slot_data )) then
					no_hov_for_ya = false
					if( index.D.dragger.swap_now ) then
						if( this_info.id > 0 ) then
							table.insert( index.G.slot_anim, {
								id = this_info.id,
								x = pic_x,
								y = pic_y - 10,
								frame = index.D.frame_num,
							})
						end
						play_sound( slot_sfxes[ this_info.id > 0 and "move_item" or "move_empty" ])
						index.slot_swap( index.D.dragger.item_id, slot_data )
						index.D.dragger.item_id = -1
					end
					if( index.G.slot_memo[ index.D.dragger.item_id ] and index.D.dragger.item_id ~= this_info.id ) then
						dragger_hovered = true
						pen.new_image( pic_x - w/2, pic_y - w/2, pen.LAYERS.MAIN_FRONT + 0.001, index.D.slot_pic.hl )
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
			play_sound( slot_sfxes.hover )
		end
		slot_hover_sfx[2] = true
	end
	
	local slot_x, slot_y = pic_x - w/2, pic_y - h/2
	if( can_drag ) then
		if( this_info.id > 0 and not( index.D.dragger.swap_now or index.G.slot_state )) then
			pic_x, pic_y = index.new_dragger_shell( this_info.id, this_info, pic_x, pic_y, w/2, h/2 )
		end
	elseif( index.D.is_opened ) then
		if( is_full == true ) then
			pen.new_image( slot_x - 0.5, slot_y - 0.5, pen.LAYERS.ICONS_FRONT + 0.001,
				index.D.slot_pic.bg_alt, { color = {150,150,150}, s_x = 21/20, s_y = 21/20, alpha = 0.75 })
		else pen.new_image( slot_x, slot_y, pen.LAYERS.ICONS_FRONT + 0.001, index.D.slot_pic.locked ) end
	end
	
	if( this_info.id > 0 ) then
		local is_dragged = index.G.slot_memo[ index.D.dragger.item_id ] and index.D.dragger.item_id == this_info.id
		local suppress_charges, suppress_action = false, false
		if( cat_tbl.on_slot ~= nil ) then
			if( no_action and is_dragged ) then
				pic_x, pic_y = pic_x + 10, pic_y + 10
			end
			
			pic_x, pic_y = index.swap_anim( this_info.id, pic_x, pic_y )
			this_info, suppress_charges, suppress_action = cat_tbl.on_slot( this_info.id, this_info, pic_x, pic_y, {
				is_lmb = clicked,
				is_rmb = r_clicked,
				is_hov = is_hovered,
				is_full = is_full,
				is_active = is_active,
				is_quick = is_quick,
				can_drag = can_drag,
				is_dragged = is_dragged,
				is_opened = index.D.is_opened or index.D.allow_tips_always,
			}, cat_tbl.on_rmb, cat_tbl.on_drag, cat_tbl.on_tooltip, might_swap and 1.2 or 1 )
		end
		if( not( suppress_action or false )) then
			if( is_dragged ) then
				if( cat_tbl.on_drag ~= nil and index.D.drag_action ) then
					cat_tbl.on_drag( this_info.id, this_info )
				end
			elseif( cat_tbl.on_rmb ~= nil and r_clicked and index.D.is_opened and is_quick ) then
				cat_tbl.on_rmb( this_info.id, this_info )
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
						pen.new_image( cross_x, cross_y, pen.LAYERS.ICONS_FRONT,
							"mods/index_core/files/pics/vanilla_no_cards.xml" )
						pen.new_image( cross_x + 0.5, cross_y + 0.5, pen.LAYERS.ICONS_FRONT + 0.001,
							"mods/index_core/files/pics/vanilla_no_cards.xml", { color = {0,0,0}, alpha = 0.75 })
					end
				else
					pen.new_text( slot_x + ( 1 - shift ), slot_y, pen.LAYERS.ICONS_FRONT,
						math.floor( this_info.charges ), { is_huge = false })
					pen.new_text( slot_x + ( 1 - shift ) + 0.5, slot_y + 0.5, pen.LAYERS.ICONS_FRONT + 0.0001,
						math.floor( this_info.charges ), { is_huge = false, color = pen.PALETTE.B, alpha = 0.75 })
				end
			end
		end
	end
	
	return w-1, h-1, clicked, r_clicked, is_hovered
end

function index.slot_setup( pic_x, pic_y, slot_data, can_drag, is_full, is_quick )
	local this_info = slot_data.idata or {}
	if( not( slot_data.id )) then
		slot_data.id = -1
		this_info = { id = slot_data.id, in_hand = 0 }
	elseif( this_info.id == nil ) then
		this_info = pen.t.get( index.D.item_list, slot_data.id )
	end
	if( slot_data.id > 0 ) then
		if( EntityHasTag( this_info.id, "index_unlocked" )) then
			can_drag = true
		elseif( this_info.is_locked ) then
			can_drag = false
		end
	elseif( EntityHasTag( index.D.dragger.item_id, "index_unlocked" )) then
		local inv_info = pen.t.get( index.D.item_list, slot_data.inv_id, nil, nil, {})
		if( inv_info.id == nil or not( inv_info.is_frozen )) then
			can_drag = true
		end
	end
	
	local w, h, clicked, r_clicked, is_hovered = index.D.slot_func( pic_x, pic_y, slot_data, this_info, this_info.in_hand > 0, can_drag, is_full, is_quick )
	if( this_info.cat ~= nil ) then
		index.cat_callback( this_info, "on_inventory", {
			this_info.id, this_info, pic_x, pic_y, {
				can_drag = can_drag,
				is_dragged = index.D.dragger.item_id > 0 and index.D.dragger.item_id == this_info.id,
				in_hand = this_info.in_hand > 0,
				is_quick = is_quick,
				is_full = is_full,
			}
		})
	end
	
	return w, h
end

function index.new_vanilla_wand( pic_x, pic_y, this_info, in_hand, can_tinker )
	local step_x, step_y = 0, 0
	local scale = index.D.no_wand_scaling and 1 or 1.5
	local extra_step = ( this_info.wand_info.shuffle_deck_when_empty or this_info.wand_info.actions_per_round > 1 ) and 3 or 0
	this_info.w_spacing = {
		extra_step - 1, 0,
		19*this_info.wand_info.deck_capacity + 4, 0,
	}

	local pic_data = pen.cache({ "index_pic_data", this_info.pic })
	if( pic_data ) then
		local drift = this_info.w_spacing[1]
		this_info.w_spacing[2] = drift
		if( pic_data.xy ) then
			drift = drift + scale*pic_data.xy[1]
		end
		if( pic_data.xml_xy ) then
			drift = drift - scale*pic_data.xml_xy[1]
		end
		this_info.w_spacing[1] = drift

		if( pic_data.dims ) then
			this_info.w_spacing[2] = this_info.w_spacing[2] + scale*pic_data.dims[1] + 1
			local min_val = math.ceil( math.max( this_info.w_spacing[1] + this_info.w_spacing[2] - extra_step, 25 )/19 )*19
			if( this_info.w_spacing[2] < min_val ) then
				this_info.w_spacing[1] = drift + ( min_val - this_info.w_spacing[2])/2
				this_info.w_spacing[2] = min_val
			end
		end

		drift = scale*pic_data.dims[2] - 18
		if( drift > 0 ) then
			this_info.w_spacing[4] = drift
		end
	end

	step_x, step_y = this_info.w_spacing[2] + this_info.w_spacing[3], 19 + this_info.w_spacing[4]
	index.D.tip_func( this_info.id, pen.LAYERS.MAIN_DEEP, { "", pic_x, pic_y, step_x, step_y }, { function( pic_x, pic_y, pic_z, inter_alpha, this_info )
		local is_shuffle, is_multi = this_info.wand_info.shuffle_deck_when_empty, this_info.wand_info.actions_per_round > 1
		if( is_shuffle or is_multi ) then
			if( is_shuffle ) then
				pen.new_image( pic_x, pic_y, pic_z,
					"data/ui_gfx/inventory/icon_gun_shuffle.png", { alpha = inter_alpha })
				pen.new_image( pic_x + 0.5, pic_y + 0.5, pic_z + 0.001,
					"data/ui_gfx/inventory/icon_gun_shuffle.png", { color = pen.PALETTE.B, alpha = inter_alpha*0.75 })
			end
			if( is_multi ) then
				local multi_y = pic_y + this_info.w_spacing[4]
				pen.new_image( pic_x, multi_y + 11, pic_z,
					"data/ui_gfx/inventory/icon_gun_actions_per_round.png", { alpha = inter_alpha })
				pen.new_image( pic_x + 0.5, multi_y + 10.5, pic_z + 0.001,
					"data/ui_gfx/inventory/icon_gun_actions_per_round.png", { color = pen.PALETTE.B, alpha = inter_alpha*0.75 })
				pen.new_text( pic_x + 9, multi_y + 10, pic_z,
					this_info.wand_info.actions_per_round, { color = pen.PALETTE.VNL.GREY, alpha = inter_alpha })
				pen.new_text( pic_x + 9.5, multi_y + 9.5, pic_z + 0.001,
					this_info.wand_info.actions_per_round, { color = pen.PALETTE.SHADOW, alpha = 0.5*inter_alpha })
			end
		end

		local drift, section_off = this_info.w_spacing[1], this_info.w_spacing[2]
		index.new_slot_pic( pic_x + drift, pic_y + 9 + this_info.w_spacing[4]/2, pic_z + 0.005, this_info.pic, inter_alpha, 0, scale, true )
		local clicked, r_clicked, is_hovered = pen.new_interface(
			pic_x, pic_y, section_off, 18 + this_info.w_spacing[4], pic_z - 0.001 )
		pic_x = pic_x + section_off
		if( this_info.is_frozen ) then
			pen.new_image( pic_x - 5, pic_y + step_y - 7, pic_z - 0.01,
				"mods/index_core/files/pics/frozen_marker.png", { has_shadow = true, alpha = inter_alpha, can_click = true })
			index.D.tip_func( GameTextGetTranslatedOrNot( "$inventory_info_frozen_description" ), { pic_z = pic_z - 5 })
		end
		if( is_hovered ) then
			index.cat_callback( this_info, "on_tooltip",
				{ nil, this_info.id, this_info, pic_x + 1, pic_y - 2, pen.LAYERS.TIPS, false, true })
		end
		pen.new_image( pic_x, pic_y - 1, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = 1, s_y = step_y + 1, alpha = 0.5*inter_alpha })
		
		local slot_count = this_info.wand_info.deck_capacity
		if( slot_count > 26 ) then
			--arrows (small bouncing of slot row post scroll based on the direction scrolled)
			--use temp cutouts for transition
		end

		if( can_tinker == nil ) then
			can_tinker = not( this_info.is_frozen )
			if( can_tinker ) then
				can_tinker = index.D.can_tinker or EntityHasTag( this_info.id, "index_unlocked" )
			end
		end

		local counter = 1
		local slot_x, slot_y = pic_x + 2, pic_y - 1 + this_info.w_spacing[4]
		local slot_data = index.D.slot_state[ this_info.id ]
		for i,col in ipairs( slot_data ) do
			for e,slot in ipairs( col ) do
				local idata = nil
				if( slot ) then
					idata = pen.t.get( index.D.item_list, slot )
					if( idata.is_permanent ) then
						pen.new_image( slot_x + 1, slot_y + 12, pen.LAYERS.ICONS_FRONT,
							"data/ui_gfx/inventory/icon_gun_permanent_actions.png" )
						pen.new_image( slot_x + 1.5, slot_y + 11.5, pen.LAYERS.ICONS_FRONT + 0.0001,
							"data/ui_gfx/inventory/icon_gun_permanent_actions.png", { color = {0,0,0}, alpha = 0.75 })
					end
				end
				
				if( counter%2 == 0 and slot_count > 2 ) then
					pen.colourer( nil, {185,220,223}) end
				w, h = index.slot_setup( slot_x, slot_y, {
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
	end, this_info }, true, nil, nil, in_hand )

	return step_x + 7, step_y + 7
end

index.FRAMER = {
	[0] = { "data/ui_gfx/inventory/item_bg_projectile.png", pen.PALETTE.VNL.ACTION_PROJECTILE },
	[1] = { "data/ui_gfx/inventory/item_bg_static_projectile.png", pen.PALETTE.VNL.ACTION_STATIC },
	[2] = { "data/ui_gfx/inventory/item_bg_modifier.png", pen.PALETTE.VNL.ACTION_MODIFIER },
	[3] = { "data/ui_gfx/inventory/item_bg_draw_many.png", pen.PALETTE.VNL.ACTION_DRAW },
	[4] = { "data/ui_gfx/inventory/item_bg_material.png", pen.PALETTE.VNL.ACTION_MATERIAL },
	[5] = { "data/ui_gfx/inventory/item_bg_utility.png", pen.PALETTE.VNL.ACTION_UTILITY },
	[6] = { "data/ui_gfx/inventory/item_bg_passive.png", pen.PALETTE.VNL.ACTION_PASSIVE },
	[7] = { "data/ui_gfx/inventory/item_bg_other.png", pen.PALETTE.VNL.ACTION_OTHER },
}