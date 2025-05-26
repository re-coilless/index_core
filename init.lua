ModMagicNumbersFileAdd( "mods/index_core/files/magic_numbers.xml" )
if( ModIsEnabled( "mnee" ) and ModIsEnabled( "penman" )) then
	ModLuaFileAppend( "mods/mnee/bindings.lua", "mods/index_core/mnee.lua" )
else return end
-- is_manual_pause = is_manual_pause or false
-- magic_pause = magic_pause or function() return end

--DO NOT forget to write special thanks to dextercd + thanks to ryyst for magic numbers + thanks to copi for akashic records spell insights + thanks to tRAINEDbYdOG and spoopy for testing
--what about making a custom pause menu through noitapatcher

penman_d = penman_d or ModImageMakeEditable
penman_r = penman_r or ModTextFileGetContent
penman_w = penman_w or ModTextFileSetContent
function OnModInit()
	dofile_once( "mods/index_core/files/_lib.lua" )
	pen.add_translations( "mods/index_core/files/translations.csv" )

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

	pen.magic_write( "data/fonts/_font_pixel.xml", pen.magic_read( "data/fonts/font_pixel.xml" ))
	pen.lib.font_builder( "data/fonts/_font_pixel.xml", {
		[176] = { pos = { 2, 0, 2 }, rect_h = 11, rect_w = 2 },
	}, "mods/index_core/files/pics/font_atlas.png" )
	pen.magic_write( "data/fonts/_font_pixel_noshadow.xml", pen.magic_read( "data/fonts/font_pixel_noshadow.xml" ))
	pen.lib.font_builder( "data/fonts/_font_pixel_noshadow.xml", {
		[176] = { pos = { 5, 0, 2 }, rect_h = 11, rect_w = 2 },
	}, "mods/index_core/files/pics/font_atlas.png" )
	pen.magic_write( "data/fonts/_font_small_numbers.xml", pen.magic_read( "data/fonts/font_small_numbers.xml" ))
	pen.lib.font_builder( "data/fonts/_font_small_numbers.xml", {
		[45] = { pos = { 17, 0, 4 }, rect_h = 6, rect_w = 4 },
		[66] = { pos = { 23, 0, 6 }, rect_h = 6, rect_w = 6 },
		[101] = { pos = { 29, 0, 4 }, rect_h = 6, rect_w = 4 },
	}, "mods/index_core/files/pics/font_atlas.png" )

	local shader_file = "data/shaders/post_final.frag"
	local file = pen.magic_read( shader_file )
	file = string.gsub( file, "uniform float low_health_indicator_alpha;", "uniform float low_health_indicator_alpha;\r\nuniform vec4 low_health_indicator_alpha_proper;" )
	file = string.gsub( file, "%* low_health_indicator_alpha;", "* low_health_indicator_alpha_proper[0];" )
	pen.magic_write( shader_file, file )

	local gun_file = "data/scripts/gun/gun.lua"
	file = pen.magic_read( gun_file )
	file = string.gsub( file, "action effect reflection stuff", "action effect reflection stuff\n_OnNotEnoughManaForAction = OnNotEnoughManaForAction\nfunction OnNotEnoughManaForAction() _OnNotEnoughManaForAction(); GlobalsSetValue( \"INDEX_GLOBAL_FUCK_YOUR_MANA\", tostring( GetUpdatedEntityID())); end" )
	pen.magic_write( gun_file, file )
	
	local fungal_file = "data/scripts/magic/fungal_shift.lua"
	file = pen.magic_read( fungal_file )
	file = string.gsub( file, "print%(CellFactory_GetUIName%(from_material%) %.%. \" %-> \" %.%. CellFactory_GetUIName%(to_material%)%)", "dofile_once( \"mods/index_core/files/_lib.lua\" )\nGlobalsSetValue( \"INDEX_GLOBAL_FUNGAL_MEMO\", GlobalsGetValue( \"INDEX_GLOBAL_FUNGAL_MEMO\", \"\" )..pen.capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( from_material )))..\"->\"..pen.capitalizer( GameTextGetTranslatedOrNot( CellFactory_GetUIName( to_material )))..\"; \" )" )
	pen.magic_write( fungal_file, file )

	local refresh_file = "data/scripts/items/spell_refresh.lua"
	file = pen.magic_read( refresh_file )
	file = string.gsub( file, "GameRegenItemActionsInPlayer%( entity_who_picked %)", "GameRegenItemActionsInPlayer( entity_who_picked )\nfor i,child in ipairs( EntityGetAllChildren( entity_who_picked ) or {}) do GameRegenItemActionsInPlayer( child ) end" )
	pen.magic_write( refresh_file, file )
	
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
	for i,item in ipairs( slotless_scum ) do
		local xml = pen.lib.nxml.parse( pen.magic_read( item..".xml" ))
		xml.attr.tags = xml.attr.tags..",index_slotless"
		pen.magic_write( item..".xml", tostring( xml ))
	end
