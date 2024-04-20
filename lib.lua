MNEE_INITER = "MNEE_IS_GOING"
MNEE_TOGGLER = "MNEE_DISABLED"
MNEE_RETOGGLER = "MNEE_REDO"
MNEE_UPDATER = "MNEE_RELOAD"

MNEE_DIV_0 = "@"
MNEE_DIV_1 = "&"
MNEE_DIV_2 = "|"
MNEE_DIV_3 = "!"

MNEE_PTN_0 = "([^"..MNEE_DIV_0.."]+)"
MNEE_PTN_1 = "([^"..MNEE_DIV_1.."]+)"
MNEE_PTN_2 = "([^"..MNEE_DIV_2.."]+)"
MNEE_PTN_3 = "([^"..MNEE_DIV_3.."]+)"

MNEE_SPECIAL_KEYS = {
	-- left_shift = 1,
	-- right_shift = 1,
	left_ctrl = 1,
	right_ctrl = 1,
	left_alt = 1,
	right_alt = 1,
	-- left_windows = 1,
	-- right_windows = 1,
}

function get_sign( a )
	if( a < 0 ) then
		return -1
	else
		return 1
	end
end

function get_table_count( tbl )
	if( tbl == nil or type( tbl ) ~= "table" ) then
		return 0
	end
	
	local table_count = 0
	for i,element in pairs( tbl ) do
		table_count = table_count + 1
	end
	return table_count
end

function limiter( value, limit, max_mode )
	max_mode = max_mode or false
	limit = math.abs( limit )
	
	if(( max_mode and math.abs( value ) < limit ) or ( not( max_mode ) and math.abs( value ) > limit )) then
		return get_sign( value )*limit
	end
	
	return value
end

function mnee_extractor( data_raw )
	if( data_raw == MNEE_DIV_1 ) then
		return {}
	end
	
	local data = {}
	for value in string.gmatch( data_raw, MNEE_PTN_1 ) do
		table.insert( data, value )
	end
	
	return data
end

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

function get_next_jpad( init_only )
	for i,j in ipairs( jpad_states ) do
		local is_real = InputIsJoystickConnected( i - 1 ) > 0
		if( j < 0 ) then
			if( is_real ) then
				jpad_states[i] = 1
				jpad_count = jpad_count + 1
			end
		else
			if( is_real ) then
				if( j > 0 and not( init_only )) then
					jpad_states[i] = 0
					return i - 1
				end
			else
				for e,jp in ipairs( jpad ) do
					if( jp == ( i - 1 )) then
						jpad[e] = false
						break
					end
				end
				jpad_states[i] = -1
				jpad_count = jpad_count - 1
			end
		end
	end

	return false
end

function get_keys()
	local storage = get_storage( GameGetWorldStateEntity(), "mnee_down" ) or 0
	if( storage == 0 ) then
		return {}
	end
	
	return mnee_extractor( ComponentGetValue2( storage, "value_string" ))
end

