function t2w( str )
	local t = {}
	
	for word in string.gmatch( str, "([^%s]+)" ) do
		table.insert( t, word )
	end
	
	return t
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

function world2gui( gui, x, y )
	local w, h = GuiGetScreenDimensions( gui )
	local cam_x, cam_y = GameGetCameraPos()
	local shit_from_ass = w/( MagicNumbersGetValue( "VIRTUAL_RESOLUTION_X" ) + MagicNumbersGetValue( "VIRTUAL_RESOLUTION_OFFSET_X" ))
	
	return w/2 + shit_from_ass*( x - cam_x ), h/2 + shit_from_ass*( y - cam_y ), shit_from_ass
end

function get_mouse_pos( gui )
	local m_x, m_y = DEBUG_GetMouseWorld()
	return world2gui( gui, m_x, m_y )
end

function gui_killer( gui )
	if( gui ~= nil ) then
		GuiDestroy( gui )
	end
end

function colourer( gui, c_type )
	local color = { r = 0, g = 0, b = 0 }
	if( type( c_type ) == "table" ) then
		color.r = c_type[1] or 255
		color.g = c_type[2] or 255
		color.b = c_type[3] or 255
	else
		if( c_type == nil or c_type == 1 ) then
			color.r = 238
			color.g = 226
			color.b = 206
		elseif( c_type == 2 ) then
			color.r = 136
			color.g = 121
			color.b = 247
		elseif( c_type == 3 ) then
			color.r = 245
			color.g = 132
			color.b = 132
		end
	end
	
	GuiColorSetForNextWidget( gui, color.r/255, color.g/255, color.b/255, 1 )
end

function bind2string( binds )
	local out = "["
	if( binds[1] == "is_axis" ) then
		out = out..binds[2]
		if( binds[3] ~= nil ) then
			out = out.."; "..binds[3]
		end
	else
		for bind in pairs( binds ) do
			out = out..( out == "[" and "" or "; " )..bind
		end
	end
	return out.."]"
end

function play_sound( event )
	if( not( sound_played )) then
		sound_played = false
		local c_x, c_y = GameGetCameraPos()
		GamePlaySound( "mods/mnee/mnee.bank", event, c_x, c_y )
	end
end

function new_text( gui, pic_x, pic_y, pic_z, text, colours )
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
		colourer( gui, colours or 1 )
		GuiZSetForNextWidget( gui, pic_z )
		GuiText( gui, pic_x, pic_y, line )
		pic_y = pic_y + 9
	end
end

function new_image( gui, uid, pic_x, pic_y, pic_z, pic, s_x, s_y, alpha, interactive )
	if( s_x == nil ) then
		s_x = 1
	end
	if( s_y == nil ) then
		s_y = 1
	end
	if( alpha == nil ) then
		alpha = 1
	end
	if( interactive == nil ) then
		interactive = false
	end
	
	if( not( interactive )) then
		GuiOptionsAddForNextWidget( gui, 2 ) --NonInteractive
	end
	GuiZSetForNextWidget( gui, pic_z )
	uid = uid + 1
	GuiIdPush( gui, uid )
	GuiImage( gui, uid, pic_x, pic_y, pic, alpha, s_x, s_y )
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

function new_anim( gui, uid, auid, pic_x, pic_y, pic_z, path, amount, delay, s_x, s_y, alpha, interactive )
	anims_state = anims_state or {}
	anims_state[auid] = anims_state[auid] or { 1, 0 }
	
	new_image( gui, uid, pic_x, pic_y, pic_z, path..anims_state[auid][1]..".png", s_x, s_y, alpha, interactive )
	
	anims_state[auid][2] = anims_state[auid][2] + 1
	if( anims_state[auid][2] > delay ) then
		anims_state[auid][2] = 0
		anims_state[auid][1] = anims_state[auid][1] + 1
		if( anims_state[auid][1] > amount ) then
			anims_state[auid][1] = 1
		end
	end
	
	return uid
end

