--[[
    =====================================================
    REDZONE LEAGUE - Système de Squad
    =====================================================
    Ce fichier gère le système d'équipe/squad.
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.Squad = {}

-- =====================================================
-- VARIABLES LOCALES
-- =====================================================

local isMenuOpen = false
local currentSquad = nil  -- {id, host, members, pendingInvites}
local pendingInvite = nil -- {squadId, hostName, hostId}
local squadMembers = {}   -- {[serverId] = {ped, name, health, armor}}
local squadRelationshipGroup = nil
local squadBlips = {} -- {[serverId] = blipHandle}
local lastBlipUpdate = nil
local isSquadThreadRunning = false

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Vérifie si le joueur est dans le redzone
---@return boolean
local function IsInRedzone()
    return Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone() or false
end

---Obtient le nom d'un joueur par son ID serveur
---@param serverId number
---@return string
local function GetPlayerNameById(serverId)
    local playerId = GetPlayerFromServerId(serverId)
    if playerId ~= -1 then
        return GetPlayerName(playerId) or ('Joueur ' .. serverId)
    end
    return 'Joueur ' .. serverId
end

-- =====================================================
-- SYSTÈME ANTI TEAM-KILL
-- =====================================================

---Initialise le groupe de relation pour le squad
local function InitSquadRelationship()
    if squadRelationshipGroup then return end

    -- Créer un groupe de relation unique pour notre squad
    local groupHash = GetHashKey('SQUAD_FRIENDLY_' .. GetPlayerServerId(PlayerId()))
    AddRelationshipGroup('SQUAD_FRIENDLY', groupHash)
    squadRelationshipGroup = groupHash

    Redzone.Shared.Debug('[SQUAD] Groupe de relation créé')
end

---Met à jour les relations entre membres du squad (pas de team kill)
---NOTE: On n'utilise plus NetworkSetFriendlyFireOption car c'est global
local function UpdateSquadRelations()
    -- Ne rien faire ici, le système anti-team kill est géré par le thread dédié
end

---Réactive le friendly fire (quand on quitte le squad)
local function ResetSquadRelations()
    Redzone.Shared.Debug('[SQUAD] Relations réinitialisées')
end

---Vérifie si un joueur est dans notre squad (fonction locale)
---@param serverId number
---@return boolean
local function IsPlayerInMySquad(serverId)
    if not currentSquad or not currentSquad.members then return false end

    for _, memberId in ipairs(currentSquad.members) do
        if memberId == serverId then
            return true
        end
    end
    return false
end

---Vérifie si un joueur est dans notre squad (fonction publique)
---@param serverId number
---@return boolean
function Redzone.Client.Squad.IsPlayerInMySquad(serverId)
    return IsPlayerInMySquad(serverId)
end

---Obtient le serverId d'un PED
---@param ped number
---@return number|nil
local function GetServerIdFromPed(ped)
    for _, playerId in ipairs(GetActivePlayers()) do
        if GetPlayerPed(playerId) == ped then
            return GetPlayerServerId(playerId)
        end
    end
    return nil
end

-- =====================================================
-- BLIPS SQUAD SUR LA CARTE
-- =====================================================

---Supprime tous les blips de squad
local function RemoveSquadBlips()
    for serverId, blip in pairs(squadBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    squadBlips = {}
end

---Met à jour les blips sur la carte pour les membres du squad
local function UpdateSquadBlips()
    if not currentSquad or not currentSquad.members then
        RemoveSquadBlips()
        return
    end

    local myServerId = GetPlayerServerId(PlayerId())
    local activeMembers = {}

    for _, memberId in ipairs(currentSquad.members) do
        if memberId ~= myServerId then
            activeMembers[memberId] = true
            local playerId = GetPlayerFromServerId(memberId)
            if playerId ~= -1 then
                local memberPed = GetPlayerPed(playerId)
                if memberPed and DoesEntityExist(memberPed) then
                    if not squadBlips[memberId] or not DoesBlipExist(squadBlips[memberId]) then
                        local blip = AddBlipForEntity(memberPed)
                        SetBlipSprite(blip, 1)
                        SetBlipColour(blip, 57)
                        SetBlipScale(blip, 0.7)
                        SetBlipAsShortRange(blip, false)
                        SetBlipCategory(blip, 7)
                        BeginTextCommandSetBlipName('STRING')
                        local memberName = GetPlayerNameById(memberId) or ('Joueur ' .. memberId)
                        AddTextComponentString(memberName)
                        EndTextCommandSetBlipName(blip)
                        squadBlips[memberId] = blip
                    end
                end
            end
        end
    end

    -- Supprimer les blips des membres qui ne sont plus dans le squad
    for serverId, blip in pairs(squadBlips) do
        if not activeMembers[serverId] then
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
            squadBlips[serverId] = nil
        end
    end
end

-- =====================================================
-- AFFICHAGE BARRE DE VIE/ARMURE DES COÉQUIPIERS
-- =====================================================

---Dessine une barre de progression 3D au-dessus d'une entité
---@param x number Position X monde
---@param y number Position Y monde
---@param z number Position Z monde
---@param value number Valeur actuelle (0-100)
---@param maxValue number Valeur max
---@param r number Rouge
---@param g number Vert
---@param b number Bleu
---@param offsetY number Décalage vertical
---@param width number Largeur de la barre
local function DrawBar3D(x, y, z, value, maxValue, r, g, b, offsetY, width, offsetX)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z + 1.0 + offsetY)

    if onScreen then
        local height = 0.005
        local barWidth = width or 0.03
        local percent = value / maxValue
        local baseX = screenX + (offsetX or 0)

        -- Fond de la barre (noir subtil)
        DrawRect(baseX, screenY, barWidth, height, 0, 0, 0, 120)

        -- Barre de remplissage
        local fillWidth = barWidth * percent
        local fillX = baseX - (barWidth / 2) + (fillWidth / 2)
        DrawRect(fillX, screenY, fillWidth, height, r, g, b, 220)
    end
end

---Dessine le nom et les barres de vie/armure au-dessus d'un joueur
---@param ped number Le PED du joueur
---@param name string Le nom du joueur
---@param isHost boolean Si c'est l'hôte du squad
local function DrawSquadMemberInfo(ped, name, isHost)
    if not DoesEntityExist(ped) then return end

    local coords = GetEntityCoords(ped)
    local myCoords = GetEntityCoords(PlayerPedId())
    local distance = #(coords - myCoords)

    -- Ne pas afficher si trop loin (max 50m)
    if distance > 50.0 then return end

    -- Récupérer vie et armure
    local health = GetEntityHealth(ped) - 100 -- 100-200 -> 0-100
    local maxHealth = GetEntityMaxHealth(ped) - 100
    local armor = GetPedArmour(ped)

    -- S'assurer que les valeurs sont dans les limites
    health = math.max(0, math.min(100, health))
    armor = math.max(0, math.min(100, armor))

    -- Calculer l'opacité basée sur la distance (plus proche = plus visible)
    local alpha = math.floor(255 * (1 - (distance / 50)))
    alpha = math.max(100, math.min(255, alpha))

    -- Afficher les barres (côte à côte)
    local barWidth = 0.025
    local gap = 0.001

    if armor > 0 then
        -- Vie à gauche, armure à droite
        local halfOffset = (barWidth + gap) / 2
        DrawBar3D(coords.x, coords.y, coords.z, health, 100, 76, 175, 80, 0.10, barWidth, -halfOffset)
        DrawBar3D(coords.x, coords.y, coords.z, armor, 100, 66, 165, 245, 0.10, barWidth, halfOffset)
    else
        -- Vie seule, centrée
        DrawBar3D(coords.x, coords.y, coords.z, health, 100, 76, 175, 80, 0.10, barWidth, 0)
    end

    -- Afficher le nom au-dessus des barres
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 1.25)
    if onScreen then
        local scale = 0.20

        SetTextFont(0)
        SetTextProportional(1)
        SetTextScale(scale, scale)
        SetTextColour(255, 255, 255, alpha)
        SetTextDropshadow(1, 0, 0, 0, 180)
        SetTextCentre(1)
        SetTextEntry('STRING')

        -- Ajouter un indicateur si c'est l'hôte
        local displayName = isHost and ('- ' .. name) or name
        AddTextComponentString(displayName)
        DrawText(screenX, screenY - 0.015)
    end
end

---Thread principal pour afficher les infos des coéquipiers
local function StartSquadDisplayThread()
    if isSquadThreadRunning then return end
    isSquadThreadRunning = true

    Redzone.Shared.Debug('[SQUAD] Démarrage du thread d\'affichage')

    CreateThread(function()
        while isSquadThreadRunning do
            local sleep = 500

            if currentSquad and currentSquad.members and #currentSquad.members > 1 then
                sleep = 0 -- Affichage chaque frame

                local myServerId = GetPlayerServerId(PlayerId())

                for _, memberId in ipairs(currentSquad.members) do
                    -- Ne pas afficher pour soi-même
                    if memberId ~= myServerId then
                        local playerId = GetPlayerFromServerId(memberId)
                        if playerId ~= -1 then
                            local memberPed = GetPlayerPed(playerId)
                            if memberPed and DoesEntityExist(memberPed) then
                                local memberName = GetPlayerNameById(memberId)
                                local isHost = (memberId == currentSquad.host)
                                DrawSquadMemberInfo(memberPed, memberName, isHost)
                            end
                        end
                    end
                end

                -- Mettre à jour les relations anti team-kill
                UpdateSquadRelations()
                -- Mettre à jour les blips sur la carte (toutes les ~2 secondes)
                if not lastBlipUpdate or (GetGameTimer() - lastBlipUpdate) > 2000 then
                    UpdateSquadBlips()
                    lastBlipUpdate = GetGameTimer()
                end
            else
                -- Pas de squad ou seul, réinitialiser
                if currentSquad == nil then
                    ResetSquadRelations()
                    RemoveSquadBlips()
                end
            end

            Wait(sleep)
        end
    end)
end

---Arrête le thread d'affichage
local function StopSquadDisplayThread()
    isSquadThreadRunning = false
    ResetSquadRelations()
    RemoveSquadBlips()
    Redzone.Shared.Debug('[SQUAD] Thread d\'affichage arrêté')
end

-- Variables pour le suivi de la santé (anti team-kill)
local lastHealth = 0
local lastArmor = 0

---Thread pour prévenir les dégâts entre membres du squad
local function StartAntiTeamKillThread()
    CreateThread(function()
        while true do
            local sleep = 100

            -- Vérifier si on est dans un squad avec d'autres membres
            local inSquadWithOthers = currentSquad and currentSquad.members and #currentSquad.members > 1

            if inSquadWithOthers then
                sleep = 0
                local myPed = PlayerPedId()
                local myServerId = GetPlayerServerId(PlayerId())
                local currentHealth = GetEntityHealth(myPed)
                local currentArmor = GetPedArmour(myPed)

                -- Sauvegarder la santé actuelle si c'est la première fois ou si on a été soigné
                if lastHealth == 0 or currentHealth > lastHealth then
                    lastHealth = currentHealth
                end
                if currentArmor > lastArmor then
                    lastArmor = currentArmor
                end

                -- Vérifier si on a perdu de la vie/armure
                local lostHealth = lastHealth - currentHealth
                local lostArmor = lastArmor - currentArmor

                if lostHealth > 0 or lostArmor > 0 then
                    -- Vérifier si c'est un coéquipier qui nous a touché
                    local damagedBySquadMember = false

                    for _, memberId in ipairs(currentSquad.members) do
                        if memberId ~= myServerId then
                            local playerId = GetPlayerFromServerId(memberId)
                            if playerId ~= -1 then
                                local memberPed = GetPlayerPed(playerId)
                                if memberPed and DoesEntityExist(memberPed) then
                                    if HasEntityBeenDamagedByEntity(myPed, memberPed, true) then
                                        damagedBySquadMember = true
                                        break
                                    end
                                end
                            end
                        end
                    end

                    if damagedBySquadMember then
                        -- Restaurer la santé/armure perdue
                        if lostHealth > 0 then
                            SetEntityHealth(myPed, lastHealth)
                        end
                        if lostArmor > 0 then
                            SetPedArmour(myPed, lastArmor)
                        end
                        ClearEntityLastDamageEntity(myPed)
                    else
                        -- Dégâts légitimes, mettre à jour les valeurs
                        lastHealth = currentHealth
                        lastArmor = currentArmor
                    end
                end

                -- Empêcher de viser/tirer sur les coéquipiers
                local _, targetEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
                if targetEntity and DoesEntityExist(targetEntity) and IsEntityAPed(targetEntity) then
                    local targetServerId = GetServerIdFromPed(targetEntity)
                    if targetServerId and IsPlayerInMySquad(targetServerId) and targetServerId ~= myServerId then
                        -- Désactiver le tir sur ce coéquipier
                        DisablePlayerFiring(PlayerId(), true)
                    end
                end
            else
                -- Pas de squad ou seul - réinitialiser le suivi de santé
                lastHealth = 0
                lastArmor = 0
            end

            Wait(sleep)
        end
    end)
end

-- =====================================================
-- GESTION DU MENU NUI
-- =====================================================

---Ouvre le menu squad
function Redzone.Client.Squad.OpenMenu()
    if not Config.Squad.Enabled then return end
    if not IsInRedzone() then
        Redzone.Client.Utils.NotifyError('Vous devez être dans le redzone.')
        return
    end

    isMenuOpen = true

    -- Demander les données au serveur
    TriggerServerEvent('redzone:squad:requestData')
end

---Ferme le menu squad
function Redzone.Client.Squad.CloseMenu()
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeSquad'
    })
