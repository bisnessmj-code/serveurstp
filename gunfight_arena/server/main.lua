-- ================================================================================================
-- GUNFIGHT ARENA LITE - SERVER MAIN (CORRIGÉ - KILLFEED AVEC NOM FIVEM)
-- ================================================================================================

ESX = exports['es_extended']:getSharedObject()

-- ================================================================================================
-- UTILITAIRES
-- ================================================================================================

local function GetFiveMName(source)
    return GetPlayerName(source) or "Inconnu"
end

-- FormatKillFeedName retourne le nom FiveM et l'ID séparément
local function FormatKillFeedName(source)
    local fivemName = GetPlayerName(source) or "Inconnu"
    return fivemName, source
end

local function ValidatePlayer(source)
    if not Utils.IsValidSource(source) then return false, nil end
    if GetPlayerPing(source) == 0 then return false, nil end
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer ~= nil, xPlayer
end

-- ================================================================================================
-- ARME - Via serveur pour synchronisation réseau
-- ================================================================================================

local function GiveWeaponToPlayer(source)
    if GetPlayerPing(source) == 0 then return false end
    
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    
    local weaponHash = GetHashKey(Config.Weapon.hash)
    local ammo = Config.Weapon.ammo
    
    if Config.DebugServer then
        Utils.Log(("GiveWeapon: Joueur %d - %s"):format(source, Config.Weapon.hash), "debug")
    end
    
    -- Donner l'arme côté serveur (synchronisé sur le réseau)
    GiveWeaponToPed(ped, weaponHash, ammo, false, true)
    SetPedAmmo(ped, weaponHash, ammo)
    SetCurrentPedWeapon(ped, weaponHash, true)
    
    -- Envoyer au client pour forcer l'équipement visuel
    TriggerClientEvent('gfarena:equipWeapon', source, Config.Weapon.hash, ammo)
    
    return true
end

local function RemoveWeaponFromPlayer(source)
    if GetPlayerPing(source) == 0 then return end
    
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    
    local weaponHash = GetHashKey(Config.Weapon.hash)
    
    if Config.DebugServer then
        Utils.Log(("RemoveWeapon: Joueur %d"):format(source), "debug")
    end
    
    -- Retirer l'arme côté serveur
    RemoveWeaponFromPed(ped, weaponHash)
    
    -- Notifier le client
    TriggerClientEvent('gfarena:removeWeapon', source)
end

-- ================================================================================================
-- EVENTS CONNEXION
-- ================================================================================================

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local src = playerId or source
    if not xPlayer then xPlayer = ESX.GetPlayerFromId(src) end
    if not xPlayer then return end
    
    local name = xPlayer.getName() or GetFiveMName(src)
    Cache.CreatePlayer(src, name)
    
    if Config.DebugServer then
        Utils.Log(("Joueur connecté: %s (#%d)"):format(name, src), "info")
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if Cache.IsPlayerInArena(src) then
        ZonesManager.RemovePlayerFromZone(src)
    end
    Cache.RemovePlayer(src)
end)

-- ================================================================================================
-- ZONE UPDATE
-- ================================================================================================

RegisterNetEvent('gfarena:requestZoneUpdate')
AddEventHandler('gfarena:requestZoneUpdate', function()
    local src = source
    if Cache.IsThrottled(src, "zoneUpdate") then return end
    ZonesManager.BroadcastZoneUpdate()
end)

-- ================================================================================================
-- REJOINDRE UNE ZONE
-- ================================================================================================