function new_dragger( gui, uid, pic_x, pic_y, pic_z, pic )
	GuiOptionsAddForNextWidget( gui, 51 ) --IsExtraDraggable
	new_button( gui, uid, pic_x, pic_y, pic_z, pic )
	uid = uid - 1018
	local _, _, _, _, _, _, _, d_x, d_y = GuiGetPreviousWidgetInfo( gui )
	if( d_x ~= pic_x and d_y ~= pic_y and d_x ~= 0 and d_y ~= 0 ) then
		if( local_grab_x[uid] == nil ) then
			local_grab_x[uid] = d_x - pic_x
		end
		if( local_grab_y[uid] == nil ) then
			local_grab_y[uid] = d_y - pic_y
		end
		
		pic_x = d_x - local_grab_x[uid]
		pic_y = d_y - local_grab_y[uid]
	else
		local_grab_x[uid] = nil
		local_grab_y[uid] = nil
	end
	
	return pic_x, pic_y
end

function new_pager( gui, uid, pic_x, pic_y, pic_z, page, max_page, profile_mode )
	profile_mode = profile_mode or false

	local clicked, r_clicked = 0, 0, 0
	uid, clicked, r_clicked = new_button( gui, uid, pic_x, pic_y, pic_z, "mods/mnee/pics/key_left.png" )
	if( clicked and max_page > 1 ) then
		play_sound( "button_special" )
		page = page - 1
		if( page < 1 ) then
			page = max_page
		end
	end
	if( r_clicked and max_page > 5 ) then
		play_sound( "switch_page" )
		page = page - 5
		if( page < 1 ) then
			page = max_page + page
		end
	end
	
	if( profile_mode ) then
		pic_y = pic_y + 11
	else
		pic_x = pic_x + 11
	end
	uid = new_button( gui, uid, pic_x, pic_y, pic_z, "mods/mnee/pics/button_21_B.png" )
	if( profile_mode ) then
		uid = new_tooltip( gui, uid, pic_z - 200, "Current Profile." )
	end
	new_text( gui, pic_x + 2, pic_y, pic_z - 0.01, tostring( profile_mode and string.char( page + 64 ) or page ), 2 )
	
	pic_x = pic_x + 22
	if( profile_mode ) then
		pic_x = pic_x - 11
		pic_y = pic_y - 11
	end
	uid, clicked, r_clicked = new_button( gui, uid, pic_x, pic_y, pic_z - 0.01, "mods/mnee/pics/key_right.png" )
	if( clicked and max_page > 1 ) then
		play_sound( "button_special" )
		page = page + 1
		if( page > max_page ) then
			page = 1
		end
	end
	if( r_clicked and max_page > 5 ) then
		play_sound( "switch_page" )
		page = page + 5
		if( page > max_page ) then
			page = page - max_page
		end
	end
	
	if( max_page > 0 and page > max_page ) then
		page = max_page
	end
	
	return uid, page
end

function new_tooltip( gui, uid, pic_z, text )
	if( not( tooltip_opened )) then
		local _, _, t_hov = GuiGetPreviousWidgetInfo( gui )
		if( t_hov ) then
			tooltip_opened = true
			local w, h = GuiGetScreenDimensions( gui )
			local pic_x, pic_y = get_mouse_pos( gui )
			pic_x = pic_x + 10
			
			if( text == "" ) then
				return uid
			end
			
			text = liner( text, w*0.9, h - 2, 5.8 )
			local length = 0
			for i,line in ipairs( text ) do
				local current_length = GuiGetTextDimensions( gui, line, 1, 2 )
				if( current_length > length ) then
					length = current_length
				end
			end
			local extra = #text > 1 and 3 or 0
			local x_offset = length + extra
			local y_offset = 9*#text + 1 + extra - ( #text > 1 and 3 or 0 )
			if( w < pic_x + x_offset ) then
				pic_x = w - x_offset
			end
			if( h < pic_y + y_offset ) then
				pic_y = h - y_offset
			end
			uid = new_image( gui, uid, pic_x, pic_y, pic_z, "mods/mnee/pics/dot_purple_dark.png", x_offset, y_offset )
			uid = new_image( gui, uid, pic_x + 1, pic_y + 1, pic_z - 0.01, "mods/mnee/pics/dot_white.png", x_offset - 2, y_offset - 2 )
			
			new_text( gui, pic_x + 2, pic_y, pic_z - 0.02, text, 2 )
		end
	end
	
	return uid
end