end

---Callback: Données du squad reçues
RegisterNetEvent('redzone:squad:data')
AddEventHandler('redzone:squad:data', function(squadData, invite)
    currentSquad = squadData
    pendingInvite = invite

    -- Construire les données pour le NUI
    local nuiData = {
        action = 'openSquad',
        hasSquad = squadData ~= nil,
        hasPendingInvite = invite ~= nil,
        maxMembers = Config.Squad.MaxMembers,
    }

    if squadData then
        nuiData.squad = {
            id = squadData.id,
            isHost = squadData.host == GetPlayerServerId(PlayerId()),
            hostId = squadData.host,
            hostName = GetPlayerNameById(squadData.host),
            members = {},
        }

        -- Ajouter les membres avec leurs noms
        for _, memberId in ipairs(squadData.members) do
            table.insert(nuiData.squad.members, {
                id = memberId,
                name = GetPlayerNameById(memberId),
                isHost = memberId == squadData.host,
            })
        end
    end

    if invite then
        nuiData.invite = {
            squadId = invite.squadId,
            hostId = invite.hostId,
            hostName = invite.hostName,
        }
    end

    -- Envoyer au NUI
    SendNUIMessage(nuiData)
    SetNuiFocus(true, true)
end)

-- =====================================================
-- CALLBACKS NUI
-- =====================================================

