bindings = {}

--see mods/mnee/lists.lua for most of the key ids

--[[gamepad button list; [*] states the gamepad number; non-standard gamepads might be supported but extra buttons will not be listed here - check naming during rebinding

[*]gpd_y
[*]gpd_x
[*]gpd_a
[*]gpd_b

[*]gpd_r1
[*]gpd_r2
[*]gpd_r3
[*]gpd_l1
[*]gpd_l2
[*]gpd_l3

[*]gpd_up
[*]gpd_down
[*]gpd_left
[*]gpd_right

[*]gpd_select
[*]gpd_start

[*]gpd_btn_lh_+
[*]gpd_btn_lh_-
[*]gpd_btn_lv_+
[*]gpd_btn_lv_-
[*]gpd_btn_rh_+
[*]gpd_btn_rh_-
[*]gpd_btn_rv_+
[*]gpd_btn_rv_-

]]

bindings["mnee"] = {
	menu = { --[ACTUAL BINDING ID]
		order_id = "a", --[SORTING ORDER]
		is_locked = false, --[PREVENT REBINDING]
		name = "Open M-nee", --[DISPLAYED NAME]
		desc = "Will open this menu.", --[DISPLAYED DESCRIPTION]
		keys = { --[DEFAULT BINDING KEYS]
			left_ctrl = 1, --number is just so the thing won't be nil
			m = 1,
		},
	},
	
	off = {
		order_id = "b",
		name = "Disable M-nee",
		desc = "Will disable all the custom inputs.",
		keys = {
			left_ctrl = 1,
			["keypad_-"] = 1,
		},
	},
	
	profile_change = {
		order_id = "c",
		name = "Change Profile",
		desc = "Cycle through independed binding profiles.",
		keys = {
			left_ctrl = 1,
			["keypad_+"] = 1,
		},
	},
}

--[[gamepad analog axis list; [*] states the gamepad number; non-standard gamepads might be supported but extra buttons will not be listed here - check naming after rebinding

[*]gpd_axis_lh
[*]gpd_axis_lv
[*]gpd_axis_rh
[*]gpd_axis_rv

bindings["example"] = {
	aa_stuff_1 = {
		is_locked = true,
		name = "Check This Out",
		desc = "You can have either proper analog input or a pair of absolute buttons. This one is generic.",
		keys = { "is_axis", "1gpd_axis_lh", },
	},
	aa_stuff_2 = {
		name = "Behold the Ultimate Power of Complete Input",
		desc = "And this one is extra fancy.",
		keys = { "is_axis", "keypad_+", "keypad_-", },
	},
}

]]