dofile_once( "mods/penman/_penman.lua" )

table.insert( actions,
{
	id = "HERMES_CORE",
	name = "HermeS Core",
	description = "A standartized custom spell code injector.",
	sprite = "mods/index_core/files/pics/hermes.png",
	type = ACTION_TYPE_OTHER,
	spawn_requires_flag = "never_spawn_this_action",
	spawn_level = "",
	spawn_probability = "",
	price = 0, mana = 0, max_uses = -1,
	action = function()
        local card_id = pen.get_card_id()
        if( not( pen.vld( card_id, true ))) then return end
        local path = pen.magic_storage( card_id, "index_action", "value_string" )
        if( not( pen.vld( path ))) then return end
        dofile( path )( card_id )
	end,
})