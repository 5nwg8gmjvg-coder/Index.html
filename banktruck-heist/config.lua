Config = {}

-- ============================================================
--  FRAMEWORK / RESOURCE NAMES
--  Adjust these if your server uses different resource names
--  (e.g. some servers rename qs-vehiclekeys to "qs-keys").
-- ============================================================
Config.Core           = 'qbx_core'      -- 'qbx_core' or 'qb-core'
Config.InventoryResource = 'qs-inventory'
Config.KeysResource      = 'qs-keys'    -- change to 'qs-vehiclekeys' if that's what's installed

-- ============================================================
--  MISSION PED
-- ============================================================
Config.Ped = {
    model    = 'a_m_m_business_01',
    coords   = vector4(-43.4, -1749.5, 29.4, 240.0), -- x, y, z, heading (docks area, edit to taste)
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    label    = 'Inside Contact',
    interactDistance = 2.5,
}

Config.Blip = {
    show     = true,
    sprite   = 500,
    color    = 5,
    scale    = 0.8,
    label    = 'Inside Contact',
}

-- ============================================================
--  ACCESS REQUIREMENTS
-- ============================================================
Config.RequiredPolice = 3          -- minimum on-duty police needed to start the heist
Config.PoliceJobs     = { 'police', 'sheriff', 'bcso' }

Config.Cooldown       = 45         -- minutes of global cooldown after a heist ends (success or the truck being looted)
Config.OneAtATime     = true       -- only one bank truck heist can be active on the server at once

-- ============================================================
--  BANK TRUCK
-- ============================================================
Config.TruckModel = `brickade` -- GTA Online's armored bank security truck

-- At least 5 spawn locations. Each has a spawn point (vector4) and a
-- patrol route (list of vector3 points) that the truck will drive between
-- on a loop until it is forced to stop.
Config.TruckSpawns = {
    {
        spawn = vector4(-43.2, -1748.9, 29.4, 240.0),
        route = {
            vector3(-198.9, -1470.6, 31.3),
            vector3(-350.9, -1480.6, 27.9),
            vector3(-540.6, -1274.9, 22.7),
            vector3(-43.2, -1748.9, 29.4),
        },
    },
    {
        spawn = vector4(147.9, -1035.8, 29.3, 26.0),
        route = {
            vector3(243.2, -827.9, 30.2),
            vector3(133.4, -712.7, 33.0),
            vector3(-47.9, -671.6, 33.0),
            vector3(147.9, -1035.8, 29.3),
        },
    },
    {
        spawn = vector4(314.8, -215.9, 54.2, 250.0),
        route = {
            vector3(150.5, -222.4, 54.0),
            vector3(-6.7, -226.5, 37.9),
            vector3(-152.5, -270.8, 37.7),
            vector3(314.8, -215.9, 54.2),
        },
    },
    {
        spawn = vector4(-1212.6, -337.3, 37.8, 60.0),
        route = {
            vector3(-1096.6, -251.97, 37.8),
            vector3(-931.9, -179.5, 37.6),
            vector3(-802.9, -186.4, 36.7),
            vector3(-1212.6, -337.3, 37.8),
        },
    },
    {
        spawn = vector4(538.9, 2671.9, 42.1, 90.0),
        route = {
            vector3(486.98, 2609.9, 42.9),
            vector3(379.99, 2578.99, 42.9),
            vector3(298.99, 2429.99, 47.2),
            vector3(538.9, 2671.9, 42.1),
        },
    },
}

Config.PatrolSpeed = 12.0 -- m/s cruise speed while patrolling
Config.DriveStyle  = 786603

-- ============================================================
--  STOP DETECTION
--  How the script decides the truck has been "pulled over" and the
--  guards should bail out and start shooting.
-- ============================================================
Config.StopDetection = {
    speedThreshold = 1.0,   -- m/s, below this counts as "stopped"
    timeStopped    = 3000,  -- ms the truck must stay below the threshold before guards react
}

-- ============================================================
--  GUARDS
-- ============================================================
Config.Guards = {
    count    = 3,               -- includes the driver
    models   = { 's_m_y_prisguard_01', 's_m_m_security_01' },
    weapon   = `WEAPON_PUMPSHOTGUN`,
    health   = 250,
    armor    = 25,
    accuracy = 55,
}

-- ============================================================
--  C4 / BACK DOORS
-- ============================================================
Config.C4 = {
    item        = 'c4bank',                     -- qs-inventory item name consumed on use
    prop        = `hei_prop_carbomb_bomb01x`,    -- sticky-bomb prop model
    plantTime   = 5000,   -- ms to hold while planting the charge
    armTime     = 10000,  -- ms fuse before detonation
    doorIndices = nil,    -- e.g. {2, 3} to force specific door indices; nil = auto-detect the last 2 doors on the model
}

-- ============================================================
--  LOOT
-- ============================================================
Config.Loot = {
    lootTime       = 8000,  -- ms to loot once the doors are blown
    giveTruckKeys  = true,  -- give the looter the truck's keys via Config.KeysResource once looted
    moneyType   = 'cash', -- 'cash' or 'bank'
    moneyMin    = 15000,
    moneyMax    = 35000,

    -- Each entry rolls independently against `chance` (0-100).
    items = {
        { item = 'goldbar',       chance = 35, min = 1, max = 3 },
        { item = 'markedbills',   chance = 60, min = 1, max = 5 },
        { item = 'diamond',       chance = 15, min = 1, max = 2 },
        { item = 'weapon_pistol', chance = 8,  min = 1, max = 1 },
        { item = 'rolex',         chance = 20, min = 1, max = 1 },
    },
}

-- ============================================================
--  DISCORD WEBHOOK
-- ============================================================
Config.Webhook = {
    url          = '', -- paste your Discord webhook URL here
    botName      = 'Bank Truck Heist',
    botAvatar    = '',
    color        = 15158332, -- red
    logStart     = true,
    logCleared   = true,  -- guards eliminated
    logBreached  = true,  -- back doors blown
    logLoot      = true,  -- truck looted (final result)
}
