if( ModIsEnabled( "mnee" )) then
	ModLuaFileAppend( "mods/mnee/bindings.lua", "mods/index_core/mnee.lua" )
end
-- is_manual_pause = is_manual_pause or false
-- magic_pause = magic_pause or function() return end

penman_r = ModTextFileGetContent
penman_w = ModTextFileSetContent

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
	-- 		is_manual_pause = true
	-- 	end
	-- end
	
	local shader_file = "data/shaders/post_final.frag"
	local file = ModTextFileGetContent( shader_file )
	file = string.gsub( file, "uniform float low_health_indicator_alpha;", "uniform float low_health_indicator_alpha;\r\nuniform vec4 low_health_indicator_alpha_proper;" )
	file = string.gsub( file, "%* low_health_indicator_alpha;", "* low_health_indicator_alpha_proper[0];" )
	ModTextFileSetContent( shader_file, file )

	local gun_file = "data/scripts/gun/gun.lua"
	file = ModTextFileGetContent( gun_file )
	file = string.gsub( file, "action effect reflection stuff", "action effect reflection stuff\n_OnNotEnoughManaForAction = OnNotEnoughManaForAction\nfunction OnNotEnoughManaForAction() _OnNotEnoughManaForAction(); GlobalsSetValue( \"INDEX_FUCKYOURMANA\", tostring( GetUpdatedEntityID())); end" )
	ModTextFileSetContent( gun_file, file )
	
	local fungal_file = "data/scripts/magic/fungal_shift.lua"
	file = ModTextFileGetContent( fungal_file )
	file = string.gsub( file, "print%(CellFactory_GetUIName%(from_material%) %.%. \" %-> \" %.%. CellFactory_GetUIName%(to_material%)%)", "dofile_once( \"mods/index_core/files/_lib.lua\" )\nGlobalsSetValue( \"fungal_memo\", GlobalsGetValue( \"fungal_memo\", \"\" )..capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( from_material )))..\"->\"..capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( to_material )))..\"; \" )" )
	ModTextFileSetContent( fungal_file, file )

	local refresh_file = "data/scripts/items/spell_refresh.lua"
	file = ModTextFileGetContent( refresh_file )
	file = string.gsub( file, "GameRegenItemActionsInPlayer%( entity_who_picked %)", "GameRegenItemActionsInPlayer( entity_who_picked )\nfor i,child in ipairs( EntityGetAllChildren( entity_who_picked ) or {}) do GameRegenItemActionsInPlayer( child ) end" )
	ModTextFileSetContent( refresh_file, file )
	
	local slotless_file = "data/entities/items/pickup/"
	local slotless_scum = {
		slotless_file.."cape",
		slotless_file.."perk",
		slotless_file.."perk_reroll",
		slotless_file.."goldnugget",
		slotless_file.."goldnugget_10",
		slotless_file.."goldnugget_50",
		slotless_file.."goldnugget_200",
		slotless_file.."goldnugget_1000",
		slotless_file.."goldnugget_10000",
		slotless_file.."goldnugget_200000",
		slotless_file.."essence_air",
		slotless_file.."essence_alcohol",
		slotless_file.."essence_fire",
		slotless_file.."essence_laser",
		slotless_file.."essence_water",
		slotless_file.."heart",
		slotless_file.."heart_better",
		slotless_file.."heart_evil",
		slotless_file.."heart_fullhp",
		slotless_file.."spell_refresh",
		slotless_file.."chest_leggy",
		slotless_file.."chest_random",
		slotless_file.."chest_random_super",
		slotless_file.."greed_curse",
		"data/entities/animals/boss_centipede/rewards/gold_reward",
		"data/entities/items/orbs/orb_base",
	}
	local nxml = dofile_once( "mods/index_core/nxml.lua" )
	for i,item in ipairs( slotless_scum ) do
		local xml = nxml.parse( ModTextFileGetContent( item..".xml" ))
		xml.attr.tags = xml.attr.tags..",index_slotless"
		ModTextFileSetContent( item..".xml", tostring( xml ))
	end
end

function OnPausePreUpdate()
	-- if( not( InputIsKeyDown( 8 --[[e]] ))) then
	-- 	magic_pause( false )
	-- end
	
	--escape closes, e again picks up in the first free slot or replaces the currently held
	--(if no noitapatcher, drop to 20 frames - off by default)
	--pause code in a func

	--top half is the shit being picked up
	--bottom half is the shit to pick + scrollbar
	--darker background
	--display inv slots and the descs if said slots in as a vert paged shit
	--only display the stuff that actually has on_gui_pause func and only check the quick+quickest invs
	--upon hovering over the slot, the list gets reodered to show the hovered at the top