function get_disarmer()
	local storage = get_storage( GameGetWorldStateEntity(), "mnee_disarmer" ) or 0
	if( storage == 0 ) then
		return {}
	end
	local data_raw = ComponentGetValue2( storage, "value_string" )
	if( data_raw == MNEE_DIV_1 ) then
		return {}
	end
	
	local data = {}
	for action in string.gmatch( data_raw, MNEE_PTN_1 ) do
		local val = {}
		for value in string.gmatch( action, MNEE_PTN_2 ) do
			table.insert( val, value )
		end
		if( #val > 0 ) then
			if( data[ val[1] ] == nil or ( val[2] > ( data[ val[1] ] or ( val[2] + 1 )))) then
				data[ val[1] ] = val[2]
			end
		end
	end
	
	return data
end

function clean_disarmer()
	local disarmer = get_disarmer()
	if( get_table_count( disarmer ) > 0 ) then
		local current_frame = GameGetFrameNum()
		
		local new_disarmer = MNEE_DIV_1
		for key,frame in pairs( disarmer ) do
			if( current_frame - tonumber( frame ) < 2 ) then
				new_disarmer = new_disarmer..MNEE_DIV_2..key..MNEE_DIV_2..frame..MNEE_DIV_2..MNEE_DIV_1
			end
		end
		
		local storage = get_storage( GameGetWorldStateEntity(), "mnee_disarmer" )
		ComponentSetValue2( storage, "value_string", new_disarmer )
	end
end

function add_disarmer( value )
	local storage = get_storage( GameGetWorldStateEntity(), "mnee_disarmer" ) or 0
	if( storage == 0 ) then
		return
	end
	ComponentSetValue2( storage, "value_string", ComponentGetValue2( storage, "value_string" )..( MNEE_DIV_2..value..MNEE_DIV_2..GameGetFrameNum()..MNEE_DIV_2 )..MNEE_DIV_1 )
end

function get_triggers()
	local storage = get_storage( GameGetWorldStateEntity(), "mnee_triggers" ) or 0
	if( storage == 0 ) then
		return {}
	end
	local triggers_raw = ComponentGetValue2( storage, "value_string" )
	if( triggers_raw == MNEE_DIV_1 ) then
		return {}
	end
	
	local triggers = {}
	for tr in string.gmatch( triggers_raw, MNEE_PTN_1 ) do
		local trigger = ""
		for val in string.gmatch( tr, MNEE_PTN_2 ) do
			if( trigger == "" ) then
				trigger = val
			else
				triggers[ trigger ] = tonumber( val )
			end
		end
	end
	
	return triggers
end

function get_axes()
	local storage = get_storage( GameGetWorldStateEntity(), "mnee_axis" ) or 0
	if( storage == 0 ) then
		return {}
	end
	local axes_raw = ComponentGetValue2( storage, "value_string" )
	if( axes_raw == MNEE_DIV_1 ) then
		return {}
	end
	
	local axes = {}
	for ax in string.gmatch( axes_raw, MNEE_PTN_1 ) do
		local axis = ""
		for val in string.gmatch( ax, MNEE_PTN_2 ) do
			if( axis == "" ) then
				axis = val
			else
				axes[ axis ] = tonumber( val )
			end
		end
	end
	
	return axes
end

function get_axis_memo()
	local storage = get_storage( GameGetWorldStateEntity(), "mnee_axis_memo" ) or 0
	if( storage == 0 ) then
		return {}
	end
	local memo_raw = ComponentGetValue2( storage, "value_string" )
	if( memo_raw == MNEE_DIV_1 ) then
		return {}
	end
	
	local data = {}
	for value in string.gmatch( memo_raw, MNEE_PTN_1 ) do
		data[ value ] = 1
	end
	
	return data
end

function toggle_axis_memo( name )
	local storage = get_storage( GameGetWorldStateEntity(), "mnee_axis_memo" ) or 0
	if( storage == 0 ) then
		return
	end
	local memo_raw = MNEE_DIV_1
	local memo = get_axis_memo()
	if( memo[ name ] == nil ) then
		memo_raw = ComponentGetValue2( storage, "value_string" )..name..MNEE_DIV_1
	else
		memo[ name ] = nil
		for nm in pairs( memo ) do
			memo_raw = memo_raw..nm..MNEE_DIV_1
		end
	end
	ComponentSetValue2( storage, "value_string", memo_raw )
end

function magic_sorter( tbl, func )
    local out_tbl = {}
    for n in pairs( tbl ) do
        table.insert( out_tbl, n )
    end
    table.sort( out_tbl, func )
	
    local i = 0
    local iter = function ()
        i = i + 1
        if( out_tbl[i] == nil ) then
            return nil
        else
            return out_tbl[i], tbl[out_tbl[i]]
        end
    end
    return iter
end

function axis_sorter( tbl, func )
	local out_tbl = {}
	for n in pairs( tbl ) do
		table.insert( out_tbl, n )
	end
	table.sort( out_tbl, function( a, b )
	    if( tbl[a].keys[1] == "is_axis" and tbl[b].keys[1] == "is_axis" ) then
			if( tbl[a].order_id ~= nil ) then print( tbl[a].order_id ) end
            return (( tbl[a].order_id or a ) < ( tbl[b].order_id or b ))
        else
		    return ( tbl[a].keys[1] == "is_axis" or ( tbl[b].keys[1] ~= "is_axis" and ( tbl[a].order_id or a ) < ( tbl[b].order_id or b )))
	    end
	end)
	
	local i = 0
	local iter = function ()
		i = i + 1
		if( out_tbl[i] == nil ) then
			return nil
		else
			return out_tbl[i], tbl[out_tbl[i]]
		end
	end
	return iter
end

function get_bindings( profile, binds_only )
	dofile_once( "mods/mnee/bindings.lua" )
	
	profile = profile or ModSettingGetNextValue( "mnee.PROFILE" )
	binds_only = binds_only or false
	
	local data_raw = ModSettingGetNextValue( "mnee.BINDINGS_"..profile )
	if( data_raw == MNEE_DIV_1 ) then
		return {}
	end
	
	local data = {}
	for mod in string.gmatch( data_raw, MNEE_PTN_1 ) do
		local mod_name = ""
		for v in string.gmatch( mod, MNEE_PTN_2 ) do
			if( mod_name ~= "" ) then
				local binding_name = ""
				for b in string.gmatch( v, MNEE_PTN_3 ) do
					if( binding_name ~= "" ) then
						if( b == "is_axis" or data[ mod_name ][ binding_name ][ "keys" ][1] == "is_axis" ) then
							table.insert( data[ mod_name ][ binding_name ][ "keys" ], b )
						else
							data[ mod_name ][ binding_name ].keys[ b ] = 1
						end
					elseif( binds_only or bindings[ mod_name ][ b ] ~= nil ) then
						binding_name = b
						data[ mod_name ][ binding_name ] = {}
						data[ mod_name ][ binding_name ][ "keys" ] = {}
						
						if( not( binds_only )) then
							data[ mod_name ][ binding_name ][ "order_id" ] = bindings[ mod_name ][ binding_name ].order_id
							data[ mod_name ][ binding_name ][ "is_locked" ] = bindings[ mod_name ][ binding_name ].is_locked
							data[ mod_name ][ binding_name ][ "name" ] = bindings[ mod_name ][ binding_name ].name
							data[ mod_name ][ binding_name ][ "desc" ] = bindings[ mod_name ][ binding_name ].desc
						end
					end
				end
			elseif( binds_only or bindings[ v ] ~= nil ) then
				mod_name = v
				data[ mod_name ] = {}
			end
		end
	end
	
	return data
end

function set_bindings( data, profile )
	if( data == nil ) then
		return
	end
	
	profile = profile or ModSettingGetNextValue( "mnee.PROFILE" )
	
	local data_raw = MNEE_DIV_1
	for mod,binds in pairs( data ) do
		data_raw = data_raw..MNEE_DIV_2..mod..MNEE_DIV_2
		for bind,info in axis_sorter( binds ) do
			data_raw = data_raw..MNEE_DIV_3..bind..MNEE_DIV_3
			for key,value in pairs( info.keys ) do
				data_raw = data_raw..( info.keys[1] == "is_axis" and value or key )..MNEE_DIV_3
			end
			data_raw = data_raw..MNEE_DIV_2
		end
		data_raw = data_raw..MNEE_DIV_1
	end
	
	ModSettingSetNextValue( "mnee.BINDINGS_"..profile, data_raw, false )
	GlobalsSetValue( MNEE_UPDATER, GameGetFrameNum())
end

function update_bindings( profile, reset )
	dofile_once( "mods/mnee/bindings.lua" )
	
	reset = reset or false
	
	local default = bindings
	local current = get_bindings( profile, true )
	local updated = false
	if( reset ) then
		updated = true
		current = default
	else
		for mod,binds in pairs( default ) do
			if( current[ mod ] == nil ) then
				current[ mod ] = binds
				updated = true
			else
				for bind,info in pairs( binds ) do
					if( current[ mod ][ bind ] == nil ) then
						current[ mod ][ bind ] = info
						updated = true
					end
				end
			end
		end
	end
	if( updated ) then
		set_bindings( current, profile )
	end
end

-- function priority_mode( mod_id )
	-- local vip_mod = GlobalsGetValue( "MNEE_PRIORITY_MOD", "0" )
	-- if( vip_mod == "0" ) then
		-- return true
	-- end
	
	-- return mod_id ~= vip_mod
-- end

function is_key_down( name, dirty_mode, pressed_mode, is_vip )
	dirty_mode = dirty_mode or false
	pressed_mode = pressed_mode or false
	is_vip = is_vip or false
	
	if( GameHasFlagRun( MNEE_TOGGLER ) and not( is_vip )) then
		return false
	end
	
	local keys_down = get_keys()
	if( #keys_down > 0 ) then
		if( not( dirty_mode )) then
			for i,key in ipairs( keys_down ) do
				if( MNEE_SPECIAL_KEYS[ key ] ~= nil ) then
					return false
				end
			end
		end
		
		for i,key in ipairs( keys_down ) do
			if( key == name ) then
				if( pressed_mode ) then
					local check = get_disarmer()[ "key"..key ] == nil
					add_disarmer( "key"..key )
					return check
				else
					return true
				end
			end
		end
	end
	
	return false
end

function get_key_pressed( name, dirty_mode, is_vip )
	return is_key_down( name, dirty_mode, true, is_vip or false )
end

function get_key_vip( name )
	return get_key_pressed( name, true, true )
end

function get_fancy_key( key )
	local lists = dofile_once( "mods/mnee/lists.lua" )
	return lists[5][key] or key
end

function get_binding_keys( mod_id, name, is_compact )
	is_compact = is_compact or false
	mnee_binding_data = mnee_binding_data or get_bindings()
	local binding = mnee_binding_data[ mod_id ][ name ]

	local symbols = is_compact and {"","-",""} or {"["," + ","]"}
	local out = symbols[1]
	for key in magic_sorter( binding.keys ) do
		out = out..get_fancy_key( key )..symbols[2]
	end
	
	out = string.sub( out, 1, -( #symbols[2] + 1 ))..symbols[3]
	if( is_compact ) then out = string.lower( out ) end
	return out
end

function is_binding_down( mod_id, name, dirty_mode, pressed_mode, is_vip, loose_mode )
	dirty_mode = dirty_mode or false
	pressed_mode = pressed_mode or false
	is_vip = is_vip or false
	loose_mode = loose_mode or false
	
	if( GameHasFlagRun( MNEE_TOGGLER ) and not( is_vip )) then
		return false
	end
	
	local keys_down = get_keys()
	if( #keys_down > 0 ) then
		local update_frame = tonumber( GlobalsGetValue( MNEE_UPDATER, "0" ))
		mnee_updater = mnee_updater or 0
		if( mnee_updater ~= update_frame ) then
			mnee_updater = update_frame
			mnee_binding_data = nil
		end
		mnee_binding_data = mnee_binding_data or get_bindings()
		
		local binding = mnee_binding_data[ mod_id ][ name ]
		if( binding ~= nil ) then
			binding = binding.keys
			
			local high_score = get_table_count( binding )
			if( high_score < 1 or ( high_score > 1 and not( loose_mode ) and high_score ~= #keys_down )) then
				return false
			end
			
			if( high_score == 1 and not( dirty_mode )) then
				for i,key in ipairs( keys_down ) do
					if( MNEE_SPECIAL_KEYS[ key ] ~= nil ) then
						return false
					end
				end
			end
			
			local score = 0
			for i,key in ipairs( keys_down ) do
				if( binding[ key ] ~= nil ) then
					score = score + 1
				end
			end
			
			if( score == high_score ) then
				if( pressed_mode ) then
					local check = get_disarmer()[ mod_id..name ] == nil
					add_disarmer( mod_id..name )
					return check
				else
					return true
				end
			end
		end
	end
	
	return false
end

function get_binding_pressed( mod_id, name, is_vip, dirty_mode, loose_mode )
	return is_binding_down( mod_id, name, dirty_mode or false, true, is_vip or false, loose_mode or false )
end

function get_binding_vip( mod_id, name )
	return get_binding_pressed( mod_id, name, true, true, true )
end

function get_axis_state( mod_id, name, dirty_mode, pressed_mode, is_vip )
	dirty_mode = dirty_mode or false
	pressed_mode = pressed_mode or false
	is_vip = is_vip or false
	
	if( GameHasFlagRun( MNEE_TOGGLER ) and not( is_vip )) then
		return 0
	end
	
	local update_frame = tonumber( GlobalsGetValue( MNEE_UPDATER, "0" ))
	mnee_updater = mnee_updater or 0
	if( mnee_updater ~= update_frame ) then
		mnee_updater = update_frame
		mnee_binding_data = nil
	end
	mnee_binding_data = mnee_binding_data or get_bindings()
	
	local binding = mnee_binding_data[ mod_id ][ name ]
	if( binding ~= nil ) then
		binding = binding.keys
		if( binding[3] == nil ) then
			local value = get_axes()[ binding[2]] or 0
			if( pressed_mode ) then
				local memo = get_axis_memo()
				if( memo[ binding[2]] == nil ) then
					if( math.abs( value ) > 500 ) then
						toggle_axis_memo( binding[2])
						return get_sign( value )
					end
				elseif( math.abs( value ) < 200 ) then
					toggle_axis_memo( binding[2])
				end
				
				return 0
			else
				return value
			end
		else
			if( is_key_down( binding[2], dirty_mode, pressed_mode, is_vip )) then
				return 1
			elseif( is_key_down( binding[3], dirty_mode, pressed_mode, is_vip )) then
				return -1
			else
				return 0
			end
		end
	end
end

function get_axis_pressed( mod_id, name, dirty_mode, is_vip )
	return get_axis_state( mod_id, name, dirty_mode or false, true, is_vip or false )
end

function get_axis_vip( mod_id, name )
	return get_axis_pressed( mod_id, name, true, true )
end

function get_shifted_value( c )
	local check = string.byte( c ) 
	if( check > 96 and check < 123 ) then
		return string.char( check - 32 )
	else
		local lists = dofile_once( "mods/mnee/lists.lua" )
		return lists[4][c] or c
	end
end

function get_keyboard_input( no_shifting )
	no_shifting = no_shifting or false
	local lists = dofile_once( "mods/mnee/lists.lua" )

	local is_shifted = not( no_shifting ) and ( InputIsKeyDown( 225 ) or InputIsKeyDown( 229 ))
	for i = 4,56 do
		if( InputIsKeyJustDown( i )) then
			local value = lists[1][i]
			if( is_shifted ) then
				value = get_shifted_value( value )
			elseif( i > 39 and i < 45 ) then
				if( i == 40 ) then
					value = 3
				elseif( i == 41 ) then
					value = 0
				elseif( i == 42 ) then
					value = 2
				elseif( i == 43 ) then
					value = 4
				elseif( i == 44 ) then
					value = " "
				end
			end
			return value
		end
	end
	for i = 1,10 do
		if( InputIsKeyJustDown( 88 + i )) then
			return string.sub( tostring( i ), -1 )
		end
	end
end