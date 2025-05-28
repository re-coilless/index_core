dofile_once( "mods/index_core/files/_lib.lua" )
if( not( ModIsEnabled( "index_core" ))) then return index.self_destruct() end
local xM = index.M

-- local check = GameGetRealWorldTimeSinceStarted()*1000

xM.gonna_drop = xM.gonna_drop or false --trigger for "drop on failure to swap"

xM.slot_anim = xM.slot_anim or {} --fancy dragging anim
xM.is_dragging = xM.is_dragging or false --a check that makes sure only one slot is being dragged at a time
xM.pending_slots = xM.pending_slots or {} --a table of slot states that enables slot code even if the pointer is outside the box
xM.slot_hover_sfx = xM.slot_hover_sfx or { 0, false } --context sensitive hover sfx
xM.pinned_tips = xM.pinned_tips or {} --tooltips that are prevented from closing

xM.mouse_memo = xM.mouse_memo or {} --for getting pointer delta
xM.mouse_memo_world = xM.mouse_memo_world or {} --for getting pointer delta in-world

local frame_num = GameGetFrameNum()
local ctrl_bodies = EntityGetWithTag( "index_ctrl" )
if( not( pen.vld( ctrl_bodies ))) then return pen.gui_builder( false ) end
local performance_check = false --frame_num%600 == 0

local function gg( g, dft )
    xM.settings_init = xM.settings_init or {}
    if(( GlobalsGetValue( "INDEX_GLOBAL_LOCK_SETTINGS", "bool0" ) == "bool0" ) and not( xM.settings_init[g])) then
        xM.settings_init[g] = true
        local setting_id, is_real = string.gsub( g, "^INDEX_SETTING_", "" )
        if(( is_real or 0 ) > 0 ) then GlobalsSetValue( g, pen.v2s( pen.setting_get( "index_core."..setting_id ), nil, nil, true )) end
    end
    return pen.s2v( GlobalsGetValue( g, pen.v2s( dft, nil, nil, true )))
end

local hooman = ctrl_bodies[1]
if( not( EntityGetIsAlive( hooman ))) then return pen.gui_builder( false ) end
local hooman_x, hooman_y = EntityGetTransform( hooman )

if( gg( index.GLOBAL_SYNC_SETTINGS, false )) then
    GlobalsSetValue( index.GLOBAL_SYNC_SETTINGS, "bool0" )
    pen.c.index_settings, xM.settings_init = nil, {}
end

