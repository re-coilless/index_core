dofile_once( "data/scripts/lib/utilities.lua" )

--utility lists
font_tbl = {
	vanilla_small = {
		default = { 4, 4 },
		space = 0,
		height = 6,
	},
	[""] = { 
		default = { 6, 6, },
		space = 4,
		height = 7,
	},
}

--core backend
function b2n( a )
	return a and 1 or 0
end

function get_sign( a )
	if( a < 0 ) then
		return -1
	else
		return 1
	end
end

function float_compare( a, b )
	local epsln = 0.0001
	return math.abs( a - b ) < epsln
end

function t2w( str )
	local t = {}
	
	for word in string.gmatch( str, "([^%s]+)" ) do
		table.insert( t, word )
	end
	
	return t
end

function uint2color( color )
	return { bit.band( color, 0xff ), bit.band( bit.rshift( color, 8 ), 0xff ), bit.band( bit.rshift( color, 16 ), 0xff )}
end

function rotate_offset( x, y, angle )
	return x*math.cos( angle ) - y*math.sin( angle ), x*math.sin( angle ) + y*math.cos( angle )
end

function limiter( value, limit, max_mode )
	max_mode = max_mode or false
	limit = math.abs( limit )
	
	if(( max_mode and math.abs( value ) < limit ) or ( not( max_mode ) and math.abs( value ) > limit )) then
		return get_sign( value )*limit
	end
	
	return value
end

function check_bounds( dot, pos, box )
	if( box == nil ) then
		return false
	end
	
	if( type( box ) ~= "table" ) then
		local off_x, off_y = ComponentGetValue2( box, "offset" )
		pos = { pos[1] + off_x, pos[2] + off_y }
		box = {
			ComponentGetValue2( box, "aabb_min_x" ),
			ComponentGetValue2( box, "aabb_max_x" ),
			ComponentGetValue2( box, "aabb_min_y" ),
			ComponentGetValue2( box, "aabb_max_y" ),
		}
	end
	return dot[1]>=(pos[1]+box[1]) and dot[2]>=(pos[2]+box[3]) and dot[1]<=(pos[1]+box[2]) and dot[2]<=(pos[2]+box[4])
end

function table_init( amount, value )
	local tbl = {}
	local temp = value
	for i = 1,amount do
		if( type( value ) == "table" ) then
			temp = {}
		end
		tbl[i] = temp
	end
	
	return tbl
end

function magic_copy( orig, copies )
    copies = copies or {}
    local orig_type = type( orig )
    local copy = {}
    if( orig_type == "table" ) then
        if( copies[orig] ) then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[ magic_copy( orig_key, copies )] = magic_copy( orig_value, copies )
            end
            setmetatable( copy, magic_copy( getmetatable( orig ), copies ))
        end
    else
        copy = orig
    end
    return copy
end

function generic_random( a, b, macro_drift, bidirectional )
	bidirectional = bidirectional or false
	
	if( macro_drift == nil ) then
		macro_drift = GetUpdatedEntityID() or 0
		if( macro_drift > 0 ) then
			local drft_a, drft_b = EntityGetTransform( macro_drift )
			macro_drift = macro_drift + tonumber( macro_drift ) + ( drft_a*1000 + drft_b )
		else
			macro_drift = 1
		end
	elseif( type( macro_drift ) == "table" ) then
		macro_drift = macro_drift[1]*1000 + macro_drift[2]
	end
	macro_drift = math.floor( macro_drift + 0.5 )
	
	local tm = { GameGetDateAndTimeUTC() }
	SetRandomSeed( math.random( GameGetFrameNum(), macro_drift ), (((( tm[2]*30 + tm[3] )*24 + tm[4] )*60 + tm[5] )*60 + tm[6] )%macro_drift )
	Random( 1, 5 ); Random( 1, 5 ); Random( 1, 5 )
	return bidirectional and ( Random( a, b*2 ) - b ) or Random( a, b )
end

function get_most_often( tbl )
	local count = {}
	for n,v in pairs( tbl ) do
		count[v] = ( count[v] or 0 ) + 1
	end
	local best = {0,0}
	for n,v in pairs( count ) do
		if( best[2] < v ) then
			best = {n,v}
		end
	end
	return unpack( best )
end

