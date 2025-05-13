dofile_once( "mods/index_core/files/_lib.lua" )
if( not( ModIsEnabled( "index_core" ))) then return index.self_destruct() end

index.G.gonna_drop = index.G.gonna_drop or false --trigger for "drop on failure to swap"

index.G.slot_memo = index.G.slot_memo or {} --a table of slot states that enables slot code even if the pointer is outside the box
index.G.slot_anim = index.G.slot_anim or {} --fancy dragging anim
index.G.slot_state = index.G.slot_state or false --a check that makes sure only one slot is being dragged at a time
index.G.slot_hover_sfx = index.G.slot_hover_sfx or { 0, false } --context sensitive hover sfx

index.G.mouse_memo = index.G.mouse_memo or {} --for getting pointer delta
index.G.mouse_memo_world = index.G.mouse_memo_world or {} --for getting pointer delta in-world

local frame_num = GameGetFrameNum()
local ctrl_bodies = EntityGetWithTag( "index_ctrl" )
if( not( pen.vld( ctrl_bodies ))) then return pen.gui_builder( false ) end

local controller_id = ctrl_bodies[1]
local storage_reset = pen.magic_storage( controller_id, "reset_settings" )
if( ComponentGetValue2( storage_reset, "value_bool" )) then
    ComponentSetValue2( storage_reset, "value_bool", false )
    index.G.settings = nil
end

index.G.settings = index.G.settings or {
    player_core_off = pen.magic_storage( controller_id, "player_core_off", "value_float" ),
    throw_pos_rad = pen.magic_storage( controller_id, "throw_pos_rad", "value_int" ),
    throw_pos_size = pen.magic_storage( controller_id, "throw_pos_size", "value_int" ),
    throw_force = pen.magic_storage( controller_id, "throw_force", "value_float" ),

    quickest_size = pen.magic_storage( controller_id, "quickest_size", "value_int" ),
    inv_spacings = pen.t.pack( pen.magic_storage( controller_id, "inv_spacings", "value_string" )),
    effect_icon_spacing = pen.magic_storage( controller_id, "effect_icon_spacing", "value_int" ),
    min_effect_duration = pen.magic_storage( controller_id, "min_effect_duration", "value_float" ),
    spell_anim_frames = pen.magic_storage( controller_id, "spell_anim_frames", "value_int" ),

    hp_threshold = pen.magic_storage( controller_id, "low_hp_flashing_threshold", "value_float" ),
    hp_threshold_min = pen.magic_storage( controller_id, "low_hp_flashing_threshold_min", "value_float" ),
    hp_flashing = pen.magic_storage( controller_id, "low_hp_flashing_period", "value_int" ),
    hp_flashing_intensity = pen.magic_storage( controller_id, "low_hp_flashing_intensity", "value_float" ),

    info_radius = pen.magic_storage( controller_id, "info_radius", "value_int" ),
    info_threshold = pen.magic_storage( controller_id, "info_threshold", "value_float" ),
    info_fading = pen.magic_storage( controller_id, "info_fading", "value_int" ),

    loot_marker = pen.magic_storage( controller_id, "loot_marker", "value_string" ),
    slot_pic = {
        bg = pen.magic_storage( controller_id, "slot_pic_bg", "value_string" ),
        bg_alt = pen.magic_storage( controller_id, "slot_pic_bg_alt", "value_string" ),
        hl = pen.magic_storage( controller_id, "slot_pic_hl", "value_string" ),
        active = pen.magic_storage( controller_id, "slot_pic_active", "value_string" ),
        locked = pen.magic_storage( controller_id, "slot_pic_locked", "value_string" ),
    },
    sfxes = {
        click = pen.t.pack( pen.magic_storage( controller_id, "sfx_click", "value_string" )),
        select = pen.t.pack( pen.magic_storage( controller_id, "sfx_select", "value_string" )),
        hover = pen.t.pack( pen.magic_storage( controller_id, "sfx_hover", "value_string" )),
        open = pen.t.pack( pen.magic_storage( controller_id, "sfx_open", "value_string" )),
        close = pen.t.pack( pen.magic_storage( controller_id, "sfx_close", "value_string" )),
        error = pen.t.pack( pen.magic_storage( controller_id, "sfx_error", "value_string" )),
        reset = pen.t.pack( pen.magic_storage( controller_id, "sfx_reset", "value_string" )),
        move_empty = pen.t.pack( pen.magic_storage( controller_id, "sfx_move_empty", "value_string" )),
        move_item = pen.t.pack( pen.magic_storage( controller_id, "sfx_move_item", "value_string" )),
    },
    
    always_show_full = pen.magic_storage( controller_id, "always_show_full", "value_bool" ),
    no_inv_shooting = pen.magic_storage( controller_id, "no_inv_shooting", "value_bool" ),
    do_vanilla_dropping = pen.magic_storage( controller_id, "do_vanilla_dropping", "value_bool" ),
    no_action_on_drop = pen.magic_storage( controller_id, "no_action_on_drop", "value_bool" ),
    force_vanilla_fullest = pen.magic_storage( controller_id, "force_vanilla_fullest", "value_bool" ),

    max_perks = pen.magic_storage( controller_id, "max_perk_count", "value_int" ),
    short_hp = pen.magic_storage( controller_id, "short_hp", "value_bool" ),
    short_gold = pen.magic_storage( controller_id, "short_gold", "value_bool" ),
    fancy_potion_bar = pen.magic_storage( controller_id, "fancy_potion_bar", "value_bool" ),
    reload_threshold = pen.magic_storage( controller_id, "reload_threshold", "value_int" ),

    info_pointer = pen.magic_storage( controller_id, "info_pointer", "value_bool" ),
    info_pointer_alpha = pen.magic_storage( controller_id, "info_pointer_alpha", "value_int" )*0.1,
    info_mtr_state = pen.magic_storage( controller_id, "info_mtr_state", "value_int" ),

    mute_applets = pen.magic_storage( controller_id, "mute_applets", "value_bool" ),
    no_wand_scaling = pen.magic_storage( controller_id, "no_wand_scaling", "value_bool" ),
    allow_tips_always = pen.magic_storage( controller_id, "allow_tips_always", "value_bool" ),
    in_world_pickups = pen.magic_storage( controller_id, "in_world_pickups", "value_bool" ),
}
index.G.settings.main_dump = index.G.settings.main_dump or dofile( "mods/index_core/files/_structure.lua" )