pen.c.index_settings = pen.c.index_settings or {
    player_core_off = gg( index.GLOBAL_PLAYER_OFF_Y, -7 ),
    throw_pos_rad = gg( index.GLOBAL_THROW_POS_RAD, 10 ),
    throw_pos_size = gg( index.GLOBAL_THROW_POS_SIZE, 10 ),
    throw_force = gg( index.GLOBAL_THROW_FORCE, 40 ),
    
    inv_quickest_size = gg( index.GLOBAL_QUICKEST_SIZE, 4 ),
    inv_spacings = pen.t.pack( gg( index.GLOBAL_SLOT_SPACING, "|2|9|" )),
    effect_icon_spacing = gg( index.GLOBAL_EFFECT_SPACING, 45 ),
    min_effect_duration = gg( index.GLOBAL_MIN_EFFECT_DURATION, 0.001 ),
    spell_anim_frames = gg( index.GLOBAL_SPELL_ANIM_FRAMES, 120 ),

    hp_threshold = gg( index.GLOBAL_LOW_HP_FLASHING_THRESHOLD, 1 ),
    hp_threshold_min = gg( index.GLOBAL_LOW_HP_FLASHING_THRESHOLD_MIN, 0.2 ),
    hp_flashing = gg( index.GLOBAL_LOW_HP_FLASHING_PERIOD, 15 ),
    hp_flashing_intensity = gg( index.GLOBAL_LOW_HP_FLASHING_INTENSITY, 0.75 ),

    info_radius = gg( index.GLOBAL_INFO_RADIUS, 10 ),
    info_threshold = gg( index.GLOBAL_INFO_THRESHOLD, 3 ),
    info_fading = gg( index.GLOBAL_INFO_FADING, 20 ),

    loot_marker = gg( index.GLOBAL_LOOT_MARKER, "data/ui_gfx/items/powder_stash.png" ),
    slot_pic = {
        bg = gg( index.GLOBAL_SLOT_PIC_BG, "data/ui_gfx/inventory/full_inventory_box.png" ),
        bg_alt = gg( index.GLOBAL_SLOT_PIC_BG_ALT, "data/ui_gfx/inventory/hover_info_empty_slot.png" ),
        hl = gg( index.GLOBAL_SLOT_PIC_HL, "data/ui_gfx/inventory/full_inventory_box_highlight.png" ),
        active = gg( index.GLOBAL_SLOT_PIC_ACTIVE, "data/ui_gfx/inventory/highlight.xml" ),
        locked = gg( index.GLOBAL_SLOT_PIC_LOCKED, "data/ui_gfx/inventory/inventory_box_inactive_overlay.png" ),
    },
    sfxes = {
        click = pen.t.pack( gg( index.GLOBAL_SFX_CLICK, "|data/audio/Desktop/ui.bank|ui/button_click|" )),
        select = pen.t.pack( gg( index.GLOBAL_SFX_SELECT, "|data/audio/Desktop/ui.bank|ui/item_equipped|" )),
        hover = pen.t.pack( gg( index.GLOBAL_SFX_HOVER, "|data/audio/Desktop/ui.bank|ui/item_move_over_new_slot|" )),
        open = pen.t.pack( gg( index.GLOBAL_SFX_OPEN, "|data/audio/Desktop/ui.bank|ui/inventory_open|" )),
        close = pen.t.pack( gg( index.GLOBAL_SFX_CLOSE, "|data/audio/Desktop/ui.bank|ui/inventory_close|" )),
        error = pen.t.pack( gg( index.GLOBAL_SFX_ERROR, "|data/audio/Desktop/ui.bank|ui/item_move_denied|" )),
        reset = pen.t.pack( gg( index.GLOBAL_SFX_RESET, "|data/audio/Desktop/ui.bank|ui/replay_saved|" )),
        move_empty = pen.t.pack( gg( index.GLOBAL_SFX_MOVE_EMPTY, "|data/audio/Desktop/ui.bank|ui/item_move_success|" )),
        move_item = pen.t.pack( gg( index.GLOBAL_SFX_MOVE_ITEM, "|data/audio/Desktop/ui.bank|ui/item_switch_places|" )),
    },
    
    always_show_full = gg( index.SETTING_ALWAYS_SHOW_FULL, false ),
    no_inv_shooting = gg( index.SETTING_NO_INV_SHOOTING, true ),
    do_vanilla_dropping = gg( index.SETTING_VANILLA_DROPPING, true ),
    no_action_on_drop = gg( index.SETTING_SILENT_DROPPING, true ),
    force_vanilla_fullest = gg( index.SETTING_FORCE_VANILLA_FULLEST, false ),
    pickup_distance = gg( index.SETTING_PICKUP_DISTANCE, 50 ),

    max_perks = gg( index.SETTING_MAX_PERK_COUNT, 5 ),
    short_hp = gg( index.SETTING_SHORT_HP, true ),
    short_gold = gg( index.SETTING_SHORT_GOLD, false ),
    fancy_potion_bar = gg( index.SETTING_FANCY_POTION_BAR, true ),
    reload_threshold = gg( index.SETTING_RELOAD_THRESHOLD, 30 ),

    info_pointer = gg( index.SETTING_INFO_POINTER, false ),
    info_pointer_alpha = gg( index.SETTING_INFO_POINTER_ALPHA, 5 )*0.1,
    info_mtr_state = gg( index.SETTING_INFO_MATTER_MODE, 1 ),

    mute_applets = gg( index.SETTING_MUTE_APPLETS, false ),
    no_wand_scaling = gg( index.SETTING_NO_WAND_SCALING, false ),
    allow_tips_always = gg( index.SETTING_FORCE_SLOT_TIPS, false ),
    in_world_pickups = gg( index.SETTING_IN_WORLD_PICKUPS, false ),
    in_world_tips = gg( index.SETTING_IN_WORLD_TIPS, false ),
    secret_shopper = gg( index.SETTING_SECRET_SHOPPER, false ),
    boss_bar_mode = gg( index.SETTING_BOSS_BAR_MODE, 1 ),
    big_wand_spells = gg( index.SETTING_BIG_WAND_SPELLS, true ),
    spell_frame = gg( index.SETTING_SPELL_FRAME, 1 ),
}

pen.c.index_struct = pen.c.index_struct or dofile( "mods/index_core/files/_structure.lua" )

