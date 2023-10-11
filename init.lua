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