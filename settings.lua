dofile( "data/scripts/lib/mod_settings.lua" )

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

function update_settings( mod_id, gui, in_main_menu, setting, old_value, new_value )
	if( GameGetWorldStateEntity ~= nil and GameGetWorldStateEntity() > 0 ) then
		local ctrl_bodies = EntityGetWithTag( "index_ctrl" ) or {}
		if( #ctrl_bodies > 0 ) then
			local controller_id = ctrl_bodies[1]
			if( ComponentGetValue2( get_storage( controller_id, "override_settings" ), "value_bool" )) then
				ComponentSetValue2( get_storage( controller_id, "update_settings" ), "value_bool", true )
			end
		end
	end
end

local mod_id = "index_core"
mod_settings_version = 1
mod_settings = 
{
	{
		id = "READ_ME",
		ui_name = "see [TOP RIGHT CORNER OF OPENED INVENTORY] for howto",
		not_setting = true,
	},
	{
		category_id = "MACRO",
		ui_name = "[MACRO]",
		ui_description = "Redefines the GUI as a whole.",
		foldable = true,
		_folded = true,
		settings = {
			{
				id = "ALWAYS_SHOW_FULL",
				ui_name = "Show Spell Inventory When Closed",
				ui_description = "Displays full inventory even when the inventory itself is closed.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "NO_INV_SHOOTING",
				ui_name = "Prevent Shooting When Opened",
				ui_description = "Stops player from being able to shoot when the inventory is opened.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "DO_VANILLA_DROPPING",
				ui_name = "Drop First - Think Later",
				ui_description = "Restores dropping logic to its original vanilla glory.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "NO_ACTION_ON_DROP",
				ui_name = "Silent Dropping",
				ui_description = "Allows removing items from inventory without triggering their on-dropped effects.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
		},
	},
	{
		category_id = "HUD",
		ui_name = "[HUD]",
		ui_description = "Changes how player state display is percieved.",
		foldable = true,
		_folded = true,
		settings = {
			{
				id = "MAX_PERKS",
				ui_name = "Perk Column Size",
				ui_description = "The maximum amount of perks to show.",
				value_default = 5,

				value_min = 3,
				value_max = 12,
				value_display_multiplier = 1,
				value_display_formatting = " $0 ",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "SHORT_HP",
				ui_name = "Compressed HP Value",
				ui_description = "Shortens HP value via M/B/T and scientific notation.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "SHORT_GOLD",
				ui_name = "Compressed Gold Value",
				ui_description = "Shortens gold value via M/B/T and scientific notation.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "FANCY_POTION_BAR",
				ui_name = "Fancy Potion Bar",
				ui_description = "Potion fullness bar inherits the color of the potion.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "RELOAD_THRESHOLD",
				ui_name = "Reload Threshold",
				ui_description = "Shows the reload/delay bars only if the wand reload/delay is above this value.",
				value_default = 30,

				value_min = 1,
				value_max = 60,
				value_display_multiplier = 1,
				value_display_formatting = " $0 ",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
		},
	},
	
	{
		category_id = "INFOBAR",
		ui_name = "[INFOBAR]",
		ui_description = "Controls the behavior of the on-pointed info display.",
		foldable = true,
		_folded = true,
		settings = {
			{
				id = "INFO_POINTER",
				ui_name = "Info To Pointer",
				ui_description = "Positions item/enemy/info text near the pointer (else, puts it to the right of the hotbar).",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "INFO_POINTER_ALPHA",
				ui_name = "Pointer Info Transparency Multiplier",
				ui_description = "Mutates the alpha of the info text when near the pointer.",
				value_default = 5,
				
				value_min = 1,
				value_max = 9,
				value_display_multiplier = 1,
				value_display_formatting = " 0.$0 ",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "INFO_MTR_HOTKEYED",
				ui_name = "Hotkeyed Material Info",
				ui_description = "Displays material names only when the hotkey is held (prevents probe entity from obstructing the pointer).",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "INFO_MTR_STATIC",
				ui_name = "Persistent Material Info",
				ui_description = "Forces material info line to be present at all times.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
		},
	},
	{
		category_id = "MISC",
		ui_name = "[MISC]",
		ui_description = "Other assorted settings.",
		foldable = true,
		_folded = true,
		settings = {
			{
				id = "MUTE_APPLETS",
				ui_name = "Mute Applets",
				ui_description = "Suppresses applet menu, so it won't ever open by itself.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "NO_WAND_SCALING",
				ui_name = "No Wand Scaling",
				ui_description = "In-inventory wand pics are being displayed at their true resolution.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "ALLOW_TIPS_ALWAYS",
				ui_name = "Always Allow Tooltips",
				ui_description = "Slots display the tooltips even if the inventory is closed.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
			{
				id = "IN_WORLD_PICKUPS",
				ui_name = "In-World Pickup Prompts",
				ui_description = "Add an in-world text prompt to all pickable items and interactive elements.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = update_settings,
			},
		},
	},
}

function ModSettingsUpdate( init_scope )
	local old_version = mod_settings_get_version( mod_id )
	mod_settings_update( mod_id, mod_settings, init_scope )
end

function ModSettingsGuiCount()
	return mod_settings_gui_count( mod_id, mod_settings )
end

function ModSettingsGui( gui, in_main_menu )
	mod_settings_gui( mod_id, mod_settings, gui, in_main_menu )
end