local ctrl_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ControlsComponent" )
local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
local dmg_comp = EntityGetFirstComponentIncludingDisabled( hooman, "DamageModelComponent" )
local char_comp = EntityGetFirstComponentIncludingDisabled( hooman, "CharacterDataComponent" )
local wallet_comp = EntityGetFirstComponentIncludingDisabled( hooman, "WalletComponent" )

local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
for i,comp in ipairs({ iui_comp, pick_comp }) do
    if( pen.vld( comp, true ) and ComponentGetIsEnabled( comp )) then
        EntitySetComponentIsEnabled( hooman, comp, false )
    end
end

local is_going = gg( index.GLOBAL_FORCED_STATE, 0 )
if( is_going == 0 ) then
    is_going = ComponentGetValue2( ctrl_comp, "enabled" ) else is_going = is_going > 0 end
if( not( is_going and pen.vld( inv_comp, true ))) then return pen.gui_builder( false ) end

local m_x, m_y = DEBUG_GetMouseWorld()
local md_x = m_x - ( xM.mouse_memo_world[1] or m_x )
local md_y = m_y - ( xM.mouse_memo_world[2] or m_y )
xM.mouse_memo_world = { m_x, m_y }

local mui_x, mui_y = pen.get_mouse_pos()
local muid_x = mui_x - ( xM.mouse_memo[1] or mui_x )
local muid_y = mui_y - ( xM.mouse_memo[2] or mui_y )
xM.mouse_memo = { mui_x, mui_y }

local gui = pen.gui_builder()
local screen_w, screen_h = GuiGetScreenDimensions( gui )

local effect_tbl, perk_tbl = index.get_status_data( hooman )
local mtr_action = pen.c.index_settings.info_mtr_state ~= 2 or index.get_input( "matter_action", true )

local global_modes, global_mutators, applets,
    boss_bars, wand_stats, spell_stats, matter_desc,
    item_cats, inv = unpack( pen.c.index_struct )

index.D = {
    xys = {}, gmod = {},
    applets = applets, gmods = global_modes,
    perk_data = perk_tbl, icon_data = effect_tbl,
    item_cats = item_cats, boss_bars = boss_bars,
    wand_stats = wand_stats, spell_stats = spell_stats,

    box_func = inv.box,
    slot_func = inv.slot, icon_func = inv.icon,
    wand_func = inv.wand, tip_func = inv.tooltip,

    player_id = hooman,
    player_xy = { 0, 0 },
    can_tinker = false, sampo = 0,
    orbs = GameGetOrbCountThisRun(),
    just_fired = ({ mnee.vanilla_input( "Fire", hooman )})[2],
    active_item = pen.get_active_item( hooman ), active_info = {},
    no_mana = tonumber( GlobalsGetValue( index.GLOBAL_FUCK_YOUR_MANA, "0" )) == hooman,

    Controls = {},
    Wallet = {}, ItemPickUpper = {},
    DamageModel = {}, CharacterData = {},

    global_mode = gg( index.GLOBAL_GLOBAL_MODE, 1 ),
    is_opened = ComponentGetValue2( iui_comp, "mActive" ),

    frame_num = frame_num,
    screen_dims = { screen_w, screen_h },
    pointer_world = { m_x, m_y }, pointer_ui = { mui_x, mui_y },
    pointer_delta = { muid_x, muid_y, math.sqrt( muid_x^2 + muid_y^2 )},
    pointer_delta_world = { md_x, md_y, math.sqrt( md_x^2 + md_y^2 )},
    pointer_matter = mtr_action and pen.get_xy_matter( m_x, m_y, -10 ) or 0,

    matter_action = mtr_action,
    tip_action = index.get_input( "tip_action", true ),
    drag_action = index.get_input( "drag_action", true ),
    shift_action = index.get_input( "shift_action", true ),
    hide_slot_tips = index.get_input( "hide_slot_tips", true ),

    item_list = {}, slot_state = {},
    invs = {}, invs_i = {}, invs_e = {},
    invs_p = { q = pen.get_child( hooman, "inventory_quick" ), f = pen.get_child( hooman, "inventory_full" )},
    inv_quick_size = ComponentGetValue2( inv_comp, "quick_inventory_slots" ) - pen.c.index_settings.inv_quickest_size,
    inv_full_size = { ComponentGetValue2( inv_comp, "full_inventory_slots_x" ), ComponentGetValue2( inv_comp, "full_inventory_slots_y" )},

    dragger = {
        item_id = gg( index.GLOBAL_DRAGGER_ITEM_ID, 0 ),
        inv_cat = gg( index.GLOBAL_DRAGGER_INV_CAT, 0 ),
        is_quickest = gg( index.GLOBAL_DRAGGER_IS_QUICKEST, false ),
        swap_soon = false, swap_now = gg( index.GLOBAL_DRAGGER_SWAP_NOW, false ),
    },
}

