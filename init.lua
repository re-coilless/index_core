-- ModRegisterAudioEventMappings( "mods/mrshll_core/GUIDs.txt" )

-- is_manual_pause = is_manual_pause or false
-- magic_pause = magic_pause or function() return end

penman_r = penman_r or function() return end
penman_w = penman_w or function() return end

function OnModInit()
	for name,func in pairs(_G) do
		if( name == "ModTextFileGetContent" ) then
			penman_r = func
		elseif( name == "ModTextFileSetContent" ) then
			penman_w = func
		end
	end

	-- magic_pause = function( is_paused )
	-- 	local ffi = require( "ffi" )
	-- 	local gg = ffi.cast( "char**", 0x01020024 )[0]
	-- 	local ppause = ffi.cast( "char**", gg + 0x48 )[0]
	-- 	if( is_manual_pause ) then
	-- 		ppause[0] = 0
	-- 		is_manual_pause = false
	-- 	elseif( is_paused ) then
	-- 		ppause[0] = 1
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

	local fungal_file = "data/scripts/magic/fungal_shift.lua"
	file = ModTextFileGetContent( fungal_file )
	file = string.gsub( file, "print%(CellFactory_GetUIName%(from_material%) %.%. \" %-> \" %.%. CellFactory_GetUIName%(to_material%)%)", "dofile_once( \"mods/index_core/files/_lib.lua\" )\nGlobalsSetValue( \"fungal_memo\", GlobalsGetValue( \"fungal_memo\", \"\" )..capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( from_material )))..\"->\"..capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( to_material )))..\"; \" )" )
	ModTextFileSetContent( fungal_file, file )
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

function OnWorldPreUpdate()
	local hooman = EntityGetWithName( "DEBUG_NAME:player" ) or 0
	if( hooman > 0 ) then
		local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
		if( iui_comp ~= nil and ComponentGetIsEnabled( iui_comp )) then
			EntitySetComponentIsEnabled( hooman, iui_comp, false )
		end
	end

	if( not( matter_test_set or false )) then
		matter_test_set = true
		
		local full_list = ""
		local full_matters = {
			CellFactory_GetAllLiquids(),
			CellFactory_GetAllSands(),
			CellFactory_GetAllGases(),
			CellFactory_GetAllFires(),
			CellFactory_GetAllSolids(),
		}
		for	i,list in ipairs( full_matters ) do
			for e,mtr in ipairs( list ) do
				full_list = full_list..mtr..(( i == #full_matters and e == #list ) and "" or "," )
			end
		end
		local matter_test = "mods/index_core/files/matter_test.xml"
		penman_w( matter_test, string.gsub( penman_r( matter_test ), "_MATTERLISTHERE_", full_list ))
	end
end

function OnWorldPostUpdate()
	local hooman = EntityGetWithName( "DEBUG_NAME:player" ) or 0
	if( hooman > 0 ) then
		local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
		if( iui_comp ~= nil and ComponentGetIsEnabled( iui_comp )) then
			EntitySetComponentIsEnabled( hooman, iui_comp, false )
		end
	end

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

	local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
	if( inv_comp ~= nil ) then
		ComponentSetValue2( inv_comp, "quick_inventory_slots", 8 )
	end

	local x, y = EntityGetTransform( hooman )
	EntityAddChild( hooman, EntityLoad( "mods/index_core/files/ctrl_body.xml" ))
end

function OnPlayerDied( hooman )
	GameSetPostFxParameter( "low_health_indicator_alpha_proper", 0, 0, 0, 0 )
end