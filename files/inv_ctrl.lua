dofile_once( "mods/index_core/files/_lib.lua" )

ctrl_data = ctrl_data or {}
dscrt_btn = dscrt_btn or {}

local controller_id = GetUpdatedEntityID()
local hooman = EntityGetParent( controller_id )
if( not( EntityGetIsAlive( hooman ))) then
    return
end

local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
local ctrl_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ControlsComponent" )

local comp_nuker = { iui_comp, pick_comp }
for i,comp in ipairs( comp_nuker ) do
    if( comp ~= nil and ComponentGetIsEnabled( comp )) then
        EntitySetComponentIsEnabled( hooman, comp, false )
    end
end

local forced_state = ComponentGetValue2( get_storage( controller_id, "forced_state" ), "value_int" )
local is_going = forced_state > 0
if( forced_state == 0 ) then
    is_going = ComponentGetValue2( ctrl_comp, "enabled" )
end

if( is_going ) then
    if( gui == nil ) then
		gui = GuiCreate()
	end
	GuiStartFrame( gui )

    local uid = 0
	local screen_w, screen_h = GuiGetScreenDimensions( gui )
    local inv, z_layers, item_types = unpack( dofile_once( "mods/index_core/files/_structure.lua" ))

    local data = {
        memo = ctrl_data,
        pixel = "mods/index_core/files/pics/THE_GOD_PIXEL.png",
        
        player_id = hooman,
        frame_num = GameGetFrameNum(),
        orbs = GameGetOrbCountThisRun(),
        active_item = get_active_wand( hooman ),

        just_fired = get_discrete_button( hooman, ctrl_comp, "mButtonDownFire" ),
        no_mana_4life = tonumber( GlobalsGetValue( "INDEX_FUCKYOUMANA", "0" )) == hooman,
        
        hp_threshold = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_threshold" ), "value_float" ),
        hp_threshold_min = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_threshold_min" ), "value_float" ),
        hp_flashing = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_period" ), "value_int" ),
        hp_flashing_intensity = ComponentGetValue2( get_storage( controller_id, "low_hp_flashing_intensity" ), "value_float" ),
        fancy_potion_bar = ComponentGetValue2( get_storage( controller_id, "fancy_potion_bar" ), "value_bool" ),
        reload_threshold = ComponentGetValue2( get_storage( controller_id, "reload_threshold" ), "value_int" ),
        delay_threshold = ComponentGetValue2( get_storage( controller_id, "delay_threshold" ), "value_int" ),

        Controls = {},
        DamageModel = {},
        CharacterData = {},
        CharacterPlatforming = {},
        Wallet = {},
        Ability = {},
        MaterialInventory = {},
    }
    local pos_tbl = {}

    if( ctrl_comp ~= nil ) then
        data.Controls = {
            ctrl_comp,

            ComponentGetValue2( ctrl_comp, "mButtonDownInventory" ),
            ComponentGetValue2( ctrl_comp, "mButtonDownInteract" ),
            ComponentGetValue2( ctrl_comp, "mButtonDownFly" ),
        }
    end
    local dmg_comp = EntityGetFirstComponentIncludingDisabled( hooman, "DamageModelComponent" )
    if( dmg_comp ~= nil ) then
        data.DamageModel = {
            dmg_comp,

            ComponentGetValue2( dmg_comp, "max_hp" ),
            ComponentGetValue2( dmg_comp, "hp" ),
            ComponentGetValue2( dmg_comp, "mHpBeforeLastDamage" ),
            math.max( data.frame_num - ComponentGetValue2( dmg_comp, "mLastDamageFrame" ), 0 ),

            ComponentGetValue2( dmg_comp, "air_needed" ),
            ComponentGetValue2( dmg_comp, "air_in_lungs_max" ),
            ComponentGetValue2( dmg_comp, "air_in_lungs" ),   
        }
    end
    local char_comp = EntityGetFirstComponentIncludingDisabled( hooman, "CharacterDataComponent" )
    if( char_comp ~= nil ) then
        data.CharacterData = {
            char_comp,

            ComponentGetValue2( char_comp, "flying_needs_recharge" ),
            ComponentGetValue2( char_comp, "fly_time_max" ),
            ComponentGetValue2( char_comp, "mFlyingTimeLeft" ),
        }
    end
    local wallet_comp = EntityGetFirstComponentIncludingDisabled( hooman, "WalletComponent" )
    if( wallet_comp ~= nil ) then
        data.Wallet = {
            wallet_comp,
            
            ComponentGetValue2( wallet_comp, "mHasReachedInf" ),
            ComponentGetValue2( wallet_comp, "money" ),
        }
    end
    if( data.active_item > 0 ) then
        local abil_comp = EntityGetFirstComponentIncludingDisabled( data.active_item, "AbilityComponent" )
        if( abil_comp ~= nil ) then
            data.memo.shot_count = data.memo.shot_count or {}
            local shot_count = ComponentGetValue2( abil_comp, "stat_times_player_has_shot" )
            data.just_fired = data.just_fired or (( data.memo.shot_count[ data.active_item ] or shot_count ) < shot_count )
            if( data.just_fired ) then
                data.memo.shot_count[ data.active_item ] = shot_count
            end

            data.Ability = {
                abil_comp,

                ComponentGetValue2( abil_comp, "use_gun_script" ),
                ComponentGetValue2( abil_comp, "mana_max" ),
                ComponentGetValue2( abil_comp, "mana" ),
                
                ComponentGetValue2( abil_comp, "never_reload" ),
                math.max( ComponentGetValue2( abil_comp, "mReloadNextFrameUsable" ) - data.frame_num, 0 ),
                math.max( ComponentGetValue2( abil_comp, "mNextFrameUsable" ) - data.frame_num, 0 ),
            }
        end
        local matter_comp = EntityGetFirstComponentIncludingDisabled( data.active_item, "MaterialInventoryComponent" )
        if( matter_comp ~= nil ) then
            data.MaterialInventory = {
                matter_comp,
                
                ComponentGetValue2( matter_comp, "max_capacity" ),
                get_matters( ComponentGetValue2( matter_comp, "count_per_material_type" )),
            }
        end
    end

    local bars = inv.bars or {}
    if( bars.hp ~= nil ) then
        uid, pos_tbl.hp = bars.hp( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( bars.air ~= nil ) then
        uid, pos_tbl.air = bars.air( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( bars.flight ~= nil ) then
        uid, pos_tbl.flight = bars.flight( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    local actions = bars.action or {}
    if( actions.mana ~= nil ) then
        uid, pos_tbl.mana = actions.mana( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( actions.reload ~= nil ) then
        uid, pos_tbl.reload = actions.reload( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( actions.delay ~= nil ) then
        uid, pos_tbl.delay = actions.delay( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    if( inv.gold ~= nil ) then
        uid, pos_tbl.gold = inv.gold( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( inv.orbs ~= nil ) then
        uid, pos_tbl.orbs = inv.orbs( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
else
    gui = gui_killer( gui )
end