local hooman = EntityGetParent( controller_id )
if( not( EntityGetIsAlive( hooman ))) then
    return pen.gui_builder( false ) end
local hooman_x, hooman_y = EntityGetTransform( hooman )
local main_x, main_y = EntityGetTransform( controller_id )

local ctrl_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ControlsComponent" )
local inv_comp = EntityGetFirstComponentIncludingDisabled( hooman, "Inventory2Component" )
local dmg_comp = EntityGetFirstComponentIncludingDisabled( hooman, "DamageModelComponent" )
local iui_comp = EntityGetFirstComponentIncludingDisabled( hooman, "InventoryGuiComponent" )
local pick_comp = EntityGetFirstComponentIncludingDisabled( hooman, "ItemPickUpperComponent" )
for i,comp in ipairs({ iui_comp, pick_comp }) do
    if( pen.vld( comp, true ) and ComponentGetIsEnabled( comp )) then
        EntitySetComponentIsEnabled( hooman, comp, false )
    end
end

local is_going = pen.magic_storage( controller_id, "forced_state", "value_int" )
if( is_going == 0 ) then
    is_going = ComponentGetValue2( ctrl_comp, "enabled" ) else is_going = is_going > 0 end
if( not( is_going and pen.vld( inv_comp, true ))) then return pen.gui_builder( false ) end

local m_x, m_y = DEBUG_GetMouseWorld()
local md_x = m_x - ( index.G.mouse_memo_world[1] or m_x )
local md_y = m_y - ( index.G.mouse_memo_world[2] or m_y )
index.G.mouse_memo_world = { m_x, m_y }

local mui_x, mui_y = pen.get_mouse_pos()
local muid_x = mui_x - ( index.G.mouse_memo[1] or mui_x )
local muid_y = mui_y - ( index.G.mouse_memo[2] or mui_y )
index.G.mouse_memo = { mui_x, mui_y }

local gui = pen.gui_builder()
local screen_w, screen_h = GuiGetScreenDimensions( gui )

