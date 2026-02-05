--[[
    =====================================================
    REDZONE LEAGUE - Configuration Principale
    =====================================================
    Ce fichier contient toutes les configurations du script.
    Modifiez les valeurs selon vos besoins.
]]

Config = {}

-- =====================================================
-- PARAMÈTRES GÉNÉRAUX
-- =====================================================

-- Mode debug : Affiche des messages de debug dans la console
-- true = activé, false = désactivé
Config.Debug = true

-- Nom du script affiché dans les notifications
Config.ScriptName = 'REDZONE LEAGUE'

-- =====================================================
-- CONFIGURATION DES NOTIFICATIONS (brutal_notify)
-- =====================================================

Config.Notify = {
    -- Durée par défaut des notifications (en ms)
    DefaultDuration = 5000,

    -- Activer le son des notifications
    Sound = true,

    -- Types de notifications disponibles: 'error', 'info', 'warning', 'success'
    Types = {
        Success = 'success',
        Error = 'error',
        Info = 'info',
        Warning = 'warning',
    }
}

-- =====================================================
-- CONFIGURATION DES PEDS
-- =====================================================

Config.Peds = {
    -- PED du menu principal (pour ouvrir le mode de jeu)
    MenuPed = {
        Model = 'a_m_m_business_01',      -- Modèle du PED
        Coords = vector4(-5806.1933, -915.5340, 502.4899, 113.3858),
        Scenario = 'WORLD_HUMAN_CLIPBOARD', -- Animation du PED
        Invincible = true,                  -- PED invincible
        Frozen = true,                      -- PED figé
        BlockEvents = true,                 -- Bloquer les événements
    },
}

-- =====================================================
-- CONFIGURATION DES PEDS COFFRE (STASH)
-- =====================================================

