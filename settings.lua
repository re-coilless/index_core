dofile( "data/scripts/lib/mod_settings.lua" )

function mod_setting_full_resetter( mod_id, gui, in_main_menu, im_id, setting )
	local clicked, right_clicked = GuiButton( gui, im_id, mod_setting_group_x_offset, 0, setting.ui_name )
	if( right_clicked ) then
		for i = 1,3 do
			ModSettingSetNextValue( "mnee.BINDINGS_"..i, "&", false )
		end
	end
	
	mod_setting_tooltip( mod_id, gui, in_main_menu, setting )
end

local mod_id = "mnee"
mod_settings_version = 1
mod_settings = 
{
	{
		id = "READ_ME",
		ui_name = "[PRESS LEFT_CTRL+M IN-GAME TO OPEN THE MENU]",
		not_setting = true,
	},
	{
		id = "NUKE_EM",
		ui_name = "Complete Reset",
		ui_description = "RMB to reset all the saved M-Nee bindings and settings.",
		value_default = false,
		hidden = false,
		scope = MOD_SETTING_SCOPE_RUNTIME,
		ui_fn = mod_setting_full_resetter,
	},
	
	{
		id = "PROFILE",
		ui_name = "Binding Profile",
		ui_description = "",
		hidden = true,
		value_default = 1,
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "BINDINGS_1",
		ui_name = "Bindings",
		ui_description = "",
		hidden = true,
		value_default = "&",
		text_max_length = 100000,
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "BINDINGS_2",
		ui_name = "Bindings",
		ui_description = "",
		hidden = true,
		value_default = "&",
		text_max_length = 100000,
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "BINDINGS_3",
		ui_name = "Bindings",
		ui_description = "",
		hidden = true,
		value_default = "&",
		text_max_length = 100000,
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	{
		id = "CTRL_AUTOMAPPING",
		ui_name = "Controller Automapping",
		ui_description = "",
		hidden = true,
		value_default = true,
		scope = MOD_SETTING_SCOPE_RUNTIME,
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