end

function OnPausePreUpdate()
	dofile_once( "mods/index_core/files/_lib.lua" )

	-- if( not( InputIsKeyDown( 8 --[[e]] ))) then
	-- 	magic_pause( false )
	-- end
	
	--if noitapatcher is real, also make the inventory be closable by escape
	--escape closes, e again picks up in the first free slot or replaces the currently held
	--(if no noitapatcher, drop to 20 frames - off by default)
	
	--top half is the shit being picked up
	--bottom half is the inventory + scrollbar
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

function OnWorldPreUpdate()
	dofile_once( "mods/index_core/files/_lib.lua" )

	local hooman = pen.get_hooman()
	if( not( pen.vld( hooman, true ))) then return end
	local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
	if( pen.vld( iui_comp, true )) then EntitySetComponentIsEnabled( hooman, iui_comp, false ) end
	
	local x, y = EntityGetTransform( hooman )
	pen.t.loop( EntityGetInRadius( x, y, 250 ), function( i, entity_id )
		local action_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "InteractableComponent" )
		if( not( pen.vld( action_comp, true ))) then return end
		if( not( ComponentGetIsEnabled( action_comp ))) then return end

		local lua_comp = EntityGetFirstComponentIncludingDisabled( entity_id, "LuaComponent", "index_ctrl" )
		if( not( pen.vld( lua_comp, true ))) then
			EntitySetComponentIsEnabled( entity_id, action_comp, false )
			EntityAddComponent( entity_id, "LuaComponent", {
				_tags = "index_ctrl",
				script_source_file = "mods/index_core/files/misc/interaction_nuker.lua",
				execute_every_n_frame = "1",
			})
		elseif( not( ComponentGetIsEnabled( lua_comp ))) then
			ComponentSetValue2( lua_comp, "execute_on_added", true )
			EntitySetComponentIsEnabled( entity_id, lua_comp, true )
		else EntitySetComponentIsEnabled( entity_id, action_comp, false ) end
	end)
end

function OnWorldPostUpdate()
	dofile_once( "mods/index_core/files/_lib.lua" )
	GlobalsSetValue( index.GLOBAL_FUCK_YOUR_MANA, "0" )

	local hooman = pen.get_hooman()
	if( not( pen.vld( hooman, true ))) then return end
	local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
	if( pen.vld( iui_comp, true )) then EntitySetComponentIsEnabled( hooman, iui_comp, false ) end
end

function OnPlayerSpawned( hooman )
	dofile_once( "mods/index_core/files/_lib.lua" )

	local initer = "HERMES_INDEX_MOMENT"
	if( GameHasFlagRun( initer )) then return end
	GameAddFlagRun( initer )
	
	GlobalsSetValue( "HERMES_IS_REAL", "1" )
	GlobalsSetValue( pen.GLOBAL_FONT_REMAP, pen.t.pack( pen.t.unarray({
		["data/fonts/font_pixel.xml"] = "data/fonts/_font_pixel.xml",
		["data/fonts/font_pixel_noshadow.xml"] = "data/fonts/_font_pixel_noshadow.xml",
		["data/fonts/font_small_numbers.xml"] = "data/fonts/_font_small_numbers.xml",
	})))

	EntityAddComponent( GameGetWorldStateEntity(), "LuaComponent", {
		script_source_file = "mods/index_core/files/inv_ctrl.lua",
		execute_every_n_frame = "1",
	})
	
	local x, y = EntityGetTransform( hooman ); EntityAddTag( hooman, "index_ctrl" )
	local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
	if( pen.vld( inv_comp, true )) then ComponentSetValue2( inv_comp, "quick_inventory_slots", 8 ) end

	--all spells wand
	--custom spell you can seamlessly write the code into
	--testing_bag insert in the chest (display contents on hover tooltip and allow dragging from and to it)

	CreateItemActionEntity( "LIGHTNING", x, y )
	EntityLoad( "mods/index_core/files/testing/chest.xml", x - 50, y - 20 )
end

function OnPlayerDied( hooman )
	GameSetPostFxParameter( "low_health_indicator_alpha_proper", 0, 0, 0, 0 )
end