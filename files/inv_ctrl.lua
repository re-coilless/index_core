dofile_once( "mods/index_core/files/_lib.lua" )

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
        player_id = hooman,
        frame_num = GameGetFrameNum(),
        
        active_item = get_active_wand( hooman ),
        orbs = GameGetOrbCountThisRun(),

        DamageModel = {},
        CharacterData = {},
        CharacterPlatforming = {},
        Wallet = {},
    }
    local pos_tbl = {}

    local dmg_comp = EntityGetFirstComponentIncludingDisabled( hooman, "DamageModelComponent" )
    if( dmg_comp ~= nil ) then
        data.DamageModel = {
            dmg_comp,

            ComponentGetValue2( dmg_comp, "max_hp" ),
            ComponentGetValue2( dmg_comp, "hp" ),
            ComponentGetValue2( dmg_comp, "mHpBeforeLastDamage" ),
            ComponentGetValue2( dmg_comp, "mLastDamageFrame" ),

            ComponentGetValue2( dmg_comp, "air_needed" ),
            ComponentGetValue2( dmg_comp, "air_in_lungs_max" ),
            ComponentGetValue2( dmg_comp, "air_in_lungs" ),   
        }
    end
    local char_comp = EntityGetFirstComponentIncludingDisabled( hooman, "CharacterDataComponent" )
    if( char_comp ~= nil ) then
        data.CharacterData = {
            char_comp,

            ComponentGetValue2( char_comp, "fly_time_max" ),
            ComponentGetValue2( char_comp, "mFlyingTimeLeft" ),
        }
    end
    local plat_comp = EntityGetFirstComponentIncludingDisabled( hooman, "CharacterPlatformingComponent" )
    if( plat_comp ~= nil ) then
        data.CharacterPlatforming = {
            plat_comp,

            ComponentGetValue2( plat_comp, "mFlyThrottle" ),
        }
    end
    local wallet_comp = EntityGetFirstComponentIncludingDisabled( hooman, "WalletComponent" )
    if( wallet_comp ~= nil ) then
        data.Wallet = {
            wallet_comp,
            
            ComponentGetValue2( wallet_comp, "money" ),
            ComponentGetValue2( wallet_comp, "mMoneyPrevFrame" ),
            ComponentGetValue2( wallet_comp, "mHasReachedInf" ),
        }
    end

    local bars = inv.bars or {}
    if( bars.hp ~= nil and dmg_comp ~= nil ) then
        uid, pos_tbl.hp = bars.hp( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( bars.flight ~= nil and char_comp ~= nil ) then
        uid, pos_tbl.flight = bars.flight( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( bars.air ~= nil and dmg_comp ~= nil ) then
        uid, pos_tbl.air = bars.air( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end

    local actions = bars.action or {}
    if( actions.mana ~= nil ) then
        
    end
    if( actions.delay ~= nil ) then
        
    end
    if( actions.recharge ~= nil ) then
        
    end

    if( inv.gold ~= nil and wallet_comp ~= nil ) then
        uid, pos_tbl.gold = inv.gold( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
    if( inv.orbs ~= nil ) then
        uid, pos_tbl.orbs = inv.orbs( gui, uid, screen_w, screen_h, data, z_layers, pos_tbl )
    end
else
    gui = gui_killer( gui )
end