---Callback: Fermer le menu
RegisterNUICallback('closeSquadMenu', function(data, cb)
    Redzone.Client.Squad.CloseMenu()
    cb('ok')
end)

---Callback: Créer un squad
RegisterNUICallback('createSquad', function(data, cb)
    TriggerServerEvent('redzone:squad:create')
    cb('ok')
end)

---Callback: Quitter le squad
RegisterNUICallback('leaveSquad', function(data, cb)
    TriggerServerEvent('redzone:squad:leave')
    cb('ok')
end)

---Callback: Dissoudre le squad (hôte seulement)
RegisterNUICallback('disbandSquad', function(data, cb)
    TriggerServerEvent('redzone:squad:disband')
    cb('ok')
end)

---Callback: Inviter un joueur
RegisterNUICallback('invitePlayer', function(data, cb)
    local targetId = tonumber(data.playerId)
    if targetId then
        TriggerServerEvent('redzone:squad:invite', targetId)
    end
    cb('ok')
end)

---Callback: Kick un joueur (hôte seulement)
RegisterNUICallback('kickPlayer', function(data, cb)
    local targetId = tonumber(data.playerId)
    if targetId then
        TriggerServerEvent('redzone:squad:kick', targetId)
    end
    cb('ok')
end)

---Callback: Accepter une invitation
RegisterNUICallback('acceptInvite', function(data, cb)
    if pendingInvite then
        TriggerServerEvent('redzone:squad:acceptInvite', pendingInvite.squadId)
    end
    cb('ok')
end)

