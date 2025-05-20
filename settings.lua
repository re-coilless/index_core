dofile( "data/scripts/lib/mod_settings.lua" )

function sync_settings( mod_id, gui, in_main_menu, setting, old_value, new_value )
	if( GameGetWorldStateEntity ~= nil and GameGetWorldStateEntity() > 0 ) then
		if( GlobalsGetValue( "INDEX_GLOBAL_LOCK_SETTINGS", "bool0" ) == "bool0" ) then
			GlobalsSetValue( "INDEX_GLOBAL_SYNC_SETTINGS", "bool1" )
		end
	end
end

function mod_setting_custom_enum( mod_id, gui, in_main_menu, im_id, setting )
	local value = ModSettingGetNextValue( mod_setting_get_id( mod_id, setting ))
	local text = setting.ui_name .. ": " .. setting.values[ value ]
	
	local new_value = value
	local clicked,right_clicked = GuiButton( gui, im_id, mod_setting_group_x_offset, 0, text )
	if clicked then
		new_value = new_value + 1
		if( new_value > #setting.values ) then new_value = 1 end
	end
	if right_clicked and setting.value_default then
		new_value = setting.value_default
	end
	if( new_value ~= value ) then
		new_value = setting.change_fn( mod_id, gui, in_main_menu, setting, value, new_value ) or new_value
		ModSettingSetNextValue( mod_setting_get_id( mod_id, setting ), new_value, false )
	end

	mod_setting_tooltip( mod_id, gui, in_main_menu, setting )
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
				change_fn = sync_settings,
			},
			{
				id = "NO_INV_SHOOTING",
				ui_name = "Prevent Shooting When Opened",
				ui_description = "Stops player from being able to shoot when the inventory is opened.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "VANILLA_DROPPING",
				ui_name = "Drop First - Think Later",
				ui_description = "Restores dropping logic to its original vanilla glory.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "SILENT_DROPPING",
				ui_name = "Silent Dropping",
				ui_description = "Allows removing items from inventory without triggering their on-drop effects.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "FORCE_VANILLA_FULLEST",
				ui_name = "Force-Show Fullest Inventory",
				ui_description = "Extra rows of inventory won't be hidden while in the \"Full\" Global Mode.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
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
				id = "MAX_PERK_COUNT",
				ui_name = "Perk Column Size",
				ui_description = "The maximum amount of perks to show.",
				value_default = 5,

				value_min = 3,
				value_max = 12,
				value_display_multiplier = 1,
				value_display_formatting = " $0 ",
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "SHORT_HP",
				ui_name = "Compressed HP Value",
				ui_description = "Shortens HP value via M/B/T and scientific notation.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "SHORT_GOLD",
				ui_name = "Compressed Gold Value",
				ui_description = "Shortens gold value via M/B/T and scientific notation.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "FANCY_POTION_BAR",
				ui_name = "Fancy Potion Bar",
				ui_description = "Potion fullness bar inherits the color of the potion.",
				value_default = true,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
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
				change_fn = sync_settings,
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
				change_fn = sync_settings,
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
				change_fn = sync_settings,
			},
			{
				id = "INFO_MATTER_MODE",
				ui_name = "Material Info Mode",
				ui_description = "Changes how the behavior of the displayed material names.",
				values = { "Auto", "Hotkeyed", "Persistent" },
				value_default = 1,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				ui_fn = mod_setting_custom_enum,
				change_fn = sync_settings,
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
				change_fn = sync_settings,
			},
			{
				id = "NO_WAND_SCALING",
				ui_name = "No Wand Scaling",
				ui_description = "In-inventory wand pics are being displayed at their true resolution.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "FORCE_SLOT_TIPS",
				ui_name = "Force Slot Tooltips",
				ui_description = "Slots display the tooltips even if the inventory is closed.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "IN_WORLD_PICKUPS",
				ui_name = "In-World Pickup Prompts",
				ui_description = "Add an in-world text prompt to all pickable items and interactive elements.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "IN_WORLD_TIPS",
				ui_name = "Anchor Pickup Tips to Items",
				ui_description = "Positions items tooltips in the world instead of within GUI.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "SECRET_SHOPPER",
				ui_name = "No Window Shopping",
				ui_description = "Prevents tips from being displayed if the item cannot be purchased.",
				value_default = false,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				change_fn = sync_settings,
			},
			{
				id = "BOSS_BAR_MODE",
				ui_name = "Boss Bar Behavior",
				ui_description = "CHanges the way boss HP bars are displayed.",
				values = { "Auto", "In-World", "In-GUI" },
				value_default = 1,
				
				scope = MOD_SETTING_SCOPE_RUNTIME,
				ui_fn = mod_setting_custom_enum,
				change_fn = sync_settings,
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