local xD = index.D
for field,value in pairs( pen.c.index_settings ) do xD[ field ] = value end

xD.player_xy = { hooman_x, hooman_y + xD.player_core_off }
xD.can_tinker = pen.get_tinker_state( xD.player_id, xD.player_xy[1], xD.player_xy[2])

if( pen.vld( ctrl_comp, true )) then
    xD.Controls = { comp = ctrl_comp,
        fly = { mnee.vanilla_input( "Fly", hooman )},
        act = { mnee.vanilla_input( "Interact", hooman )},
        inv = { mnee.vanilla_input( "Inventory", hooman )},
        lmb = { mnee.vanilla_input( "LeftClick", hooman )},
        rmb = { mnee.vanilla_input( "RightClick", hooman )}}
end
if( pen.vld( dmg_comp, true )) then
    xD.DamageModel = { comp = dmg_comp,
        hp = ComponentGetValue2( dmg_comp, "hp" ),
        hp_max = ComponentGetValue2( dmg_comp, "max_hp" ),
        hp_last = ComponentGetValue2( dmg_comp, "mHpBeforeLastDamage" ),
        hp_frame = math.max( frame_num - ComponentGetValue2( dmg_comp, "mLastDamageFrame" ), 0 ),
        
        air = ComponentGetValue2( dmg_comp, "air_in_lungs" ),
        can_air = ComponentGetValue2( dmg_comp, "air_needed" ),
        air_max = ComponentGetValue2( dmg_comp, "air_in_lungs_max" )}
end
if( pen.vld( char_comp, true )) then
    local max_flight =
        ComponentGetValue2( char_comp, "fly_time_max" )*( 2^GameGetGameEffectCount( hooman, "HOVER_BOOST" ))
    xD.CharacterData = { comp = char_comp, flight_max = max_flight,
        flight_always = not( ComponentGetValue2( char_comp, "flying_needs_recharge" )),
        flight = math.min( ComponentGetValue2( char_comp, "mFlyingTimeLeft" ), max_flight )}
end
if( pen.vld( wallet_comp, true )) then
    xD.Wallet = { comp = wallet_comp,
        money = ComponentGetValue2( wallet_comp, "money" ),
        money_always = ComponentGetValue2( wallet_comp, "mHasReachedInf" )}
end
if( pen.vld( pick_comp, true )) then
    xD.ItemPickUpper = { comp = pick_comp,
        pick_only = ComponentGetValue2( pick_comp, "only_pick_this_entity" ),
        pick_always = ComponentGetValue2( pick_comp, "pick_up_any_item_buggy" )}
end



--invs init
xD.invs[ xD.invs_p.q ] = index.get_inv_info(
    xD.invs_p.q, { xD.inv_quickest_size, xD.inv_quick_size }, nil,
    function( inv_info ) return {( inv_info.inv_slot[2] == -2 ) and "quick" or "quickest" } end)
xD.invs[ xD.invs_p.f ] = index.get_inv_info( xD.invs_p.f, xD.inv_full_size )
pen.t.loop( EntityGetWithTag( "index_inventory" ), function( i, inv )
    local xD = index.D
    xD.invs[ inv ] = index.get_inv_info( inv ); table.insert( xD.invs_e, inv )
end)

if( pen.vld( xD.active_item, true )) then --just fix this with phantom "hand" item
    local got_items = pen.vld( EntityGetAllChildren( xD.invs_p.q ))
    if( EntityGetParent( xD.active_item ) == xD.invs_p.f and got_items ) then
        xD.active_item = 0; pen.reset_active_item( xD.player_id )
    end
end

--item data init
index.get_items( hooman )
if( pen.vld( xD.active_item, true )) then
    xD.active_info = pen.t.get( xD.item_list, xD.active_item, nil, nil, {})
    if( pen.vld( xD.active_info.id, true )) then
        if( pen.vld( xD.active_info.AbilityC, true )) then
            xM.shot_count = xM.shot_count or {}
            local shot_count = ComponentGetValue2( xD.active_info.AbilityC, "stat_times_player_has_shot" )
            xD.just_fired = xD.just_fired or (( xM.shot_count[ xD.active_item ] or shot_count ) < shot_count )
            if( xD.just_fired ) then xM.shot_count[ xD.active_item ] = shot_count end
        end
    else xD.active_item = 0 end
