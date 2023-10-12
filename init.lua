-- ModRegisterAudioEventMappings( "mods/mrshll_core/GUIDs.txt" )

-- is_manual_pause = is_manual_pause or false
-- magic_pause = magic_pause or function() return end
function OnModInit()
	-- magic_pause = function( is_paused )
	-- 	local ffi = require( "ffi" )
	-- 	local gg = ffi.cast( "char**", 0x01020024 )[0]
	-- 	local ppause = ffi.cast( "char**", gg + 0x48 )[0]
	-- 	if( is_manual_pause ) then
	-- 		ppause[0] = 0
	-- 		is_manual_pause = false
	-- 	elseif( is_paused ) then
	-- 		ppause[0] = 1
	-- 		print( "balls" )
	-- 		is_manual_pause = true
	-- 	end
	-- end
	
	local shader_file = "data/shaders/post_final.frag"
	local file = ModTextFileGetContent( shader_file )
	file = string.gsub( file, "uniform float low_health_indicator_alpha;", "uniform float low_health_indicator_alpha;\r\nuniform vec4 low_health_indicator_alpha_proper;" )
	file = string.gsub( file, "* low_health_indicator_alpha;", "* low_health_indicator_alpha_proper[0];" )
	ModTextFileSetContent( shader_file, file )

	local gun_file = "data/scripts/gun/gun.lua"
	file = ModTextFileGetContent( gun_file )
	file = string.gsub( file, "action effect reflection stuff", "action effect reflection stuff\n_OnNotEnoughManaForAction = OnNotEnoughManaForAction\nfunction OnNotEnoughManaForAction() _OnNotEnoughManaForAction(); GlobalsSetValue( \"INDEX_FUCKYOUMANA\", tostring( GetUpdatedEntityID())); end" )
	ModTextFileSetContent( gun_file, file )
end

-- function OnPausePreUpdate()
-- 	if( not( InputIsKeyDown( 8 --[[e]] ))) then
-- 		magic_pause( false )
-- 	end
-- end

-- function OnWorldPreUpdate()
-- 	if( InputIsKeyDown( 8 --[[e]] )) then
-- 		magic_pause( true )
-- 	end
-- end

--DO NOT forget to write special thanks to dextercd

function OnWorldPostUpdate()
	if( GlobalsGetValue( "INDEX_FUCKYOUMANA", "0" ) ~= "0" ) then
		GlobalsSetValue( "INDEX_FUCKYOUMANA", "0" )
	end
end

function OnPlayerSpawned( hooman ) 
	local initer = "HERMES_INDEX_MOMENT"
	if( GameHasFlagRun( initer )) then
		return
	end
	GameAddFlagRun( initer )
	
	GlobalsSetValue( "HERMES_IS_REAL", "1" )
	
	local x, y = EntityGetTransform( hooman )
	EntityAddChild( hooman, EntityLoad( "mods/index_core/files/ctrl_body.xml" ))
end

function OnPlayerDied( hooman )
	GameSetPostFxParameter( "low_health_indicator_alpha_proper", 0, 0, 0, 0 )
end