RegisterNetEvent('gfarena:joinRequest')
AddEventHandler('gfarena:joinRequest', function(zoneId)
    local src = source
    
    if Config.DebugServer then
        Utils.Log(("joinRequest reçu de %d pour zone %s"):format(src, tostring(zoneId)), "debug")
    end
    
    if Cache.IsThrottled(src, "joinRequest") then
        TriggerClientEvent('esx:showNotification', src, Config.Messages.cooldown)
        return
    end
    
    local isValid, xPlayer = ValidatePlayer(src)
    if not isValid then return end
    
    if not Utils.IsValidZoneId(zoneId) then
        TriggerClientEvent('esx:showNotification', src, Config.Messages.invalidZone)
        return
    end
    
    if Cache.IsPlayerInArena(src) then
        TriggerClientEvent('esx:showNotification', src, Config.Messages.alreadyInArena)
        return
    end
    
    if ZonesManager.IsZoneFull(zoneId) then
        TriggerClientEvent('esx:showNotification', src, Config.Messages.arenaFull)
        return
    end
    
    if not Cache.HasPlayer(src) then
        local name = xPlayer.getName() or GetFiveMName(src)
        Cache.CreatePlayer(src, name)
    end
    
    local success = ZonesManager.AddPlayerToZone(src, zoneId)
    if not success then
        TriggerClientEvent('esx:showNotification', src, "Impossible de rejoindre")
        return
    end
    
    Wait(500)
    
    if GetPlayerPing(src) == 0 then
        ZonesManager.RemovePlayerFromZone(src)
        return
    end
    
    if Config.DebugServer then
        Utils.Log(("joinRequest: Envoi gfarena:join à %d"):format(src), "debug")
    end
    
    TriggerClientEvent('gfarena:join', src, zoneId, false)
    
    Wait(1000)
    
    if GetPlayerPing(src) == 0 then
        ZonesManager.RemovePlayerFromZone(src)
        return
    end
    
    GiveWeaponToPlayer(src)
    
    Wait(200)
    TriggerClientEvent('esx:showNotification', src, Config.Messages.enterArena)
    
    local zone = Utils.GetZoneById(zoneId)
    Utils.Log(("Joueur %d a rejoint zone %d (%s)"):format(src, zoneId, zone.name), "success")
end)

-- ================================================================================================
-- QUITTER L'ARÈNE
-- ================================================================================================

RegisterNetEvent('gfarena:leaveArena')
AddEventHandler('gfarena:leaveArena', function()
    local src = source
    
    if Config.DebugServer then
        Utils.Log(("leaveArena reçu de %d"):format(src), "debug")
    end
    
    if Cache.IsThrottled(src, "leaveRequest") then return end
    
    if not Cache.IsPlayerInArena(src) then
        if Config.DebugServer then
            Utils.Log("leaveArena: Pas en arène", "warning")
        end
        return
    end
    
    RemoveWeaponFromPlayer(src)
    ZonesManager.RemovePlayerFromZone(src)
    TriggerClientEvent('gfarena:exitZone', src)
    
    Wait(100)
    TriggerClientEvent('esx:showNotification', src, Config.Messages.exitArena)
    
    Utils.Log(("Joueur %d a quitté l'arène"):format(src), "info")
end)

-- ================================================================================================
-- SORTIE DE ZONE (détecté par client)
-- ================================================================================================

RegisterNetEvent('gfarena:outOfBounds')
AddEventHandler('gfarena:outOfBounds', function()
    local src = source
    
    if Config.DebugServer then
        Utils.Log(("outOfBounds: Joueur %d"):format(src), "debug")
    end
    
    if not Cache.IsPlayerInArena(src) then return end
    
    RemoveWeaponFromPlayer(src)
    ZonesManager.RemovePlayerFromZone(src)
    TriggerClientEvent('gfarena:exitZone', src)
    TriggerClientEvent('esx:showNotification', src, Config.Messages.exitArena)
    
    Utils.Log(("Joueur %d a quitté (hors zone)"):format(src), "info")
end)

-- ================================================================================================
-- MORT D'UN JOUEUR
-- ================================================================================================