local effect_tbl, perk_tbl = index.get_status_data( hooman )
local mtr_action = index.G.settings.info_mtr_state ~= 2 or index.get_input( "matter_action", true )
local global_modes, global_mutators, applets, item_cats, inv = unpack( index.G.settings.main_dump )
index.D = {
    main_id = controller_id,
    player_id = hooman,
    player_xy = { 0, 0 },

    pointer_world = { m_x, m_y },
    pointer_ui = { mui_x, mui_y },
    pointer_delta = { muid_x, muid_y, math.sqrt( muid_x^2 + muid_y^2 )},
    pointer_delta_world = { md_x, md_y, math.sqrt( md_x^2 + md_y^2 )},
    pointer_matter = mtr_action and pen.get_xy_matter( m_x, m_y, -10 ) or 0,

    matter_action = mtr_action,
    tip_action = index.get_input( "tip_action", true ),
    drag_action = index.get_input( "drag_action", true ),
    shift_action = index.get_input( "shift_action", true ),

    inventory = inv_comp,
    inv_count_quickest = index.G.settings.quickest_size,
    inv_count_quick = ComponentGetValue2( inv_comp, "quick_inventory_slots" ) - index.G.settings.quickest_size,
    inv_count_full = { ComponentGetValue2( inv_comp, "full_inventory_slots_x" ), ComponentGetValue2( inv_comp, "full_inventory_slots_y" )},
    is_opened = ComponentGetValue2( iui_comp, "mActive" ),

    frame_num = frame_num,
    global_mode = pen.magic_storage( controller_id, "global_mode", "value_int" ),

    applets = applets,
    xys = {}, gmod = {},
    gmods = global_modes,

    slot_func = inv.slot,
    icon_func = inv.icon,
    tip_func = inv.tooltip,
    box_func = inv.box,
    wand_func = inv.wand,
    
    orbs = GameGetOrbCountThisRun(),
    icon_data = effect_tbl, perk_data = perk_tbl,

    active_item = pen.get_active_item( hooman ), active_info = {},
    no_mana_4life = tonumber( GlobalsGetValue( "INDEX_FUCKYOURMANA", "0" )) == hooman,
    just_fired = mnee.vanilla_input( "Fire", hooman ),
    can_tinker = false, sampo = 0,

    item_list = {},
    slot_state = {},
    item_cats = item_cats,

    invs = {},
    invs_i = {}, invs_e = {}, invs_p = {
        q = pen.get_child( hooman, "inventory_quick" ),
        f = pen.get_child( hooman, "inventory_full" ),
    },

    dragger = {
        item_id = pen.magic_storage( controller_id, "dragger_item_id", "value_int" ),
        inv_cat = pen.magic_storage( controller_id, "dragger_inv_cat", "value_float" ),
        is_quickest = pen.magic_storage( controller_id, "dragger_is_quickest", "value_bool" ),
        swap_now = pen.magic_storage( controller_id, "dragger_swap_now", "value_bool" ),
    },

    player_core_off = index.G.settings.player_core_off,
    throw_pos_rad = index.G.settings.throw_pos_rad,
    throw_pos_size = index.G.settings.throw_pos_size,
    throw_force = index.G.settings.throw_force,

    inv_spacings = index.G.settings.inv_spacings,
    effect_icon_spacing = index.G.settings.effect_icon_spacing,
    min_effect_duration = index.G.settings.min_effect_duration,
    spell_anim_frames = index.G.settings.spell_anim_frames,

    hp_threshold = index.G.settings.hp_threshold,
    hp_threshold_min = index.G.settings.hp_threshold_min,
    hp_flashing = index.G.settings.hp_flashing,
    hp_flashing_intensity = index.G.settings.hp_flashing_intensity,

    info_radius = index.G.settings.info_radius,
    info_threshold = index.G.settings.info_threshold,
    info_fading = index.G.settings.info_fading,

    loot_marker = index.G.settings.loot_marker,
    slot_pic = index.G.settings.slot_pic,
    sfxes = index.G.settings.sfxes,

    always_show_full = index.G.settings.always_show_full,
    no_inv_shooting = index.G.settings.no_inv_shooting,
    do_vanilla_dropping = index.G.settings.do_vanilla_dropping,
    no_action_on_drop = index.G.settings.no_action_on_drop,

    max_perks = index.G.settings.max_perks,
    short_hp = index.G.settings.short_hp,
    short_gold = index.G.settings.short_gold,
    fancy_potion_bar = index.G.settings.fancy_potion_bar,
    reload_threshold = index.G.settings.reload_threshold,

    info_pointer = index.G.settings.info_pointer,
    info_pointer_alpha = index.G.settings.info_pointer_alpha,
    info_mtr_state = index.G.settings.info_mtr_state,

    no_wand_scaling = index.G.settings.no_wand_scaling,
    allow_tips_always = index.G.settings.allow_tips_always,
    in_world_pickups = index.G.settings.in_world_pickups,
    
    Controls = {},
    DamageModel = {},
    CharacterData = {},
    Wallet = {},
    ItemPickUpper = {},
}