end



--slot table init
xD.slot_state = {}
for i,inv_info in pairs( xD.invs ) do
    if( inv_info.kind[1] == "quick" ) then
        xD.slot_state[ inv_info.id ] = {
            quickest = pen.t.init( inv_info.size[1], false ),
            quick = pen.t.init( inv_info.size[2], false ),
        }
    else
        xD.slot_state[ inv_info.id ] = pen.t.init( inv_info.size[1], false )
        for i,slot in ipairs( xD.slot_state[ inv_info.id ]) do
            xD.slot_state[ inv_info.id ][i] = pen.t.init( inv_info.size[2], false )
        end
    end
end

local get_out = {}
for i,info in ipairs( xD.item_list ) do
    xD.item_list[i] = index.set_to_slot( info )
    if( not( pen.vld( info.inv_slot ))) then table.insert( get_out, i ) end

    local ctrl_func = index.cat_callback( info, "ctrl_script" )
    if( not( pen.vld( ctrl_func ))) then
        index.inventory_man( info, pen.vld( info.in_hand, true ), info.deep_processing )
    else ctrl_func( info ) end
end
for i = #get_out,1,-1 do table.remove( xD.item_list, get_out[i]) end



--gmods and applets init
xD.gmod = xD.gmods[ xD.global_mode ]
xD.gmod.name, xD.gmod.desc = pen.magic_translate( xD.gmod.name ), pen.magic_translate( xD.gmod.desc )
for i,mut in ipairs( global_mutators ) do xD.xys = mut( xD.xys ) end

if( xD.applets.done == nil ) then
    xD.applets.done = true
    local close_applets = {
        name = "CLOSE",
        pic = "data/ui_gfx/status_indicators/neutralized.png",
        toggle = function( state )
            if( not( state )) then return end
            local xD, xM = index.D, index.M

            if( xD.is_opened ) then
                xD.applets.r_state, xM.applets_r_drift = false, xD.applets_r_drift
            else xD.applets.l_state, xM.applets_l_drift = false, xD.applets_l_drift end
        end,
    }

    table.insert( xD.applets.l, close_applets )
    table.insert( xD.applets.r, close_applets )
end



--rendering pass
local global_callback = xD.gmod.custom_func
if( xD.gmod.allow_shooting ) then xD.no_inv_shooting = false end
if( pen.vld( global_callback )) then inv = global_callback( screen_w, screen_h, xD.xys, inv, false ) end

if( not( xD.gmod.nuke_default )) then
    if( pen.vld( inv.full_inv )) then xD.xys.inv_root, xD.xys.full_inv = inv.full_inv( screen_w, screen_h, xD.xys ) end
    
    local bars = inv.bars or {}
    if( pen.vld( bars.hp )) then xD.xys.hp = bars.hp( screen_w, screen_h, xD.xys ) end
    if( pen.vld( bars.air )) then xD.xys.air = bars.air( screen_w, screen_h, xD.xys ) end
    if( pen.vld( bars.flight )) then xD.xys.flight = bars.flight( screen_w, screen_h, xD.xys ) end
    if( pen.vld( bars.bossbar )) then xD.xys.bossbar = bars.bossbar( screen_w, screen_h, xD.xys ) end
    
    if( pen.vld( inv.applet_strip )) then xD.xys.applets_l, xD.xys.applets_r = inv.applet_strip( screen_w, screen_h, xD.xys ) end

    local actions = bars.action or {}
    if( pen.vld( actions.mana )) then xD.xys.mana = actions.mana( screen_w, screen_h, xD.xys ) end
    if( pen.vld( actions.reload )) then xD.xys.reload = actions.reload( screen_w, screen_h, xD.xys ) end
    if( pen.vld( actions.delay )) then xD.xys.delay = actions.delay( screen_w, screen_h, xD.xys ) end

    if( pen.vld( inv.gold )) then xD.xys.gold = inv.gold( screen_w, screen_h, xD.xys ) end
    if( pen.vld( inv.orbs )) then xD.xys.orbs = inv.orbs( screen_w, screen_h, xD.xys ) end
    if( pen.vld( inv.info )) then xD.xys.info = inv.info( screen_w, screen_h, xD.xys ) end
    
    local icons = inv.icons or {}
    if( pen.vld( icons.ingestions )) then xD.xys.ingestions = icons.ingestions( screen_w, screen_h, xD.xys ) end
    if( pen.vld( icons.stains )) then xD.xys.stains = icons.stains( screen_w, screen_h, xD.xys ) end
    if( pen.vld( icons.effects )) then xD.xys.effects = icons.effects( screen_w, screen_h, xD.xys ) end
    if( pen.vld( icons.perks )) then xD.xys.perks = icons.perks( screen_w, screen_h, xD.xys ) end

    if( pen.vld( inv.pickup )) then inv.pickup( screen_w, screen_h, xD.xys, inv.pickup_info ) end
    if( pen.vld( inv.gmodder )) then inv.gmodder( screen_w, screen_h, xD.xys ) end
    if( pen.vld( inv.extra )) then inv.extra( screen_w, screen_h, xD.xys ) end
