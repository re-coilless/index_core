dofile_once( "mods/mnee/lib.lua" )
dofile_once( "mods/penman/_libman.lua" )
dofile_once( "data/scripts/lib/utilities.lua" )

index = index or {}
index.G = index.G or {} --global params
index.D = index.D or {} --frame-iterated data
index.M = index.M or {} --interframe memory values

-- index.register_item_pic
-- index.swap_anim
-- index.check_dragger_buffer
-- index.new_dragger_shell

-- index.new_vanilla_wtt
-- index.new_vanilla_stt

-- index.new_slot_pic
-- index.new_spell_frame
-- index.new_vanilla_slot
-- index.slot_setup
-- index.new_vanilla_wand

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

	local hooman = ( EntityGetWithTag( "index_ctrl" ) or {})[1]
	if( pen.vld( hooman, true )) then
		EntitySetComponentIsEnabled( hooman, EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" ), true )
		EntitySetComponentIsEnabled( hooman, EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" ), true )
		EntityRemoveTag( hooman, "index_ctrl" )
	end

	EntityRemoveComponent( GetUpdatedEntityID(), GetUpdatedComponentID())
end

---Returns a table of all detected status effects, stains, ingestions and perks.
---@param hooman entity_id
---@return table effects, table perks
function index.get_status_data( hooman )
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
	if( pen.vld( ing_comp, true )) then
		local raw_count = ComponentGetValue2( ing_comp, "ingestion_size" )
		local total_cap = ComponentGetValue2( ing_comp, "ingestion_capacity" )
		if( raw_count > 0 ) then ing_perc = math.floor( 100*raw_count/total_cap + 0.5 ) end
	end
	
	local status_comp = EntityGetFirstComponentIncludingDisabled( hooman, "StatusEffectDataComponent" )
	local ing_many = ComponentGetValue2( status_comp, "ingestion_effect_causes_many" )
	local ing_matter = ComponentGetValue2( status_comp, "ingestion_effect_causes" )
	pen.t.loop( ComponentGetValue2( status_comp, "ingestion_effects" ), function( effect_id, duration )
		if( duration == 0 ) then return end
		
		local effect_info = index.get_thresholded_effect(
			pen.t.get( status_effects, { effect_id }, "real_id", nil, nil, {}), duration )
		local time = index.get_effect_duration( duration, effect_info )
		if( effect_info.id == nil or time == 0 ) then return end
		
		local is_many = ing_many[ effect_id ] == 1
		local hardcoded_cancer_fucking_ass_list = {
			INGESTION_MOVEMENT_SLOWER = 1, INGESTION_EXPLODING = 1, INGESTION_DAMAGE = 1 }
		local mtr = GameTextGetTranslatedOrNot( CellFactory_GetUIName( ing_matter[ effect_id ]))
		local message = GameTextGet( "$ingestion_status_caused_by"..( is_many and "_many" or "" ), mtr == "" and "???" or mtr )
		if( ing_perc >= 100 and hardcoded_cancer_fucking_ass_list[ effect_info.id ]) then
			if( GameGetGameEffectCount( hooman, "IRON_STOMACH" ) == 0 ) then
				message, time = GameTextGetTranslatedOrNot( "$ingestion_status_caused_by_overingestion" ), -1
			else time = 0 end
		end
		if( time == 0 ) then return end
		
		table.insert( effect_tbl.ings, {
			pic = effect_info.ui_icon,
			txt = index.get_effect_timer( time ),
			desc = GameTextGetTranslatedOrNot( effect_info.ui_name ),
			tip = GameTextGetTranslatedOrNot( effect_info.ui_description ).."\n"..message,
			amount = time*60, is_danger = effect_info.is_harmful,
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

	pen.t.loop( ComponentGetValue2( status_comp, "mStainEffectsSmoothedForUI" ), function( effect_id, duration )
		local perc = index.get_stain_perc( duration )
		if( perc == 0 ) then return end
		local effect_info = index.get_thresholded_effect(
			pen.t.get( status_effects, { effect_id }, "real_id", nil, nil, {}), duration )
		if( not( pen.vld( effect_info.id ))) then return end

		table.insert( effect_tbl.stains, {
			id = effect_id,
			pic = effect_info.ui_icon,
			txt = math.min( perc, 100 ).."%",
			desc = GameTextGetTranslatedOrNot( effect_info.ui_name ),
			tip = GameTextGetTranslatedOrNot( effect_info.ui_description ),
			amount = math.min( perc/100, 1 ), is_danger = effect_info.is_harmful,
		})
	end)
	table.sort( effect_tbl.stains, function( a, b ) return a.id > b.id end)

	local dmg_comp = EntityGetFirstComponentIncludingDisabled( hooman, "DamageModelComponent" )
	if( pen.vld( dmg_comp, true ) and ComponentGetIsEnabled( dmg_comp ) and ComponentGetValue2( dmg_comp, "mIsOnFire" )) then
		local fire_info = pen.t.get( status_effects, "ON_FIRE" )
		local perc = math.floor( 100*ComponentGetValue2( dmg_comp, "mFireFramesLeft" )/ComponentGetValue2( dmg_comp, "mFireDurationFrames" ))
		table.insert( effect_tbl.stains, 1, {
			pic = fire_info.ui_icon, txt = perc.."%",
			desc = GameTextGetTranslatedOrNot( fire_info.ui_name ),
			tip = GameTextGetTranslatedOrNot( fire_info.ui_description ),
			amount = math.min( perc/100, 1 ), is_danger = true,
		})
	end

	local frame_num = GameGetFrameNum()
    pen.child_play_full( hooman, function( child )
        local info_comp = EntityGetFirstComponentIncludingDisabled( child, "UIIconComponent" )
        if( not( pen.vld( info_comp, true ))) then return end
		if( not( ComponentGetValue2( info_comp, "display_in_hud" ))) then return end

		local icon_info = {
			pic = ComponentGetValue2( info_comp, "icon_sprite_file" ), txt = "",
			desc = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "name" )),
			tip = GameTextGetTranslatedOrNot( ComponentGetValue2( info_comp, "description" )), count = 1, }
		if( ComponentGetValue2( info_comp, "is_perk" )) then
			dofile_once( "data/scripts/perks/perk_list.lua" )
			local _,true_id = pen.t.get( perk_tbl, icon_info.pic, "pic" )
			if( not( pen.vld( true_id ))) then
				if( EntityGetName( child ) == "fungal_shift_ui_icon" ) then
					icon_info.tip = GlobalsGetValue( index.GLOBAL_FUNGAL_MEMO, "" ).."\n"..icon_info.tip
					icon_info.count = tonumber( GlobalsGetValue( "fungal_shift_iteration", "0" ))
					icon_info.is_fungal = true
					
					local raw_timer = tonumber( GlobalsGetValue( "fungal_shift_last_frame", "0" ))
					local fungal_timer = math.max( 60*60*5 + raw_timer - frame_num, 0 )
					if( fungal_timer > 0 ) then
						icon_info.amount = fungal_timer
						icon_info.txt = index.get_effect_timer( icon_info.amount/60 )
						icon_info.tip = icon_info.tip.."\n"..icon_info.txt.." until next Shift window."
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

				local effect = pen.t.get( simple_effects, child, nil, nil, {})
				if( not( pen.vld( effect ))) then return end

				icon_info.amount = ComponentGetValue2( effect[2], "frames" )
				local effect_info = index.get_thresholded_effect(
					pen.t.get( status_effects, { effect[3]}, "real_id", nil, nil, {}), icon_info.amount )
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
				if( time > 0 ) then table.insert( effect_tbl.misc[ true_id ].time_tbl, time ) end
				effect_tbl.misc[ true_id ].count = effect_tbl.misc[ true_id ].count + 1
				if( effect_tbl.misc[ true_id ].amount < icon_info.amount ) then effect_tbl.misc[ true_id ].amount = icon_info.amount end
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
    table.sort( perk_tbl, function( a, b ) return a.count > b.count end)
    
	pen.t.loop( effect_tbl.misc, function( i, e )
		table.sort( e.time_tbl, function( a, b ) return a > b end)
        effect_tbl.misc[1].txt = index.get_effect_timer( e.time_tbl[1])
        if( #e.time_tbl <= 1 ) then return end
		local tip = GameTextGetTranslatedOrNot( "$menu_replayedit_writinggif_timeremaining" )
		effect_tbl.misc[1].tip = effect_tbl.misc[1].tip.."\n"..string.gsub(
			tip, "%$0 ", index.get_effect_timer( e.time_tbl[ #e.time_tbl ], true ))
	end)
    table.sort( effect_tbl.misc, function( a, b ) return a.amount > b.amount end)

	return effect_tbl, perk_tbl
end

function index.full_stopper( text )
	if( not( pen.vld( text ))) then return "" end
	if( string.find( text, "%p$" ) == nil ) then text = text.."." end
	return text
end
function index.hud_text_fix( key )
	local txt = GameTextGetTranslatedOrNot( key ) or ""
	local _,pos = string.find( txt, ":", 1, true )
	if( pos ~= nil ) then txt = string.sub( txt, 1, pos-1 ) end
	return txt..":\n"
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
	local some_cancer = 14/99 --idk fucking why
	return math.max( math.floor( 100*( perc - some_cancer )/( 1 - some_cancer ) + 0.5 ), 0 )
end
function index.get_effect_timer( secs, no_units )
	if(( secs or -1 ) < 0 ) then return "" end

	local is_tiny = secs < 1
	secs = string.format( "%."..pen.b2n( is_tiny ).."f", secs )
	if( not( no_units )) then secs = string.gsub( GameTextGet( "$inventory_seconds", secs ), " ", "" ) end
	return is_tiny and string.sub( secs, 2 ) or secs
end
function index.get_effect_duration( frames, info, eps )
	frames = frames - 60*(( info or {}).ui_timer_offset_normalized or 0 )
	if( math.abs( frames*60 ) <= ( eps or index.G.settings.min_effect_duration )) then frames = 0 end
	return frames < 0 and -1 or frames
end
function index.get_thresholded_effect( effects, frames )
	local final_id = #effects
	if( final_id < 2 ) then return effects[1] or {} end
	table.sort( effects, function( a, b )
		return ( a.min_threshold_normalized or 0 ) < ( b.min_threshold_normalized or 0 )
	end)
	
	for i,effect in ipairs( effects ) do
		if( frames < 60*( effect.min_threshold_normalized or 0 )) then
			final_id = math.max( i-1, 1 ); break
		end
	end
	return effects[ final_id ]
end

---Extracts offsets from SpriteComponent.
function index.register_item_pic( info )
	if( not( pen.vld( info.pic ))) then return end
	local force_update = EntityHasTag( info.id, "index_update" )
	if( force_update ) then EntityRemoveTag( info.id, "index_update" ) end

	return pen.cache({ "index_pic_data", info.pic }, function()
		local anim_data = pen.magic_storage( info.id, "index_pic_anim", "value_string" ) --this should contain the anim anme and nothing else
		if( pen.vld( anim_data )) then data.anim = pen.t.pack( anim_data ) end
		local w, h = pen.get_pic_dims( info.pic, force_update )
		local data = { dims = { w, h }, xy = { 0, 0 }}

		local off_data = pen.magic_storage( info.id, "index_pic_offset", "value_string" )
		if( not( pen.vld( off_data ))) then
			-- data.xy = { data.dims[1]/2, data.dims[2]/2 }
			local pic_comp = EntityGetFirstComponentIncludingDisabled( info.id, "SpriteComponent", "item" )
				or EntityGetFirstComponentIncludingDisabled( info.id, "SpriteComponent", "enabled_in_hand" )
			if( pen.vld( pic_comp, true )) then
				data.xy = { ComponentGetValue2( pic_comp, "offset_x" ), ComponentGetValue2( pic_comp, "offset_y" )}
			end
		else data.xy = pen.t.pack( off_data ) end

		return data
	end, { reset_count = 0, force_update = force_update })
end

function index.swap_anim( item_id, end_x, end_y ) 
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

function index.get_stat( main_value, added_value, default, allow_inf )
	main_value, added_value = main_value or default, added_value or 0
	local is_dft = main_value == default
	local value = pen.get_short_num(
		is_dft and added_value or ( main_value + added_value ), ( is_dft or not( allow_inf )) and 1 or nil, is_dft )
	return value, is_dft and ( added_value == 0 )
end

------------------------------------------------------		[INVENTORY]		------------------------------------------------------

function index.is_inv_empty( slot_state )
	for i,col in pairs( slot_state ) do
		for e,slot in ipairs( col ) do
			if( slot ) then return false end
		end
	end
	return true
end

function index.cat_callback( info, callback, input, fallback, do_default )
	local func_local = info[ callback ]
	if( type( input or 1 ) ~= "table" ) then
		return func_local or index.D.item_cats[ info.cat ][ callback ] end
	table.insert( input, 1, info )

	local out = fallback or {}
	local is_real = pen.vld( func_local )
	if( do_default == nil ) then do_default = not( is_real ) end
	if( is_real ) then out = { func_local( unpack( input ))} end
	if( do_default ) then
		local func_main = index.D.item_cats[ info.cat ][ callback ]
		if( func_main ~= nil ) then out = { func_main( unpack( input ))} end
	end
	return unpack( out )
end

---Transforms numerical inv_cat value to a table of all allowed inventories.
---@param inv_cat number -1 is quick only (is_quickest changes this), -0.5 is quick and quickest, 0 is everything, 0.5 is full only, 1 is nothing
---@param is_quickest boolean
---@return table inv_kinds
function index.get_valid_invs( inv_cat, is_quickest )
	local inv_kinds = {}
	if( math.floor( inv_cat ) == 0 ) then table.insert( inv_kinds, "full" ) end
	if( math.ceil( inv_cat ) == 0 ) then table.insert( inv_kinds, "quick" ); table.insert( inv_kinds, "quickest" ) end
	if( inv_cat == -1 ) then table.insert( inv_kinds, is_quickest and "quickest" or "quick" ) end
	return inv_kinds
end

function index.get_inv_info( inv_id, size, kind, kind_func, check_func, update_func, gui_func, sort_func )
	local kind_data = pen.magic_storage( inv_id, "index_kind", "value_string" )
	if( kind_data ~= nil ) then kind = pen.t.pack( kind_data ) end
	local kind_path = pen.magic_storage( inv_id, "index_kind_func", "value_string" )
	if( kind_path ~= nil ) then kind_func = dofile( kind_path ) end
	local size_data = pen.magic_storage( inv_id, "index_size", "value_string" )
	if( size_data ~= nil ) then size = pen.t.pack( size_data, true ) end
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
		inventory_quick = { "quick", size[1] > 0 and "quickest" or nil },
	}
	return {
		id = inv_id,
		kind = kind or inv_ts[ EntityGetName( inv_id )] or { "universal" },
		kind_func = kind_func,
		size = size,
		func = gui_func,
		check = check_func,
		update = update_func,
		sort = sort_func,
	}
end

function index.inv_check( item_info, info )
	if(( item_info.id or 0 ) < 0 ) then return true end
	if( item_info.id == info.inv_id ) then return false end
	
	local kind_memo = info.kind
	local inv_info = index.D.invs[ info.inv_id ]
	info.kind = pen.vld( inv_info.kind_func ) and inv_info.kind_func( info ) or inv_info.kind
	
	local is_universal = pen.t.get( info.kind, "universal" ) ~= 0
	local is_valid = pen.vld( pen.t.get( index.get_valid_invs( item_info.inv_cat, item_info.is_quickest ), info.kind, nil, nil, {}))
	local is_fit = ( is_universal or is_valid ) and ( inv_info.check == nil or inv_info.check( item_info, info ))
	if( is_fit ) then is_fit = index.cat_callback( item_info, "on_inv_check", { info }, { is_fit }) end
	
	info.kind = kind_memo
	return is_fit
end

function index.slot_swap_check( item_in, item_out, slot_info )
	local inv_memo = item_out.inv_id; index.G.slot_memo = item_out.inv_slot
	item_out.inv_id, item_out.inv_slot = item_out.inv_id or slot_info.inv_id, item_out.inv_slot or slot_info.inv_slot
	local is_fit = index.inv_check( item_in, item_out ) and index.inv_check( item_out, item_in )
	item_out.inv_id, item_out.inv_slot = inv_memo, index.G.slot_memo
	return is_fit
end

function index.inventory_boy( info, in_hand )
	local item_id = info.id
	local in_wand = pen.vld( info.in_wand, true )
	if( in_wand or in_hand == nil ) then
		local wand_id = in_wand and info.in_wand or item_id
		in_hand = pen.vld( pen.get_item_owner( wand_id ), true )
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
	if( in_hand and pen.get_active_item( pen.get_item_owner( item_id )) == item_id ) then return end
	if( in_hand ) then hooman = EntityGetParent( item_id ) end
	local x, y = EntityGetTransform( hooman )
	EntitySetTransform( item_id, x, y )
	EntityApplyTransform( item_id, x, y )
end

function index.inventory_man( info, in_hand, force_full )
	local item_id = info.id
	pen.child_play_full( item_id, function( child, params )
		info.id = child
		index.inventory_boy( info, in_hand )
		if( not( force_full ) and index.D.invs[ child ] ~= nil ) then return true end
	end)
	info.id = item_id
end

function index.set_to_slot( info, is_player )
	if( is_player == nil ) then
		local parent_id = EntityGetParent( info.id )
		is_player = index.D.invs_p.q == parent_id or index.D.invs_p.f == parent_id
	end
	
	local slot_num = { ComponentGetValue2( info.ItemC, "inventory_slot" )}
	if( slot_num[1] == -1 and slot_num[2] == -1 ) then return info end

	local valid_invs = index.get_valid_invs( info.inv_cat, info.is_quickest )
	if( slot_num[2] == -5 ) then
		if( not( info.is_hidden )) then
			local inv_list = is_player and index.D.invs_p or { info.inv_id }
			pen.t.loop( inv_list, function( _,inv_id )
				local inv_info = index.D.invs[ inv_id ]
				local is_universal = pen.t.get( inv_info.kind, "universal" ) ~= 0
				local is_valid = pen.vld( pen.t.get( valid_invs, inv_info.kind, nil, nil, {}))
				if( not( is_universal or is_valid )) then return end
				
				for i,slot in pairs( index.D.slot_state[ inv_id ]) do
					pen.t.loop( slot, function( k, s )
						if( s ) then return end
						local is_fancy = type( i ) == "string"
						if( is_fancy and pen.t.get( valid_invs, i ) == 0 ) then return end

						local temp_slot = is_fancy and { k, i == "quickest" and -1 or -2 } or { i, k }
						if( index.inv_check( info, { inv_id = inv_id, inv_slot = temp_slot })) then
							if( temp_slot[2] < 0 ) then temp_slot[2] = temp_slot[2] + 1 end
							
							local parent_check = EntityGetParent( info.id )
							if( parent_check > 0 and inv_id ~= parent_check) then
								EntityRemoveFromParent( info.id )
								EntityAddChild( inv_id, info.id )
							end

							slot_num = temp_slot
							index.D.slot_state[ inv_id ][i][k] = info.id
							return true
						end
					end)

					if( slot_num[2] ~= -5 ) then break end
				end

				if( slot_num[2] ~= -5 ) then return true end
			end)
			if( slot_num[2] == -5 ) then return info end
		else slot_num = { -1, -1 } end
		slot_num[1], slot_num[2] = slot_num[1] - 1, slot_num[2] - 1
		ComponentSetValue2( info.ItemC, "inventory_slot", slot_num[1], slot_num[2])
	elseif( slot_num[2] == -1 ) then
		index.D.slot_state[ info.inv_id ].quickest[ slot_num[1] + 1 ] = info.id
		info.inv_kind = "quickest"
	elseif( slot_num[2] == -2 ) then
		index.D.slot_state[ info.inv_id ].quick[ slot_num[1] + 1 ] = info.id
		info.inv_kind = "quick"
	elseif( slot_num[2] >= 0 ) then
		index.D.slot_state[ info.inv_id ][ slot_num[1] + 1 ][ slot_num[2] + 1 ] = info.id
		info.inv_kind = info.inv_kind[1]
	end

	slot_num[1] = slot_num[1] + 1
	slot_num[2] = slot_num[2] < 0 and slot_num[2] or slot_num[2] + 1
	info.inv_slot = slot_num
	return info
end

function index.slot_swap( item_in, slot_info )
	local reset, idata = { 0, 0 }, {
		pen.t.get( index.D.item_list, item_in, nil, nil, {}),
		pen.t.get( index.D.item_list, slot_info.id, nil, nil, {})}
	local parent1, parent2 = EntityGetParent( item_in ), slot_info.inv_id
	
	pen.t.loop({ parent1, parent2 }, function( i, p )
		if( not( pen.vld( p, true ))) then return end
		local p_info = index.D.invs[p] or {}
		if( not( pen.vld( p_info.update ))) then return end
		if( p_info.update( pen.t.get( index.D.item_list, p, nil, nil, p_info ), idata[( i + 1 )%2 + 1 ], idata[ i%2 + 1 ])) then
			table.insert( reset, pen.get_item_owner( p, true ))
		end
	end)
	if( parent1 ~= parent2 ) then
		reset[1] = pen.get_item_owner( item_in )
		EntityRemoveFromParent( item_in )
		EntityAddChild( parent2, item_in )
		if( pen.vld( slot_info.id, true )) then
			reset[2] = pen.get_item_owner( slot_info.id )
			EntityRemoveFromParent( slot_info.id )
			EntityAddChild( parent1, slot_info.id )
		end
	end
	
	local item_comp1 = EntityGetFirstComponentIncludingDisabled( item_in, "ItemComponent" )
	local slot1 = { ComponentGetValue2( item_comp1, "inventory_slot" )}
	local slot2 = slot_info.inv_slot
	ComponentSetValue2( item_comp1, "inventory_slot", slot2[1] - 1, slot2[2] < 0 and slot2[2] or slot2[2] - 1 )
	if( slot_info.id > 0 ) then
		local item_comp2 = EntityGetFirstComponentIncludingDisabled( slot_info.id, "ItemComponent" )
		ComponentSetValue2( item_comp2, "inventory_slot", unpack( slot1 ))
	end
	
	pen.t.loop( idata, function( i, d )
		if( not( pen.vld( d.id, true ))) then return end
		index.cat_callback( d, "on_inv_swap", { slot_info })
	end)
	for i,deadman in pairs( reset ) do
		if( pen.vld( deadman, true )) then pen.reset_active_item( deadman ) end
	end
end

function index.check_item_name( name )
	return pen.vld( name ) and ( string.find( name, "%$" ) ~= nil or string.find( name, "%w_%w" ) == nil )
end

function index.get_entity_name( entity_id, item_comp, abil_comp )
	local name = pen.vld( item_comp, true ) and ComponentGetValue2( item_comp, "item_name" ) or ""

	local info_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "UIInfoComponent" )
	if( pen.vld( info_comp, true )) then
		local temp = ComponentGetValue2( info_comp, "name" )
		name = index.check_item_name( temp ) and temp or name
	elseif( pen.vld( abil_comp, true )) then
		local temp = ComponentGetValue2( abil_comp, "ui_name" )
		name = index.check_item_name( temp ) and temp or name
	end
	if( not( index.check_item_name( name ))) then
		local temp = EntityGetName( entity_id )
		name = index.check_item_name( temp ) and temp or name
	end

	return index.check_item_name( name ) and string.gsub( GameTextGetTranslatedOrNot( name ), "(%s*)%$0(%s*)", "" ) or "", name
end

function index.get_potion_info( entity_id, name, volume, max_volume, matters )
	local cnt = 1
	local info = pen.t.loop_concat( matters, function( i, mtr )
		if( cnt > 3 ) then return end
		if( i ~= 1 and mtr[2] <= 5 ) then return end
		cnt = cnt + 1
		return { i == 1 and "" or " + ", pen.capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( mtr[1]))), nil }
	end) or ""
	
	local v = nil
	if(( max_volume or 0 ) > 0 ) then
		v = GameTextGet( "$item_potion_fullness", tostring( math.floor( 100*volume/max_volume + 0.5 ))) end
	if( string.sub( name, 1, 1 ) == "$" ) then
		name = pen.capitalizer( GameTextGet( name, ( info == "" and GameTextGetTranslatedOrNot( "$item_potion_empty" ) or info )))
	else name = string.gsub( GameTextGetTranslatedOrNot( name ), " %(%)", "" ) end
	return table.concat({ info, ( info == "" and info or " " ), name }), v
end

function index.get_item_data( item_id, inv_info, item_list )
	local info = { id = item_id }
	if( pen.vld( inv_info )) then
		info.inv_id = inv_info.id
		info.inv_kind = inv_info.kind
	end
	
	local item_comp = EntityGetFirstComponentIncludingDisabled( item_id, "ItemComponent" )
	if( not( pen.vld( item_comp, true ))) then return {} end
	
	local abil_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" )
	if( pen.vld( abil_comp, true  )) then
		info.AbilityC = abil_comp
		-- info.charges = {
		-- 	ComponentGetValue2( abil_comp, "shooting_reduces_amount_in_inventory" ),
		-- 	ComponentGetValue2( abil_comp, "max_amount_in_inventory" ),
		-- 	ComponentGetValue2( abil_comp, "amount_in_inventory" ),
		-- }
		info.pic = ComponentGetValue2( abil_comp, "sprite_file" )
		info.is_throwing = ComponentGetValue2( abil_comp, "throw_as_item" )
		info.uses_rmb = EntityHasTag( item_id, "index_has_rbm" ) or info.is_throwing
		if( info.is_throwing ) then
			pen.t.loop( EntityGetComponentIncludingDisabled( item_id, "LuaComponent" ), function( i, comp )
				local path = ComponentGetValue2( comp, "script_kick" )
				if( not( pen.vld( path ))) then return end
				info.is_kicking = true
				return true
			end)
		end
	end
	
	info.ItemC = item_comp
	local inv_name = pen.magic_storage( item_id, "preferred_inventory", "value_string" )
	info.inv_cat = index.INVS[ inv_name or ComponentGetValue2( item_comp, "preferred_inventory" )] or 0
	
	local ui_pic = ComponentGetValue2( item_comp, "ui_sprite" )
	if( pen.vld( ui_pic )) then info.pic = ui_pic end
	
	info.desc = index.full_stopper( GameTextGetTranslatedOrNot( ComponentGetValue2( item_comp, "ui_description" )))
	-- info.is_stackable = ComponentGetValue2( item_comp, "is_stackable" )
	info.is_consumable = ComponentGetValue2( item_comp, "is_consumable" )
	
	info.is_frozen = ComponentGetValue2( item_comp, "is_frozen" )
	info.is_permanent = ComponentGetValue2( item_comp, "permanently_attached" )
	info.is_locked = info.is_permanent
	if( EntityHasTag( item_id, "index_unlocked" )) then
		info.is_locked = false
	elseif( EntityHasTag( item_id, "index_locked" )) then
		info.is_locked = true
	end

	info.charges = pen.magic_storage( item_id, "current_charges", "value_int" )
	info.charges = info.charges	or ComponentGetValue2( item_comp, "uses_remaining" )

	index.M.cbk_tbl = index.M.cbk_tbl or {} --cache this
	index.M.cbk_tbl[ item_id ] = index.M.cbk_tbl[ item_id ] or {}

	local callback_list = {
		-- "on_check", "on_info_name",
		
		"on_data", "on_processed",
		"on_processed_forced", "ctrl_script",

		"on_inv_check", "on_inv_swap",
		"on_inventory", "on_tooltip", "on_slot",

		"on_equip", "on_action",
		"on_pickup", "on_drop",

		"on_gui_pause", "on_gui_world" }
	for k,callback in ipairs( callback_list ) do
		info[ callback ] = pen.cache({ "callback_tbl", item_id, callback }, function()
			local func_path = pen.magic_storage( item_id, callback, "value_string" )
			if( pen.vld( func_path )) then return dofile_once( func_path ) end
		end)
	end
	
	pen.t.loop( index.D.item_cats, function( k, cat )
		if( not( cat.on_check( item_id ))) then return end
		info.cat = k
		info.is_wand = cat.is_wand or false
		info.is_potion = cat.is_potion or false
		info.is_spell = cat.is_spell or false
		info.is_quickest = cat.is_quickest or false
		info.is_hidden = cat.is_hidden or false
		info.do_full_man = cat.do_full_man or false
		return true
	end)
	
	info.name, info.raw_name = index.get_entity_name( item_id, item_comp, abil_comp )
	if( not( pen.vld( info.cat ))) then
		return {}
	elseif( not( pen.vld( info.name ))) then
		info.name = index.D.item_cats[ info.cat ].name
	end
	info.name = pen.capitalizer( info.name )
	
	-- dofile_once( "data/scripts/gun/gun.lua" )
	-- dofile_once( "data/scripts/gun/gun_enums.lua" )
	-- dofile_once( "data/scripts/gun/gun_actions.lua" )
	info = index.cat_callback( info, "on_data", { item_list or {}}, { info })
	info.in_hand = pen.get_item_owner(( info.in_wand or false ) and info.in_wand or item_id )
	return info
end

function index.get_items( hooman )
	local item_tbl = {}
	pen.t.loop({ "invs", "invs_i" }, function( k, inv )
		for i,inv_info in pairs( index.D[ inv ]) do
			if( k == 2 ) then index.D.invs[i] = inv_info end
			pen.child_play( inv_info.id, function( parent, child, e )
				local new_info = index.get_item_data( child, inv_info, item_tbl )
				if( not( pen.vld( new_info.id, true ))) then return end

				if( not( EntityHasTag( new_info.id, "index_processed" ))) then
					index.cat_callback( new_info, "on_processed", {})
					ComponentSetValue2( new_info.ItemC, "inventory_slot", -5, -5 )
					EntityAddTag( new_info.id, "index_processed" )
				end

				index.cat_callback( new_info, "on_processed_forced", {})
				index.register_item_pic( new_info )
				table.insert( item_tbl, new_info )
			end, inv_info.sort )
		end
	end)
	index.D.item_list = item_tbl
end

function index.vanilla_pick_up( hooman, item_id )
	local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
	if( not( pen.vld( pick_comp, true ))) then return end
	EntitySetComponentIsEnabled( hooman, pick_comp, true )
	GamePickUpInventoryItem( hooman, item_id, true )
	EntitySetComponentIsEnabled( hooman, pick_comp, true )
end

function index.pick_up_item( hooman, info, is_audible, is_silent )
	local callback = index.cat_callback( info, "on_pickup" )
	if( pen.vld( callback )) then gonna_pause = callback( info, false ) end
	local item_id, gonna_pause, is_shopping = info.id, 0, pen.vld( info.cost )
	
	if( gonna_pause == 0 ) then
		if( not( is_silent )) then
			info.name = info.name or GameTextGetTranslatedOrNot( ComponentGetValue2( info.ItemC, "item_name" ))
			GamePrint( GameTextGet( "$log_pickedup", info.name ))
			if( is_audible or is_shopping ) then
				index.play_sound({
					"data/audio/Desktop/event_cues.bank",
					is_shopping and "event_cues/shop_item/create" or "event_cues/pick_item_generic/create"
				})
			end
		end

		local _,slot = ComponentGetValue2( info.ItemC, "inventory_slot" )
		EntityAddChild( index.D.invs_p[ slot < 0 and "q" or "f" ], item_id )

		if( is_shopping ) then
			if( not( index.D.Wallet.money_always )) then
				index.D.Wallet.money = index.D.Wallet.money - info.cost
				ComponentSetValue2( index.D.Wallet.comp, "money", index.D.Wallet.money )
			end
			
			pen.t.loop( EntityGetAllComponents( item_id ), function( i, comp )
				if( ComponentHasTag( comp, "shop_cost" )) then EntityRemoveComponent( item_id, comp ) end
			end)
		end

		info.xy = { EntityGetTransform( item_id )}
		pen.lua_callback( item_id, { "script_item_picked_up", "item_pickup" }, { item_id, hooman, info.name })
		if( callback ~= nil ) then callback( info, true ) end
		if( EntityGetIsAlive( item_id )) then
			ComponentSetValue2( info.ItemC, "has_been_picked_by_player", true )
			ComponentSetValue2( info.ItemC, "mFramePickedUp", index.D.frame_num )

			index.inventory_man( info, false )
		end
	elseif( gonna_pause == 1 ) then
		--engage the pause
	end
end

function index.drop_item( h_x, h_y, info, throw_force, do_action )
	local item_id = info.id
	local has_no_cancer = not( info.is_kicking or false )
	if( not( has_no_cancer )) then
		local owner_id = pen.get_item_owner( item_id, true )
		local ctrl_comp = EntityGetFirstComponentIncludingDisabled( owner_id, "ControlsComponent" )
		if( pen.vld( ctrl_comp, true )) then
			local inv_comp = pen.reset_active_item( owner_id )
			ComponentSetValue2( inv_comp, "mSavedActiveItemIndex", pen.get_item_num( info.inv_id, item_id ))
			ComponentSetValue2( ctrl_comp, "mButtonFrameThrow", index.D.frame_num + 1 )
		else has_no_cancer = true end
	end

	if( has_no_cancer ) then EntityRemoveFromParent( item_id ) end
	local p_d_x, p_d_y = index.D.pointer_world[1] - h_x, index.D.pointer_world[2] - h_y
	local p_delta = math.min( math.sqrt( p_d_x^2 + p_d_y^2 ), 50 )/10
	local angle = math.atan2( p_d_y, p_d_x )

	local from_x, from_y = 0, 0
	if( pen.vld( info.in_hand, true )) then
		from_x, from_y = EntityGetTransform( item_id )
		pen.reset_active_item( info.in_hand )
	else
		index.D.throw_pos_rad = index.D.throw_pos_rad + index.D.throw_pos_size
		from_x, from_y = h_x + math.cos( angle )*index.D.throw_pos_rad, h_y + math.sin( angle )*index.D.throw_pos_rad
		local is_hit, hit_x, hit_y = RaytraceSurfaces( h_x, h_y, from_x, from_y )
		if( is_hit ) then index.D.throw_pos_rad = math.sqrt(( h_x - hit_x )^2 + ( h_y - hit_y )^2 ) end
		index.D.throw_pos_rad = index.D.throw_pos_rad - index.D.throw_pos_size
		from_x, from_y = h_x + math.cos( angle )*index.D.throw_pos_rad, h_y + math.sin( angle )*index.D.throw_pos_rad
	end

	local extra_v_force = 0
	local vel_comp = EntityGetFirstComponentIncludingDisabled( item_id, "VelocityComponent" )
	if( pen.vld( vel_comp, true )) then extra_v_force = ComponentGetValue2( vel_comp, "gravity_y" )/4 end

	local force = p_delta*throw_force
	local force_x, force_y = math.cos( angle )*force, math.sin( angle )*force
	force_y = force_y - math.max( 0.25*math.abs( force_y ), ( extra_v_force + throw_force )/2 )
	local to_x, to_y = from_x + force_x, from_y + force_y

	EntitySetTransform( item_id, from_x, from_y, nil, 1, 1 )
	-- EntityApplyTransform( item_id, from_x, from_y )
	if( has_no_cancer ) then index.inventory_man( info, false ) end
	pen.t.loop( EntityGetComponentIncludingDisabled( item_id, "SpriteComponent", "enabled_in_world" ), function( i, comp )
		ComponentSetValue2( comp, "z_index", -1 + ( i - 1 )*0.0001 )
		EntityRefreshSprite( item_id, comp )
	end)
	
	ComponentSetValue2( info.ItemC, "inventory_slot", -5, -5 )
	ComponentSetValue2( info.ItemC, "play_hover_animation", false )
	ComponentSetValue2( info.ItemC, "has_been_picked_by_player", true )
	ComponentSetValue2( info.ItemC, "next_frame_pickable", index.D.frame_num + 30 )

	if( p_delta > 2 ) then
		local shape_comp = EntityGetFirstComponentIncludingDisabled( item_id, "PhysicsImageShapeComponent" )
		if( pen.vld( shape_comp, true )) then
			local phys_mult = 1.75
			local throw_comp = EntityGetFirstComponentIncludingDisabled( item_id, "PhysicsThrowableComponent" )
			if( pen.vld( throw_comp, true )) then phys_mult = phys_mult*ComponentGetValue2( throw_comp, "throw_force_coeff" ) end
			
			local mass = pen.get_mass( item_id )
			PhysicsApplyTorque( item_id, phys_mult*5*mass )
			PhysicsApplyForce( item_id, phys_mult*force_x*mass, phys_mult*force_y*mass )
		elseif( pen.vld( vel_comp, true )) then ComponentSetValue2( vel_comp, "mVelocity", force_x, force_y ) end
	end

	if( not( has_no_cancer and do_action )) then return end
	pen.lua_callback( item_id, { "script_throw_item", "throw_item" }, { from_x, from_y, to_x, to_y })
end

------------------------------------------------------		[GUI]		------------------------------------------------------

function index.slot_z( dragged_id, pic_z )
	return index.D.dragger.item_id == dragged_id and pic_z - 2 or pic_z
end

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
		index.D.dragger.inv_cat = info.inv_cat
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

	local temp, steps = 0, { 10, 4, 2, 1 }
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

function index.new_vanilla_bar( pic_x, pic_y, pic_z, dims, color, shake_frame, alpha, only_slider )
	local eid = pic_x..";"..pic_y..";"..pic_z

	if( shake_frame ~= nil ) then
		if( shake_frame < 0 ) then
			pic_x = pic_x - 20*math.sin( shake_frame*math.pi/6.666 )/shake_frame
		else pic_x = pic_x + 2.5*math.sin( shake_frame*math.pi/5 ) end
		pen.new_pixel( pic_x - ( dims[1] + 1 ), pic_y, pic_z + 0.004, pen.PALETTE.VNL.WARNING, dims[1] + 2, dims[2] + 2 )
	end
	
	pen.new_pixel( pic_x - dims[1], pic_y + 1, pic_z, color, pen.estimate( eid, dims[3], "wgt" ), dims[2], alpha )
	
	if( only_slider ) then return end

	pen.new_pixel( pic_x, pic_y, pic_z + 0.01, pen.PALETTE.VNL.BROWN, 1, dims[2] + 2, 0.75 )
	pen.new_pixel( pic_x - dims[1], pic_y, pic_z + 0.01, pen.PALETTE.VNL.BROWN, dims[1], 1, 0.75 )
	pen.new_pixel( pic_x - ( dims[1] + 1 ), pic_y, pic_z + 0.01, pen.PALETTE.VNL.BROWN, 1, dims[2] + 2, 0.75 )
	pen.new_pixel( pic_x - dims[1], pic_y + dims[2] + 1, pic_z + 0.01, pen.PALETTE.VNL.BROWN, dims[1], 1, 0.75 )

	pen.new_image( pic_x - dims[1], pic_y + 1, pic_z + 0.015,
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

		local total_hp = math.min( math.max(( data.is_boss or false ) and 40 or max_hp, 0 ), 40 )
		length = data.length or ( data.length_mult or 1 )*math.max( math.floor( 157.8 - 307.1/( 1 + ( total_hp/0.38 )^( 0.232 )) + 0.5 ), 45 )
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
					pic_z + 0.005, data.color_bg or pen.PALETTE.VNL.HP_LOW, length + 2, height + 2 )
			else pic = data.color_dmg or pen.PALETTE.VNL.DAMAGE end
            red_shift = red_shift*perc
        end

		local delay = 30 --data.damage_fading
        if( data.dmg_data.hp_frame <= delay ) then
            local last_hp = math.min( math.max( data.dmg_data.hp_last, 0 ), max_hp )
            pen.new_pixel( pic_x - length, pic_y + 1,
				pic_z + 0.001, pen.PALETTE.VNL.DAMAGE, length*last_hp/max_hp, height, ( delay - data.dmg_data.hp_frame )/delay )
        end
        
		hp = math.min( math.floor( hp*25 + 0.5 ), 9e99 )
        max_hp = math.min( math.floor( max_hp*25 + 0.5 ), 9e99 )
        index.new_vanilla_bar( pic_x, pic_y, pic_z, { length, height, length*hp/max_hp }, pic, nil, nil, data.only_slider )
	end)
    return length, height, max_hp, hp, red_shift
end

function index.new_pickup_info( screen_h, screen_w, pickup_info, xys )
	pickup_info.color = pickup_info.color or {}

	if( pen.vld( pickup_info.desc )) then
		if( type( pickup_info.desc ) ~= "table" ) then
			pickup_info.desc = { pickup_info.desc, false } end
		if( pen.vld( pickup_info.desc[1] )) then
			local clr = ( pickup_info.desc[2] == true ) and "RED" or "YELLOW"
			local pic_x, pic_y = unpack( xys.pickup_info or { screen_w/2, screen_h - 44 })
			local is_elaborate = type( pickup_info.desc[2]) == "string" and pen.vld( pickup_info.desc[2])
			pen.new_text( pic_x, pic_y, pen.LAYERS.WORLD_UI, pickup_info.desc[1], {
				is_centered_x = true, has_shadow = true, color = pickup_info.color[1] or pen.PALETTE.VNL[ clr ]})
			if( is_elaborate ) then
				pen.new_text( pic_x, pic_y + 12, pen.LAYERS.WORLD_UI, pickup_info.desc[2], {
					is_centered_x = true, has_shadow = true, color = pickup_info.color[2] or pen.PALETTE.VNL.LGREY})
			end
		end
	end

	if( index.D.is_opened ) then return end
	if( not( pen.vld( pickup_info.id, true ))) then return end
	if( not( index.D.in_world_pickups or EntityHasTag( pickup_info.id, "index_txt" ))) then return end
	if( pen.vld( pickup_info.txt )) then
		local x, y = EntityGetTransform( pickup_info.id )
		local pic_x, pic_y = pen.world2gui( x, y )
		pen.new_text( pic_x, pic_y + 3, pen.LAYERS.WORLD_FRONT, pickup_info.txt, {
			is_centered_x = true, has_shadow = true, color = pen.PALETTE.VNL.LGREY })
	end
end

function index.tipping( pic_x, pic_y, pic_z, s_x, s_y, text, data, func )
	data = data or {}
	local clicked, r_clicked = false, false
	pic_z = pen.get_hybrid_table( pic_z or { pen.LAYERS.TIPS, pen.LAYERS.MAIN_DEEP })
	clicked, r_clicked, data.is_active = pen.new_interface( pic_x, pic_y, s_x, s_y, pic_z[1], data )
	if( pen.vld( pic_z[2]) and data.is_active ) then pen.new_pixel( pic_x, pic_y, pic_z[2], pen.PALETTE.VNL.RUNIC, s_x, s_y, 0.75 ) end
	( func or index.D.tip_func )( text, data, func )
	return data.is_active, clicked, r_clicked
end

function index.new_vanilla_worldtip( info, tid, pic_x, pic_y, no_space, cant_buy, tip_func )
	if( cant_buy and index.D.secret_shopper ) then return end
	
	if( index.D.in_world_tips ) then
		local x, y = EntityGetTransform( info.id )
		pic_x, pic_y = pen.world2gui( x, y )
		pic_x, pic_y = pic_x + 15, pic_y + 15
	else pic_x, pic_y = unpack( index.D.xys.hp ); pic_x = pic_x - 44 end
	
	tip_func( info, tid, pic_x, pic_y, pen.LAYERS.TIPS )
end

--advanced mode hides the wand pic and arranges the stats in two columns
function index.new_vanilla_wtt( info, tid, pic_x, pic_y, pic_z, is_simple )
	if( not( pen.vld( info.pic ))) then return end
	if( not( pen.vld( info.name ))) then return end
	if( not( pen.vld( info.wand_info ))) then return end
	
	local spells = { p = {}, n = {}}
	pen.t.loop( EntityGetAllChildren( info.id ), function( i, spell )
		local kid_info = pen.t.get( index.D.item_list, spell, nil, nil, {})
		if( not( pen.vld( kid_info.id, true ))) then kid_info = index.get_item_data( spell, info, index.D.item_list ) end
		if( pen.vld( kid_info.id, true )) then table.insert( spells[ kid_info.is_permanent and "p" or "n" ], kid_info ) end
	end)
	for field,tbl in pairs( spells ) do
		table.sort( spells[ field ], function( a, b )
			local inv_slot = { 0, 0 }
			pen.t.loop({ a.ItemC, b.ItemC }, function( i, comp )
				if( pen.vld( comp, true )) then inv_slot[i] = ComponentGetValue2( comp, "inventory_slot" ) end
			end)
			return inv_slot[1] < inv_slot[2]
		end)
	end

	local title_w, title_h = pen.get_text_dims( info.name, true )
	title_w = title_w + ( info.wand_info.shuffle_deck_when_empty and 12 or 0 ) + 2
	
	local desc_w, desc_h = 0, 0
	local will_desc = pen.vld( info.desc ) and index.D.tip_action
	if( will_desc ) then
		desc_w, desc_h = unpack( pen.get_tip_dims( info.desc or "", math.max( title_w, 100 ), -1, -2 ))
		desc_h = desc_h + 5
	end

	local pic_data = index.register_item_pic( info )
	local pic_scale = index.D.no_wand_scaling and 1 or 2
	local pic_w, pic_h = pic_scale*pic_data.dims[1], pic_scale*pic_data.dims[2]
	
	local stats_w, stats_h = 60 + pic_h, 0
	pen.t.loop( index.WAND_STATS, function( i, stat )
		if( pen.get_hybrid_function( stat.is_hidden, info )) then return end
		if( pen.get_hybrid_function( stat.is_advanced, info ) and not( index.D.tip_action )) then return end
		stats_h = stats_h + (( i ~= #index.WAND_STATS and stat.spacer ) and 11 or 8 )
	end)
	stats_h = math.max( stats_h + 2, pic_w + 4 )

	local got_spells = ( pen.vld( spells.p ) or pen.vld( spells.n )) and not( index.D.tip_action or is_simple )
	local size_x, size_y = 9*math.ceil( math.max( desc_w + 2, title_w, stats_w )/9 ), title_h + desc_h + stats_h + 5
	if( got_spells ) then size_y = size_y + 10*math.ceil( 9*#spells.p/size_x ) + 10*math.ceil( 9*#spells.n/size_x ) + 5 end
	if( pen.vld( spells.p )) then size_y = size_y + ( pen.vld( spells.n ) and 1 or 0 ) end

	local showed_stt = false
	index.D.tip_func( "", {
		tid = tid, info = info,
		is_left = true, is_active = true, allow_hover = true,
		pic_z = pic_z, pos = { pic_x, pic_y }, dims = { size_x, size_y },
	}, function( t, d )
		local info = d.info
		local size_x, size_y = unpack( d.dims )
		local pic_x, pic_y, pic_z = unpack( d.pos )
		
		local inter_alpha = pen.animate( 1, d.t, { ease_out = "exp", frames = d.frames })
		pen.new_shadowed_text( pic_x + d.edging, pic_y + d.edging - 2, pic_z, info.name, {
			dims = { size_x, size_y }, fully_featured = true, has_shadow = true, color = pen.PALETTE.VNL.YELLOW, alpha = inter_alpha })
		if( will_desc ) then
			pen.new_shadowed_text( pic_x + d.edging + 2, pic_y + d.edging + title_h, pic_z, info.desc, {
				dims = { desc_w, size_y }, fully_featured = true, has_shadow = true, alpha = inter_alpha, line_offset = -2 })
		end
		pen.new_image( pic_x + 1, pic_y + d.edging + title_h + desc_h, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = size_x - 2, s_y = 1, alpha = inter_alpha })
		
		local inter_size = 15*( 1 - pen.animate( 1, d.t, { ease_out = "wav1.5", frames = d.frames }))
		local pos_x, pos_y = pic_x + 0.5*inter_size, pic_y + 0.5*inter_size
		local scale_x, scale_y = size_x - inter_size, size_y - inter_size
		
		local gui, uid = pen.gui_builder()
		GuiOptionsAddForNextWidget( gui, 2 ) --NonInteractive
		GuiZSetForNextWidget( gui, pic_z + 0.01 )
		GuiImageNinePiece( gui, uid, pos_x, pos_y, scale_x, scale_y, 1.15*math.max( 1 - inter_alpha/6, 0.1 ))
		
		if( info.is_frozen ) then
			local tip = table.concat({ GameTextGet( "$inventory_info_frozen"),
				"\n{>color>{{-}|VNL|GREY|{-}", GameTextGet( "$inventory_info_frozen_description"), "}<color<}" })
			local is_hovered = index.tipping( pos_x - 4, pos_y - 4,
				pic_z, 7, 7, tip, { tid = "wtt", is_left = true, fully_featured = true, pic_z = pic_z - 1 })
			pen.new_image( pos_x - 4, pos_y - 4, pic_z - 0.1, "mods/index_core/files/pics/frozen_marker.png",
				{ color = pen.PALETTE.VNL[ is_hovered and "YELLOW" or "RED" ], alpha = inter_alpha, has_shadow = true })
		end
		if( info.wand_info.shuffle_deck_when_empty ) then
			local tip = table.concat({ GameTextGet( "$inventory_shuffle"),
				"\n{>color>{{-}|VNL|GREY|{-}", GameTextGet( "$inventory_shuffle_tooltip"), "}<color<}" })
			local is_hovered = index.tipping( pos_x + scale_x - 8,
				pos_y + 1, pic_z, 7, 7, tip, { tid = "wtt", is_left = true, fully_featured = true, pic_z = pic_z - 1 })
			pen.new_image( pos_x + scale_x - 8, pos_y + 1, pic_z, "data/ui_gfx/inventory/icon_gun_shuffle.png",
				{ color = pen.PALETTE.VNL[ is_hovered and "YELLOW" or "RED" ], alpha = inter_alpha, has_shadow = true })
		end

		local t_x = pic_x + d.edging + 2
		local t_y = pic_y + d.edging + title_h + desc_h + 5

		local real_stats_w = 0
		pen.t.loop( index.WAND_STATS, function( i, stat )
			if( pen.get_hybrid_function( stat.is_hidden, info )) then return end
			if( pen.get_hybrid_function( stat.is_advanced, info ) and not( index.D.tip_action )) then return end

			local value = stat.value( info, info.wand_info )
			local txt, hl_type = stat.txt( value, info, info.wand_info )
			local alpha = (( hl_type == true ) and 0.5 or 1 )*inter_alpha
			pen.new_image( t_x + ( stat.off_x or 0 ), t_y + ( stat.off_y or 0 ), pic_z, stat.pic, { has_shadow = true, alpha = alpha })

			local clr = "GREY"
			if( index.D.active_item ~= info.id and pen.vld( index.D.active_info.wand_info )) then
				local is_better = nil
				local held_value = stat.value( index.D.active_info, index.D.active_info.wand_info )
				local _,held_hl_type = stat.txt( held_value, index.D.active_info, index.D.active_info.wand_info )
				if( held_hl_type == 1 or hl_type == 1 ) then
					is_better = true
				elseif( held_value ~= value ) then
					is_better = held_value > value
				end

				if( is_better ~= nil ) then
					if( stat.bigger_better ) then
						is_better = not( is_better ) end
					clr, alpha = is_better and "GREEN" or "RED", inter_alpha
				end
			end

			local tip = pen.magic_translate( pen.get_hybrid_function( stat.name or "", info ))
			if( pen.vld( tip )) then
				if( pen.vld( stat.desc )) then
					tip = table.concat({ tip, " = ", value, "\n{>color>{{-}|VNL|GREY|{-}",
						pen.magic_translate( pen.get_hybrid_function( stat.desc or "", info )), "}<color<}" }) end
				local is_hovered = index.tipping(
					t_x, t_y - 1, pic_z, 40, 7, tip, { tid = "wtt", is_left = true, fully_featured = true, pic_z = pic_z - 1 })
				if( is_hovered ) then clr, alpha = "YELLOW", 1 end
			end

			local dims = ( stat.func or pen.new_shadowed_text )(
				t_x + 9, t_y - 1, pic_z, txt, { color = pen.PALETTE.VNL[ clr ], alpha = alpha })
			real_stats_w = math.max( real_stats_w, dims[1])
			
			t_y = t_y + (( i ~= #index.WAND_STATS and stat.spacer ) and 11 or 8 )
		end)
		
		real_stats_w = real_stats_w + 13
		off_x, off_y = pen.rotate_offset( -pic_w/2, -pic_h/2, -math.rad( 90 ))
		local icon_x, icon_y = pic_x + size_x - ( size_x - real_stats_w )/2 + off_x, t_y + 2 - ( stats_h )/2 + off_y
		pen.new_image( icon_x, icon_y, pic_z + 0.001, info.pic, {
			s_x = pic_scale, s_y = pic_scale, alpha = inter_alpha, angle = -math.rad( 90 )})
		
		if( pen.vld( info.desc ) and not( index.D.tip_action )) then
			pen.new_shadowed_text( pic_x, pic_y + size_y + 2, pic_z,
				"hold "..mnee.get_binding_keys( "index_core", "tip_action" ).."...", { color = pen.PALETTE.VNL.GRET, alpha = 0.8*inter_alpha })
		end

		local clicked, r_clicked, is_hovered = pen.new_interface( pic_x - 2, pic_y - 2, size_x + 4, size_y + 4, pic_z + 0.1 )
		
		if( got_spells ) then
			t_x, t_y = t_x - 2, t_y + 8
			pen.new_image( t_x - 1, t_y - 4, pic_z,
				"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = size_x - 2, s_y = 1, alpha = inter_alpha })
			
			pen.t.loop({ spells.p, spells.n }, function( i, tbl )
				local cnt = 0
				if( i == 1 and pen.vld( tbl )) then
					local tip = table.concat({ GameTextGet( "$streamingevent_add_always_cast" ),
						"\n{>color>{{-}|VNL|GREY|{-}", "The following spells are permanently attached to the wand.", "}<color<}" })
					local is_hovered = index.tipping( t_x + 0.5, t_y + 0.5,
						pic_z, 7, 7, tip, { tid = "wtt", is_left = true, fully_featured = true, pic_z = pic_z - 1 })
					pen.new_image( t_x + 0.5, t_y + 0.5, pic_z, "data/ui_gfx/inventory/icon_gun_permanent_actions.png",
						{ color = is_hovered and pen.PALETTE.VNL.YELLOW or nil, alpha = inter_alpha, has_shadow = true })
					cnt = cnt + 1
				end

				for k,spell in ipairs( tbl ) do
					local tid = "stt"..spell.id
					pen.new_image( t_x + 9*cnt, t_y, pic_z, spell.pic, { s_x = 0.5, s_y = 0.5, alpha = inter_alpha })
					if( index.M.stt_safety == tid ) then pen.colourer( nil, pen.PALETTE.VNL.BRIGHT_SLOT )
					elseif( k%2 == ( i - 1 )) then pen.colourer( nil, pen.PALETTE.VNL.DARK_SLOT ) end
					
					local _,_,is_hovered = pen.new_image( t_x + 9*cnt - 1, t_y - 1, pic_z + 0.001,
						index.D.slot_pic.bg_alt, { s_x = 0.5, s_y = 0.5, alpha = inter_alpha, can_click = true })
					if(( index.M.stt_safety or tid ) == tid and not( is_hovered )) then index.M.stt_safety = nil
					elseif(( index.M.stt_safety or tid ) ~= tid ) then is_hovered = false end

					local is_pinned = pen.vld( pen.c.ttips[ tid ]) and pen.c.ttips[ tid ].inter_state[3]
					if( is_hovered or is_pinned ) then
						index.cat_callback( spell, "on_tooltip", { tid, t_x + 9*cnt + 9, t_y + 8, pic_z - 1, true })
						index.M.stt_safety, showed_stt = tid, true
					end
					
					cnt = cnt + 1
					if( 9*( cnt + 1 ) > size_x ) then t_y, cnt = t_y + 10, 0 end
				end
				if( pen.vld( tbl )) then t_y = t_y + 11 end
			end)
		end

		return clicked, r_clicked, is_hovered
	end)

	if( not( showed_stt )) then index.M.stt_safety = nil end
end

--add new marker for spells that are new (for wand tip too)
function index.new_vanilla_stt( info, tid, pic_x, pic_y, pic_z, is_simple )
	if( not( pen.vld( info.name ))) then return end
	if( not( pen.vld( info.desc ))) then return end
	if( not( pen.vld( info.spell_info ))) then return end
	
	local title_w, title_h = pen.get_text_dims( info.tip_name, true )
	title_w = title_w + ( info.charges >= 0 and ( 6*string.len( info.charges ) + 12 ) or 0 ) + 11
	local desc_w, desc_h = unpack( pen.get_tip_dims( info.desc, { 121, math.max( title_w, 121 )}, -1, -2 ))
	desc_h = desc_h + 5

	local stats_w, stats_h = 120, 0
	for k,c in ipairs( index.SPELL_STATS ) do
		local this_h = 0
		pen.t.loop( c, function( i, stat )
			if( pen.get_hybrid_function( stat.is_hidden, info )) then return end
			if( pen.get_hybrid_function( stat.is_advanced, info ) and not( index.D.tip_action )) then return end
			this_h = this_h + (( i ~= #c and stat.spacer ) and 11 or 8 )
		end)
		stats_h = math.max( stats_h, this_h )
	end
	
	local size_x, size_y = math.max( title_w, desc_w + 2, stats_w ), title_h + desc_h + stats_h + 7
	
	index.D.tip_func( "", {
		tid = tid, info = info,
		is_left = true, is_active = true, allow_hover = true,
		pic_z = pic_z, pos = { pic_x, pic_y }, dims = { size_x, size_y },
	}, function( t, d )
		local info = d.info
		local size_x, size_y = unpack( d.dims )
		local pic_x, pic_y, pic_z = unpack( d.pos )
		local inter_alpha = pen.animate( 1, d.t, { ease_out = "exp", frames = d.frames })

		local tip = table.concat({ GameTextGet( "$inventory_actiontype" ),
			": {>color>{{-}|VNL|GREY|{-}", GameTextGet( index.FRAMER[ info.spell_info.type ][3]), "}<color<}" })
		local is_hovered = index.tipping( pic_x + d.edging - 0.5, pic_y + d.edging - 0.5,
			pic_z, 7, 7, tip, { tid = "stt", is_left = true, fully_featured = true, pic_z = pic_z - 1 })
		pen.new_image( pic_x + d.edging - 0.5, pic_y + d.edging - 0.5, pic_z - 0.001, "data/ui_gfx/inventory/icon_action_type.png", {
			color = is_hovered and pen.PALETTE.VNL.YELLOW or index.FRAMER[ info.spell_info.type ][2], alpha = inter_alpha, has_shadow = true })
		pen.new_shadowed_text( pic_x + d.edging + 9, pic_y + d.edging - 2,
			pic_z, info.tip_name, { color = pen.PALETTE.VNL.YELLOW, alpha = inter_alpha })
		pen.new_shadowed_text( pic_x + d.edging + 2, pic_y + d.edging + title_h, pic_z, info.desc, {
			dims = { desc_w + 2, size_y }, fully_featured = true, alpha = inter_alpha, line_offset = -2 })
		
		if( info.charges >= 0 ) then
			local tip = table.concat({ GameTextGet( "$inventory_usesremaining" ),
				" = {>color>{{-}|VNL|GREY|{-}", info.charges, "/", info.spell_info.max_uses, "}<color<}" })
			local is_hovered = index.tipping( pic_x + size_x - ( 20 + d.edging ) + 0.5, pic_y + d.edging - 0.5,
				pic_z, 30, 7, tip, { tid = "stt", is_left = true, fully_featured = true, pic_z = pic_z - 1 })
			pen.new_image( pic_x + size_x - ( 7 + d.edging ) + 0.5, pic_y + d.edging - 0.5,
				pic_z, "data/ui_gfx/inventory/icon_action_max_uses.png", { alpha = inter_alpha })
			pen.new_shadowed_text( pic_x + size_x - ( 7 + d.edging ), pic_y + d.edging - 2, pic_z, pen.get_tiny_num( info.charges ),
				{ color = pen.PALETTE.VNL[ is_hovered and "YELLOW" or "GREY" ], alpha = inter_alpha, is_right_x = true })
		end

		local inter_size = 15*( 1 - pen.animate( 1, d.t, { ease_out = "wav1.5", frames = d.frames }))
		local pos_x, pos_y = pic_x + 0.5*inter_size, pic_y + 0.5*inter_size
		local scale_x, scale_y = size_x - inter_size, size_y - inter_size
		
		local gui, uid = pen.gui_builder()
		GuiOptionsAddForNextWidget( gui, 2 ) --NonInteractive
		GuiZSetForNextWidget( gui, pic_z + 0.01 )
		GuiImageNinePiece( gui, uid, pos_x, pos_y, scale_x, scale_y, 1.15*math.max( 1 - inter_alpha/6, 0.1 ))

		if( not( is_simple or index.D.tip_action )) then
			pen.new_shadowed_text( pic_x, pic_y + size_y + 2, pic_z,
				"hold "..mnee.get_binding_keys( "index_core", "tip_action" ).."...", { color = pen.PALETTE.VNL.GRET, alpha = 0.8*inter_alpha })
		end

		pen.new_image( pic_x + 1, pic_y + d.edging + title_h + desc_h, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = size_x - 2, s_y = 1, alpha = inter_alpha })
		pen.new_image( pic_x + size_x/2 - 0.5, pic_y + d.edging + title_h + desc_h + 3, pic_z,
			"mods/index_core/files/pics/vanilla_tooltip_1.xml", { s_x = 1, s_y = stats_h + 6, alpha = inter_alpha })

		local t_x = pic_x + d.edging + 2
		local t_y = pic_y + d.edging + title_h + desc_h + 5

		local c = info.spell_info.meta.state
		local c_proj = info.spell_info.meta.state_proj
		for k,clm in ipairs( index.SPELL_STATS ) do
			local is_right = k == 2
			pen.t.loop( clm, function( i, stat )
				if( pen.get_hybrid_function( stat.is_hidden, info )) then return end
				if( pen.get_hybrid_function( stat.is_advanced, info ) and not( index.D.tip_action )) then return end

				local value = stat.value( info, c, c_proj )
				local txt, hl_type = stat.txt( value, info, c, c_proj )
				local alpha = (( hl_type == true ) and 0.5 or 1 )*inter_alpha
				pen.new_image( t_x + ( stat.off_x or 0 ), t_y + ( stat.off_y or 0 ),
					pic_z, pen.get_hybrid_function( stat.pic, info ), { has_shadow = true, alpha = alpha })

				local clr = "GREY"
				local tip = pen.magic_translate( pen.get_hybrid_function( stat.name or "", info ))
				if( pen.vld( tip )) then
					if( pen.vld( stat.desc )) then
						tip = table.concat({ tip, " = ", value, "\n{>color>{{-}|VNL|GREY|{-}",
							pen.magic_translate( pen.get_hybrid_function( stat.desc or "", info )), "}<color<}" }) end
					local is_hovered = index.tipping( t_x - ( is_right and 41 or 0 ),
						t_y - 1, pic_z, 50, 7, tip, { tid = "stt", is_left = true, fully_featured = true, pic_z = pic_z - 1 })
					if( is_hovered ) then clr, alpha = "YELLOW", 1 end
				end
				
				( stat.func or pen.new_shadowed_text )( t_x + ( is_right and -1 or 9 ),
					t_y - 1, pic_z, txt, { is_right_x = is_right, color = pen.PALETTE.VNL[ clr ], alpha = alpha })

				t_y = t_y + (( i ~= #clm and stat.spacer ) and 11 or 8 )
			end)
			t_x, t_y = t_x + size_x - 15, pic_y + d.edging + title_h + desc_h + 5
		end

		if( pen.vld( info.spell_info.price, true )) then
			local price = pen.get_short_num( info.spell_info.price )
			pen.new_shadowed_text( pic_x + size_x + 2, pic_y + size_y + 2,
				pic_z, price.."$", { is_right_x = true, fully_featured = true, color = pen.PALETTE.VNL.YELLOW, alpha = inter_alpha })
		end
		
		return pen.new_interface( pic_x - 2, pic_y - 2, size_x + 4, size_y + 4, pic_z + 0.1 )
	end)
end

function index.new_vanilla_ptt( info, tid, pic_x, pic_y, pic_z, is_simple )
	if( not( pen.vld( info.pic ))) then return end
	if( not( pen.vld( info.name ))) then return end
	if( not( pen.vld( info.desc ))) then return end
	if( not( pen.vld( info.matter_info ))) then return end
	
	local pic_scale, spacer = 1.5, "\t"
	local matter = info.matter_info.matter

	local desc = info.desc
	local matter_desc = ""
	if( matter[1] > 0 ) then
		if( info.matter_info.may_drink ) then
			desc = desc.."\n"..GameTextGet( "$item_description_potion_usage", "[RMB]" ) end
		desc = desc.."\n"..GameTextGetTranslatedOrNot( "$inventory_capacity" ).." = "..matter[1].."/"..info.matter_info.volume
		
		for i,m in ipairs( matter[2]) do
			if( #matter[2] == 1 ) then break end
			local count = 100*m[2]/matter[1]
			local temp = pen.liner( pen.capitalizer(
				GameTextGetTranslatedOrNot( CellFactory_GetUIName( m[1]))), 75, -1, nil, { aggressive = true })[1]
			matter_desc = matter_desc..( i == 1 and "" or "\n" )..spacer..
				temp..": "..( count < 1 and "<" or "" )..math.max( math.floor( count + 0.5 ), 1 ).."%"
		end
	end
	
	local icon_w, icon_h = pen.get_pic_dims( info.pic )
	icon_w, icon_h = pic_scale*icon_w, pic_scale*icon_h

	local title_w, title_h = pen.get_text_dims( info.name, true )
	local desc_w, desc_h = unpack( pen.get_tip_dims( desc, math.max( title_w + 2, 100 ), -1, -2 ))
	local size_x, size_y = math.max( title_w + 2, desc_w + 2 ) + icon_w + 7, math.max( title_h + desc_h + 4, icon_h )
	
	local will_matter = pen.vld( matter_desc ) and index.D.tip_action
	if( will_matter ) then
		local _,matter_wh = pen.liner( matter_desc, nil, nil, nil, { line_offset = -2 })
		size_y = size_y + matter_wh[2] + 7
	end

	index.D.tip_func( "", {
		tid = tid, info = info,
		is_left = true, is_active = true,
		pic_z = pic_z, pos = { pic_x, pic_y }, dims = { size_x, size_y },
	}, function( t, d )
		local info = d.info
		local size_x, size_y = unpack( d.dims )
		local pic_x, pic_y, pic_z = unpack( d.pos )
		
		local inter_alpha = pen.animate( 1, d.t, { ease_out = "exp", frames = d.frames })
		pen.new_shadowed_text( pic_x + d.edging, pic_y + d.edging - 2, pic_z, info.name, {
			dims = { size_x - icon_w - 3, size_y }, fully_featured = true, alpha = inter_alpha, color = pen.PALETTE.VNL.YELLOW })
		pen.new_shadowed_text( pic_x + d.edging + 2, pic_y + d.edging + title_h, pic_z, desc, {
			dims = { desc_w + 2, size_y }, fully_featured = true, alpha = inter_alpha, line_offset = -2 })
		
		local inter_size = 15*( 1 - pen.animate( 1, d.t, { ease_out = "wav1.5", frames = d.frames }))
		local pos_x, pos_y = pic_x + 0.5*inter_size, pic_y + 0.5*inter_size
		local scale_x, scale_y = size_x - inter_size, size_y - inter_size
		
		local gui, uid = pen.gui_builder()
		GuiOptionsAddForNextWidget( gui, 2 ) --NonInteractive
		GuiZSetForNextWidget( gui, pic_z + 0.01 )
		GuiImageNinePiece( gui, uid, pos_x, pos_y, scale_x, scale_y, 1.15*math.max( 1 - inter_alpha/6, 0.1 ))
		
		local icon_x, icon_y = pos_x + scale_x - ( d.edging + icon_w ), pos_y + ( scale_y - icon_h )/2
		pen.new_image( icon_x, icon_y, pic_z, info.pic, { s_x = pic_scale, s_y = pic_scale, alpha = inter_alpha })
		
		if( matter[1] > 0 ) then
			local cut = pic_scale*info.potion_cutout
			local step = ( icon_h - 2*cut )*math.max( math.min( 1 - matter[1]/info.matter_info.volume, 1 ), 0 ) + cut
			pen.new_cutout( icon_x, icon_y + step, icon_w, icon_h - cut, function( v )
				pen.new_image( 0, -step, v[1],
					v[2], { color = pen.get_color_matter( v[6]), s_x = v[3], s_y = v[4], alpha = v[5]})
			end, { pic_z - 1, info.pic, pic_scale, pic_scale, 0.8*inter_alpha, CellFactory_GetName( matter[2][1][1])})
		end

		if( pen.vld( matter_desc ) and not( index.D.tip_action )) then
			pen.new_shadowed_text( pic_x, pic_y + size_y + 2, pic_z,
				"hold "..mnee.get_binding_keys( "index_core", "tip_action" ).."...", { color = pen.PALETTE.VNL.GRET, alpha = 0.8*inter_alpha })
		end

		if( not( will_matter )) then return end
		
		local line_w, line_h = pen.get_text_dims( spacer, true )
		for i,m in ipairs( matter[2]) do
			local perc = math.max(( line_w + 2 )*m[2]/matter[1], 1 )
			local t_x, t_y = pic_x + d.edging + 3 + line_w, pic_y + title_h + desc_h + line_h*( i - 1 ) + 9
			pen.new_pixel( t_x, t_y, pic_z + tonumber( "0.0001"..i ),
				pen.get_color_matter( CellFactory_GetName( m[1])), -perc, line_h, inter_alpha )
			if(( line_w + 2 ) - perc > 0.25 ) then
				pen.new_pixel( t_x - perc, t_y, pic_z + tonumber( "0.0001"..i ), pen.PALETTE.W, -0.5, line_h, 0.75*inter_alpha )
			end
		end
		pen.new_shadowed_text( pic_x + d.edging + 7, pic_y + d.edging + title_h + desc_h + 6.5, pic_z, matter_desc, {
			line_offset = -2, dims = { size_x, size_y }, fully_featured = true, alpha = inter_alpha })
		index.new_vanilla_box( pic_x + d.edging + 2, pic_y + title_h + desc_h + 10,
			pic_z + 0.001, { line_w, line_h*#matter[2] - 2 }, inter_alpha )
	end)
end

function index.new_vanilla_itt( info, tid, pic_x, pic_y, pic_z, is_simple, do_magic )
	if( not( pen.vld( info.pic ))) then return end
	if( not( pen.vld( info.name ))) then return end
	if( not( pen.vld( info.desc ))) then return end
	
	local pic_scale = 1.5
	local icon_w, icon_h = pen.get_pic_dims( info.pic )
	icon_w, icon_h = pic_scale*icon_w, pic_scale*icon_h

	local title_w, title_h = pen.get_text_dims( info.name, true )
	local desc_w, desc_h = unpack( pen.get_tip_dims( info.desc, math.max( title_w + 2, 100 ), -1, -2 ))
	local size_x, size_y = math.max( title_w + 2, desc_w ) + icon_w + 7, math.max( title_h + desc_h + 4, icon_h )

	index.D.tip_func( "", {
		tid = tid, info = info,
		is_left = true, is_active = true,
		pic_z = pic_z, pos = { pic_x, pic_y }, dims = { size_x, size_y },
	}, function( t, d )
		local info = d.info
		local size_x, size_y = unpack( d.dims )
		local pic_x, pic_y, pic_z = unpack( d.pos )
		
		local inter_alpha = pen.animate( 1, d.t, { ease_out = "exp", frames = d.frames })
		pen.new_shadowed_text( pic_x + d.edging, pic_y + d.edging - 2, pic_z, info.name, {
			dims = { size_x - icon_w - 3, size_y }, fully_featured = true, alpha = inter_alpha,
			color = pen.PALETTE.VNL[ do_magic and "RUNIC" or "YELLOW" ]})
		
		local runic_state = do_magic and pen.magic_storage( info.id, "index_runic_cypher", "value_float", nil, true ) or 1
		if( runic_state ~= 1 ) then
			pen.new_shadowed_text( pic_x + d.edging + 2, pic_y + d.edging + title_h, pic_z,
				"{>runic>{"..info.desc.."}<runic<}", { dims = { desc_w + 2, size_y },
				fully_featured = true, color = pen.PALETTE.VNL.RUNIC, alpha = inter_alpha*( 1 - runic_state ), line_offset = -2 })
			pen.magic_storage( info.id, "index_runic_cypher", "value_float", pen.estimate( "runic"..info.id, { 1, 0 }, "exp500" ))
		end
		if( runic_state > 0 ) then
			pen.new_shadowed_text( pic_x + d.edging + 2, pic_y + d.edging + title_h, pic_z + 0.001, info.desc, {
				dims = { desc_w + 2, size_y }, fully_featured = true, alpha = inter_alpha*runic_state, line_offset = -2 })
		end
		
		local inter_size = 15*( 1 - pen.animate( 1, d.t, { ease_out = "wav1.5", frames = d.frames }))
		local pos_x, pos_y = pic_x + 0.5*inter_size, pic_y + 0.5*inter_size
		local scale_x, scale_y = size_x - inter_size, size_y - inter_size
		
		local gui, uid = pen.gui_builder()
		GuiOptionsAddForNextWidget( gui, 2 ) --NonInteractive
		GuiZSetForNextWidget( gui, pic_z + 0.01 )
		GuiImageNinePiece( gui, uid, pos_x, pos_y, scale_x, scale_y, 1.15*math.max( 1 - inter_alpha/6, 0.1 ))
		
		local icon_x, icon_y = pos_x + scale_x - ( d.edging + icon_w ), pos_y + ( scale_y - icon_h )/2
		pen.new_image( icon_x, icon_y, pic_z, info.pic, { s_x = pic_scale, s_y = pic_scale, alpha = inter_alpha })
	end)
end

function index.new_vanilla_ttt( info, tid, pic_x, pic_y, pic_z, is_simple )
	return index.new_vanilla_itt( info, tid, pic_x, pic_y, pic_z, is_simple, true )
end

function index.new_slot_pic( pic_x, pic_y, pic_z, pic, alpha, angle, hov_scale, fancy_shadow )
	angle = angle or 0
	scale_up = scale_up or false
	
	local pic_data = pen.cache({ "index_pic_data", pic }) or { xy = { 0, 0 }}
	
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
	local _,_,is_hovered = pen.new_image( pic_x + pic_off_x, pic_y + pic_off_y,
		pic_z, icon_info.pic, { has_shadow = kind == 2, can_click = true })

	if( is_hovered and kind == 4 ) then
		pen.new_pixel( pic_x + pic_off_x + 3, pic_y + pic_off_y + 2, pic_z + 0.001, pen.PALETTE.VNL.RUNIC, 11, 11, 0.75 )
		pen.new_pixel( pic_x + pic_off_x + 2, pic_y + pic_off_y + 3, pic_z + 0.001, pen.PALETTE.VNL.RUNIC, 13, 9, 0.75 )
		pen.new_pixel( pic_x + pic_off_x + 4, pic_y + pic_off_y + 1, pic_z + 0.001, pen.PALETTE.VNL.RUNIC, 9, 13, 0.75 )
	elseif( kind == 2 ) then
		-- local step = math.floor( h*( 1 - math.min( icon_info.amount, 1 )) + 0.5 )
		-- pen.new_cutout( pic_x + pic_off_x, pic_y + pic_off_y + step, w, h, function( v )
		-- 	return pen.new_image( 0, -step, v[1], v[2])
		-- end, { pic_z - 0.002, icon_info.pic })
		
		local scale = 10*icon_info.amount
		local pos = 10*( 1 - icon_info.amount )
		if( pos > 0 ) then
			pen.new_pixel( pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 1, pic_z - 0.001, pen.PALETTE.VNL.GREY, 10, pos, 0.3 ) end
		pen.new_pixel( pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 1 + pos,
			pic_z + 0.004, is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W, 10, scale, is_hovered and 1 or 0.5 )
		
		pen.new_pixel( pic_x + pic_off_x + 0.5, pic_y + pic_off_y, pic_z + 0.004, pen.PALETTE.SHADOW, 10, 1, 0.35 )
		pen.new_pixel( pic_x + pic_off_x - 0.5, pic_y + pic_off_y + 1, pic_z + 0.004, pen.PALETTE.SHADOW, 1, 10, 0.35 )
		pen.new_pixel( pic_x + pic_off_x + 10.5, pic_y + pic_off_y + 1, pic_z + 0.004, pen.PALETTE.SHADOW, 1, 10, 0.35 )
		pen.new_pixel( pic_x + pic_off_x + 0.5, pic_y + pic_off_y + 11, pic_z + 0.004, pen.PALETTE.SHADOW, 10, 1, 0.35 )
	end

	local txt_off_x, txt_off_y = 0, 0
	if( kind == 2 ) then
		txt_off_x, txt_off_y = 1, 1
	elseif( kind == 4 ) then
		txt_off_x, txt_off_y = 1, 2
	end

	if( pen.vld( icon_info.txt )) then
		icon_info.txt = pen.despacer( icon_info.txt )
		pen.new_shadowed_text( pic_x + txt_off_x - 1, pic_y + 1 + txt_off_y, pic_z, icon_info.txt,
			{ is_right_x = true, color = is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W, alpha = is_hovered and 1 or 0.5 })
	end
	if(( icon_info.count or 0 ) > 1 ) then
		pen.new_shadowed_text( pic_x + 15, pic_y + 1 + txt_off_y, pic_z, "x"..icon_info.count,
			{ color = is_hovered and pen.PALETTE.VNL.YELLOW or pen.PALETTE.W, alpha = is_hovered and 1 or 0.5 })
	end

	local tip_x, tip_y = pic_x + 15, pic_y + 16
	if( pen.vld( icon_info.tip )) then
		local dims, text, tid = {}, "", ""
		local is_extra = type( icon_info.tip ) == "function"
		if( is_extra ) then
			dims = {
				14*math.min( #icon_info.other_perks, 10 ),
				14*math.max( math.ceil(( #icon_info.other_perks )/10 ), 1 ) + 1
			}
			tid, tip_y = "extra_perks_tip", tip_y - 2
		else
			if( pen.vld( icon_info.desc )) then
				if( icon_info.is_danger ) then
					text = text.."{>color>{{-}|VNL|WARNING|{-}"..pen.despacer( icon_info.desc ).."}<color<}\n"
				else text = text..pen.despacer( icon_info.desc ).."\n" end
			end
			text = text.."{>color>{{-}|VNL|GREY|{-}"..pen.despacer( icon_info.tip ).."}<color<}"
		end
		is_hovered, dims = index.D.tip_func( text, { pos = { tip_x, tip_y + ( kind == 4 and 1 or 0 )}, pic_z = pic_z - 0.4,
			tid = tid, allow_hover = true, dims = dims, is_active = is_hovered, is_left = true, is_over = false, fully_featured = true })
		if( is_extra and is_hovered ) then icon_info.tip( tip_x - dims[1] + 2, tip_y + 3, pic_z - 0.5, icon_info.other_perks ) end
		if( is_hovered and pen.vld( dims )) then h = h + dims[2] + ( kind == 4 and 2 or 4 ) + ( kind == 1 and 1 or 0 ) + 7 end
	end

	if( kind == 4 ) then
		pic_y = pic_y - 3 end
	if( kind == 1 ) then
		pen.new_image( pic_x, pic_y, pic_z + 0.002, "data/ui_gfx/status_indicators/bg_ingestion.png" )
		
		local d_frame = icon_info.digestion_delay
		if( icon_info.is_stomach and d_frame > 0 ) then
			pen.new_image( pic_x + 1, pic_y + 1 + 10*( 1 - d_frame ), pic_z + 0.001,
				"mods/index_core/files/pics/vanilla_stomach_bg.xml", { s_x = 10, s_y = math.ceil( 20*d_frame )/2, alpha = 0.3 })
		end
	end

	return w, h + ( kind == 2 and 1 or 0 )
end

--display slot number on hover with dragger
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
						index.play_sound( slot_sfxes[ this_info.id > 0 and "move_item" or "move_empty" ])
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
			
			pic_x, pic_y = index.swap_anim( this_info.id, pic_x, pic_y ) --pen.animate
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
			pic_x, pic_y, {
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
			index.cat_callback( this_info, "on_tooltip", { "", pic_x + 1, pic_y - 2, pen.LAYERS.TIPS, false, true })
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

index.GLOBAL_FUNGAL_MEMO = "INDEX_GLOBAL_FUNGAL_MEMO" --stores fungal transformations
index.GLOBAL_FUCK_YOUR_MANA = "INDEX_GLOBAL_FUCK_YOUR_MANA" --trigger mana bar shaking

index.GLOBAL_FORCED_STATE = "INDEX_GLOBAL_FORCED_STATE" --0 checks CtrlComp for enabled, 1 is always enabled, -1 is always disabled
index.GLOBAL_GLOBAL_MODE = "INDEX_GLOBAL_GLOBAL_MODE" --GMOD type
index.GLOBAL_LOCK_SETTINGS = "INDEX_GLOBAL_LOCK_SETTINGS" --prevent settings from being synched or updated
index.GLOBAL_SYNC_SETTINGS = "INDEX_GLOBAL_SYNC_SETTINGS" --apply settings to globals

index.GLOBAL_DRAGGER_EXTERNAL = "INDEX_GLOBAL_DRAGGER_EXTERNAL" --compatibility brige for dragging to inventories outside Index system
index.GLOBAL_DRAGGER_SWAP_NOW = "INDEX_GLOBAL_DRAGGER_SWAP_NOW" --si true when the dragger item is being let go
index.GLOBAL_DRAGGER_ITEM_ID = "INDEX_GLOBAL_DRAGGER_ITEM_ID" --the entity id of the dragged item
index.GLOBAL_DRAGGER_INV_CAT = "INDEX_GLOBAL_DRAGGER_INV_CAT" --the numerical inventory category of the dragged item
index.GLOBAL_DRAGGER_IS_QUICKEST = "INDEX_GLOBAL_DRAGGER_IS_QUICKEST" --whether the inventory the item is being dragged from is quickest

index.GLOBAL_PLAYER_OFF_Y = "INDEX_GLOBAL_PLAYER_OFF_Y" --player center offset in y axis
index.GLOBAL_THROW_POS_RAD = "INDEX_GLOBAL_THROW_POS_RAD" --radius of valid throw position
index.GLOBAL_THROW_POS_SIZE = "INDEX_GLOBAL_THROW_POS_SIZE" --size of the area to be checked for validity
index.GLOBAL_THROW_FORCE = "INDEX_GLOBAL_THROW_FORCE" --force applied to thrown object

index.GLOBAL_QUICKEST_SIZE = "INDEX_GLOBAL_QUICKEST_SIZE" --the size of the wand inventory
index.GLOBAL_SLOT_SPACING = "INDEX_GLOBAL_SLOT_SPACING" --distance between individual slots
index.GLOBAL_EFFECT_SPACING = "INDEX_GLOBAL_EFFECT_SPACING" --distance between individual effect icons
index.GLOBAL_MIN_EFFECT_DURATION = "INDEX_GLOBAL_MIN_EFFECT_DURATION" --minimal duration required for the efect to appear as an icon
index.GLOBAL_SPELL_ANIM_FRAMES = "INDEX_GLOBAL_SPELL_ANIM_FRAMES" --the speed of spell swaying anim

index.GLOBAL_LOW_HP_FLASHING_THRESHOLD = "INDEX_GLOBAL_LOW_HP_FLASHING_THRESHOLD" --maximal hp value at which the flashing starts
index.GLOBAL_LOW_HP_FLASHING_THRESHOLD_MIN = "INDEX_GLOBAL_LOW_HP_FLASHING_THRESHOLD_MIN" --additional threshold correction for extreme max hps
index.GLOBAL_LOW_HP_FLASHING_PERIOD = "INDEX_GLOBAL_LOW_HP_FLASHING_PERIOD" --the speed with which the flashing will happen
index.GLOBAL_LOW_HP_FLASHING_INTENSITY = "INDEX_GLOBAL_LOW_HP_FLASHING_INTENSITY" --the maximum scale of the red borders

index.GLOBAL_INFO_RADIUS = "INDEX_GLOBAL_INFO_RADIUS" --maximal distance to the target for the prompt to appear
index.GLOBAL_INFO_THRESHOLD = "INDEX_GLOBAL_INFO_THRESHOLD" --minimal speed with which the pointer is being moved for the prompt to appear
index.GLOBAL_INFO_FADING = "INDEX_GLOBAL_INFO_FADING" --speed in frames with which the info prompt will fade out

index.GLOBAL_LOOT_MARKER = "INDEX_GLOBAL_LOOT_MARKER"
index.GLOBAL_SLOT_PIC_BG = "INDEX_GLOBAL_SLOT_PIC_BG"
index.GLOBAL_SLOT_PIC_BG_ALT = "INDEX_GLOBAL_SLOT_PIC_BG_ALT"
index.GLOBAL_SLOT_PIC_HL = "INDEX_GLOBAL_SLOT_PIC_HL"
index.GLOBAL_SLOT_PIC_ACTIVE = "INDEX_GLOBAL_SLOT_PIC_ACTIVE"
index.GLOBAL_SLOT_PIC_LOCKED = "INDEX_GLOBAL_SLOT_PIC_LOCKED"

index.GLOBAL_SFX_CLICK = "INDEX_GLOBAL_SFX_CLICK"
index.GLOBAL_SFX_SELECT = "INDEX_GLOBAL_SFX_SELECT"
index.GLOBAL_SFX_HOVER = "INDEX_GLOBAL_SFX_HOVER"
index.GLOBAL_SFX_OPEN = "INDEX_GLOBAL_SFX_OPEN"
index.GLOBAL_SFX_CLOSE = "INDEX_GLOBAL_SFX_CLOSE"
index.GLOBAL_SFX_ERROR = "INDEX_GLOBAL_SFX_ERROR"
index.GLOBAL_SFX_RESET = "INDEX_GLOBAL_SFX_RESET"
index.GLOBAL_SFX_MOVE_EMPTY = "INDEX_GLOBAL_SFX_MOVE_EMPTY"
index.GLOBAL_SFX_MOVE_ITEM = "INDEX_GLOBAL_SFX_MOVE_ITEM"

index.SETTING_ALWAYS_SHOW_FULL = "INDEX_SETTING_ALWAYS_SHOW_FULL"
index.SETTING_NO_INV_SHOOTING = "INDEX_SETTING_NO_INV_SHOOTING"
index.SETTING_VANILLA_DROPPING = "INDEX_SETTING_VANILLA_DROPPING"
index.SETTING_SILENT_DROPPING = "INDEX_SETTING_SILENT_DROPPING"
index.SETTING_FORCE_VANILLA_FULLEST = "INDEX_SETTING_FORCE_VANILLA_FULLEST"

index.SETTING_MAX_PERK_COUNT = "INDEX_SETTING_MAX_PERK_COUNT"
index.SETTING_SHORT_HP = "INDEX_SETTING_SHORT_HP"
index.SETTING_SHORT_GOLD = "INDEX_SETTING_SHORT_GOLD"
index.SETTING_FANCY_POTION_BAR = "INDEX_SETTING_FANCY_POTION_BAR"
index.SETTING_RELOAD_THRESHOLD = "INDEX_SETTING_RELOAD_THRESHOLD"

index.SETTING_INFO_POINTER = "INDEX_SETTING_INFO_POINTER"
index.SETTING_INFO_POINTER_ALPHA = "INDEX_SETTING_INFO_POINTER_ALPHA"
index.SETTING_INFO_MATTER_MODE = "INDEX_SETTING_INFO_MATTER_MODE"

index.SETTING_MUTE_APPLETS = "INDEX_SETTING_MUTE_APPLETS"
index.SETTING_NO_WAND_SCALING = "INDEX_SETTING_NO_WAND_SCALING"
index.SETTING_FORCE_SLOT_TIPS = "INDEX_SETTING_FORCE_SLOT_TIPS"
index.SETTING_IN_WORLD_PICKUPS = "INDEX_SETTING_IN_WORLD_PICKUPS"
index.SETTING_IN_WORLD_TIPS = "INDEX_SETTING_IN_WORLD_TIPS"
index.SETTING_SECRET_SHOPPER = "INDEX_SETTING_SECRET_SHOPPER"
index.SETTING_BOSS_BAR_MODE = "INDEX_SETTING_BOSS_BAR_MODE"

index.INVS = { QUICK = -1, TRUE_QUICK = -0.5, ANY = 0, FULL = 0.5 }
index.FRAMER = { --https://davidmathlogic.com/colorblind/#%23B95632-%23CC80B6-%23CAA146-%23A8D5DA-%238EC373-%233F8492-%23735D8E-%234A446D
	[0] = { "data/ui_gfx/inventory/item_bg_projectile.png", pen.PALETTE.VNL.ACTION_PROJECTILE, "$inventory_actiontype_projectile" },
	[1] = { "data/ui_gfx/inventory/item_bg_static_projectile.png", pen.PALETTE.VNL.ACTION_STATIC, "$inventory_actiontype_staticprojectile" },
	[2] = { "data/ui_gfx/inventory/item_bg_modifier.png", pen.PALETTE.VNL.ACTION_MODIFIER, "$inventory_actiontype_modifier" },
	[3] = { "data/ui_gfx/inventory/item_bg_draw_many.png", pen.PALETTE.VNL.ACTION_DRAW, "$inventory_actiontype_drawmany" },
	[4] = { "data/ui_gfx/inventory/item_bg_material.png", pen.PALETTE.VNL.ACTION_MATERIAL, "$inventory_actiontype_material" },
	[5] = { "data/ui_gfx/inventory/item_bg_utility.png", pen.PALETTE.VNL.ACTION_UTILITY, "$inventory_actiontype_utility" },
	[6] = { "data/ui_gfx/inventory/item_bg_passive.png", pen.PALETTE.VNL.ACTION_PASSIVE, "$inventory_actiontype_passive" },
	[7] = { "data/ui_gfx/inventory/item_bg_other.png", pen.PALETTE.VNL.ACTION_OTHER, "$inventory_actiontype_other" },
}

index.BOSS_BARS = { --apocalyptic thanks to Priskip
	["data/entities/animals/boss_alchemist/boss_alchemist.xml"] = {
		pic = "mods/index_core/files/pics/priskips_bossbars/alchemist.png",
		-- in_world = false,
		-- color = pen.PALETTE.VNL.HP,
		-- color_text = pen.PALETTE.VNL.ACTION_OTHER,
		color_bg = { 120, 131, 146, 47/255 }, pos = { 20, 3, 294, 17 },
		-- func = function( pic_x, pic_y, pic_z, entity_id, data ) return legnth, height end,
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
		func_extra = function( pic_x, pic_y, pic_z, entity_id, data, perc )
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
index.WAND_STATS = {
	{
		pic = "data/ui_gfx/inventory/icon_gun_actions_per_round.png",
		name = "$inventory_actionspercast",
		desc = "$inventory_actionspercast_tooltip",

		-- spacer = false,
		-- is_hidden = false,
		-- is_advanced = false,
		bigger_better = true,
		value = function( info, w )
			return w.actions_per_round or 0 end,
		txt = function( value, info, w ) return index.get_stat( value, nil, 0 ) end,
		-- func = function( pic_x, pic_y, pic_z, txt, data ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_gun_capacity.png",
		name = "$inventory_capacity",
		desc = "$inventory_capacity_tooltip",

		bigger_better = true,
		value = function( info, w )
			return w.deck_capacity or 0 end,
		txt = function( value, info, w ) return index.get_stat( value, nil, 0 ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_spread_degrees.png",
		name = "$inventory_spread",
		desc = "$inventory_spread_tooltip",
		
		spacer = true,
		value = function( info, w )
			return w.spread_degrees or 0 end,
		txt = function( value, info, w )
			local v, is_dft = index.get_stat( value, nil, 0 )
			return v.."°", is_dft
		end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_mana_max.png",
		name = "$inventory_manamax",
		desc = "$inventory_manamax_tooltip",

		bigger_better = true,
		value = function( info, w )
			return w.mana_max or 0 end,
		txt = function( value, info, w ) return index.get_stat( value, nil, 0 ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_mana_charge_speed.png",
		name = "$inventory_manachargespeed",
		desc = "$inventory_manachargespeed_tooltip",

		spacer = true,
		bigger_better = true,
		value = function( info, w )
			return w.mana_charge_speed or 0 end,
		txt = function( value, info, w ) return index.get_stat( value, nil, 0 ) end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_fire_rate_wait.png", off_y = 1,
		name = "$inventory_castdelay",
		desc = "$inventory_castdelay_tooltip",

		value = function( info, w )
			return w.delay_time or 0 end,
		txt = function( value, info, w )
			local v, is_dft = index.get_stat( value/60, nil, 0, false, true )
			return v.."s", is_dft
		end,
	},
	{
		pic = "data/ui_gfx/inventory/icon_gun_reload_time.png",
		name = "$inventory_rechargetime",
		desc = "$inventory_rechargetime_tooltip",
		
		spacer = true,
		value = function( info, w )
			return w.reload_time or 0 end,
		txt = function( value, info, w )
			if( w.never_reload ) then return "Ø", 1 end
			local v, is_dft = index.get_stat( value/60, nil, 0, false, true )
			return v.."s", is_dft
		end,
	},
}

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

index.SPELL_STATS = { --custom descs
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
			txt = function( value, info, c, c_proj ) return index.get_stat( value, nil, 0 ) end,
			-- func = function( pic_x, pic_y, pic_z, txt, data ) end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_mana_drain.png",
			name = "$inventory_manadrain",
			
			value = function( info, c, c_proj )
				return info.spell_info.mana or 0 end,
			txt = function( value, info, c, c_proj ) return index.get_stat( value, nil, 0 ) end,
		},
		{
			off_y = 1,
			pic = "data/ui_gfx/inventory/icon_fire_rate_wait.png",
			name = "$inventory_mod_castdelay",

			value = function( info, c, c_proj )
				return c.fire_rate_wait or 0 end,
			txt = function( value, info, c, c_proj )
				local v, is_dft = index.get_stat( nil, value/60, 0, false, true )
				return v.."s", is_dft
			end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_reload_time.png",
			name = "$inventory_mod_rechargetime",

			value = function( info, c, c_proj )
				return c.reload_time or 0 end,
			txt = function( value, info, c, c_proj )
				if( info.spell_info.is_chainsaw ) then return "Chainsaw", 1 end
				local v, is_dft = index.get_stat( nil, value/60, 0, false, true )
				return v.."s", is_dft
			end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_spread_degrees.png",
			name = "$inventory_mod_spread",
			
			spacer = true,
			value = function( info, c, c_proj )
				return c.spread_degrees or 0 end,
			txt = function( value, info, c, c_proj )
				local v, is_dft = index.get_stat( nil, value, 0 )
				return v.."°", is_dft
			end,
		},
	},
	{
		{
			pic = "data/ui_gfx/inventory/icon_damage_projectile.png",
			name = "$inventory_mod_damage",
			
			value = function( info, c, c_proj )
				return c_proj.damage.total or 0 end,
			txt = function( value, info, c, c_proj )
				if( c.damage_null_all > 0 ) then return "Ø", 1 end
				return index.get_stat( 25*value, 25*( c.damage_total_add or 0 ), 0 )
			end,
		},
		{
			off_y = 1,
			pic = "data/ui_gfx/inventory/icon_damage_critical_chance.png",
			name = "$inventory_mod_critchance",

			value = function( info, c, c_proj )
				return c_proj.crit.chance or 0 end,
			txt = function( value, info, c, c_proj )
				local v, is_dft = index.get_stat( value, c.damage_critical_chance, 0, false, true )
				return v.."%", is_dft
			end,
		},
		{
			off_y = 1,
			pic = "data/ui_gfx/inventory/icon_speed_multiplier.png",
			name = "$inventory_mod_speed",

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
			name = "$inventory_mod_bounces",
			
			value = function( info, c, c_proj )
				return c_proj.bounces or 0 end,
			txt = function( value, info, c, c_proj )
				if( c_proj.inf_bounces ) then return "∞", 1 end
				return index.get_stat( value, c.bounces, 0 )
			end,
		},
		{
			pic = "data/ui_gfx/inventory/icon_explosion_radius.png",
			name = "$inventory_mod_explosion_radius",

			spacer = true,
			value = function( info, c, c_proj )
				return c_proj.lightning.explosion_radius or c_proj.explosion.explosion_radius or 0 end,
			txt = function( value, info, c, c_proj ) return index.get_stat( value, c.explosion_radius, 0 ) end,
		},
	},
}