index.D.player_xy = { hooman_x, hooman_y + index.D.player_core_off }
index.D.can_tinker = pen.get_tinker_state( index.D.player_id, index.D.player_xy[1], index.D.player_xy[2])
if( pen.vld( ctrl_comp, true )) then
    index.D.Controls = {
        comp = ctrl_comp,
        fly = { mnee.vanilla_input( "Fly" )},
        act = { mnee.vanilla_input( "Interact" )},
        inv = { mnee.vanilla_input( "Inventory" )},
        lmb = { mnee.vanilla_input( "LeftClick" )},
        rmb = { mnee.vanilla_input( "RightClick" )},
    }
end
if( pen.vld( dmg_comp, true )) then
    index.D.DamageModel = {
        comp = dmg_comp,
        hp = ComponentGetValue2( dmg_comp, "hp" ),
        hp_max = ComponentGetValue2( dmg_comp, "max_hp" ),
        hp_last = ComponentGetValue2( dmg_comp, "mHpBeforeLastDamage" ),
        hp_frame = math.max( frame_num - ComponentGetValue2( dmg_comp, "mLastDamageFrame" ), 0 ),
        air = ComponentGetValue2( dmg_comp, "air_in_lungs" ),
        can_air = ComponentGetValue2( dmg_comp, "air_needed" ),
        air_max = ComponentGetValue2( dmg_comp, "air_in_lungs_max" ),
    }
end
local char_comp = EntityGetFirstComponentIncludingDisabled( hooman, "CharacterDataComponent" )
if( pen.vld( char_comp, true )) then
    local max_flight = ComponentGetValue2( char_comp, "fly_time_max" )*( 2^GameGetGameEffectCount( hooman, "HOVER_BOOST" ))
    index.D.CharacterData = {
        comp = char_comp,
        flight_max = max_flight,
        flight_always = not( ComponentGetValue2( char_comp, "flying_needs_recharge" )),
        flight = math.min( ComponentGetValue2( char_comp, "mFlyingTimeLeft" ), max_flight ),
    }
end
local wallet_comp = EntityGetFirstComponentIncludingDisabled( hooman, "WalletComponent" )
if( pen.vld( wallet_comp, true )) then
    index.D.Wallet = {
        comp = wallet_comp,
        money = ComponentGetValue2( wallet_comp, "money" ),
        money_always = ComponentGetValue2( wallet_comp, "mHasReachedInf" ),
    }
end
if( pen.vld( pick_comp, true )) then
    index.D.ItemPickUpper = {
        comp = pick_comp,
        pick_only = ComponentGetValue2( pick_comp, "only_pick_this_entity" ),
        pick_always = ComponentGetValue2( pick_comp, "pick_up_any_item_buggy" ),
    }
end

--player invs init
index.D.invs[ index.D.invs_p.q ] = index.get_inv_info(
    index.D.invs_p.q, { index.D.inv_count_quickest, index.D.inv_count_quick }, nil,
    function( inv_info ) return {( inv_info.inv_slot[2] == -2 ) and "quick" or "quickest" } end
)
index.D.invs[ index.D.invs_p.f ] = index.get_inv_info( index.D.invs_p.f, index.D.inv_count_full )
pen.t.loop( EntityGetWithTag( "index_inventory" ), function( i, inv )
    index.D.invs[ inv ] = index.get_inv_info( inv )
    table.insert( index.D.invs_e, inv )
end)

--item data init
index.get_items( hooman )
if( pen.vld( index.D.active_item, true )) then
    index.D.active_info = pen.t.get( index.D.item_list, index.D.active_item )
    if( pen.vld( index.D.active_info.id, true )) then
        if( pen.vld( index.D.active_info.AbilityC, true )) then
            index.M.shot_count = index.M.shot_count or {}
            local shot_count = ComponentGetValue2( index.D.active_info.AbilityC, "stat_times_player_has_shot" )
            index.D.just_fired = index.D.just_fired or (( index.M.shot_count[ index.D.active_item ] or shot_count ) < shot_count )
            if( index.D.just_fired ) then index.M.shot_count[ index.D.active_item ] = shot_count end
        end
    else index.D.active_item = 0 end
end