RegisterNetEvent('gfarena:playerDied')
AddEventHandler('gfarena:playerDied', function(zoneId, killerId)
    local victimId = source
    
    if Config.DebugServer then
        Utils.Log(("playerDied: Victime=%d, Killer=%s"):format(victimId, tostring(killerId)), "debug")
    end
    
    if Cache.IsThrottled(victimId, "killEvent") then return end
    if not Cache.IsPlayerInArena(victimId) then return end
    
    local victim = Cache.GetPlayer(victimId)
    if not victim or victim.zoneId ~= zoneId then return end
    
    local killerValid = false
    local killerStreak = 0
    local xKiller = nil
    
    if killerId and killerId ~= victimId then
        xKiller = ESX.GetPlayerFromId(killerId)
        if xKiller and Cache.IsPlayerInArena(killerId) then
            local killer = Cache.GetPlayer(killerId)
            if killer and killer.zoneId == zoneId then
                killerValid = true
            end
        end
    end
    
    if killerValid then
        killerStreak = Cache.RecordKill(killerId, victimId)

        -- Enregistrer le kill dans la base de données
        Stats.RecordKill(killerId)
        Stats.RecordDeath(victimId)

        local reward = Config.Rewards.killReward
        xKiller.addAccountMoney(Config.Rewards.account, reward)
        TriggerClientEvent('esx:showNotification', killerId, Config.Messages.killRecorded:format(reward))
        
        if Config.Rewards.killStreakBonus.enabled then
            local bonus = Config.Rewards.killStreakBonus.bonuses[killerStreak]
            if bonus then
                xKiller.addAccountMoney(Config.Rewards.account, bonus)
                TriggerClientEvent('esx:showNotification', killerId, Config.Messages.streakBonus:format(killerStreak, bonus))
            end
        end
        
        TriggerClientEvent('gfarena:healPlayer', killerId)
        
        -- CORRECTION: Utilisation de FormatKillFeedName qui récupère maintenant le nom FiveM + ID
        local killerName, killerSid = FormatKillFeedName(killerId)
        local victimName, victimSid = FormatKillFeedName(victimId)

        if Config.DebugServer then
            Utils.Log(("Kill Feed: %s a tué %s (streak: %d)"):format(killerName, victimName, killerStreak), "info")
        end

        local zonePlayers = ZonesManager.GetZonePlayers(zoneId)
        for _, playerId in ipairs(zonePlayers) do
            TriggerClientEvent('gfarena:killFeed', playerId, killerName, victimName, false, killerStreak, killerSid, victimSid)
        end
    else
        victim.session.deaths = victim.session.deaths + 1
        victim.session.currentStreak = 0
    end
    
    CreateThread(function()
        Wait(Config.Gameplay.respawnDelay)
        
        if Cache.IsPlayerInArena(victimId) and GetPlayerPing(victimId) > 0 then
            if Config.DebugServer then
                Utils.Log(("Respawn joueur %d"):format(victimId), "debug")
            end
            
            TriggerClientEvent('gfarena:join', victimId, zoneId, true)
            
            Wait(1000)
            if GetPlayerPing(victimId) > 0 then
                GiveWeaponToPlayer(victimId)
            end
        end
    end)
end)

-- ================================================================================================
-- COMMANDE
-- ================================================================================================

RegisterCommand(Config.Commands.exit, function(source)
    if source == 0 then return end
    
    if Config.DebugServer then
        Utils.Log(("Commande /%s par %d"):format(Config.Commands.exit, source), "debug")
    end
    
    if Cache.IsPlayerInArena(source) then
        RemoveWeaponFromPlayer(source)
        ZonesManager.RemovePlayerFromZone(source)
        TriggerClientEvent('gfarena:exitZone', source)
        TriggerClientEvent('esx:showNotification', source, Config.Messages.exitArena)
        Utils.Log(("Joueur %d a quitté via commande"):format(source), "info")
    else
        TriggerClientEvent('esx:showNotification', source, Config.Messages.notInArena)
    end
end, false)

-- ================================================================================================
-- INIT
-- ================================================================================================

CreateThread(function()
    Wait(3000)
    
    print("^2╔═══════════════════════════════════════════════════════╗^0")
    print("^2║         GUNFIGHT ARENA LITE - SERVER                   ║^0")
    print("^2║         Mode de jeu pur sans base de données           ║^0")
    print("^2╚═══════════════════════════════════════════════════════╝^0")
    print("")
    print(("^3[GF-Arena]^0 Zones: %d"):format(Utils.TableCount(Config.ZonesIndex)))
    print(("^3[GF-Arena]^0 Arme: %s"):format(Config.Weapon.hash))
    print(("^3[GF-Arena]^0 Debug: %s"):format(Config.DebugServer and "ACTIVÉ" or "désactivé"))
    print(("^3[GF-Arena]^0 Commande: /%s"):format(Config.Commands.exit))
    print(("^3[GF-Arena]^0 KillFeed: Nom FiveM activé"):format())
    print("")
    print("^2[GF-Arena]^0 Serveur opérationnel")
    print("")
end)