-- ================================================================================================
-- GUNFIGHT ARENA LITE - CONFIG
-- ================================================================================================

local Config = {}

-- DEBUG
Config.Debug = true
Config.DebugClient = true
Config.DebugServer = true

-- PERFORMANCE
Config.Performance = {
    throttle = {
        joinRequest = 2000,
        leaveRequest = 1000,
        killEvent = 100,
        zoneUpdate = 500,
    },
}

-- ZONES
Config.Zones = {
    {
        id = 1, enabled = true, name = "Zone 1", image = "images/zone1.webp",
        center = vector3(3727.674805, 778.193420, 1297.649902), radius = 65.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(3713.960449, 765.784607, 1299.649902), heading = 303.307098},
            {pos = vector3(3739.542969, 764.980225, 1299.64990), heading = 110.551186},
            {pos = vector3(3739.793457, 790.931885, 1299.64990), heading = 206.929122},
            {pos = vector3(3716.333984, 792.593384, 1299.599365), heading = 85.039368},
            {pos = vector3(3728.123047, 776.452759, 1299.616211), heading = 39.685040},
        },
        routingBucket = 100, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 2, enabled = true, name = "Zone 2", image = "images/zone2.webp",
        center = vector3(295.898896, 2857.450440, 42.444702), radius = 80.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(295.516480, 2879.050538, 43.619018), heading = 53.858268},
            {pos = vector3(307.463746, 2894.848388, 43.602172), heading = 14.173228},
            {pos = vector3(327.415374, 2879.301026, 43.450562), heading = 297.637786},
            {pos = vector3(335.248352, 2850.250488, 43.416870), heading = 189.921264},
        },
        routingBucket = 200, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 3, enabled = true, name = "Zone 3", image = "images/zone3.webp",
        center = vector3(78.131866, -390.408782, 38.333374), radius = 100.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(71.643960, -400.760438, 37.536254), heading = 90.0},
            {pos = vector3(54.989010, -445.134064, 37.536254), heading = 90.0},
            {pos = vector3(11.393406, -430.167022, 39.743530), heading = 90.0},
            {pos = vector3(48.923076, -367.107696, 39.912110), heading = 90.0},
        },
        routingBucket = 300, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 4, enabled = true, name = "Zone 4", image = "images/zone4.webp",
        center = vector3(-1693.279174, -2834.571534, 430.912110), radius = 100.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(-1685.050538, -2834.993408, 431.114258), heading = 0.0},
            {pos = vector3(-1673.709838, -2831.973632, 431.114258), heading = 0.0},
            {pos = vector3(-1700.294556, -2817.507812, 431.114258), heading = 0.0},
            {pos = vector3(-1698.013184, -2828.268066, 431.114258), heading = 0.0},
        },
        routingBucket = 400, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 5, enabled = true, name = "Zone 5", image = "images/zone5.webp",
        center = vector3(2746.180176, 1539.903320, 24.494506), radius = 100.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(2746.180176, 1539.903320, 24.494506), heading = 0.0},
            {pos = vector3(2767.463624, 1560.923096, 24.494506), heading = 0.0},
            {pos = vector3(2784.896728, 1555.582398, 24.494506), heading = 0.0},
        },
        routingBucket = 500, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 6, enabled = true, name = "Zone 6", image = "images/zone6.webp",
        center = vector3(2444.980224, 4980.514160, 35.803710), radius = 100.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(2447.657226, 4980.896484, 46.803710), heading = 303.307098},
            {pos = vector3(2418.804444, 4990.773438, 46.331910), heading = 110.551186},
            {pos = vector3(2486.795654, 4948.602050, 44.680542), heading = 206.929122},
        },
        routingBucket = 600, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 7, enabled = true, name = "Zone 7", image = "images/zone7.webp",
        center = vector3(60.092308, 3705.613282, 39.743530), radius = 100.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(76.984620, 3737.604492, 39.676148), heading = 45.0},
            {pos = vector3(97.503296, 3722.439454, 39.524536), heading = 90.0},
            {pos = vector3(61.780220, 3680.637452, 39.827880), heading = 135.0},
        },
        routingBucket = 700, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 8, enabled = true, name = "Zone 8", image = "images/zone8.webp",
        center = vector3(1723.991210, -1628.057128, 112.450562), radius = 95.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(1718.861572, -1684.378052, 112.551636), heading = 0.0},
            {pos = vector3(1741.951660, -1692.619750, 112.703248), heading = 45.0},
            {pos = vector3(1766.993408, -1573.002198, 112.619018), heading = 90.0},
        },
        routingBucket = 800, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 9, enabled = true, name = "Zone 9", image = "images/zone9.webp",
        center = vector3(1239.177978, -2969.406494, 9.296020), radius = 75.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(1239.177978, -2969.406494, 9.296020), heading = 0.0},
            {pos = vector3(1231.819824, -2985.797852, 9.312866), heading = 45.0},
            {pos = vector3(1250.109864, -2985.758300, 9.312866), heading = 90.0},
        },
        routingBucket = 900, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
    {
        id = 10, enabled = true, name = "Zone 10", image = "images/zone10.webp",
        center = vector3(-2368.457032, 3249.507812, 32.953125), radius = 75.0, maxPlayers = 15,
        spawnPoints = {
            {pos = vector3(-2368.457032, 3249.507812, 32.953125), heading = 0.0},
            {pos = vector3(-2328.725342, 3267.534180, 32.818360), heading = 45.0},
            {pos = vector3(-2360.808838, 3207.283448, 32.818360), heading = 90.0},
        },
        routingBucket = 1000, markerColor = {r = 255, g = 0, b = 0, a = 50}
    },
}