--slot table init
index.D.slot_state = {}
for i,inv_info in pairs( index.D.invs ) do
    if( inv_info.kind[1] == "quick" ) then
        index.D.slot_state[ inv_info.id ] = {
            quickest = pen.t.init( inv_info.size[1], false ),
            quick = pen.t.init( inv_info.size[2], false ),
        }
    else
        index.D.slot_state[ inv_info.id ] = pen.t.init( inv_info.size[1], false )
        for i,slot in ipairs( index.D.slot_state[ inv_info.id ]) do
            index.D.slot_state[ inv_info.id ][i] = pen.t.init( inv_info.size[2], false )
        end
    end
end

--assignment to slots
local nuke_em = {}
for i,info in ipairs( index.D.item_list ) do
    index.D.item_list[i] = index.set_to_slot( info )
    if( info.inv_slot == nil ) then table.insert( nuke_em, i ) end

    local ctrl_func = index.cat_callback( info, "ctrl_script" )
    if( not( pen.vld( ctrl_func ))) then
        index.inventory_man( info, ( info.in_hand or 0 ) > 0 )
    else ctrl_func( info ) end
end
if( pen.vld( nuke_em )) then
    for i = #nuke_em,1,-1 do
        table.remove( index.D.item_list, nuke_em[i])
    end
end

--global mode init
index.D.gmod = global_modes[ index.D.global_mode ]
index.D.gmod.name = GameTextGetTranslatedOrNot( index.D.gmod.name )
index.D.gmod.desc = GameTextGetTranslatedOrNot( index.D.gmod.desc )
if( not( index.D.gmod.allow_advanced_draggables )) then index.D.drag_action = false end
for i,mut in ipairs( global_mutators ) do index.D.xys = mut( index.D.xys ) end
if( index.D.applets.done == nil ) then
    index.D.applets.done = true --make sure this is working

    local close_applets = {
        name = "CLOSE",
        pic = "data/ui_gfx/status_indicators/neutralized.png",
        toggle = function( state )
            if( not( state )) then return end
            if( index.D.is_opened ) then
                index.D.applets.r_state = false
                index.M.applets_r_drift = index.D.applets_r_drift
            else
                index.D.applets.l_state = false
                index.M.applets_l_drift = index.D.applets_l_drift
            end
        end,
    }
    table.insert( index.D.applets.l, close_applets )
    table.insert( index.D.applets.r, close_applets )
end

--hud and inventory handling
local global_callback = index.D.gmod.custom_func
if( global_callback ~= nil ) then
    inv = global_callback( screen_w, screen_h, index.D.xys, inv, false ) end
if( not( index.D.gmod.nuke_default )) then
    if( inv.full_inv ~= nil ) then
        -- index.D.xys.inv_root, index.D.xys.full_inv = inv.full_inv( screen_w, screen_h, index.D.xys )
    end
    if( inv.applet_strip ~= nil ) then
        index.D.xys.applets_l, index.D.xys.applets_r = inv.applet_strip( screen_w, screen_h, index.D.xys )
    end
    
    local bars = inv.bars or {}
    if( bars.hp ~= nil ) then index.D.xys.hp = bars.hp( screen_w, screen_h, index.D.xys ) end
    if( bars.air ~= nil ) then index.D.xys.air = bars.air( screen_w, screen_h, index.D.xys ) end
    if( bars.flight ~= nil ) then index.D.xys.flight = bars.flight( screen_w, screen_h, index.D.xys ) end
    if( bars.bossbar ~= nil ) then index.D.xys.bossbar = bars.bossbar( screen_w, screen_h, index.D.xys ) end
    
    local actions = bars.action or {}
    if( actions.mana ~= nil ) then index.D.xys.mana = actions.mana( screen_w, screen_h, index.D.xys ) end
    if( actions.reload ~= nil ) then index.D.xys.reload = actions.reload( screen_w, screen_h, index.D.xys ) end
    if( actions.delay ~= nil ) then index.D.xys.delay = actions.delay( screen_w, screen_h, index.D.xys ) end

    if( inv.gold ~= nil ) then index.D.xys.gold = inv.gold( screen_w, screen_h, index.D.xys ) end
    if( inv.orbs ~= nil ) then index.D.xys.orbs = inv.orbs( screen_w, screen_h, index.D.xys ) end
    if( inv.info ~= nil ) then index.D.xys.info = inv.info( screen_w, screen_h, index.D.xys ) end
    
    local icons = inv.icons or {}
    if( icons.ingestions ~= nil ) then index.D.xys.ingestions = icons.ingestions( screen_w, screen_h, index.D.xys ) end
    if( icons.stains ~= nil ) then index.D.xys.stains = icons.stains( screen_w, screen_h, index.D.xys ) end
    if( icons.effects ~= nil ) then index.D.xys.effects = icons.effects( screen_w, screen_h, index.D.xys ) end
    if( icons.perks ~= nil ) then index.D.xys.perks = icons.perks( screen_w, screen_h, index.D.xys ) end
    
    if( inv.pickup ~= nil ) then inv.pickup( screen_w, screen_h, index.D.xys, inv.pickup_info ) end
    if( inv.modder ~= nil ) then inv.modder( screen_w, screen_h, index.D.xys ) end
    if( inv.extra ~= nil ) then inv.extra( screen_w, screen_h, index.D.xys ) end