function from_tbl_with_id( tbl, id, subtract, custom_key )
	local stuff = 0
	local tbl_id = nil

	local key = custom_key or "id"
	if( type( id ) == "table" ) then
		stuff = {}
		if( subtract ) then
			if( #id < #tbl ) then
				if( #id > 0 ) then
					for i = #tbl,1,-1 do
						for e,dud in ipairs( id ) do
							if( dud == ( tbl[i][key] or tbl[i][1] or tbl[i])) then
								table.remove( tbl, i )
								table.remove( id, e )
								break
							end
						end
					end
				end
				return tbl
			end
			return {}
		else
			for i,dud in ipairs( tbl ) do
				for e,bub in ipairs( id ) do
					if(( dud[key] or dud[1] or dud ) == bub ) then
						table.insert( stuff, dud )
						break
					end
				end
			end
		end
	else
		local gonna_stuff = true
		for i,dud in ipairs( tbl ) do
			if( gonna_stuff and type( dud ) == "table" ) then
				stuff = {}
				gonna_stuff = false
			end
			if(( dud[key] or dud[1] or dud ) == id ) then
				stuff = dud
				tbl_id = i
				break
			end
		end
	end
	
	return stuff, tbl_id
end

function D_extractor( data_raw, use_nums, div )
	if( data_raw == nil ) then
		return nil
	end
	use_nums = use_nums or false
	
	local data = {}
	
	for value in string.gmatch( data_raw, "([^"..( div or "|" ).."]+)" ) do
		if( use_nums ) then
			table.insert( data, tonumber( value ))
		else
			table.insert( data, value )
		end
	end
	
	return data
end

function D_packer( data, div )
	if( data == nil ) then
		return nil
	end

	div = div or "|"
	local data_raw = div
	
	for i,value in ipairs( data ) do
		data_raw = data_raw..value..div
	end
	
	return data_raw
end

function clean_append( to_file, from_file )
	local marker = "%-%-<{> MAGICAL APPEND MARKER <}>%-%-"
	local line_wrecker = "\n\n\n"
	
	local a = ModTextFileGetContent( to_file )
	local b = ModTextFileGetContent( from_file )
	ModTextFileSetContent( to_file, string.gsub( a, marker, b..line_wrecker..marker ))
end

function get_button_state( ctrl_comp, btn, frame )
	return { ComponentGetValue2( ctrl_comp, "mButtonDown"..btn ), ComponentGetValue2( ctrl_comp, "mButtonFrame"..btn ) == frame }
end

function get_discrete_button( entity_id, comp, btn )
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

function get_input( vanilla_id, mnee_id, is_continuous, is_dirty )
	is_dirty = is_dirty or false
	is_continuous = is_continuous or false
	
	local state = false
	if( ModIsEnabled( "mnee" )) then
		dofile_once( "mods/mnee/lib.lua" )
		state = is_binding_down( "index_core", mnee_id, is_dirty, not( is_continuous ))
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

--ESC backend
function get_storage( hooman, name )
	local comps = EntityGetComponentIncludingDisabled( hooman, "VariableStorageComponent" ) or {}
	if( #comps > 0 ) then
		for i,comp in ipairs( comps ) do
			if( ComponentGetValue2( comp, "name" ) == name ) then
				return comp
			end
		end
	end
	
	return nil
end

function edit_component_ultimate( entity_id, type_name, do_what )
	if( entity_id == 0 or entity_id == nil ) then
		return
	end
	
	local comp = EntityGetFirstComponentIncludingDisabled( entity_id, type_name )
	if( comp ~= nil ) then
		local modified_vars = { }
		do_what( comp, modified_vars )
		for key,value in pairs( modified_vars ) do 
			ComponentSetValue( comp, key, to_string(value) )
		end
		return comp
	end
end

function edit_component_with_tag_ultimate( entity_id, type_name, tag, do_what )
	if( entity_id == 0 or entity_id == nil ) then
		return
	end
	
	local comp = EntityGetFirstComponentIncludingDisabled( entity_id, type_name, tag )
	if( comp ~= nil ) then
		local modified_vars = { }
		do_what( comp, modified_vars )
		for key,value in pairs( modified_vars ) do 
			ComponentSetValue( comp, key, to_string(value) )
		end
		return comp
	end
end

function closest_getter( x, y, stuff, check_sight, limits, extra_check )
	check_sight = check_sight or false
	limits = limits or { 0, 0, }
	if( #( stuff or {}) == 0 ) then
		return 0
	end
	
	local actual_thing = 0
	local min_dist = -1
	for i,raw_thing in ipairs( stuff ) do
		local thing = type( raw_thing ) == "table" and raw_thing[1] or raw_thing

		local t_x, t_y = EntityGetTransform( thing )
		if( not( check_sight ) or not( RaytracePlatforms( x, y, t_x, t_y ))) then
			local d_x, d_y = math.abs( t_x - x ), math.abs( t_y - y )
			if(( d_x < limits[1] or limits[1] == 0 ) and ( d_y < limits[2] or limits[2] == 0 )) then
				local dist = math.sqrt( d_x^2 + d_y^2 )
				if( min_dist == -1 or dist < min_dist ) then
					if( extra_check == nil or extra_check( raw_thing )) then
						min_dist = dist
						actual_thing = raw_thing
					end
				end
			end
		end
	end
	
	return actual_thing
end

function get_hooman_child( hooman, tag, ignore_id )
	if( hooman == nil ) then
		return -1
	end
	
	local children = EntityGetAllChildren( hooman ) or {}
	if( #children > 0 ) then
		for i,child in ipairs( children ) do
			if( child ~= ignore_id and ( EntityGetName( child ) == tag or EntityHasTag( child, tag ))) then
				return child
			end
		end
	end
	
	return nil
end

function child_play( entity_id, action )
	local children = EntityGetAllChildren( entity_id ) or {}
	if( #children > 0 ) then
		for i,child in ipairs( children ) do
			local value = action( entity_id, child, i ) or false
			if( value ) then
				return value
			end
		end
	end
end

function child_play_full( dude_id, func, params )
	func( dude_id, params )
	return child_play( dude_id, function( parent, child )
		return child_play_full( child, func, params )
	end)
end

function vanilla_lua_callback( entity_id, func_names, input )
	local comps = EntityGetComponentIncludingDisabled( entity_id, "LuaComponent" ) or {}
	if( #comps > 0 ) then
		local real_GetUpdatedEntityID = GetUpdatedEntityID
		local real_GetUpdatedComponentID = GetUpdatedComponentID
		GetUpdatedEntityID = function() return entity_id end

		for i,comp in ipairs( comps ) do
			local path = ComponentGetValue2( comp, func_names[1]) or ""
			if( path ~= "" ) then
				GetUpdatedComponentID = function() return comp end
				dofile( path )
				_G[ func_names[2]]( unpack( input ))
			end
		end
		
		GetUpdatedEntityID = real_GetUpdatedEntityID
		GetUpdatedComponentID = real_GetUpdatedComponentID
	end
end

function play_sound( data, sfx, x, y )
	if( x == nil or y == nil ) then
		x, y = unpack( data.player_xy )
	end
	local sound = type( sfx ) == "table" and sfx or data.sfxes[ sfx ]
	GamePlaySound( sound[1], sound[2], x, y )
end

function get_active_wand( hooman )
	local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
	if( inv_comp ~= nil ) then
		return tonumber( ComponentGetValue2( inv_comp, "mActiveItem" ) or 0 )
	end
	
	return 0
end

function get_phys_mass( entity_id )
	local mass = 0
	
	local shape_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "PhysicsImageShapeComponent" )
	if( shape_comp ~= nil ) then
		local proj_x, proj_y = EntityGetTransform( entity_id )
		local drift_x, drift_y = ComponentGetValue2( shape_comp, "offset_x" ), ComponentGetValue2( shape_comp, "offset_y" )
		proj_x, proj_y = proj_x - drift_x, proj_y - drift_y
		drift_x, drift_y = 1.5*drift_x, 1.5*drift_y
		
		local function calculate_force_for_body( entity, body_mass, body_x, body_y, body_vel_x, body_vel_y, body_vel_angular )
			if( math.abs( proj_x - body_x ) < 0.001 and math.abs( proj_y - body_y ) < 0.001 ) then
				mass = body_mass
			end
			return body_x, body_y, 0, 0, 0
		end
		PhysicsApplyForceOnArea( calculate_force_for_body, nil, proj_x - drift_x, proj_y - drift_y, proj_x + drift_x, proj_y + drift_y )
	end
	
	return mass
end

function get_matters( matters )
	local mttrs = {}
	local got_some = 0
	if( #matters > 0 ) then
		for i,mttr in ipairs( matters ) do
			if( mttr > 0 ) then
				table.insert( mttrs, {i-1,mttr})
				got_some = got_some + mttr
			end
		end 
		table.sort( mttrs, function( a, b )
			return a[2] > b[2]
		end)
	end
	return got_some, mttrs
end

function chugger_3000( mouth_id, cup_id, total_vol, mtr_list, perc )
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

function get_inv_data( inv_id, slot_count, kind, kind_func, check_func, gui_func )
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

function get_item_num( data, inv_id, item_id )
	local slot_tbl = data.slot_state[ inv_id ]
	local is_fancy, gonna_add = slot_tbl.quickest ~= nil, true
	local num, quickest_num = 0, 0
	for i,col in pairs( slot_tbl ) do
		for e,slot in ipairs( col ) do
			if( slot ) then
				if( slot == item_id ) then
					if( is_fancy and i == "quick" ) then
						gonna_add = false
					else
						return i == "quickest" and quickest_num or num
					end
				else
					if( i == "quickest" ) then
						quickest_num = quickest_num + 1
					elseif( gonna_add ) then
						num = num + 1
					end
				end
			end
		end
	end
	
	return is_fancy and ( num + quickest_num ) or -1
end

function inv_check( data, item_info, inv_info )
	if(( item_info.id or 0 ) < 0 ) then
		return true
	end

	local kind_memo = inv_info.kind
	local inv_data = inv_info.full or data.inventories[ inv_info.inv_id ]
	inv_info.kind = inv_data.kind_func ~= nil and inv_data.kind_func( inv_info ) or inv_data.kind
	
	local val = ( from_tbl_with_id( inv_info.kind, "universal" ) ~= 0 ) or ( #from_tbl_with_id( get_valid_inventories( item_info.inv_type, item_info.is_quickest ), inv_info.kind ) > 0 and ( inv_data.check == nil or inv_data.check( item_info, inv_info )))
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
	if( in_hand == nil ) then
		in_hand = item_id == data.active_item
	end
	
	local hooman = EntityGetRootEntity( item_id )
	local is_free = hooman == item_id
	local comps = EntityGetAllComponents( item_id ) or {}
	if( #comps > 0 ) then
		for i,comp in ipairs( comps ) do
			local world_check = ComponentHasTag( comp, "enabled_in_world" ) and is_free
			local inv_check = ComponentHasTag( comp, "enabled_in_inventory" ) and not( is_free )
			local hand_check = ComponentHasTag( comp, "enabled_in_hand" ) and in_hand
			EntitySetComponentIsEnabled( item_id, comp, world_check or inv_check or hand_check )
		end
	end

	if( not( is_free )) then
		if( in_hand ) then
			--set pos and such to the arm pos
		else
			local x, y = EntityGetTransform( hooman )
			EntitySetTransform( item_id, x, y )
			EntityApplyTransform( item_id, x, y )
		end
	end
end

function inventory_man( item_id, data, this_info, in_hand ) --use inv_boy instead
	child_play_full( item_id, function( child, params )
		if( child ~= item_id ) then params[3] = false end
		inventory_boy( child, unpack( params ))
	end, { data, this_info, in_hand })
end

function set_to_slot( slot_info, data, is_player )
	if( is_player == nil ) then
		is_player = EntityGetRootEntity( slot_info.id ) == data.player_id
	end
	
	local valid_invs = get_valid_inventories( slot_info.inv_type, slot_info.is_quickest )
	local slot_num = { ComponentGetValue2( slot_info.ItemC, "inventory_slot" )}
	if( slot_num[1] ~= -1 or slot_num[2] ~= -1 ) then
		if( slot_num[1] == -5 ) then
			if( slot_info.is_hidden ) then
				slot_num = {-1,-1}
			else
				local inv_list = nil
				if( is_player ) then
					inv_list = data.inventories_player
				else
					inv_list = { slot_info.inv_id }
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
										if( inv_check( data, slot_info, { inv_id = inv_id, inv_slot = temp_slot, full = inv_dt, })) then
											if( temp_slot[2] < 0 ) then temp_slot[2] = temp_slot[2] + 1 end
											slot_num = temp_slot
											data.slot_state[ inv_id ][i][k] = slot_info.id
											break
										end
									end
								end
							end
							if( slot_num[1] ~= -5 ) then
								break
							end
						end
					end
					if( slot_num[1] ~= -5 ) then
						break
					end
				end
				if( slot_num[1] == -5 ) then
					return slot_info
				end
			end

			slot_num[1], slot_num[2] = slot_num[1] - 1, slot_num[2] - 1
			ComponentSetValue2( slot_info.ItemC, "inventory_slot", slot_num[1], slot_num[2])
		elseif( slot_num[2] == -1 ) then
			data.slot_state[ slot_info.inv_id ].quickest[ slot_num[1] + 1 ] = slot_info.id
			slot_info.inv_kind = "quickest"
		elseif( slot_num[2] == -2 ) then
			data.slot_state[ slot_info.inv_id ].quick[ slot_num[1] + 1 ] = slot_info.id
			slot_info.inv_kind = "quick"
		elseif( slot_num[2] >= 0 ) then
			data.slot_state[ slot_info.inv_id ][ slot_num[1] + 1 ][ slot_num[2] + 1 ] = slot_info.id
			slot_info.inv_kind = slot_info.inv_kind[1]
		end
	end
	
	slot_num[1], slot_num[2] = slot_num[1] + 1, slot_num[2] < 0 and slot_num[2] or slot_num[2] + 1
	slot_info.inv_slot = slot_num
	return slot_info
end

function slot_swap( item_in, slot_data, active_item )
	local active_reset = false

	local parent1 = EntityGetParent( item_in )
	local parent2 = slot_data.inv_id
	if( parent1 ~= parent2 ) then
		active_reset = item_in == active_item or slot_data.id == active_item

		EntityRemoveFromParent( item_in )
		EntityAddChild( parent2, item_in )
		if( slot_data.id > 0 ) then
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

	return active_reset
end

function get_item_name( entity_id, abil_comp, item_comp )
	local actual_bullshit = {
		default = 1,
		unknown = 1,
		[" "] = 1,
		[""] = 1,
	}
	
	local name = abil_comp ~= nil and ComponentGetValue2( abil_comp, "ui_name" ) or ""
	name = name == "" and EntityGetName( entity_id ) or name
	local temp = ( ComponentGetValue2( item_comp, "always_use_item_name_in_ui" ) or actual_bullshit[ name ]) and ComponentGetValue2( item_comp, "item_name" ) or name
	name = actual_bullshit[ temp ] and name or temp
	return string.gsub( GameTextGetTranslatedOrNot( name ), "(%s*)%$0(%s*)", "" )
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
	
	local v = tostring( math.floor( 100*total_count/max_count + 0.5 ))
	return info..( info == "" and info or " " )..GameTextGetTranslatedOrNot( name ), GameTextGet( "$item_potion_fullness", v )
end

function get_item_data( item_id, data, inventory_data )
	local slot_info = { id = item_id, }
	if( inventory_data ~= nil ) then
		slot_info.inv_id = inventory_data.id
		slot_info.inv_kind = inventory_data.kind
	end
	
	local item_comp = EntityGetFirstComponentIncludingDisabled( item_id, "ItemComponent" )
	if( item_comp == nil ) then
		return
	end

	local abil_comp = EntityGetFirstComponentIncludingDisabled( item_id, "AbilityComponent" )
	if( abil_comp ~= nil ) then
		slot_info.AbilityC = abil_comp
		slot_info.charges = {
			ComponentGetValue2( abil_comp, "shooting_reduces_amount_in_inventory" ),
			ComponentGetValue2( abil_comp, "max_amount_in_inventory" ),
			ComponentGetValue2( abil_comp, "amount_in_inventory" ),
		}
		slot_info.pic = ComponentGetValue2( abil_comp, "sprite_file" )
	end
	if( item_comp ~= nil ) then
		slot_info.ItemC = item_comp

		local invs = { QUICK=-1, TRUE_QUICK=-0.5, ANY=0, FULL=0.5, }
		local storage_inv = get_storage( item_id, "preferred_inventory" )
		local inv_name = storage_inv == nil and ComponentGetValue2( item_comp, "preferred_inventory" ) or ComponentGetValue2( storage_inv, "value_string" )
		slot_info.inv_type = invs[inv_name] or 0
		
		local ui_pic = ComponentGetValue2( item_comp, "ui_sprite" ) or ""
		if( ui_pic ~= "" ) then
			slot_info.pic = ui_pic
		end

		slot_info.desc = GameTextGetTranslatedOrNot( ComponentGetValue2( item_comp, "ui_description" ))
		slot_info.uses_left = ComponentGetValue2( item_comp, "uses_remaining" )
		slot_info.is_frozen = ComponentGetValue2( item_comp, "is_frozen" )
		slot_info.is_stackable = ComponentGetValue2( item_comp, "is_stackable" ) --check item name + path to stack
		slot_info.is_consumable = ComponentGetValue2( item_comp, "is_consumable" )
	end
	
	for k,kind in ipairs( data.item_cats ) do
		if( kind.on_check( item_id, data, slot_info )) then
			slot_info.cat = k
			slot_info.is_wand = kind.is_wand or false
			slot_info.is_potion = kind.is_potion or false
			slot_info.is_spell = kind.is_spell or false
			slot_info.is_quickest = kind.is_quickest or false
			slot_info.is_hidden = kind.is_hidden or false
			slot_info.advanced_pic = kind.advanced_pic or false
			break
		end
	end
	slot_info.name = get_item_name( item_id, abil_comp, item_comp )
	if( slot_info.cat == nil ) then
		return
	elseif(( slot_info.name or "" ) == "" ) then
		slot_info.name = data.item_cats[ slot_info.cat ].name
	end
	slot_info.name = capitalizer( slot_info.name )

	if( data.item_cats[ slot_info.cat ].on_data ~= nil ) then
		data, slot_info = data.item_cats[ slot_info.cat ].on_data( item_id, data, slot_info )
	end
	
	return data, slot_info
end

function get_items( hooman, data )
	local item_tbl = {}
	for i,inv_data in pairs( data.inventories ) do
		child_play( inv_data.id, function( parent, child, j )
			local new_item = nil
			data, new_item = get_item_data( child, data, inv_data )
			if( new_item ~= nil ) then
				if( not( EntityHasTag( new_item.id, "index_processed" ))) then
					if( data.item_cats[ new_item.cat ].on_processed ~= nil ) then
						data.item_cats[ new_item.cat ].on_processed( new_item.id, data, new_item )
					end
					
					ComponentSetValue2( new_item.ItemC, "inventory_slot", -5, -5 )
					EntityAddTag( new_item.id, "index_processed" )
				end

				new_item.pic = register_item_pic( data, new_item, new_item.advanced_pic )
				if( data.item_cats[ new_item.cat ].ctrl_script ~= nil ) then
					data.item_cats[ new_item.cat ].ctrl_script( new_item.id, data, new_item )
				else
					inventory_man( new_item.id, data, new_item )
				end
				table.insert( item_tbl, new_item )
			end
		end)
	end

	data.item_list = item_tbl
	return data
end

function pick_up_item( hooman, data, this_data, do_the_sound, is_silent )
	local entity_id = this_data.id
	
	this_data.name = this_data.name or GameTextGetTranslatedOrNot( ComponentGetValue2( this_data.ItemC, "item_name" ))
	if( not( is_silent or false )) then
		GamePrint( GameTextGet( "$log_pickedup", this_data.name ))
		if( do_the_sound ) then
			play_sound( data, { "data/audio/Desktop/event_cues.bank", this_data.cost == nil and "event_cues/pick_item_generic/create" or "event_cues/shop_item/create" })
		end
	end
	
	local gonna_pause = 0
	local callback = data.item_cats[ this_data.cat ].on_pickup
	if( callback ~= nil ) then
		gonna_pause = callback( entity_id, data, this_data, false )
	end
	if( gonna_pause == 0 ) then
		local _,slot = ComponentGetValue2( this_data.ItemC, "inventory_slot" )
		EntityAddChild( data.inventories_player[ slot < 0 and 1 or 2 ], entity_id )

		if( this_data.cost ~= nil ) then
			if( not( data.Wallet[2])) then
				data.Wallet[3] = data.Wallet[3] - this_data.cost
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

		this_data.xy = { EntityGetTransform( entity_id )}
		vanilla_lua_callback( entity_id, { "script_item_picked_up", "item_pickup" }, { entity_id, hooman, this_data.name })
		if( callback ~= nil ) then
			callback( entity_id, data, this_data, true )
		end
		if( EntityGetIsAlive( entity_id )) then
			ComponentSetValue2( this_data.ItemC, "has_been_picked_by_player", true )
			ComponentSetValue2( this_data.ItemC, "mFramePickedUp", data.frame_num )

			inventory_man( entity_id, data, this_data, false )
		end
	elseif( gonna_pause == 1 ) then
		--engage the pause
	end
end

function drop_item( h_x, h_y, this_data, data, throw_force, do_action )
	local this_item = this_data.id
	EntityRemoveFromParent( this_item )

	local p_d_x, p_d_y = data.pointer_world[1] - h_x, data.pointer_world[2] - h_y
	local p_delta = math.min( math.sqrt( p_d_x^2 + p_d_y^2 ), 50 )/10
	local angle = math.atan2( p_d_y, p_d_x )
	local from_x, from_y = 0, 0
	if( data.active_item == this_item ) then
		from_x, from_y = EntityGetTransform( this_item )
		ComponentSetValue2( data.inventory, "mActiveItem", 0 )
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
	inventory_man( this_item, data, this_data, false )
	
	local pic_comps = EntityGetComponentIncludingDisabled( this_item, "SpriteComponent", "enabled_in_world" ) or {}
	if( #pic_comps > 0 ) then
		for i,comp in ipairs( pic_comps ) do
			ComponentSetValue2( comp, "z_index", -1 )
			EntityRefreshSprite( this_item, comp )
		end
	end
	ComponentSetValue2( this_data.ItemC, "inventory_slot", -5, -5 )
	ComponentSetValue2( this_data.ItemC, "play_hover_animation", false )
	ComponentSetValue2( this_data.ItemC, "has_been_picked_by_player", true )
	ComponentSetValue2( this_data.ItemC, "next_frame_pickable", data.frame_num + 30 )

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

	if( do_action ) then
		vanilla_lua_callback( this_item, { "script_throw_item", "throw_item" }, { from_x, from_y, to_x, to_y })
	end
end

--GUI backend
function world2gui( x, y, not_pos )
	not_pos = not_pos or false
	
	local gui = GuiCreate()
	GuiStartFrame( gui )
	local w, h = GuiGetScreenDimensions( gui )
	GuiDestroy( gui )
	
	local shit_from_ass = w/( MagicNumbersGetValue( "VIRTUAL_RESOLUTION_X" ) + MagicNumbersGetValue( "VIRTUAL_RESOLUTION_OFFSET_X" ))
	if( not_pos ) then
		x, y = shit_from_ass*x, shit_from_ass*y
	else
		local cam_x, cam_y = GameGetCameraPos()
		x, y = w/2 + shit_from_ass*( x - cam_x ), h/2 + shit_from_ass*( y - cam_y )
	end
	
	return x, y, shit_from_ass
end

function get_text_dim( text, char_table )
	local w, h = 0, 0
	
	if( char_table == nil ) then
		local gui = GuiCreate()
		GuiStartFrame( gui )
		w, h = GuiGetTextDimensions( gui, text, 1, 2 )
		GuiDestroy( gui )
	else
		h = char_table.height or 0
		for chr in string.gmatch( text, "." ) do
			w = w + ( chr == " " and ( char_table.space or 1 ) or ( char_table[chr] or char_table.default[ 1 + b2n( tonumber( chr ) ~= nil )]))
		end
	end
	
	return w, h
end

function get_pic_dim( path )
	local gui = GuiCreate()
	GuiStartFrame( gui )
	local w, h = GuiGetImageDimensions( gui, path, 1 )
	GuiDestroy( gui )
	
	return w, h
end

function get_mouse_pos()
	local m_x, m_y = DEBUG_GetMouseWorld()
	return world2gui( m_x, m_y )
end

function slot_z( data, id, z )
	return data.dragger.item_id == id and z-2 or z
end

function capitalizer( text )
	return string.gsub( string.gsub( tostring( text ), "%s%l", string.upper ), "^%l", string.upper )
end

function space_obliterator( txt )
	return tostring( string.gsub( tostring( txt ), "%s+$", "" ))
end

function liner( text, length, height, length_k, clean_mode, forced_reverse )
	local formated = {}
	if( text ~= nil and text ~= "" ) then
		local length_counter = 0
		if( height ~= nil ) then
			length_k = length_k or 6
			length = math.floor( length/length_k + 0.5 )
			height = math.floor( height/9 )
			local height_counter = 1
			
			local full_text = "@"..text.."@"
			for line in string.gmatch( full_text, "([^@]+)" ) do
				local rest = ""
				local buffer = ""
				local dont_touch = false
				
				length_counter = 0
				text = ""
				
				local words = t2w( line )
				for i,word in ipairs( words ) do
					buffer = word
					local w_length = string.len( buffer ) + 1
					length_counter = length_counter + w_length
					dont_touch = false
					
					if( length_counter > length ) then
						if( w_length >= length ) then
							rest = string.sub( buffer, length - ( length_counter - w_length - 1 ), w_length )
							text = text..buffer.." "
						else
							length_counter = w_length
						end
						table.insert( formated, tostring( string.gsub( string.sub( text, 1, length ), "@ ", "" )))
						height_counter = height_counter + 1
						text = ""
						while( rest ~= "" ) do
							w_length = string.len( rest ) + 1
							length_counter = w_length
							buffer = rest
							if( length_counter > length ) then
								rest = string.sub( rest, length + 1, w_length )
								table.insert( formated, tostring( string.sub( buffer, 1, length )))
								dont_touch = true
								height_counter = height_counter + 1
							else
								rest = ""
								length_counter = w_length
							end
							
							if( height_counter > height ) then
								break
							end
						end
					end
					
					if( height_counter > height ) then
						break
					end
					
					text = text..buffer.." "
				end
				
				if( not( dont_touch )) then
					table.insert( formated, tostring( string.sub( text, 1, length )))
				end
			end
		else
			local gui = GuiCreate()
			GuiStartFrame( gui )
			
			local starter = math.floor( math.abs( length )/7 + 0.5 )
			local total_length = string.len( text )
			if( starter < total_length ) then
				if(( length > 0 ) and forced_reverse == nil ) then
					length = math.abs( length )
					formated = string.sub( text, 1, starter )
					for i = starter + 1,total_length do
						formated = formated..string.sub( text, i, i )
						length_counter = GuiGetTextDimensions( gui, formated, 1, 2 )
						if( length_counter > length ) then
							formated = string.sub( formated, 1, string.len( formated ) - 1 )
							break
						end
					end
				else
					length = math.abs( length )
					starter = total_length - starter
					formated = string.sub( text, starter, total_length )
					while starter > 0 do
						starter = starter - 1
						formated = string.sub( text, starter, starter )..formated
						length_counter = GuiGetTextDimensions( gui, formated, 1, 2 )
						if( length_counter > length ) then
							formated = string.sub( formated, 2, string.len( formated ))
							break
						end
					end
				end
			else
				formated = text
			end
			
			GuiDestroy( gui )
		end
	else
		if( clean_mode == nil ) then
			table.insert( formated, "[NIL]" )
		else
			formated = ""
		end
	end
	
	return formated
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

function get_stain_perc( perc )
	local some_cancer = 14/99
	return math.max( math.floor( 100*( perc - some_cancer )/( 1 - some_cancer ) + 0.5 ), 0 )
end

function get_effect_timer( secs, skip_num )
	if( secs < 0 ) then
		return ""
	else
		local is_tiny = secs < 1
		secs = string.format( "%."..b2n( is_tiny ).."f", secs )
		if( not( skip_num or false )) then
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

function simple_anim( data, name, target, speed, min_delta )
	speed = speed or 0.1
	min_delta = min_delta or 1
	
	data.memo[name] = data.memo[name] or 0
	local delta = target - data.memo[name]
	data.memo[name] = data.memo[name] + limiter( limiter( speed*delta, min_delta, true ), delta )
	return data.memo[name]
end

function get_short_num( num, negative_inf )
	negative_inf = negative_inf or false

	if( num < 0 and negative_inf ) then
		return "i"
	else
		num = math.max( num, 0 )
	end
	if( num < 999e12 ) then
		local sstr = string.format( "%.0f", num )
		
		local ender = { 12, "T" }
		if( num < 10^4 ) then
			ender = { 0, ""}
		elseif( num < 10^6 ) then
			ender = { 3, "K" }
		elseif( num < 10^9 ) then
			ender = { 6, "M" }
		elseif( num < 10^12 ) then
			ender = { 9, "B" }
		end

		num = string.sub( sstr, 1, #sstr - ender[1])..ender[2]
	elseif( num < 9e99 ) then
		num = tostring( string.format("%e", num ))
		local _, pos = string.find( num, "+", 1, true )
		num = string.sub( num, 1, 1 ).."e"..string.sub( 100 + tonumber( string.sub( num, pos+1, #num )), 2 )
	else
		num = "i"
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

function register_item_pic( data, this_data, is_advanced )
	item_pic_data[ this_data.pic ] = item_pic_data[ this_data.pic ] or {xy={0,0}, xml_xy={0,0}}
	if( item_pic_data[ this_data.pic ].dims == nil ) then
		item_pic_data[ this_data.pic ].dims = { get_pic_dim( this_data.pic )}

		local is_xml = string.sub( this_data.pic, -4 ) == ".xml" and is_advanced

		local storage_anim = get_storage( this_data.id, "index_pic_anim" )
		if( storage_anim ~= nil ) then
			item_pic_data[ this_data.pic ].anim = D_extractor( ComponentGetValue2( storage_anim, "value_string" ))
		end

		local storage_off = get_storage( this_data.id, "index_pic_offset" )
		if( storage_off ~= nil ) then
			item_pic_data[ this_data.pic ].xy = D_extractor( ComponentGetValue2( storage_off, "value_string" ), true )
		elseif( not( is_xml )) then
			if( is_advanced ) then
				local pic_comp = EntityGetFirstComponentIncludingDisabled( this_data.id, "SpriteComponent", "item" )
				if( pic_comp == nil ) then
					pic_comp = EntityGetFirstComponentIncludingDisabled( this_data.id, "SpriteComponent", "enabled_in_hand" )
				end
				if( pic_comp ~= nil ) then
					item_pic_data[ this_data.pic ].xy = { ComponentGetValue2( pic_comp, "offset_x" ), ComponentGetValue2( pic_comp, "offset_y" )}
				end
			else
				item_pic_data[ this_data.pic ].xy = { item_pic_data[ this_data.pic ].dims[1]/2, item_pic_data[ this_data.pic ].dims[2]/2 }
			end
		end
		
		if( is_xml and ModIsEnabled( "penman" )) then
			dofile_once( "mods/penman/lib.lua" )
			if( item_pic_data[ this_data.pic ].penman == nil ) then
				item_pic_data[ this_data.pic ].penman = penman_read( this_data.pic )
				item_pic_data[ this_data.pic ].dims = nil
				this_data.pic = data.nopixel
			elseif( type( item_pic_data[ this_data.pic ].penman ) == "number" ) then
				local nxml = dofile_once( "mods/index_core/nxml.lua" )
				local xml = nxml.parse( penman_restore( penman_return( item_pic_data[ this_data.pic ].penman )))
				local xml_kid = xml:first_of( "RectAnimation" )
				if( xml_kid.attr.has_offset ) then
					item_pic_data[ this_data.pic ].xml_xy = { -xml_kid.attr.offset_x, -xml_kid.attr.offset_y }
				else
					item_pic_data[ this_data.pic ].xml_xy = { -xml.attr.offset_x, -xml.attr.offset_y }
				end
				item_pic_data[ this_data.pic ].dims = { xml_kid.attr.frame_width, xml_kid.attr.frame_height }
				if( xml_kid.attr.shrink_by_one_pixel ) then
					item_pic_data[ this_data.pic ].dims[1] = item_pic_data[ this_data.pic ].dims[1] + 1
					item_pic_data[ this_data.pic ].dims[2] = item_pic_data[ this_data.pic ].dims[2] + 1
				end
			end
		end
	end

	return this_data.pic
end

--GUI frontend
function gui_killer( gui )
	if( gui ~= nil ) then
		GuiDestroy( gui )
	end
end

function colourer( gui, c_type, alpha )
	c_type = c_type or {}
	if( #c_type == 0 and alpha == nil ) then
		return
	end

	local color = { r = 0, g = 0, b = 0 }
	if( type( c_type ) == "table" ) then
		color.r = c_type[1] or 255
		color.g = c_type[2] or 255
		color.b = c_type[3] or 255
	end
	GuiColorSetForNextWidget( gui, color.r/255, color.g/255, color.b/255, alpha or c_type[4] or 1 )
end

function new_text( gui, pic_x, pic_y, pic_z, text, colours, alpha )
	local out_str = {}
	if( text ~= nil ) then
		if( type( text ) == "table" ) then
			out_str = text
		else
			table.insert( out_str, text )
		end
	else
		table.insert( out_str, "[NIL]" )
	end
	
	for i,line in ipairs( out_str ) do
		colourer( gui, colours, alpha )
		GuiZSetForNextWidget( gui, pic_z )
		GuiText( gui, pic_x, pic_y, line )
		pic_y = pic_y + 9
	end
end

function new_image( gui, uid, pic_x, pic_y, pic_z, pic, s_x, s_y, alpha, interactive, angle )
	if( not( interactive or false )) then
		GuiOptionsAddForNextWidget( gui, 2 ) --NonInteractive
	end
	GuiZSetForNextWidget( gui, pic_z )
	if( uid >= 0 ) then GuiIdPush( gui, uid ) end
	uid = math.abs( uid ) + 1
	GuiImage( gui, uid, pic_x, pic_y, pic, alpha or 1, s_x or 1, s_y or 1, angle )
	return uid
end

function new_button( gui, uid, pic_x, pic_y, pic_z, pic )
	GuiZSetForNextWidget( gui, pic_z )
	uid = uid + 1
	GuiIdPush( gui, uid )
	GuiOptionsAddForNextWidget( gui, 6 ) --NoPositionTween
	GuiOptionsAddForNextWidget( gui, 4 ) --ClickCancelsDoubleClick
	GuiOptionsAddForNextWidget( gui, 21 ) --DrawNoHoverAnimation
	GuiOptionsAddForNextWidget( gui, 47 ) --NoSound
	local clicked, r_clicked = GuiImageButton( gui, uid, pic_x, pic_y, "", pic )
	return uid, clicked, r_clicked
end

function new_dragger( gui, pic_x, pic_y ) --you need to uid them manually
	local is_going = false
	
	GuiOptionsAddForNextWidget( gui, 51 ) --IsExtraDraggable
	new_button( gui, 1023, 0, 0, -999999, "mods/index_core/files/pics/null_fullhd.png" )
	local clicked, r_clicked, hovered, _, _, _, _, d_x, d_y = GuiGetPreviousWidgetInfo( gui )
	if( d_x ~= 0 and d_y ~= 0 ) then
		pic_x = d_x
		pic_y = d_y
		is_going = true
	end
	
	return pic_x, pic_y, is_going, clicked, r_clicked, hovered
end

function new_shadow_text( gui, pic_x, pic_y, pic_z, text, alpha )
	new_text( gui, pic_x, pic_y, pic_z - 0.01, text, nil, alpha )
	new_text( gui, pic_x, pic_y + 1, pic_z, text, { 0, 0, 0 }, alpha )
end

function new_anim_looped( core_path, delay, duration )
	local num = math.floor( GameGetFrameNum()/tonumber( delay ))%tonumber( duration ) + 1
	return core_path..num..".png"
end

function new_font( gui, uid, pic_x, pic_y, pic_z, font_path, txt, colours )
	uid = uid + 1
	txt = tostring( txt )
	colours = colours or {}

	local drift = 0
	local data = dofile( font_path.."data.lua" )
	for c in string.gmatch( txt, "." ) do
		if( c == " " ) then
			drift = drift + data.space
		else
			local pic = font_path..( data[string.byte(c)] or c )..".png"
			colourer( gui, colours )
			new_image( gui, -uid, pic_x + drift, pic_y, pic_z, pic, 1, 1, colours[4])
			drift = drift + get_pic_dim( pic ) + data.step
		end
	end

	return uid, drift
end

function new_font_vanilla_small( gui, uid, pic_x, pic_y, pic_z, txt, colours )
	return new_font( gui, uid, pic_x, pic_y, pic_z, "mods/index_core/files/fonts/vanilla_small/", txt, colours )
end

function new_interface( gui, uid, pos, pic_z, is_debugging )
	local x, y, s_x, s_y = pos[1], pos[2], math.abs( pos[3] or 1 ), math.abs( pos[4] or 1 )

	local is_vertical = s_x < s_y
	local width = is_vertical and s_x or s_y
	local clicked, r_clicked, hovered = false, false, false
	
	local function do_interface( p_x, p_y )
		uid = new_image( gui, uid, p_x, p_y, pic_z, "data/ui_gfx/empty"..( is_debugging and "_white" or "" )..".png", width/2, width/2, 0.75, true )
		local c, r_c, h = GuiGetPreviousWidgetInfo( gui )
		clicked, r_clicked, hovered = clicked or c, r_clicked or r_c, hovered or h
	end
	
	if( s_x ~= 0 and s_y ~= 0 ) then
		local count = math.floor( is_vertical and s_y/s_x or s_x/s_y )
		for i = 1,count do
			do_interface( x, y )
			if( is_vertical ) then
				y = y + width
			else
				x = x + width
			end
		end
		local leftover = ( is_vertical and s_y or s_x ) - count*width
		if( leftover > 0 ) then
			local drift = width - leftover
			if( is_vertical ) then
				y = y - drift
			else
				x = x - drift
			end
			do_interface( x, y )
		end
	end

	return uid, clicked, r_clicked, hovered
end

function new_pickup_info( gui, uid, screen_h, screen_w, data, pickup_info, zs, xyz )
	if(( pickup_info.desc or "" ) ~= "" ) then
		if( type( pickup_info.desc ) ~= "table" ) then
			pickup_info.desc = { pickup_info.desc, false }
		end
		if( pickup_info.desc[1] ~= "" ) then
			local w, h = get_text_dim( pickup_info.desc[1])
			if( pickup_info.desc[2] == true ) then colourer( gui, {208,70,70}) end
			new_shadow_text( gui, ( screen_w - w )/2, screen_h - 40, zs.in_world_ui, pickup_info.desc[1])
			if( type( pickup_info.desc[2]) == "string" and pickup_info.desc[2] ~= "" ) then
				w, h = get_text_dim( pickup_info.desc[2])
				new_text( gui, ( screen_w - w )/2, screen_h - 28, zs.in_world_ui, pickup_info.desc[2], {127,127,127})
			end
		end
	end
	if( pickup_info.id > 0 and not( data.is_opened ) and ( data.in_world_pickups or EntityHasTag( pickup_info.id, "index_txt" ))) then
		if(( pickup_info.txt or "" ) ~= "" ) then
			local x, y = EntityGetTransform( pickup_info.id )
			local pic_x, pic_y = world2gui( x, y )
			local w, h = get_text_dim( pickup_info.txt )
			colourer( gui, {200,200,200})
			new_shadow_text( gui, pic_x - w/2 + 2, pic_y + 3, zs.in_world_front, pickup_info.txt )
		end
	end

	return uid
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

function new_vanilla_plate( gui, uid, pic_x, pic_y, pic_z, dims )
	uid = new_image( gui, uid, pic_x, pic_y, pic_z, "mods/index_core/files/pics/vanilla_plate.xml", dims[1], dims[2])

	uid = new_image( gui, uid, pic_x - 2, pic_y - 2, pic_z, "mods/index_core/files/pics/vanilla_plate_a1.xml" )
	uid = new_image( gui, uid, pic_x + dims[1], pic_y - 2, pic_z, "mods/index_core/files/pics/vanilla_plate_a2.xml" )
	uid = new_image( gui, uid, pic_x + dims[1], pic_y + dims[2], pic_z, "mods/index_core/files/pics/vanilla_plate_a3.xml" )
	uid = new_image( gui, uid, pic_x - 2, pic_y + dims[2], pic_z, "mods/index_core/files/pics/vanilla_plate_a4.xml" )

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
		uid = new_image( gui, uid, pic_x + temp, pic_y - 2, pic_z, "mods/index_core/files/pics/vanilla_plate_b"..pic_id..".xml" )
		uid = new_image( gui, uid, pic_x + temp, pic_y + dims[2], pic_z, "mods/index_core/files/pics/vanilla_plate_c"..pic_id..".xml" )
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
		uid = new_image( gui, uid, pic_x - 2, pic_y + temp, pic_z, "mods/index_core/files/pics/vanilla_plate_d"..pic_id..".xml" )
		uid = new_image( gui, uid, pic_x + dims[1], pic_y + temp, pic_z, "mods/index_core/files/pics/vanilla_plate_e"..pic_id..".xml" )
		temp = temp + steps[pic_id]
	end

	return uid
end

function new_vanilla_bar( gui, uid, pic_x, pic_y, zs, dims, bar_pic, shake_frame, bar_alpha )
	local will_shake = shake_frame ~= nil
	if( will_shake ) then
		if( shake_frame < 0 ) then
			shake_frame = shake_frame + 1
			pic_x = pic_x + 10*math.sin( shake_frame*math.pi/6 )/shake_frame
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

function new_vanilla_tooltip( gui, uid, tid, z, text, extra_func, is_triggered, is_right, is_up )
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
			pic_x, pic_y = text[2] or ( pic_x + 5 ), text[3] or ( pic_y + 5 )
			
			local length = 0
			if( text[1] ~= "" ) then
				text[1] = string.gsub( text[1], "\n", "@" )
				text[1] = liner( text[1], w*0.9, h - 2, 5.8 )
				for i,line in ipairs( text[1]) do
					local current_length = GuiGetTextDimensions( gui, line, 1, 2 )
					if( current_length > length ) then
						length = current_length
					end
				end
			end
			
			local edge_spacing = 3
			local x_offset, y_offset = text[4] or length, text[5] or 9*#text[1]
			x_offset, y_offset = x_offset + edge_spacing - 1, y_offset + edge_spacing
			
			if( is_right or is_up ) then
				if( is_right ) then
					pic_x = pic_x - x_offset - 1
				end
				if( is_up ) then
					pic_y = pic_y - y_offset + 9 + edge_spacing
				end
			else
				if( w < pic_x + x_offset + 1 ) then
					pic_x = w - x_offset - 1
				end
				if( h < pic_y + y_offset + 1 ) then
					pic_y = h - y_offset - 1
				end
			end

			local inter_alpha = math.sin( math.min( anim_frame, 10 )*math.pi/20 )
			if( type( extra_func[1] ) == "function" ) then
				uid = extra_func[1]( gui, uid, pic_x + 2, pic_y + 2, z, inter_alpha, extra_func[2])
			else
				new_shadow_text( gui, pic_x + 3, pic_y + 1, z, text[1], inter_alpha )
			end
			
			anim_frame = anim_frame + 1
			local inter_size = 30*math.sin( anim_frame*0.3937 )/anim_frame
			pic_x, pic_y = pic_x + 0.5*inter_size, pic_y + 0.5*inter_size
			x_offset, y_offset = x_offset - inter_size, y_offset - inter_size
			inter_alpha = math.max( 1 - inter_alpha/6, 0.1 )

			local gui_core = "mods/index_core/files/pics/vanilla_tooltip_"
			uid = new_image( gui, uid, pic_x, pic_y, z + 0.01, gui_core.."0.xml", x_offset, y_offset, inter_alpha )
			local lines = {{0,-1,x_offset-1,1},{-1,0,1,y_offset-1},{1,y_offset,x_offset-1,1},{x_offset,1,1,y_offset-1}}
			for i,line in ipairs( lines ) do
				uid = new_image( gui, uid, pic_x + line[1], pic_y + line[2], z, gui_core.."1.xml", line[3], line[4], inter_alpha )
			end
			local dots = {{-1,-1},{x_offset-1,-1},{x_offset,0},{-1,y_offset-1},{0,y_offset},{x_offset,y_offset}}
			for i,dot in ipairs( dots ) do
				uid = new_image( gui, uid, pic_x + dot[1], pic_y + dot[2], z, gui_core.."2.xml", 1, 1, inter_alpha )
			end
		end
	end
	
	return uid, is_triggered
end

function tipping( gui, uid, tid, pos, tip, zs, is_right, is_debugging )
	if( type( zs ) ~= "table" ) then
		zs = {zs}
	end
	local clicked, r_clicked, is_hovered = false
	uid, clicked, r_clicked, is_hovered = new_interface( gui, uid, pos, zs[1], is_debugging )
	if( zs[2] ~= nil and is_hovered ) then
		uid = new_image( gui, uid, pos[1], pos[2], zs[2], "data/ui_gfx/hud/colors_reload_bar_bg_flash.png", pos[3]/2, pos[4]/2, 0.5 )
	end
	is_right = is_right or false
	
	local out = { new_vanilla_tooltip( gui, uid, tid, zs[1], { tip[1], tip[2], tip[3], tip[4], tip[5] }, nil, is_hovered, is_right )}
	table.insert( out, clicked )
	table.insert( out, r_clicked )
	return unpack( out )
end

function new_slot_pic( gui, uid, pic_x, pic_y, z, pic, alpha, angle, hov_scale, fancy_shadow )
	angle = angle or 0
	fancy_shadow = fancy_shadow or false
	scale_up = scale_up or false
	item_pic_data[ pic ] = item_pic_data[ pic ] or {
		xy = { 0, 0 },
		xml_xy = { 0, 0 },
		dims = { get_pic_dim( pic )},
	}
	
	local w, h = unpack( item_pic_data[ pic ].dims or {1,1})
	local off_x, off_y = 0, 0
	if( item_pic_data[ pic ].xy[1] ~= 0 or item_pic_data[ pic ].xy[2] ~= 0 ) then
		local x, y = unpack( item_pic_data[ pic ].xy )
		x, y = rotate_offset( x, y, angle )
		off_x, off_y = off_x + x, off_y + y
	end
	if( item_pic_data[ pic ].anim ) then
		pic = new_anim_looped( unpack( item_pic_data[ pic ].anim ))
	end
	
	local extra_scale = hov_scale or 1
	pic_x, pic_y = pic_x - extra_scale*off_x, pic_y - extra_scale*off_y
	uid = new_image( gui, uid, pic_x, pic_y, z - 0.002, pic, extra_scale, extra_scale, alpha, false, angle )

	local sign = fancy_shadow and 1 or -1
	local scale_x, scale_y = 1/w + 1, 1/h + 1
	colourer( gui, {0,0,0})
	off_x, off_y = rotate_offset( sign*0.5, sign*0.5, angle )
	uid = new_image( gui, uid, pic_x + extra_scale*off_x, pic_y + extra_scale*off_y, z, pic, extra_scale*scale_x, extra_scale*scale_y, 0.25, false, angle )
	
	return uid, pic_x, pic_y
end

function new_icon( gui, uid, pic_x, pic_y, pic_z, info, kind )
	local pic_off_x, pic_off_y = 0, 0
	if( kind == 2 ) then
		pic_off_x, pic_off_y = 0.5, 0.5
	elseif( kind == 4 ) then
		pic_off_x, pic_off_y = -2.5, 0
	end

    local w, h = get_pic_dim( info.pic )
	uid = new_image( gui, uid, pic_x + pic_off_x, pic_y + pic_off_y, pic_z, info.pic, nil, nil, kind == 2 and math.min( 0.15*( 3 + 5*info.amount ), 1 ) or 1, true )
	local _, _, is_hovered = GuiGetPreviousWidgetInfo( gui )

	if( kind == 2 and info.amount > 0 ) then
		GuiColorSetForNextWidget( gui, 0.3, 0.3, 0.3, 1 )
		uid = new_image( gui, uid, pic_x + pic_off_x, pic_y + pic_off_y, pic_z + 0.003, info.pic, nil, nil, 0.5 )
		
		local scale = 10*info.amount
		local pos = 10*( 1 - info.amount )
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

	info.txt = space_obliterator( info.txt )
	info.desc = space_obliterator( info.desc )

	local tip_x, tip_y = pic_x - 3, pic_y
	if( info.txt ~= "" ) then
		local t_x, t_h = get_text_dim( info.txt )
		t_x = t_x - txt_off_x
		new_shadow_text( gui, pic_x - ( t_x + 1 ), pic_y + 1 + txt_off_y, pic_z, info.txt, is_hovered and 1 or 0.5 )
		tip_x = tip_x - t_x
	end
	if(( info.count or 0 ) > 1 ) then
		new_shadow_text( gui, pic_x + 15, pic_y + 1 + txt_off_y, pic_z, "x"..info.count, is_hovered and 1 or 0.5 )
	end
	if( kind == 4 ) then
		pic_y = pic_y - 3
	end
	if( info.desc ~= "" and is_hovered and tip_anim["generic"][1] > 0 ) then
		local anim = math.sin( math.min( tip_anim["generic"][3], 10 )*math.pi/20 )
		local t_x, t_h = get_text_dim( info.desc )
		new_text( gui, pic_x - t_x + w, pic_y + h + 2, pic_z, info.desc, info.is_danger and {224,96,96} or nil, anim )
		
		local bg_x = pic_x - ( t_x + 2 ) + w
		local bg_pic = "mods/index_core/files/pics/vanilla_tooltip_"
		uid = new_image( gui, uid, bg_x, pic_y + h + 2, pic_z + 0.01, bg_pic.."2.xml", t_x + 3, 1, anim*0.5 )
		uid = new_image( gui, uid, bg_x, pic_y + h + 3, pic_z + 0.01, bg_pic.."0.xml", t_x + 3, 8, anim*0.8 )
		uid = new_image( gui, uid, bg_x, pic_y + h + 11, pic_z + 0.01, bg_pic.."2.xml", t_x + 3, 1, anim*0.5 )
		
		h = h + t_h + ( kind == 4 and 2 or 4 ) + ( kind == 1 and 1 or 0 )
	end
	if( info.tip ~= "" ) then
		local is_func = type( info.tip ) == "function"
		local v = { is_func and "" or space_obliterator( info.tip ), tip_x, tip_y + ( kind == 4 and 1 or 0 ), }
		if( is_func ) then
			v[4] = math.min( #info.other_perks, 10 )*14-1
			v[5] = 14*math.max( math.ceil(( #info.other_perks )/10 ), 1 )
		end
		uid = new_vanilla_tooltip( gui, uid, nil, pic_z - 5, v, { info.tip, info.other_perks }, is_hovered, true, true )
	end

	if( kind == 1 ) then
		uid = new_image( gui, uid, pic_x, pic_y, pic_z + 0.002, "data/ui_gfx/status_indicators/bg_ingestion.png" )
		
		local d_frame = info.digestion_delay
		if( info.is_stomach and d_frame > 0 ) then
			uid = new_image( gui, uid, pic_x + 1, pic_y + 1 + 10*( 1 - d_frame ), pic_z + 0.001, "mods/index_core/files/pics/vanilla_stomach_bg.xml", 10, math.ceil( 20*d_frame )/2, 0.3 )
		end
	end

	return uid, w, h
end

function new_slot( gui, uid, pic_x, pic_y, zs, data, slot_data, info, cat_tbl, is_active, can_drag, is_full, is_quick )
	cat_tbl = cat_tbl or {}
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
	
	if( info.id > 0 ) then
		if( EntityHasTag( info.id, "index_locked" )) then
			can_drag = false
		end
		if( data.dragger.item_id == info.id ) then
			colourer( data.the_gui, {150,150,150})
		end
	end
	local pic_bg, clicked, r_clicked, is_hovered = ( is_full == true ) and data.slot_pic.bg_alt or data.slot_pic.bg, false, false, false
	local w, h = get_pic_dim( pic_bg )
	uid = new_image( data.the_gui, uid, pic_x, pic_y, zs.main_far_back, pic_bg, nil, nil, nil, true )
	local clicked, r_clicked, is_hovered = GuiGetPreviousWidgetInfo( data.the_gui )
	local might_swap = not( data.is_opened ) and is_quick and is_hovered
	if(( clicked or slot_data.force_equip ) and info.id > 0 ) then
		local do_default = might_swap or slot_data.force_equip
		if( cat_tbl.on_action ~= nil ) then
			if( cat_tbl.on_action( info.id, data, info, 1 )) then
				play_sound( data, slot_sfxes.select )
				do_default = false
			end
		end
		if( do_default and data.active_item ~= info.id ) then
			play_sound( data, slot_sfxes.select )
			ComponentSetValue2( data.inventory, "mActiveItem", 0 )
			ComponentSetValue2( data.inventory, "mActualActiveItem", 0 )
			ComponentSetValue2( data.inventory, "mInitialized", false )
			ComponentSetValue2( data.inventory, "mSavedActiveItemIndex", get_item_num( data, slot_data.inv_id, info.id ))
		end
	end
	
	local dragger_hovered = false
	pic_x, pic_y = pic_x + w/2, pic_y + h/2
	if( is_active ) then
		uid = new_image( gui, uid, pic_x, pic_y, zs.icons_front + 0.0001, data.slot_pic.active )
	end
	if( data.dragger.item_id > 0 ) then
		if( check_bounds( data.pointer_ui, {pic_x,pic_y}, {-w/2,w/2,-h/2,h/2})) then
			data.dragger.wont_drop = true
			
			if( can_drag ) then
				local dragged_data = from_tbl_with_id( data.item_list, data.dragger.item_id )
				if( slot_swap_check( data, dragged_data, info, slot_data )) then
					if( data.dragger.swap_now ) then
						if( info.id > 0 ) then
							table.insert( slot_anim, {
								id = info.id,
								x = pic_x,
								y = pic_y,
								frame = data.frame_num,
							})
						end
						play_sound( data, slot_sfxes[ info.id > 0 and "move_item" or "move_empty" ])
						
						--custom swap callback

						if( slot_swap( data.dragger.item_id, slot_data, data.active_item )) then
							ComponentSetValue2( data.inventory, "mActiveItem", 0 )
						end
						data.dragger.item_id = -1
					end
					if( slot_memo[ data.dragger.item_id ] and data.dragger.item_id ~= info.id ) then
						dragger_hovered = true
						uid = new_image( gui, uid, pic_x - w/2, pic_y - w/2, zs.icons_front + 0.00001, data.slot_pic.hl )
					end
				end
			end
		end
	end
	if((( info.id > 0 and is_hovered ) or dragger_hovered ) and not( slot_hover_sfx[2])) then
		local slot_uid = tonumber( slot_data.inv_id ).."|"..slot_data.inv_slot[1]..":"..slot_data.inv_slot[2]
		if( slot_hover_sfx[1] ~= slot_uid ) then
			slot_hover_sfx[1] = slot_uid
			play_sound( data, slot_sfxes.hover )
		end
		slot_hover_sfx[2] = true
	end
	
	if( can_drag ) then
		if( info.id > 0 and not( data.dragger.swap_now or slot_going )) then
			data, pic_x, pic_y = new_dragger_shell( info.id, info, pic_x, pic_y, w/2, h/2, data )
		end
	elseif( data.is_opened ) then
		uid = new_image( gui, uid, pic_x - 10, pic_y - w/2, zs.icons_front + 0.001, data.slot_pic.locked )
	end
	
	if( info.id > 0 ) then
		local is_dragged, suppress_action = slot_memo[ data.dragger.item_id ] and data.dragger.item_id == info.id, false
		if( cat_tbl.on_slot ~= nil ) then
			pic_x, pic_y = swap_anim( info.id, pic_x, pic_y, data )
			uid, suppress_action = cat_tbl.on_slot( gui, uid, info.id, data, info, pic_x, pic_y, zs, clicked, r_clicked, is_hovered, cat_tbl.on_tooltip, cat_tbl.on_action, is_full, is_active, is_quick, is_dragged, might_swap and 1.2 or 1 )
		end
		if( not( suppress_action or false )) then
			if( cat_tbl.on_action ~= nil ) then
                if( is_dragged ) then
                    if( data.drag_action ) then
                        cat_tbl.on_action( info.id, data, info, 3 )
                    end
                elseif( r_clicked and data.is_opened and is_quick ) then
					this_info.rmb_is_usable = is_quick
                    cat_tbl.on_action( info.id, data, info, 2 )
                end
            end
		end
	end
	
	return uid, data, w-1, h-1, clicked, r_clicked, is_hovered
end

function slot_setup( gui, uid, pic_x, pic_y, zs, data, slot_func, slot_data, can_drag, is_full, is_quick )
	local item = {}
	if( not( slot_data.id )) then
		slot_data.id = -1
		item = { id = slot_data.id }
	else
		item = from_tbl_with_id( data.item_list, slot_data.id )
	end

	local cat_callbacks = data.item_cats[ item.cat ]
	local w, h, clicked, r_clicked, is_hovered = false, false, false
	uid, data, w, h, clicked, r_clicked, is_hovered = slot_func( gui, uid, pic_x, pic_y, zs, data, slot_data, item, cat_callbacks, item.id == data.active_item, can_drag, is_full, is_quick )
	if( cat_callbacks ~= nil and cat_callbacks.on_inventory ~= nil ) then
		uid, data = cat_callbacks.on_inventory( gui, uid, item.id, data, item, pic_x, pic_y, zs, can_drag, data.dragger.item_id > 0 and data.dragger.item_id == item.id, item.id == data.active_item, is_quick )
	end
	
	return uid, w, h
end