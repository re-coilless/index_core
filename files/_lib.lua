dofile_once( "data/scripts/lib/utilities.lua" )

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

function clean_append( to_file, from_file )
	local marker = "%-%-<{> MAGICAL APPEND MARKER <}>%-%-"
	local line_wrecker = "\n\n\n"
	
	local a = ModTextFileGetContent( to_file )
	local b = ModTextFileGetContent( from_file )
	ModTextFileSetContent( to_file, string.gsub( a, marker, b..line_wrecker..marker ))
end

function t2w( str )
	local t = {}
	
	for word in string.gmatch( str, "([^%s]+)" ) do
		table.insert( t, word )
	end
	
	return t
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

function get_sign( a )
	if( a < 0 ) then
		return -1
	else
		return 1
	end
end

function limiter( value, limit, max_mode )
	max_mode = max_mode or false
	limit = math.abs( limit )
	
	if(( max_mode and math.abs( value ) < limit ) or ( not( max_mode ) and math.abs( value ) > limit )) then
		return get_sign( value )*limit
	end
	
	return value
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

function access_list( storage, tbl )
	if( tbl == nil ) then
		local data_raw = ComponentGetValue2( storage, "value_string" )
		if( data_raw == "@" ) then
			return {}
		end
		
		local data = {}
		
		for style in string.gmatch( data_raw, "([^@]+)" ) do
			table.insert( data, style )
		end
		
		return data
	else
		local storage_styles = storage
		local value = "@"
		if( #tbl > 0 ) then
			for i,style in ipairs( tbl ) do
				value = value..style.."@"
			end
		end
		ComponentSetValue2( storage_styles, "value_string", value )
		
		return value
	end
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

function get_matter( matters, id )
	local max_matter = { 0, 0 }
	if( #matters > 0 ) then
		for i,matter in ipairs( matters ) do
			if( id ~= nil and id == i - 1 ) then
				return { id, matter }
			elseif( matter > max_matter[2] ) then
				max_matter[1] = i - 1
				max_matter[2] = matter
			end
		end
	end
	return max_matter
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

function get_active_wand( hooman )
	local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
	if( inv_comp ~= nil ) then
		return tonumber( ComponentGetValue2( inv_comp, "mActiveItem" ) or 0 )
	end
	
	return 0
end

function get_item_name( entity_id, item_comp )
	return GameTextGetTranslatedOrNot( ComponentGetValue2( item_comp, "always_use_item_name_in_ui" ) and ( EntityGetName( entity_id ) or "" ) or ComponentGetValue2( item_comp, "item_name" ))
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

function play_sound( event )
	local c_x, c_y = GameGetCameraPos()
	GamePlaySound( "mods/mrshll_core/mrshll.bank", event, c_x, c_y )
end

function get_uint_color( color )
	return { bit.band( color, 0xff ), bit.band( bit.rshift( color, 8 ), 0xff ), bit.band( bit.rshift( color, 16 ), 0xff )}
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

function gui_killer( gui )
	if( gui ~= nil ) then
		GuiDestroy( gui )
	end
end

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

function capitalizer( text )
	text = tostring( text )
	return string.upper( string.sub( text, 1, 1 ))..string.sub( text, 2 )
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

function get_mouse_pos()
	local m_x, m_y = DEBUG_GetMouseWorld()
	return world2gui( m_x, m_y )
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

function new_image( gui, uid, pic_x, pic_y, pic_z, pic, s_x, s_y, alpha, interactive )
	if( not( interactive or false )) then
		GuiOptionsAddForNextWidget( gui, 2 ) --NonInteractive
	end
	GuiZSetForNextWidget( gui, pic_z )
	uid = uid + 1
	GuiIdPush( gui, uid )
	GuiImage( gui, uid, pic_x, pic_y, pic, alpha or 1, s_x or 1, s_y or 1 )
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
			new_image( gui, uid, pic_x + drift, pic_y, pic_z, pic, 1, 1, colours[4])
			drift = drift + get_pic_dim( pic ) + data.step
		end
	end

	return uid, drift
end

function new_font_vanilla_small( gui, uid, pic_x, pic_y, pic_z, txt, colours )
	return new_font( gui, uid, pic_x, pic_y, pic_z, "mods/index_core/files/fonts/vanilla_small/", txt, colours )
end

function new_tooltip( gui, uid, z, text, extra_func, is_triggered )
	is_triggered = is_triggered or false

	local _, _, is_hovered = GuiGetPreviousWidgetInfo( gui )
	if( is_hovered or is_triggered ) then
		if( not( tip_going )) then
			tip_going = true

			local frame_num = GameGetFrameNum()
			tip_anim[2] = frame_num
			if( tip_anim[1] == 0 ) then
				tip_anim[1] = frame_num
				return uid
			end
			local anim_frame = tip_anim[3]

			if( type( text ) ~= "table" ) then
				text = { text }
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
			
			local is_right = extra_func == "is_right"
			if( is_right ) then
				pic_x = pic_x - x_offset - 1
			else
				if( w < pic_x + x_offset + 1 ) then
					pic_x = w - x_offset - 1
				end
				if( h < pic_y + y_offset + 1 ) then
					pic_y = h - y_offset - 1
				end
			end

			local inter_alpha = math.sin( math.min( anim_frame, 10 )*math.pi/20 )
			if( type( extra_func or "" ) == "function" ) then
				uid = extra_func( gui, uid, pic_x + 2, pic_y + 2, z, inter_alpha )
			else
				new_text( gui, pic_x + 3, pic_y + 1, z - 0.01, text[1], { 255, 255, 255 }, inter_alpha )
				new_text( gui, pic_x + 3, pic_y + 2, z, text[1], { 0, 0, 0 }, inter_alpha )
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
	
	return uid
end

function tipping( gui, uid, pos, tip, zs, is_right, is_debugging )
	if( type( zs ) ~= "table" ) then
		zs = {zs}
	end
	local x, y, s_x, s_y = pos[1], pos[2], math.abs( pos[3] or 1 ), math.abs( pos[4] or 1 )

	local is_vertical = s_x < s_y
	local width = is_vertical and s_x or s_y
	local clicked, r_clicked, hovered = false, false, false
	
	local function do_interface( p_x, p_y )
		new_image( gui, uid, p_x, p_y, zs[1], "data/ui_gfx/empty"..( is_debugging and "_white" or "" )..".png", width/2, width/2, 0.75, true )
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

	if( zs[2] ~= nil and hovered ) then
		uid = new_image( gui, uid, pos[1], pos[2], zs[2], "data/ui_gfx/hud/colors_reload_bar_bg_flash.png", s_x/2, s_y/2, 0.5 )
	end
	is_right = is_right or false
	return new_tooltip( gui, uid + 1, zs[1], { tip[1], tip[2], tip[3], tip[4], tip[5] }, is_right and "is_right" or nil, hovered )
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