end
if( not( index.D.gmod.nuke_custom )) then
    for cid,cfunc in pen.t.order( inv.custom ) do
        index.D.xys[ cid ] = cfunc( screen_w, screen_h, index.D.xys )
    end
end

if( index.D.gmod.allow_shooting ) then index.D.no_inv_shooting = false end
if( global_callback ~= nil ) then inv = global_callback( screen_w, screen_h, index.D.xys, inv, true ) end
if( index.D.no_inv_shooting and index.D.is_opened ) then pen.new_interface( -5, -5, screen_w + 10, screen_h + 10, 9999 ) end

if( index.D.inv_toggle and not( index.D.gmod.no_inv_toggle or false )) then
    index.M.inv_alpha = frame_num + 15
    index.play_sound( index.D.is_opened and "close" or "open" )
    ComponentSetValue2( iui_comp, "mActive", not( index.D.is_opened ))
elseif( index.D.gmod.no_inv_toggle and not( index.D.is_opened )) then
    ComponentSetValue2( iui_comp, "mActive", true )
end

--dropping handling
if( index.D.do_vanilla_dropping ) then
    if( index.D.dragger.item_id == 0 ) then
        never_drop = false
    elseif( index.D.gmod.allow_advanced_draggables or never_drop ) then
        index.D.dragger.wont_drop = true
    elseif( index.D.drag_action and index.G.slot_memo[ index.D.dragger.item_id ]) then
        never_drop = true
    end
else
    if( not( index.G.gonna_drop )) then
        if( not( index.D.drag_action ) or index.D.gmod.allow_advanced_draggables ) then
            index.D.dragger.wont_drop = true
        elseif( index.D.drag_action and index.G.slot_memo[ index.D.dragger.item_id ]) then
            index.G.gonna_drop = true
        end
    elseif( index.D.dragger.item_id == 0 ) then
        index.G.gonna_drop = false
    else pen.new_shadowed_text( index.D.pointer_ui[1] + 6, index.D.pointer_ui[2] - 13, pen.LAYERS.TIPS_FRONT, "[DROP]" ) end
end

if( index.G.slot_hover_sfx[2]) then
    index.G.slot_hover_sfx[2] = false
elseif( index.G.slot_hover_sfx[1] ~= 0 ) then
    index.G.slot_hover_sfx[1] = 0
end

--dragging handling
if( index.G.slot_state or index.D.dragger.item_id ~= 0 ) then
    if( index.D.dragger.swap_soon ) then
        pen.magic_storage( controller_id, "dragger_swap_now", "value_bool", true )
    else
        if( not( index.G.slot_state ) or index.D.dragger.swap_now ) then
            if( index.D.dragger.swap_now and index.D.dragger.item_id > 0 ) then
                local storage_external = pen.magic_storage( controller_id, "dragger_done_externally" )
                if( ComponentGetValue2( storage_external, "value_bool" )) then
                    ComponentSetValue2( storage_external, "value_bool", false )
                else
                    if( not( index.D.dragger.wont_drop or false ) and inv.drop ~= nil ) then
                        inv.drop( index.D.dragger.item_id )
                    else index.play_sound( "error" ) end
                end
            end
            index.G.gonna_drop = false
            index.G.slot_memo = nil
            index.D.dragger = {}
        end
        pen.magic_storage( controller_id, "dragger_swap_now", "value_bool", false )
        pen.magic_storage( controller_id, "dragger_item_id", "value_int", index.D.dragger.item_id or 0 )
        pen.magic_storage( controller_id, "dragger_inv_cat", "value_float", index.D.dragger.inv_cat or 0 )
        pen.magic_storage( controller_id, "dragger_is_quickest", "value_bool", index.D.dragger.is_quickest or false )
    end
    index.G.slot_state = false
end

pen.gui_builder( true )