Config.StashPeds = {
    -- Configuration générale du stash
    Settings = {
        -- Nom du stash (préfixé avec l'identifier du joueur)
        StashName = 'redzone_personal_stash',
        -- Label affiché dans l'inventaire
        Label = 'Coffre',
        -- Nombre de slots (très grande capacité)
        MaxSlots = 500,
        -- Poids maximum (quasi illimité)
        MaxWeight = 100000000,
        -- Texte d'aide affiché près du PED
        HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour ouvrir votre coffre',
    },

    -- Liste des PEDs coffre (même coffre pour tous)
    Locations = {
        {
            id = 1,
            name = 'Coffre Zone Traintement',
            Model = 's_m_m_armoured_01',       -- Modèle du PED (garde armé)
            Coords = vector4(1156.259400, -1487.894532, 34.688598, 172.913392),
            Scenario = 'WORLD_HUMAN_GUARD_STAND', -- Animation de garde
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 2,
            name = 'Coffre Zone Casino',
            Model = 's_m_m_armoured_01',
            Coords = vector4(-304.694520, -885.810974, 31.065918, 238.110230),
            Scenario = 'WORLD_HUMAN_GUARD_STAND',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 3,
            name = 'Coffre Zone Pole emploi',
            Model = 's_m_m_armoured_01',
            Coords = vector4(890.993408, -37.371430, 78.750976, 144.566926),
            Scenario = 'WORLD_HUMAN_GUARD_STAND',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 4,
            name = 'Coffre Zone Aeroport',
            Model = 's_m_m_armoured_01',
            Coords = vector4(-1000.167054, -2524.483398, 13.828614, 240.944886),
            Scenario = 'WORLD_HUMAN_GUARD_STAND',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 5,
            name = 'Coffre Zone Ouest',
            Model = 's_m_m_armoured_01',
            Coords = vector4(-1562.901124, -296.307678, 48.252808, 317.480316),
            Scenario = 'WORLD_HUMAN_GUARD_STAND',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
    },
}

-- =====================================================
-- CONFIGURATION DES PEDS DE SORTIE (EXIT)
-- =====================================================

Config.ExitPeds = {
    -- Configuration générale
    Settings = {
        Model = 'a_m_m_business_01',
        Scenario = 'WORLD_HUMAN_CLIPBOARD',
        Invincible = true,
        Frozen = true,
        BlockEvents = true,
        HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour quitter le REDZONE',
    },
    -- Positions des PEDs de sortie (dans les zones redzone)
    Locations = {
        {
            id = 1,
            name = 'Sortie Zone Traitement',
            Coords = vector4(1156.048340, -1500.567016, 34.688598, 76.535438),
        },
        {
            id = 2,
            name = 'Sortie Zone Casino',
            Coords = vector4(887.261536, -49.819778, 78.750976, 42.519684),
        },
        {
            id = 3,
            name = 'Sortie Zone Pole Emploi',
            Coords = vector4(-294.646148, -896.545044, 31.065918, 348.661408),
        },
        {
            id = 4,
            name = 'Sortie Zone Aeroport',
            Coords = vector4(-997.714294, -2521.569336, 13.828614, 249.448822),
        },
        {
            id = 5,
            name = 'Sortie Zone Ouest',
            Coords = vector4(-1559.815430, -298.892304, 48.185302, 320.314972),
        },
    },
}

-- =====================================================
-- CONFIGURATION DES INTERACTIONS
-- =====================================================

Config.Interaction = {
    -- Touche pour interagir avec le PED (E par défaut)
    InteractKey = 38, -- E

    -- Distance d'interaction avec le PED
    InteractDistance = 2.5,

    -- Touche pour quitter/annuler (X par défaut)
    CancelKey = 73, -- X

    -- Texte d'aide affiché près du PED
    HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu REDZONE',
}

-- =====================================================
-- CONFIGURATION DU MODE DE JEU
-- =====================================================

Config.Gamemode = {
    -- Nom du mode de jeu
    Name = 'REDZONE LEAGUE',

    -- Description courte
    Description = 'Mode de jeu PvP en instance',

    -- Temps pour quitter le redzone (en secondes)
    QuitCountdown = 30,

    -- Commande pour quitter
    QuitCommand = 'quitredzone',

    -- Point de sortie (téléportation quand on quitte le redzone)
    ExitPoint = vector4(-5807.7890, -919.5560, 506.3991, 82.2047),
}

-- =====================================================
-- POINTS DE SPAWN POUR REJOINDRE LE REDZONE
-- =====================================================

Config.SpawnPoints = {
    -- Point de spawn 1
    {
        id = 1,
        name = 'Zone Traitement',
        coords = vector4(1157.9208, -1495.6087, 34.6717, 212.5984),
        blip = {
            enabled = true,
            sprite = 310,
            color = 1,
            scale = 0.8,
            name = 'Redzone - Zone traitement',
        },
    },
    -- Point de spawn 2
    {
        id = 2,
        name = 'Zone Casino',
        coords = vector4(885.2966, -40.4043, 78.7509, 283.4645),
        blip = {
            enabled = true,
            sprite = 310,
            color = 1,
            scale = 0.8,
            name = 'Redzone - Zone casino',
        },
    },
    -- Point de spawn 3
    {
        id = 3,
        name = 'Zone Pole Emploi',
        coords = vector4(-285.3098, -886.8791, 32.5655, 167.2440),
        blip = {
            enabled = true,
            sprite = 310,
            color = 1,
            scale = 0.8,
            name = 'Redzone - Zone pole emploi',
        },
    },
    -- Point de spawn 4
    {
        id = 4,
        name = 'Zone Aeroport',
        coords = vector4(-994.391236, -2528.162598, 13.828614, 277.795288),
        blip = {
            enabled = true,
            sprite = 310,
            color = 1,
            scale = 0.8,
            name = 'Redzone - Zone aeroport',
        },
    },
    -- Point de spawn 5
    {
        id = 5,
        name = 'Zone Ouest',
        coords = vector4(-1566.804444, -285.731872, 48.269654, 229.606292),
        blip = {
            enabled = true,
            sprite = 310,
            color = 1,
            scale = 0.8,
            name = 'Redzone - Zone ouest',
        },
    }
}

-- =====================================================
-- POINTS DE TÉLÉPORTATION EN INSTANCE
-- =====================================================

Config.InstanceSpawns = {
    -- Point de téléportation 1
    {
        id = 1,
        name = 'Spawn Alpha',
        coords = vector4(0.0, 0.0, 72.0, 0.0), -- À modifier selon votre map
    },
    -- Point de téléportation 2
    {
        id = 2,
        name = 'Spawn Beta',
        coords = vector4(10.0, 10.0, 72.0, 90.0), -- À modifier selon votre map
    },
    -- Point de téléportation 3
    {
        id = 3,
        name = 'Spawn Gamma',
        coords = vector4(-10.0, -10.0, 72.0, 180.0), -- À modifier selon votre map
    },
    -- Point de téléportation 4
    {
        id = 4,
        name = 'Spawn Delta',
        coords = vector4(20.0, -20.0, 72.0, 270.0), -- À modifier selon votre map
    },
    -- Point de téléportation 5
    {
        id = 5,
        name = 'Spawn Epsilon',
        coords = vector4(-20.0, 20.0, 72.0, 45.0), -- À modifier selon votre map
    },
}

-- =====================================================
-- RÈGLES DU JEU
-- =====================================================

Config.Rules = {
    Title = 'RÈGLEMENT OFFICIEL DU SERVEUR',
    Rules = {
        -- SECTION 1: COMPORTEMENT / DISCIPLINE
        '§1 COMPORTEMENT / DISCIPLINE',
        'Trash religion / racisme → BAN PERMANENT',
        'Harcèlement / sexisme → BAN PERMANENT',
        'Word → Ban de 15 jours du serveur',
        'Trash talk (entre joueurs) → NON AUTORISÉ (avertissement, kick, ban temporaire ou permanent)',
        'Menace de Dox / leak d\'infos personnelles → BAN PERMANENT',
        'Publicité d\'un autre serveur → BAN PERMANENT',
        'Publicité de cheat → BAN PERMANENT',
        'Tentative de RMT (vente d\'items contre argent réel) → BAN PERMANENT',
        'Cheat → BAN PERMANENT',
        'Aim assist / manette → BAN PERMANENT',
        'Macro / script → BAN PERMANENT',

        -- SECTION 2: ZONE ROUGE / GUNFIGHT
        '§2 ZONE ROUGE / GUNFIGHT',
        'Interdiction de tirer sur une personne hors zone rouge → Sanction',
        'Toute action ou tir effectué hors zone est interdit → Sanction',
        'Le loot est autorisé uniquement à l\'intérieur de la zone rouge',
        'Interdiction de sortir un cadavre de la zone pour le loot → Sanction',
        'Loot interdit après la fin de la zone rouge → Sanction',
        'Toutes les armes sont autorisées en zone rouge',
        'Interdiction de jouer en bordure de zone → Sanction',
        'Aucun PRESS autorisé en fin de zone rouge → Sanction',
        'Les toits non accessibles en véhicule sont interdits → Sanction',

        -- SECTION 3: RÈGLES DE LOOT
        '§3 RÈGLES DE LOOT',
        'Tout ce qui se trouve dans l\'inventaire du joueur est autorisé au loot',
        'Loot autorisé uniquement directement sur le cadavre au sol',
        'Le loot en portant le cadavre est interdit → Sanction',
        'Interdiction de loot en se mettant à travers un véhicule blindé → Sanction',

        -- SECTION 4: ZONES DE FARM
        '§4 ZONES DE FARM',
        'Dans la zone safe de redzone gagne 60$ toutes les minutes',

        -- SECTION 5: FIN DE ZONE
        '§5 FIN DE ZONE',
        'FIN DE ZONE = LOOT INTERDIT',
        'STOP TIR immédiat',
        'AUCUN PRESS → Tout non-respect entraînera une sanction',

        -- SECTION 6: RÈGLES DU PRESS
        '§6 RÈGLES DU PRESS',
        'Lors d\'un press, le joueur dispose de 30 secondes pour drop',
        'La fuite est autorisée pendant ces 30 secondes',
        'Au-delà, le drop est obligatoire',
        'Les attaquants doivent drop dans les 10 secondes suivant le début du press',
        'Une fois l\'équipe pressée drop, personne d\'externe ne peut rejoindre → Sanction',
        'Aucune réanimation autorisée tant que le press n\'est pas terminé',
        'Aucun press autorisé en fin de zones → Sanction',
        'Press possible sur n\'importe qui en véhicule, y compris joueurs à pied',
        'Interdiction de press les mêmes joueurs avant 5 minutes',
        'Aucun retour après mort sur un press → Sanction',

        -- SECTION 7: PACKS / MODS
        '§7 PACKS / MODS',
        '✓ Autorisés: Pack Legit, Blood FX, Kill Effect, Tracer non abusif',
        '✗ Interdits: No Bush/Low Bush, No Props, No Recoil, No Window',
        '✗ Interdits: Kill Effect affichant les personnes autour, Red lumineux',
        '✗ Interdits: No Roulade, Potato Mods, tout mod donnant un avantage',

        -- SECTION 8: SANCTIONS PACKS / MODS
        '§8 SANCTIONS PACKS / MODS',
        'Moins de 10h de jeu → 1h de ban + obligation de retirer le mod',
        'Plus de 10h de jeu → BAN PERMANENT (Unban via Ticket Boutique uniquement)',

        -- AVERTISSEMENT FINAL
        '⚠ Le non-respect du règlement entraîne automatiquement une sanction',
        '⚠ L\'ignorance des règles n\'excuse en aucun cas une infraction',
    },
}

-- =====================================================
-- CONFIGURATION NUI (Interface)
-- =====================================================

Config.NUI = {
    -- Dimensions de l'interface
    Width = 1800,
    Height = 1020,

    -- Afficher le curseur
    ShowCursor = true,

    -- Permettre de fermer avec Échap
    AllowEscape = true,
}

-- =====================================================
-- CONFIGURATION DE L'INVENTAIRE (qs-inventory)
-- =====================================================

Config.Inventory = {
    -- Nom du système d'inventaire utilisé
    System = 'qs-inventory',

    -- Retirer les armes en entrant dans le redzone
    RemoveWeaponsOnEnter = true,

    -- Restaurer les armes en quittant le redzone
    RestoreWeaponsOnExit = true,
}

-- =====================================================
-- MESSAGES DE DEBUG
-- =====================================================

Config.DebugMessages = {
    ScriptLoaded = '[REDZONE] Script chargé avec succès',
    PedSpawned = '[REDZONE] PED spawné à la position: ',
    PlayerEntered = '[REDZONE] Joueur entré dans le redzone: ',
    PlayerLeft = '[REDZONE] Joueur a quitté le redzone: ',
    MenuOpened = '[REDZONE] Menu ouvert par le joueur: ',
    MenuClosed = '[REDZONE] Menu fermé',
    TeleportStarted = '[REDZONE] Téléportation commencée',
    TeleportCancelled = '[REDZONE] Téléportation annulée',
    TeleportCompleted = '[REDZONE] Téléportation terminée',
}

-- =====================================================
-- CONFIGURATION DES PEDS VÉHICULE
-- =====================================================

Config.VehiclePeds = {
    Settings = {
        HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour choisir un véhicule',
        -- Anti Car-Kill: Les joueurs passent à travers les véhicules des autres
        AntiCarKill = true,
    },
    -- Groupes ayant accès aux véhicules VIP
    VipGroups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'},

    Vehicles = {
        -- Véhicules accessibles à tous
        { id = 1, name = 'Revolter', model = 'revolter' },
        { id = 2, name = 'Sultan', model = 'sultan' },
        { id = 3, name = 'BF400', model = 'bf400' },
        

        -- Véhicules VIP (groups = liste des groupes autorisés)
        { id = 4, name = 'Kuruma (Blindé)', model = 'kuruma2', groups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'} },
        { id = 5, name = 'dominator 4 (blibdé arrière)', model = 'dominator4', groups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'} },
        { id = 6, name = 'dominator 5 (blibdé arrière)', model = 'dominator5', groups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'} },
        { id = 7, name = 'dominator 6 (blibdé arrière)', model = 'dominator6', groups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'} },
    },
    Locations = {
        {
            id = 1,
            name = 'Véhicule Zone traitement',
            Model = 's_m_y_xmech_01',
            Coords = vector4(1159.094482, -1495.463746, 34.688598, 85.039368),
            SpawnPoint = vector4(1149.599976, -1479.626342, 35.688598, 0.0),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 2,
            name = 'Véhicule Zone casino',
            Model = 's_m_y_xmech_01',
            Coords = vector4(890.729676, -45.428570, 78.750976, 62.362206),
            SpawnPoint = vector4(872.571412, -57.665936, 78.262330, 155.905518),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 3,
            name = 'Véhicule Zone Pole emploi',
            Model = 's_m_y_xmech_01',
            Coords = vector4(-298.945068, -884.940674, 31.065918, 172.913392),
            SpawnPoint = vector4(-276.580230, -894.369202, 31.065918, 340.157470),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 4,
            name = 'Véhicule Zone Aeroport',
            Model = 's_m_y_xmech_01',
            Coords = vector4(-997.002198, -2535.204346, 13.828614, 334.488190),
            SpawnPoint = vector4(-986.175842, -2526.672608, 13.828614, 280.629914),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 5,
            name = 'Véhicule Zone Ouest',
            Model = 's_m_y_xmech_01',
            Coords = vector4(-1565.643920, -293.525268, 48.269654, 314.645660),
            SpawnPoint = vector4(-1553.564820, -298.008790, 48.151612, 226.771652),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
    },
}

-- =====================================================
-- CONFIGURATION DES PEDS SHOP ARMES
-- =====================================================

Config.ShopPeds = {
    Settings = {
        HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour ouvrir l\'armurerie',
        -- Réduction VIP en pourcentage
        VipDiscount = 15,
        -- Munitions données avec chaque arme
        DefaultAmmo = 250,
    },

    -- Groupes VIP ayant droit à la réduction
    VipGroups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'},

    -- Produits disponibles par catégorie (avec prix et images)
    -- type: 'weapon' = arme, 'item' = objet inventaire
    Products = {
        Items = {
            { name = 'Bandage', model = 'bandage', price = 500, image = 'bandage.png', type = 'item' },
            { name = 'Gilet Pare-Balles', model = 'armor', price = 5000, image = 'vest.png', type = 'item' },
        },
        Munitions = {
            -- price = prix par unité de munition, ammoAmount = quantité par défaut affichée
            { name = 'Munitions Pistolet', model = 'pistol_ammo', price = 5, image = 'pistol_ammo.png', type = 'ammo', ammoType = 'AMMO_PISTOL', ammoAmount = 50 },
            { name = 'Munitions SMG', model = 'smg_ammo', price = 7, image = 'smg_ammo.png', type = 'ammo', ammoType = 'AMMO_SMG', ammoAmount = 60 },
            { name = 'Munitions Fusil', model = 'rifle_ammo', price = 8, image = 'rifle_ammo.png', type = 'ammo', ammoType = 'AMMO_RIFLE', ammoAmount = 60 },
            { name = 'Munitions Shotgun', model = 'shotgun_ammo', price = 12, image = 'shotgun_ammo.png', type = 'ammo', ammoType = 'AMMO_SHOTGUN', ammoAmount = 24 },
            { name = 'Munitions MG', model = 'mg_ammo', price = 10, image = 'mg_ammo.png', type = 'ammo', ammoType = 'AMMO_MG', ammoAmount = 100 },
        },
        Pistols = {
            { name = 'Pistol', model = 'WEAPON_PISTOL', price = 5000, image = 'weapon_pistol.png', type = 'weapon' },
            { name = 'Pistol MK2', model = 'WEAPON_PISTOL_MK2', price = 7000, image = 'weapon_pistol_mk2.png', type = 'weapon' },
            { name = 'Pistol .50', model = 'WEAPON_PISTOL50', price = 8500, image = 'weapon_pistol50.png', type = 'weapon' },
            { name = 'Combat Pistol', model = 'WEAPON_COMBATPISTOL', price = 6500, image = 'weapon_combatpistol.png', type = 'weapon' },
            { name = 'Heavy Pistol', model = 'WEAPON_HEAVYPISTOL', price = 7500, image = 'weapon_heavypistol.png', type = 'weapon' },
            { name = 'Vintage Pistol', model = 'WEAPON_VINTAGEPISTOL', price = 6000, image = 'weapon_vintagepistol.png', type = 'weapon' },
            { name = 'AP Pistol', model = 'WEAPON_APPISTOL', price = 9000, image = 'weapon_appistol.png', type = 'weapon' },
            { name = 'Ceramic Pistol', model = 'WEAPON_CERAMICPISTOL', price = 8000, image = 'weapon_ceramicpistol.png', type = 'weapon' },
            { name = 'Revolver', model = 'WEAPON_REVOLVER', price = 7000, image = 'weapon_revolver.png', type = 'weapon' },
            { name = 'Revolver MK2', model = 'WEAPON_REVOLVER_MK2', price = 9500, image = 'weapon_revolver_mk2.png', type = 'weapon' },
            { name = 'Navy Revolver', model = 'WEAPON_NAVYREVOLVER', price = 8500, image = 'weapon_navyrevolver.png', type = 'weapon' },
            { name = 'Double Action', model = 'WEAPON_DOUBLEACTION', price = 6000, image = 'weapon_doubleaction.png', type = 'weapon' },
            { name = 'Marksman Pistol', model = 'WEAPON_MARKSMANPISTOL', price = 7500, image = 'weapon_marksmanpistol.png', type = 'weapon' },
        },
        SMGs = {
            { name = 'Micro SMG', model = 'WEAPON_MICROSMG', price = 12000, image = 'weapon_microsmg.png', type = 'weapon' },
            { name = 'SMG', model = 'WEAPON_SMG', price = 15000, image = 'weapon_smg.png', type = 'weapon' },
            { name = 'Assault SMG', model = 'WEAPON_ASSAULTSMG', price = 18000, image = 'weapon_assaultsmg.png', type = 'weapon' },
            { name = 'Combat PDW', model = 'WEAPON_COMBATPDW', price = 17000, image = 'weapon_combatpdw.png', type = 'weapon' },
            { name = 'Machine Pistol', model = 'WEAPON_MACHINEPISTOL', price = 11000, image = 'weapon_machinepistol.png', type = 'weapon' },
            { name = 'Gusenberg', model = 'WEAPON_GUSENBERG', price = 14000, image = 'weapon_gusenberg.png', type = 'weapon' },
        },
        Rifles = {
            { name = 'Carbine Rifle', model = 'WEAPON_CARBINERIFLE', price = 25000, image = 'weapon_carbinerifle.png', type = 'weapon' },
            { name = 'Carbine Rifle MK2', model = 'WEAPON_CARBINERIFLE_MK2', price = 32000, image = 'weapon_carbinerifle_mk2.png', type = 'weapon' },
            { name = 'Assault Rifle', model = 'WEAPON_ASSAULTRIFLE', price = 28000, image = 'weapon_assaultrifle.png', type = 'weapon' },
            { name = 'Assault Rifle MK2', model = 'WEAPON_ASSAULTRIFLE_MK2', price = 35000, image = 'weapon_assaultrifle_mk2.png', type = 'weapon' },
            { name = 'Advanced Rifle', model = 'WEAPON_ADVANCEDRIFLE', price = 32000, image = 'weapon_advancedrifle.png', type = 'weapon' },
            { name = 'Special Carbine', model = 'WEAPON_SPECIALCARBINE', price = 30000, image = 'weapon_specialcarbine.png', type = 'weapon' },
            { name = 'Special Carbine MK2', model = 'WEAPON_SPECIALCARBINE_MK2', price = 38000, image = 'weapon_specialcarbine_mk2.png', type = 'weapon' },
            { name = 'Bullpup Rifle', model = 'WEAPON_BULLPUPRIFLE', price = 27000, image = 'weapon_bullpuprifle.png', type = 'weapon' },
            { name = 'Bullpup Rifle MK2', model = 'WEAPON_BULLPUPRIFLE_MK2', price = 34000, image = 'weapon_bullpuprifle_mk2.png', type = 'weapon' },
            { name = 'Compact Rifle', model = 'WEAPON_COMPACTRIFLE', price = 22000, image = 'weapon_compactrifle.png', type = 'weapon' },
            { name = 'Military Rifle', model = 'WEAPON_MILITARYRIFLE', price = 35000, image = 'weapon_militaryrifle.png', type = 'weapon' },
        },
        Shotguns = {
            { name = 'Pump Shotgun', model = 'WEAPON_PUMPSHOTGUN', price = 15000, image = 'weapon_pumpshotgun.png', type = 'weapon' },
            { name = 'Pump Shotgun MK2', model = 'WEAPON_PUMPSHOTGUN_MK2', price = 20000, image = 'weapon_pumpshotgun_mk2.png', type = 'weapon' },
            { name = 'Sawed-Off', model = 'WEAPON_SAWNOFFSHOTGUN', price = 12000, image = 'weapon_sawnoffshotgun.png', type = 'weapon' },
            { name = 'Assault Shotgun', model = 'WEAPON_ASSAULTSHOTGUN', price = 22000, image = 'weapon_assaultshotgun.png', type = 'weapon' },
            { name = 'Bullpup Shotgun', model = 'WEAPON_BULLPUPSHOTGUN', price = 18000, image = 'weapon_bullpupshotgun.png', type = 'weapon' },
            { name = 'Heavy Shotgun', model = 'WEAPON_HEAVYSHOTGUN', price = 25000, image = 'weapon_heavyshotgun.png', type = 'weapon' },
            { name = 'Double Barrel', model = 'WEAPON_DBSHOTGUN', price = 16000, image = 'weapon_dbshotgun.png', type = 'weapon' },
            { name = 'Auto Shotgun', model = 'WEAPON_AUTOSHOTGUN', price = 20000, image = 'weapon_autoshotgun.png', type = 'weapon' },
            { name = 'Combat Shotgun', model = 'WEAPON_COMBATSHOTGUN', price = 24000, image = 'weapon_combatshotgun.png', type = 'weapon' },
        },
        MGs = {
            { name = 'MG', model = 'WEAPON_MG', price = 45000, image = 'weapon_mg.png', type = 'weapon' },
            { name = 'Combat MG', model = 'WEAPON_COMBATMG', price = 50000, image = 'weapon_combatmg.png', type = 'weapon' },
            { name = 'Combat MG MK2', model = 'WEAPON_COMBATMG_MK2', price = 60000, image = 'weapon_combatmg_mk2.png', type = 'weapon' },
        },
    },

    -- Emplacements des PEDs shop
    Locations = {
        {
            id = 1,
            name = 'Armurerie Zone traitement',
            Model = 's_m_y_ammucity_01',
            Coords = vector4(1154.782470, -1505.512084, 34.688598, 36.850396),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 2,
            name = 'Armurerie Zone Pole emploi',
            Model = 's_m_y_ammucity_01',
            Coords = vector4(-291.481324, -888.316468, 31.065918, 155.905518),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 3,
            name = 'Armurerie Zone Casino',
            Model = 's_m_y_ammucity_01',
            Coords = vector4(882.553834, -52.035164, 78.750976, 17.007874),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 4,
            name = 'Armurerie Zone Aeroport',
            Model = 's_m_y_ammucity_01',
            Coords = vector4(-999.784606, -2533.252686, 13.828614, 334.488190),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
        {
            id = 5,
            name = 'Armurerie Zone Ouest',
            Model = 's_m_y_ammucity_01',
            Coords = vector4(-1568.492310, -290.993408, 48.269654, 325.984252),
            Scenario = 'WORLD_HUMAN_CLIPBOARD',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },
    },
}

-- =====================================================
-- CONFIGURATION DU SYSTÈME DE MORT/RÉANIMATION
-- =====================================================

Config.Death = {
    -- Durée du timer avant de pouvoir respawn (en secondes)
    BleedoutTime = 30,

    -- Durée de l'animation de réanimation (en secondes)
    ReviveTime = 5,

    -- Distance d'interaction avec un joueur à terre
    InteractDistance = 2.5,

    -- Textes d'aide
    -- NOTE: Les touches sont configurables dans Paramètres FiveM > Raccourcis clavier > FiveM
    -- Par défaut: E pour réanimer, G pour porter/lâcher, I pour fouiller, Backspace pour respawn
    HelpTexts = {
        ReviveCarryLoot = '[E] Réanimer | [G] Porter | [I] Fouiller',
        DropCarry = '[G] Lâcher le joueur',
    },

    -- Messages
    Messages = {
        Died = 'Vous êtes à terre !',
        WaitingRevive = 'En attente de réanimation...',
        CanRespawn = 'Appuyez sur [Retour arrière] pour respawn ou attendez un allié',
        Respawning = 'Retour en zone safe...',
        Revived = 'Vous avez été réanimé !',
        RevivedPlayer = 'Joueur réanimé avec succès !',
    },
}

-- =====================================================
-- CONFIGURATION DES RÉCOMPENSES DE KILL
-- =====================================================

Config.KillReward = {
    -- Activer le système de récompense
    Enabled = true,

    -- Montant d'argent sale par kill
    Amount = 2000,

    -- Type d'argent: 'black_money' = argent sale, 'money' = argent normal
    MoneyType = 'black_money',

    -- Message de notification
    Message = '+$%s argent sale pour le kill!',
}

-- =====================================================
-- CONFIGURATION DU SYSTÈME DE LOOT
-- =====================================================

Config.Loot = {
    -- Durée de l'animation de loot (en secondes)
    LootTime = 7,

    -- Distance d'interaction pour looter
    InteractDistance = 2.5,

    -- Texte d'aide affiché près d'un joueur mort
    -- NOTE: La touche est configurable dans Paramètres FiveM > Raccourcis clavier > FiveM
    HelpText = '[I] Fouiller le joueur',

    -- Messages
    Messages = {
        LootStarted = 'Fouille en cours...',
        LootComplete = 'Fouille terminée !',
        LootCancelled = 'Fouille annulée',
        AlreadyBeingLooted = 'Ce joueur est déjà fouillé',
        CannotLoot = 'Vous ne pouvez pas fouiller ce joueur',
    },
}

-- =====================================================
-- CONFIGURATION DU BLANCHIMENT D'ARGENT
-- =====================================================

Config.MoneyLaundering = {
    -- Activer le système de blanchiment
    Enabled = true,

    -- Rayon du cercle d'interaction
    InteractRadius = 2.0,

    -- =====================================================
    -- SYSTÈME DE POSITIONS DYNAMIQUES
    -- =====================================================

    -- Intervalle de changement de position (en secondes)
    -- Pour tester: 60 (1 minute), pour production: 3600 (1 heure)
    ChangeInterval = 3600,

    -- Positions de blanchiment (rotation automatique)
    Positions = {
        {
            id = 1,
            name = 'Zone Centre',
            coords = vector4(707.195618, -965.709900, 30.408814, 215.433074),
        },
        {
            id = 2,
            name = 'Zone Sud',
            coords = vector4(474.250550, -1311.454956, 29.212402, 85.039368),
        },
        {
            id = 3,
            name = 'Zone Est',
            coords = vector4(726.975830, -1069.134034, 28.302612, 5.669292),
        },
    },

    -- Configuration du blip
    Blip = {
        Enabled = true,
        Sprite = 500,           -- Icône du blip (500 = dollar)
        Color = 2,              -- Couleur verte
        Scale = 0.8,
        Name = 'Blanchiment',
    },

    -- Montant à blanchir par transaction
    AmountPerTransaction = 10000,

    -- Item source (argent sale)
    DirtyMoneyItem = 'black_money',

    -- Configuration pour les joueurs normaux
    Normal = {
        Duration = 3,           -- Durée en secondes
        Fee = 20,               -- Pourcentage prélevé (20%)
    },

    -- Configuration VIP (staff, admin, etc.)
    VIP = {
        Duration = 1,           -- Durée en secondes
        Fee = 10,               -- Pourcentage prélevé (10%)
        Groups = {'vip', 'staff', 'organisateur', 'admin', 'responsable'},
    },

    -- Messages
    Messages = {
        NotEnoughDirtyMoney = 'Vous n\'avez pas assez d\'argent sale (minimum $25,000)',
        LaunderingInProgress = 'Blanchiment en cours...',
        LaunderingComplete = 'Blanchiment réussi ! +$%s sur votre compte',
        LaunderingCancelled = 'Blanchiment annulé',
        HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour blanchir $25,000',
        ZoneChanged = 'Le point de blanchiment a changé ! Nouvelle position: %s',
    },
}

-- =====================================================
-- CONFIGURATION DU SYSTÈME DE SQUAD
-- =====================================================

Config.Squad = {
    -- Activer le système de squad
    Enabled = true,

    -- Nombre maximum de membres dans un squad (incluant l'hôte)
    MaxMembers = 4,

    -- Messages
    Messages = {
        Created = 'Squad créé ! Invitez des joueurs avec leur ID.',
        Disbanded = 'Le squad a été dissous.',
        Joined = 'Vous avez rejoint le squad de %s',
        Left = 'Vous avez quitté le squad.',
        Kicked = 'Vous avez été expulsé du squad.',
        PlayerKicked = '%s a été expulsé du squad.',
        PlayerLeft = '%s a quitté le squad.',
        PlayerJoined = '%s a rejoint le squad.',
        InviteSent = 'Invitation envoyée à %s',
        InviteReceived = '%s vous invite à rejoindre son squad. Tapez /squad pour accepter.',
        AlreadyInSquad = 'Vous êtes déjà dans un squad.',
        SquadFull = 'Le squad est complet.',
        PlayerNotFound = 'Joueur introuvable.',
        PlayerNotInRedzone = 'Ce joueur n\'est pas dans le redzone.',
        NotInSquad = 'Vous n\'êtes pas dans un squad.',
        NotHost = 'Seul l\'hôte peut faire ça.',
        CannotInviteSelf = 'Vous ne pouvez pas vous inviter vous-même.',
    },
}

-- =====================================================
-- CONFIGURATION DE LA ZONE DE COMBAT DYNAMIQUE
-- =====================================================

Config.CombatZone = {
    -- Activer le système de zone de combat dynamique
    Enabled = true,

    -- Rayon de la zone en mètres
    Radius = 135.0,

    -- Intervalle de changement de position (en secondes)
    -- Pour tester: 60 (1 minute), pour production: 3600 (1 heure)
    ChangeInterval = 3600,

    -- Configuration du blip
    Blip = {
        Sprite = 543,           -- Icône du blip (543 = cible/combat)
        Color = 1,              -- Couleur rouge
        Scale = 1.0,
        Name = 'Zone de Combat',
    },

    -- Couleur du cercle sur la map (rouge semi-transparent)
    CircleColor = 1,            -- 1 = rouge
    CircleAlpha = 128,          -- Transparence (0-255)

    -- Positions de la zone (rotation automatique)
    Positions = {
        {
            id = 1,
            name = 'Zone Alpha',
            coords = vector4(210.118682, 54.804394, 83.772216, 51.023624),
        },
        {
            id = 2,
            name = 'Zone Beta',
            coords = vector4(155.050552, -1634.953858, 29.279908, 195.590546),
        },
    },

    -- Messages
    Messages = {
        ZoneChanged = 'La zone de combat a changé ! Nouvelle position: %s',
        ZoneActive = 'Zone de combat active: %s',
    },
}

-- =====================================================
-- CONFIGURATION DU FARM AFK EN ZONE SAFE
-- =====================================================

Config.SafeZoneFarm = {
    -- Activer le système de farm AFK
    Enabled = true,

    -- Montant d'argent sale gagné par intervalle (joueurs normaux)
    Amount = 60,

    -- Montant d'argent sale gagné par intervalle (joueurs VIP)
    VipAmount = 80,

    -- Groupes considérés comme VIP pour le farm
    VipGroups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'},

    -- Intervalle en secondes (60 = 1 minute)
    Interval = 60,

    -- Type d'argent: 'black_money' = argent sale, 'money' = argent normal
    MoneyType = 'black_money',

    -- Messages
    Messages = {
        Reward = '+$%s argent sale (farm zone safe)',
        RewardVip = '+$%s argent sale (farm zone safe - bonus VIP)',
        Started = 'Farm AFK activé - Restez en zone safe pour gagner de l\'argent',
    },
}

-- =====================================================
-- CONFIGURATION DU SYSTÈME DE PRESS
-- =====================================================

Config.Press = {
    -- Activer le système de press
    Enabled = true,

    -- Distance maximale pour presser un joueur (en mètres)
    MaxDistance = 15.0,

    -- Durée de la notification pour le joueur pressé (en secondes)
    NotificationDuration = 30,

    -- Durée de la boule rouge autour des joueurs (en secondes)
    SphereDisplayDuration = 10,

    -- Cooldown entre deux press (en secondes) pour éviter le spam
    Cooldown = 35,

    -- Couleur de la sphère (RGBA)
    SphereColor = {
        r = 255,
        g = 0,
        b = 0,
        a = 100,
    },

    -- Rayon de la sphère autour du joueur
    SphereRadius = 1.5,

    -- Messages
    Messages = {
        -- Message pour le joueur qui presse
        YouPressed = 'ATTENTION VOUS AVEZ PRESSE UN JOUEUR',
        YouPressedSub = '30 SECONDS AVANT LE DROP !',

        -- Message pour le joueur pressé
        BeingPressed = 'ATTENTION LE JOUEUR VOUS PRESSE',
        BeingPressedSub = 'VOUS AVEZ 30 SECONDS POUR DROP',

        -- Erreurs
        NoPlayerNearby = 'Aucun joueur à proximité',
        CannotPressSelf = 'Vous ne pouvez pas vous presser vous-même',
        CannotPressSquadMate = 'Vous ne pouvez pas presser un coéquipier',
        OnCooldown = 'Vous devez attendre avant de presser à nouveau',
        NotInRedzone = 'Vous devez être dans le redzone',
    },
}

-- =====================================================
-- CONFIGURATION DE LA ZONE CAL50 (Zone Combat Spéciale)
-- =====================================================

Config.Cal50Zone = {
    -- Activer le système de zone CAL50
    Enabled = true,

    -- Rayon de la zone en mètres
    Radius = 150.0,

    -- Intervalle de changement de position (en secondes)
    -- Pour tester: 60 (1 minute), pour production: 3600 (1 heure)
    ChangeInterval = 3600,

    -- Configuration du blip
    Blip = {
        Sprite = 543,           -- Icône du blip (543 = cible/combat)
        Color = 3,              -- Couleur bleue
        Scale = 1.0,
        Name = 'Zone CAL50',
    },

    -- Couleur du cercle sur la map (bleu semi-transparent)
    CircleColor = 3,            -- 3 = bleu
    CircleAlpha = 128,          -- Transparence (0-255)

    -- Positions de la zone (rotation automatique)
    Positions = {
        {
            id = 1,
            name = 'Zone CAL50 - Centre',
            coords = vector4(-350.887908, -682.918702, 32.801514, 320.314972),
        },
        {
            id = 2,
            name = 'Zone CAL50 - Port',
            coords = vector4(-1142.690064, -1497.323120, 4.392700, 104.881896),
        },
    },

    -- Messages
    Messages = {
        ZoneChanged = 'La zone CAL50 a changé ! Nouvelle position: %s',
        ZoneActive = 'Zone CAL50 active: %s (Armes autorisées: CAL50 uniquement)',
    },
}

-- =====================================================
-- CONFIGURATION DU SYSTÈME DE FARM WEED
-- =====================================================

Config.WeedFarm = {
    -- Activer le système de farm weed
    Enabled = true,

    -- =====================================================
    -- POINTS DE RÉCOLTE
    -- =====================================================
    Harvest = {
        -- Item donné lors de la récolte
        Item = 'weed',
        -- Quantité donnée par récolte
        Amount = 2,
        -- Temps de récolte en secondes (joueurs normaux)
        Duration = 3,
        -- Temps de récolte en secondes (VIP)
        VipDuration = 1,
        -- Distance d'interaction
        InteractDistance = 2.0,
        -- Temps de respawn du point après récolte (en secondes)
        RespawnTime = 30,

        -- Configuration du blip
        Blip = {
            Enabled = true,
            Sprite = 469,           -- Icône plante
            Color = 2,              -- Vert
            Scale = 0.8,
            Name = 'Récolte Weed',
        },

        -- Positions des points de récolte
        Positions = {
            vector4(-444.276916, 1602.237304, 358.036622, 235.275588),
            vector4(-445.384614, 1600.879150, 358.120850, 232.440948),
            vector4(-446.518676, 1599.639526, 358.306152, 232.440948),
            vector4(-447.705506, 1598.188964, 358.474610, 238.110230),
        },

        -- Messages
        Messages = {
            HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour récolter',
            Started = 'Récolte en cours...',
            Complete = '+%d weed récoltée(s)',
            Cooldown = 'Ce point a déjà été récolté, revenez plus tard',
        },
    },

    -- =====================================================
    -- POINT DE TRAITEMENT
    -- =====================================================
    Process = {
        -- Item requis
        InputItem = 'weed',
        InputAmount = 4,
        -- Item donné
        OutputItem = 'weed_brick',
        OutputAmount = 1,
        -- Temps de traitement en secondes (joueurs normaux)
        Duration = 3,
        -- Temps de traitement en secondes (VIP)
        VipDuration = 1,
        -- Distance d'interaction
        InteractDistance = 2.0,

        -- Configuration du blip
        Blip = {
            Enabled = true,
            Sprite = 478,           -- Icône usine/processing
            Color = 2,              -- Vert
            Scale = 0.8,
            Name = 'Traitement Weed',
        },

        -- Position du point de traitement
        Position = vector4(1193.261596, -1240.298950, 36.323120, 82.204728),

        -- Messages
        Messages = {
            HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour traiter (4 weed = 1 brick)',
            Started = 'Traitement en cours...',
            Complete = '+1 weed_brick créé',
            NotEnough = 'Vous n\'avez pas assez de weed (4 requis)',
        },
    },

    -- =====================================================
    -- POINT DE VENTE
    -- =====================================================
    Sell = {
        -- Item à vendre
        Item = 'weed_brick',
        -- Prix par unité (en black_money)
        PricePerUnit = 3000,
        -- Distance d'interaction
        InteractDistance = 2.5,

        -- Configuration du blip
        Blip = {
            Enabled = true,
            Sprite = 500,           -- Icône dollar
            Color = 2,              -- Vert
            Scale = 0.8,
            Name = 'Point de Vente Weed',
        },

        -- Configuration du PED vendeur
        Ped = {
            Model = 'a_m_y_hipster_01',
            Position = vector4(512.215394, -1950.923096, 24.983154, 303.307098),
            Scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            Invincible = true,
            Frozen = true,
            BlockEvents = true,
        },

        -- Messages
        Messages = {
            HelpText = 'Appuyez sur ~INPUT_CONTEXT~ pour vendre vos weed_brick',
            Complete = 'Vente réussie ! +$%d black_money',
            NoItem = 'Vous n\'avez pas de weed_brick à vendre',
        },
    },

    -- Groupes VIP (temps réduit)
    VipGroups = {'vip', 'staff', 'organisateur', 'responsable', 'admin'},
}

-- =====================================================
-- FIN DE LA CONFIGURATION
-- =====================================================