end

if( not( xD.gmod.nuke_custom )) then
    for cid,cfunc in pen.t.order( inv.custom ) do xD.xys[ cid ] = cfunc( screen_w, screen_h, xD.xys ) end
end

if( xD.inv_toggle and not( xD.gmod.force_inv_open )) then
    xM.inv_alpha = frame_num + 15
    index.play_sound( xD.is_opened and "close" or "open" )
    ComponentSetValue2( iui_comp, "mActive", not( xD.is_opened ))
elseif( xD.gmod.force_inv_open and not( xD.is_opened )) then ComponentSetValue2( iui_comp, "mActive", true ) end
if( xD.no_inv_shooting and xD.is_opened ) then pen.new_interface( -5, -5, screen_w + 10, screen_h + 10, 9999 ) end
if( pen.vld( global_callback )) then inv = global_callback( screen_w, screen_h, xD.xys, inv, true ) end



--dropping handling
if( xD.do_vanilla_dropping ) then
    if( not( pen.vld( xD.dragger.item_id, true ))) then
        xM.never_drop = false
    elseif( xD.gmod.allow_advanced_draggables or xM.never_drop ) then
        xD.dragger.wont_drop = true
    elseif( xD.drag_action and xM.pending_slots[ xD.dragger.item_id ]) then
        xM.never_drop = true
    end
else
    if( not( xM.gonna_drop )) then
        if( not( xD.drag_action ) or xD.gmod.allow_advanced_draggables ) then
            xD.dragger.wont_drop = true
        elseif( xD.drag_action and xM.pending_slots[ xD.dragger.item_id ]) then
            xM.gonna_drop = true
        end
    elseif( not( pen.vld( xD.dragger.item_id, true ))) then
        xM.gonna_drop = false
    else pen.new_shadowed_text( xD.pointer_ui[1] + 6, xD.pointer_ui[2] - 13, pen.LAYERS.TIPS_FRONT, "[DROP]" ) end
end

if( xM.slot_hover_sfx[2]) then
    xM.slot_hover_sfx[2] = false
elseif( xM.slot_hover_sfx[1] ~= 0 ) then
    xM.slot_hover_sfx[1] = 0
end



--dragging handling
if( xM.is_dragging or xD.dragger.item_id ~= 0 ) then
    if( not( xD.dragger.swap_soon )) then
        if( not( xM.is_dragging ) or xD.dragger.swap_now ) then
            if( xD.dragger.swap_now and xD.dragger.item_id > 0 ) then
                if( not( gg( index.GLOBAL_DRAGGER_EXTERNAL, false ))) then
                    if( not( xD.dragger.wont_drop ) and pen.vld( inv.drop )) then
                        inv.drop( xD.dragger.item_id )
                    else index.play_sound( "error" ) end
                else GlobalsSetValue( index.GLOBAL_DRAGGER_EXTERNAL, "bool0" ) end
            end

            xM.gonna_drop, xM.pending_slots, xD.dragger = false, nil, {}
        end

        GlobalsSetValue( index.GLOBAL_DRAGGER_SWAP_NOW, "bool0" )
        GlobalsSetValue( index.GLOBAL_DRAGGER_ITEM_ID, tostring( xD.dragger.item_id or 0 ))
        GlobalsSetValue( index.GLOBAL_DRAGGER_INV_CAT, tostring( xD.dragger.inv_cat or 0 ))
        GlobalsSetValue( index.GLOBAL_DRAGGER_IS_QUICKEST, ( xD.dragger.is_quickest or false ) and "bool1" or "bool0" )
    else GlobalsSetValue( index.GLOBAL_DRAGGER_SWAP_NOW, "bool1" ) end
    
    xM.is_dragging = false
end

pen.gui_builder( true )
index.D = nil

-- print( GameGetRealWorldTimeSinceStarted()*1000 - check )