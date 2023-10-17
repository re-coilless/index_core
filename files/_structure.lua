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

local GUI_STRUCT = {
    bars = {
        hp = new_generic_hp,
        air = new_generic_air,
        flight = new_generic_flight,
        action = {
            mana = new_generic_mana,
            reload = new_generic_reload,
            delay = new_generic_delay,
        },
    },

    gold = new_generic_gold,
    orbs = new_generic_orbs,
    info = new_generic_info,

     --make a universal "slot" fucntion that allows dragging, and displays all the shit automatically and has item type callbacks
    full_inv = f,
    wands = {
        --slot count

        --macro_func
        --wand func (for full inv)
        --wand func (for pickup)
    },
    
    icons = {
        ingestions = new_generic_ingestions,
        stains = new_generic_stains,
        effects = new_generic_effects,
        perks = new_generic_perks,
    },
    
    custom = {}, --table of string-indexed funcs (sorted alphabetically)
}

--<{> MAGICAL APPEND MARKER <}>--

return { GUI_STRUCT, Z_LAYERS, ITEM_TYPES }