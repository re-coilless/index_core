dofile_once( "mods/index_core/files/_lib.lua" )

local entity_id = GetUpdatedEntityID()
if( not( pen.magic_storage( entity_id, "override_settings", "value_bool" ))) then return end

local storage_update = pen.magic_storage( entity_id, "update_settings" )
if( ComponentGetValue2( storage_update, "value_bool" )) then
    local type_tbl = { ["boolean"] = "value_bool", ["number"] = "value_int", ["string"] = "value_string" }
    local var_tbl = {
        ALWAYS_SHOW_FULL = "always_show_full",
        NO_INV_SHOOTING = "no_inv_shooting",
        DO_VANILLA_DROPPING = "do_vanilla_dropping",
        NO_ACTION_ON_DROP = "no_action_on_drop",
        FORCE_VANILLA_FULLEST = "force_vanilla_fullest",

        MAX_PERKS = "max_perk_count",
        SHORT_HP = "short_hp",
        SHORT_GOLD = "short_gold",
        FANCY_POTION_BAR = "fancy_potion_bar",
        RELOAD_THRESHOLD = "reload_threshold",

        INFO_POINTER = "info_pointer",
        INFO_POINTER_ALPHA = "info_pointer_alpha",
        INFO_MTR_HOTKEYED = "info_mtr_hotkeyed",
        INFO_MTR_STATIC = "info_mtr_static",

        MUTE_APPLETS = "mute_applets",
        NO_WAND_SCALING = "no_wand_scaling",
        ALLOW_TIPS_ALWAYS = "allow_tips_always",
        IN_WORLD_PICKUPS = "in_world_pickups",
    }
    for name,var in pairs( var_tbl ) do
        local v = ModSettingGetNextValue( "index_core."..name )
        if( v ~= nil ) then
            pen.magic_storage( entity_id, var, type_tbl[ type( v )], v )
        end
    end

    ComponentSetValue2( storage_update, "value_bool", false )
    pen.magic_storage( entity_id, "reset_settings", "value_bool", true )
end