Config.ZonesIndex = {}
for _, zone in ipairs(Config.Zones) do
    if zone.enabled then
        Config.ZonesIndex[zone.id] = zone
    end
end

-- LOBBY
Config.Lobby = {
    ped = {
        enabled = true,
        model = "s_m_y_ammucity_01",
        position = vector3(-5823.402344, -926.123046, 501.489990),
        heading = 274.960632,
        frozen = true,
        invincible = true,
        blockEvents = true,
        scenario = "WORLD_HUMAN_GUARD_STAND"
    },
    interactDistance = 2.5,
    spawn = {
        position = vector3(-5809.622070, -918.791199, 506.31494),
        heading = 90.708656
    },
    blip = {
        enabled = true,
        sprite = 311,
        color = 1,
        scale = 0.8,
        name = "Gunfight Arena"
    }
}

-- ARMES
Config.Weapon = {
    hash = "WEAPON_PISTOL50",
    ammo = 1000
}

-- GAMEPLAY
Config.Gameplay = {
    spawnInvincibility = 1500,
    spawnAlpha = 128,
    spawnAlphaDuration = 1000,
    respawnDelay = 1500,
    infiniteStamina = true,
    showZoneMarker = true,
}

-- RÉCOMPENSES
Config.Rewards = {
    killReward = 2000,
    account = "bank",
    killStreakBonus = {
        enabled = true,
        bonuses = {
            [3] = 1000,
            [5] = 2500,
            [7] = 4000,
            [10] = 7500,
        }
    }
}

-- UI
Config.UI = {
    helpMessage = {
        enabled = true,
        text = "Appuyez sur ~r~[X]~s~ ou tapez ~r~/quittergf~s~ pour quitter",
        position = {x = 0.94, y = 0.15},
        scale = 0.35,
        font = 4,
        color = {r = 255, g = 255, b = 255, a = 215}
    },
}

-- COMMANDES
Config.Commands = {
    exit = "quittergf"
}

Config.Keys = {
    interact = 38,
    exit = 73
}

-- MESSAGES
Config.Messages = {
    enterArena = "Bienvenue dans l'arène !",
    exitArena = "Vous avez quitté l'arène.",
    killRecorded = "+$%d",
    streakBonus = "SÉRIE x%d ! +$%d",
    arenaFull = "Cette zone est pleine.",
    alreadyInArena = "Vous êtes déjà dans une arène.",
    notInArena = "Vous n'êtes pas dans une arène.",
    invalidZone = "Zone invalide.",
    cooldown = "Veuillez patienter.",
}

_G.Config = Config
return Config