---Callback: Refuser une invitation
RegisterNUICallback('declineInvite', function(data, cb)
    if pendingInvite then
        TriggerServerEvent('redzone:squad:declineInvite', pendingInvite.squadId)
        pendingInvite = nil
    end
    cb('ok')
end)

-- =====================================================
-- ÉVÉNEMENTS SERVEUR
-- =====================================================

---Événement: Squad créé
RegisterNetEvent('redzone:squad:created')
AddEventHandler('redzone:squad:created', function(squadData)
    currentSquad = squadData
    Redzone.Client.Utils.NotifySuccess(Config.Squad.Messages.Created)

    -- Démarrer le thread d'affichage
    InitSquadRelationship()
    StartSquadDisplayThread()

    -- Rafraîchir le menu si ouvert
    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Squad dissous
RegisterNetEvent('redzone:squad:disbanded')
AddEventHandler('redzone:squad:disbanded', function()
    currentSquad = nil
    Redzone.Client.Utils.NotifyWarning(Config.Squad.Messages.Disbanded)

    -- Arrêter le thread et réinitialiser
    StopSquadDisplayThread()

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Joueur a rejoint
RegisterNetEvent('redzone:squad:playerJoined')
AddEventHandler('redzone:squad:playerJoined', function(playerId, playerName)
    local message = string.format(Config.Squad.Messages.PlayerJoined, playerName)
    Redzone.Client.Utils.NotifyInfo(message)

    -- Réinitialiser le suivi de santé pour inclure le nouveau membre
    lastHealth = 0
    lastArmor = 0

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Joueur a quitté
RegisterNetEvent('redzone:squad:playerLeft')
AddEventHandler('redzone:squad:playerLeft', function(playerId, playerName)
    local message = string.format(Config.Squad.Messages.PlayerLeft, playerName)
    Redzone.Client.Utils.NotifyWarning(message)

    -- Réinitialiser le suivi de santé immédiatement
    lastHealth = 0
    lastArmor = 0

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Joueur a été kick
RegisterNetEvent('redzone:squad:playerKicked')
AddEventHandler('redzone:squad:playerKicked', function(playerId, playerName)
    local message = string.format(Config.Squad.Messages.PlayerKicked, playerName)
    Redzone.Client.Utils.NotifyWarning(message)

    -- Réinitialiser le suivi de santé immédiatement
    lastHealth = 0
    lastArmor = 0

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Vous avez rejoint un squad
RegisterNetEvent('redzone:squad:joined')
AddEventHandler('redzone:squad:joined', function(squadData, hostName)
    currentSquad = squadData
    pendingInvite = nil
    local message = string.format(Config.Squad.Messages.Joined, hostName)
    Redzone.Client.Utils.NotifySuccess(message)

    -- Démarrer le thread d'affichage
    InitSquadRelationship()
    StartSquadDisplayThread()

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Vous avez quitté le squad
RegisterNetEvent('redzone:squad:left')
AddEventHandler('redzone:squad:left', function()
    currentSquad = nil
    Redzone.Client.Utils.NotifyInfo(Config.Squad.Messages.Left)

    -- Arrêter le thread et réinitialiser
    StopSquadDisplayThread()

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Vous avez été kick
RegisterNetEvent('redzone:squad:kicked')
AddEventHandler('redzone:squad:kicked', function()
    currentSquad = nil
    Redzone.Client.Utils.NotifyError(Config.Squad.Messages.Kicked)

    -- Arrêter le thread et réinitialiser
    StopSquadDisplayThread()

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Invitation envoyée
RegisterNetEvent('redzone:squad:inviteSent')
AddEventHandler('redzone:squad:inviteSent', function(playerName)
    local message = string.format(Config.Squad.Messages.InviteSent, playerName)
    Redzone.Client.Utils.NotifySuccess(message)
end)

---Événement: Invitation reçue
RegisterNetEvent('redzone:squad:inviteReceived')
AddEventHandler('redzone:squad:inviteReceived', function(squadId, hostId, hostName)
    pendingInvite = {
        squadId = squadId,
        hostId = hostId,
        hostName = hostName,
    }

    local message = string.format(Config.Squad.Messages.InviteReceived, hostName)
    Redzone.Client.Utils.NotifyInfo(message)

    -- Si le menu est ouvert, rafraîchir
    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

---Événement: Erreur
RegisterNetEvent('redzone:squad:error')
AddEventHandler('redzone:squad:error', function(errorType)
    local message = Config.Squad.Messages[errorType] or 'Une erreur est survenue.'
    Redzone.Client.Utils.NotifyError(message)
end)

---Événement: Mise à jour du squad (membre déconnecté, etc.)
RegisterNetEvent('redzone:squad:updated')
AddEventHandler('redzone:squad:updated', function(squadData)
    currentSquad = squadData

    -- Réinitialiser le suivi de santé pour que les anciens membres puissent être attaqués
    lastHealth = 0
    lastArmor = 0

    -- S'assurer que le thread tourne
    if currentSquad and not isSquadThreadRunning then
        InitSquadRelationship()
        StartSquadDisplayThread()
    end

    if isMenuOpen then
        TriggerServerEvent('redzone:squad:requestData')
    end
end)

-- =====================================================
-- COMMANDE
-- =====================================================

RegisterCommand('squad', function()
    if isMenuOpen then
        Redzone.Client.Squad.CloseMenu()
    else
        Redzone.Client.Squad.OpenMenu()
    end
end, false)

-- Suggestion de commande
TriggerEvent('chat:addSuggestion', '/squad', 'Ouvre le menu de gestion d\'équipe')

-- =====================================================
-- ÉVÉNEMENTS D'ENTRÉE/SORTIE DU REDZONE
-- =====================================================

---Appelé quand le joueur quitte le redzone
function Redzone.Client.Squad.OnLeaveRedzone()
    -- Fermer le menu si ouvert
    if isMenuOpen then
        Redzone.Client.Squad.CloseMenu()
    end

    -- Arrêter le thread d'affichage
    StopSquadDisplayThread()

    -- Notifier le serveur qu'on quitte le redzone
    TriggerServerEvent('redzone:squad:playerLeftRedzone')

    currentSquad = nil
    pendingInvite = nil
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('IsPlayerInMySquad', IsPlayerInMySquad)
exports('GetCurrentSquad', function()
    return currentSquad
end)
exports('HasSquad', function()
    return currentSquad ~= nil
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if isMenuOpen then
        SetNuiFocus(false, false)
    end

    -- Arrêter le thread et réinitialiser les relations
    StopSquadDisplayThread()
end)

-- =====================================================
-- ANTI TEAM-KILL - PROTECTION CLIENT
-- =====================================================

-- Variables pour la protection
local savedHealth = 200
local savedArmor = 0
local isTemporarilyInvincible = false

-- Fonction de résurrection forcée
local function ForceResurrect()
    local myPed = PlayerPedId()
    local coords = GetEntityCoords(myPed)
    local heading = GetEntityHeading(myPed)

    -- D'abord, reset l'état de mort dans le module death.lua
    local resetSuccess = pcall(function()
        exports['redzone']:ForceResetDeathState()
    end)

    if resetSuccess then
        Redzone.Shared.Debug('[SQUAD] État de mort réinitialisé via export')
    end

    -- Restaurer la santé
    SetEntityHealth(myPed, savedHealth > 100 and savedHealth or 200)
    SetPedArmour(myPed, savedArmor)
    ClearPedTasksImmediately(myPed)

    -- Si mort, résurrection
    if IsEntityDead(myPed) or GetEntityHealth(myPed) <= 100 then
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
        Wait(0)
        myPed = PlayerPedId()
        SetEntityHealth(myPed, savedHealth > 100 and savedHealth or 200)
        SetPedArmour(myPed, savedArmor)
    end

    -- Réactiver les contrôles explicitement
    EnableAllControlActions(0)
    EnableControlAction(0, 199, true) -- Pause Menu
    EnableControlAction(0, 200, true) -- Pause Menu Alternate
    EnableControlAction(0, 71, true)  -- VehicleAccelerate
    EnableControlAction(0, 72, true)  -- VehicleBrake

    print('[SQUAD] Résurrection forcée - Santé: ' .. tostring(savedHealth))
end

-- Rend le joueur temporairement invincible (utilisé quand attaqué par un coéquipier)
local function SetTemporaryInvincibility(duration)
    if isTemporarilyInvincible then return end
    isTemporarilyInvincible = true

    local myPed = PlayerPedId()
    SetEntityInvincible(myPed, true)

    SetTimeout(duration or 500, function()
        -- Vérifier qu'on n'est pas mort/système de mort actif
        local ped = PlayerPedId()
        local deathSystemActive = exports['redzone']:IsPlayerDead()
        if not deathSystemActive then
            SetEntityInvincible(ped, false)
        end
        isTemporarilyInvincible = false
    end)
end

-- Sauvegarder la santé régulièrement
CreateThread(function()
    while true do
        Wait(50)
        if currentSquad and currentSquad.members and #currentSquad.members > 1 then
            local myPed = PlayerPedId()
            local health = GetEntityHealth(myPed)
            local armor = GetPedArmour(myPed)

            if health > 100 and not IsEntityDead(myPed) then
                savedHealth = health
                savedArmor = armor
            end
        end
    end
end)

-- Événement serveur pour restaurer la santé
RegisterNetEvent('redzone:squad:restoreHealth')
AddEventHandler('redzone:squad:restoreHealth', function()
    -- Reset l'état de mort d'abord
    pcall(function()
        exports['redzone']:ForceResetDeathState()
    end)

    ForceResurrect()
    -- Restaurer plusieurs fois pour être sûr (mais moins de fois)
    for i = 1, 3 do
        SetTimeout(i * 150, function()
            ForceResurrect()
            EnableAllControlActions(0)
        end)
    end
end)

-- Événement serveur pour résurrection forcée (quand mort entre coéquipiers détectée)
RegisterNetEvent('redzone:squad:forceResurrect')
AddEventHandler('redzone:squad:forceResurrect', function()
    print('[SQUAD] Résurrection forcée demandée par le serveur')

    -- Reset l'état de mort d'abord - CRITIQUE
    pcall(function()
        exports['redzone']:ForceResetDeathState()
    end)

    ForceResurrect()
    -- Restaurer plusieurs fois pour être sûr
    for i = 1, 5 do
        SetTimeout(i * 150, function()
            ForceResurrect()
            EnableAllControlActions(0)
            EnableControlAction(0, 199, true) -- Pause Menu
            EnableControlAction(0, 200, true) -- Pause Menu Alternate
        end)
    end
end)

-- Intercepter quand on se fait toucher par un coéquipier (fanca_antitank)
AddEventHandler('fanca_antitank:gotHit', function(attacker, attackerServerId, hitLocation, weaponHash, weaponName, dying, isHeadshot, withMeleeWeapon, damage, enduranceDamage)
    if attackerServerId and IsPlayerInMySquad(attackerServerId) then
        local myServerId = GetPlayerServerId(PlayerId())
        if attackerServerId ~= myServerId then
            print('[SQUAD] Hit par coéquipier: ' .. tostring(attackerServerId))
            -- Activer invincibilité temporaire ET restaurer
            SetTemporaryInvincibility(1000)

            -- Reset l'état de mort si dying
            if dying then
                pcall(function()
                    exports['redzone']:ForceResetDeathState()
                end)
            end

            ForceResurrect()
            if dying then
                for i = 1, 5 do
                    SetTimeout(i * 150, function()
                        ForceResurrect()
                        EnableAllControlActions(0)
                    end)
                end
            end
        end
    end
end)

-- Intercepter l'effet de kill
AddEventHandler('fanca_antitank:effect', function(isVictim, otherId, killerData)
    if isVictim and IsPlayerInMySquad(otherId) then
        local myServerId = GetPlayerServerId(PlayerId())
        if otherId ~= myServerId then
            print('[SQUAD] Kill par coéquipier: ' .. tostring(otherId))

            -- Reset l'état de mort IMMÉDIATEMENT
            pcall(function()
                exports['redzone']:ForceResetDeathState()
            end)

            SetTemporaryInvincibility(2000)
            for i = 1, 8 do
                SetTimeout(i * 150, function()
                    ForceResurrect()
                    EnableAllControlActions(0)
                end)
            end
        end
    end
end)

-- Intercepter l'événement killed
AddEventHandler('fanca_antitank:killed', function(targetId, targetPed, playerId, playerPed, killDistance, killerData)
    local myServerId = GetPlayerServerId(PlayerId())
    if targetId == myServerId and IsPlayerInMySquad(playerId) then
        print('[SQUAD] Killed par coéquipier: ' .. tostring(playerId))

        -- Reset l'état de mort IMMÉDIATEMENT
        pcall(function()
            exports['redzone']:ForceResetDeathState()
        end)

        SetTemporaryInvincibility(2000)
        for i = 1, 8 do
            SetTimeout(i * 150, function()
                ForceResurrect()
                EnableAllControlActions(0)
            end)
        end
    end
end)

-- =====================================================
-- ÉVÉNEMENT NATIF - CEventNetworkEntityDamage
-- =====================================================

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local victimDied = args[4] == 1

        local myPed = PlayerPedId()

        -- Vérifier si on est la victime
        if victim == myPed and attacker and attacker ~= 0 then
            -- Trouver l'ID serveur de l'attaquant
            local attackerServerId = GetServerIdFromPed(attacker)

            if attackerServerId and IsPlayerInMySquad(attackerServerId) then
                local myServerId = GetPlayerServerId(PlayerId())
                if attackerServerId ~= myServerId then
                    print('[SQUAD] Dégâts par coéquipier détectés (gameEvent)')

                    -- Activer invincibilité temporaire immédiatement
                    SetTemporaryInvincibility(1500)

                    -- Reset l'état de mort si on est mort
                    if victimDied then
                        pcall(function()
                            exports['redzone']:ForceResetDeathState()
                        end)
                        SetTemporaryInvincibility(3000)
                    end

                    -- Restaurer immédiatement
                    ForceResurrect()

                    if victimDied then
                        for i = 1, 8 do
                            SetTimeout(i * 150, function()
                                ForceResurrect()
                                EnableAllControlActions(0)
                                EnableControlAction(0, 199, true)
                                EnableControlAction(0, 200, true)
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- =====================================================
-- THREAD DE PROTECTION PROACTIVE (ANTI TEAM-KILL)
-- =====================================================

-- Thread qui surveille si un coéquipier nous vise et active l'invincibilité
CreateThread(function()
    while true do
        local sleep = 100

        if currentSquad and currentSquad.members and #currentSquad.members > 1 then
            sleep = 0
            local myPed = PlayerPedId()
            local myServerId = GetPlayerServerId(PlayerId())
            local myHealth = GetEntityHealth(myPed)

            -- Vérification de sécurité: si on est vivant mais que le module death pense qu'on est mort
            local isActuallyAlive = not IsEntityDead(myPed) and myHealth > 100
            if isActuallyAlive then
                -- S'assurer que les contrôles de base fonctionnent toujours
                EnableControlAction(0, 199, true) -- Pause Menu (Échap)
                EnableControlAction(0, 200, true) -- Pause Menu Alternate
                EnableControlAction(0, 71, true)  -- VehicleAccelerate
                EnableControlAction(0, 72, true)  -- VehicleBrake
            end

            -- Parcourir tous les joueurs actifs
            for _, playerId in ipairs(GetActivePlayers()) do
                local serverId = GetPlayerServerId(playerId)

                -- Si c'est un coéquipier (pas nous)
                if serverId ~= myServerId and IsPlayerInMySquad(serverId) then
                    local playerPed = GetPlayerPed(playerId)

                    if playerPed and DoesEntityExist(playerPed) then
                        -- Vérifier si ce coéquipier nous vise
                        local isAimingAtUs = false

                        if IsPlayerFreeAiming(playerId) then
                            local success, targetEntity = GetEntityPlayerIsFreeAimingAt(playerId)
                            if success and targetEntity == myPed then
                                isAimingAtUs = true
                            end
                        end

                        -- Vérifier aussi s'il tire
                        if IsPedShooting(playerPed) then
                            -- Activer l'invincibilité temporaire si un coéquipier tire
                            SetTemporaryInvincibility(500)
                        end

                        if isAimingAtUs then
                            -- Un coéquipier nous vise, activer l'invincibilité
                            SetTemporaryInvincibility(200)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

-- Démarrer le thread anti team-kill (tourne toujours en arrière-plan)
StartAntiTeamKillThread()

Redzone.Shared.Debug('[CLIENT/SQUAD] Module Squad chargé')