end

-- function OnWorldPreUpdate()
-- 	if( InputIsKeyDown( 8 --[[e]] )) then
-- 		magic_pause( true )
-- 	end
-- end

--DO NOT forget to write special thanks to dextercd + thanks for nxml + thanks for wiki + thanks to ryyst for magic numbers + thanks to aarlvo for scroll container trick + thanks to copi for akashic records spell insights

function OnWorldPreUpdate()
	dofile_once( "mods/index_core/files/_lib.lua" )
	
	if( not( custom_font_set or false )) then
		custom_font_set = true
		register_new_font( "default", penman_r, penman_w,
			"data/fonts/font_pixel_noshadow",
			"mods/index_core/files/fonts/vanilla/", -2 )
		register_new_font( "vanilla_shadow", penman_r, penman_w,
			"data/fonts/font_pixel",
			"mods/index_core/files/fonts/vanilla_shadow/", -2 )
		register_new_font( "vanilla_small", penman_r, penman_w,
			"mods/index_core/files/fonts/vanilla_small/font_small_numbers",
			"mods/index_core/files/fonts/vanilla_small/", 1 )
		register_new_font( "vanilla_rune", penman_r, penman_w,
			"data/fonts/font_pixel_runes",
			"mods/index_core/files/fonts/vanilla_rune/", -2 )
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
		local matter_test = "mods/index_core/files/misc/matter_test.xml"
		penman_w( matter_test, string.gsub( penman_r( matter_test ), "_MATTERLISTHERE_", full_list ))
	end

	local hooman = EntityGetWithName( "DEBUG_NAME:player" ) or 0
	if( hooman > 0 ) then
		local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
		if( iui_comp ~= nil ) then
			EntitySetComponentIsEnabled( hooman, iui_comp, false )
		end
		
		local x, y = EntityGetTransform( hooman )
		local entities = EntityGetInRadius( x, y, 250 ) or {}
        if( #entities > 0 ) then
			for i,ent in ipairs( entities ) do
				local action_comp = EntityGetFirstComponentIncludingDisabled( ent, "InteractableComponent" )
                if( action_comp ~= nil ) then
					if( ComponentGetIsEnabled( action_comp )) then
						local lua_comp = EntityGetFirstComponentIncludingDisabled( ent, "LuaComponent", "index_ctrl" )
						if( lua_comp == nil ) then
							EntitySetComponentIsEnabled( ent, action_comp, false )
							EntityAddComponent( ent, "LuaComponent",
							{
								_tags = "index_ctrl",
								script_source_file = "mods/index_core/files/misc/interaction_nuker.lua",
								execute_every_n_frame = "1",
							})
						elseif( not( ComponentGetIsEnabled( lua_comp ))) then
							ComponentSetValue2( lua_comp, "execute_on_added", true )
							EntitySetComponentIsEnabled( ent, lua_comp, true )
						else
							EntitySetComponentIsEnabled( ent, action_comp, false )
						end
					end
				end
			end
		end
	end
end

function OnWorldPostUpdate()
	local hooman = EntityGetWithName( "DEBUG_NAME:player" ) or 0
	if( hooman > 0 ) then
		local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
		if( iui_comp ~= nil ) then
			EntitySetComponentIsEnabled( hooman, iui_comp, false )
		end
	end
	
	GlobalsSetValue( "INDEX_FUCKYOURMANA", "0" )
end

function OnPlayerSpawned( hooman ) 
	local initer = "HERMES_INDEX_MOMENT"
	if( GameHasFlagRun( initer )) then
		return
	end
	GameAddFlagRun( initer )
	GlobalsSetValue( "HERMES_IS_REAL", "1" )
	
	EntityAddComponent( GameGetWorldStateEntity(), "LuaComponent",
	{
		script_source_file = "mods/index_core/files/inv_ctrl.lua",
		execute_every_n_frame = "1",
	})

	local x, y = EntityGetTransform( hooman )
	EntityAddChild( hooman, EntityLoad( "mods/index_core/files/ctrl_body.xml" ))
	local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
	if( inv_comp ~= nil ) then
		ComponentSetValue2( inv_comp, "quick_inventory_slots", 8 )
	end
	
	-- CreateItemActionEntity( "LIGHTNING", x, y )
	EntityLoad( "mods/index_core/files/testing/chest.xml", x - 50, y - 20 )
	--testing_bag insert in the chest (autoarrange in the grid when inside player root inventory; display contents on hover tooltip)
	--all spells wand
	--custom spell where you can write the code directly into
end

function OnPlayerDied( hooman )
	GameSetPostFxParameter( "low_health_indicator_alpha_proper", 0, 0, 0, 0 )
end