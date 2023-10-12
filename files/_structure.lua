dofile_once( "mods/index_core/files/_elements.lua" )

local Z_LAYERS = {
    background = 2, --general background

    main_far_back = 1, --slot background
    main_back = 0.01, --bar background
    main = 0, --slot highlights, bars, perks, effects
    main_front = -0.01,

    icons_back = -0.09,
    icons = -1, --inventory item icons
    icons_front = -1.01, --spell charges

    tips_back = -10100,
    tips = -10101, --tooltips duh 
    tips_front = -10102,
}

local ITEM_TYPES = {
    {
        --name
        --check func
        --on_hover
        --ctrl_script
    },
    --wand
    --potion
    --spell
    --item
    --tablet
}

local INV_STRUCT = {
    bars = {
        hp = new_generic_hp,
        flight = new_generic_flight,
        air = new_generic_air,
        action = {
            mana = new_generic_mana,
            delay = new_generic_delay,
            recharge = new_generic_recharge,
        },
    },

    gold = new_generic_gold,
    orbs = new_generic_orbs,

    wands = {
        --slot count
        --slot func
        --macro_func
    },
    items = {
        --slot count
        --slot func
        --macro func
    },
    spells = {
        --slot count
        --slot func
        --macro func
    },

    info = f, --DEBUG_SHOW_MOUSE_MATERIAL
    
    perks = {
        --max count
    },
    effects = f,

    custom = {}, --table of string-indexed funcs
}

--<{> MAGICAL APPEND MARKER <}>--

return { INV_STRUCT, Z_LAYERS, ITEM_TYPES }