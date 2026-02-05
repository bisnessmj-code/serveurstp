--[[
    REDZONE LEAGUE - Player Interact (ALT + Clic)
    Permet de copier l'ID ou la tenue d'un joueur cible
]]

Redzone = Redzone or {}
Redzone.Client = Redzone.Client or {}
Redzone.Client.PlayerInteract = {}

local isMenuOpen = false
local targetServerId = nil
local targetPed = nil
local isCursorActive = false

local function IsInRedzone()
    return Redzone.Client.Teleport and Redzone.Client.Teleport.IsInRedzone and Redzone.Client.Teleport.IsInRedzone() or false
end

local function GetServerIdFromPed(ped)
    for _, playerId in ipairs(GetActivePlayers()) do
        if GetPlayerPed(playerId) == ped then
            return GetPlayerServerId(playerId)
        end
    end
    return nil
end

local function GetPlayerNameFromPed(ped)
    for _, playerId in ipairs(GetActivePlayers()) do
        if GetPlayerPed(playerId) == ped then
            return GetPlayerName(playerId)
        end
    end
    return "Inconnu"
end

local function HideInteractMenu()
    if isMenuOpen then
        isMenuOpen = false
        SendNUIMessage({ action = 'hidePlayerInteract' })
    end
    if targetPed and DoesEntityExist(targetPed) then
        SetEntityDrawOutline(targetPed, false)
    end
    targetServerId = nil
    targetPed = nil
end

local function DisableCursor()
    if isCursorActive then
        isCursorActive = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

local function GetTargetPlayer()
    local camCoords = GetGameplayCamCoord()
    local bestScreenDist = 0.15
    local bestEntity = nil

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local ped = GetPlayerPed(playerId)
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local pedCoords = GetEntityCoords(ped)
                local dist = #(pedCoords - camCoords)
                if dist < 30.0 then
                    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(pedCoords.x, pedCoords.y, pedCoords.z + 0.5)
                    if onScreen then
                        local screenDist = math.sqrt((screenX - 0.5) * (screenX - 0.5) + (screenY - 0.5) * (screenY - 0.5))
                        if screenDist < bestScreenDist then
                            bestScreenDist = screenDist
                            bestEntity = ped
                        end
                    end
                end
            end
        end
    end

    return bestEntity
end

-- Thread principal : ALT gauche (control 19)
CreateThread(function()
    while true do
        local sleep = 500

        if IsInRedzone() then
            sleep = 0

            local altPressed = IsDisabledControlPressed(0, 19) or IsControlPressed(0, 19)

            if altPressed then
                -- Bloquer TOUS les controles de camera/mouvement/tir
                DisableControlAction(0, 1, true)    -- LookLeftRight
                DisableControlAction(0, 2, true)    -- LookUpDown
                DisableControlAction(0, 3, true)    -- LookUpOnly
                DisableControlAction(0, 4, true)    -- LookDownOnly
                DisableControlAction(0, 5, true)    -- LookLeftOnly
                DisableControlAction(0, 6, true)    -- LookLeftOnly
                DisableControlAction(0, 12, true)   -- WeaponWheelUpDown
                DisableControlAction(0, 13, true)   -- WeaponWheelLeftRight
                DisableControlAction(0, 24, true)   -- Attack
                DisableControlAction(0, 25, true)   -- Aim
                DisableControlAction(0, 37, true)   -- SelectWeapon
                DisableControlAction(0, 44, true)   -- Cover
                DisableControlAction(0, 106, true)  -- VehicleMouseControlOverride
                DisableControlAction(0, 142, true)  -- MeleeAttackAlternate
                DisableControlAction(0, 257, true)  -- Attack2
                DisableControlAction(0, 263, true)  -- MeleeAttack1
                DisableControlAction(0, 264, true)  -- MeleeAttack2

                -- Activer le curseur NUI
                if not isCursorActive then
                    isCursorActive = true
                    SetNuiFocusKeepInput(true)
                    SetNuiFocus(true, true)
                end

                -- Detecter un joueur
                local entity = GetTargetPlayer()

                if entity then
                    local serverId = GetServerIdFromPed(entity)
                    if serverId then
                        local playerName = GetPlayerNameFromPed(entity)

                        if targetPed and targetPed ~= entity and DoesEntityExist(targetPed) then
                            SetEntityDrawOutline(targetPed, false)
                        end

                        targetServerId = serverId
                        targetPed = entity
                        SetEntityDrawOutline(entity, true)

                        if not isMenuOpen then
                            isMenuOpen = true
                            SendNUIMessage({
                                action = 'showPlayerInteract',
                                name = playerName,
                                serverId = serverId
                            })
                        end
                    else
                        HideInteractMenu()
                    end
                else
                    HideInteractMenu()
                end
            else
                if isCursorActive then
                    HideInteractMenu()
                    DisableCursor()
                end
                sleep = 5
            end
        else
            if isCursorActive then
                HideInteractMenu()
                DisableCursor()
            end
        end

        Wait(sleep)
    end
end)

-- Callback NUI: Copier ID
RegisterNUICallback('playerInteract:copyId', function(data, cb)
    if Redzone.Client.Utils and Redzone.Client.Utils.Notify then
        Redzone.Client.Utils.Notify('REDZONE', 'ID ' .. tostring(data.serverId) .. ' copie dans le presse-papier', 'success', 3000, false)
    end
    HideInteractMenu()
    DisableCursor()
    cb('ok')
end)

-- Callback NUI: Copier Tenue
RegisterNUICallback('playerInteract:copyOutfit', function(data, cb)
    if targetPed and DoesEntityExist(targetPed) then
        local myPed = PlayerPedId()

        for i = 0, 11 do
            local drawable = GetPedDrawableVariation(targetPed, i)
            local texture = GetPedTextureVariation(targetPed, i)
            SetPedComponentVariation(myPed, i, drawable, texture, 0)
        end

        for i = 0, 2 do
            local propIndex = GetPedPropIndex(targetPed, i)
            local propTexture = GetPedPropTextureIndex(targetPed, i)
            if propIndex == -1 then
                ClearPedProp(myPed, i)
            else
                SetPedPropIndex(myPed, i, propIndex, propTexture, true)
            end
        end

        if Redzone.Client.Utils and Redzone.Client.Utils.Notify then
            Redzone.Client.Utils.Notify('REDZONE', 'Tenue copiee avec succes', 'success', 3000, false)
        end
    end
    HideInteractMenu()
    DisableCursor()
    cb('ok')
end)

-- Callback NUI: Fermer le menu
RegisterNUICallback('playerInteract:close', function(data, cb)
    HideInteractMenu()
    DisableCursor()
    cb('ok')
end)
