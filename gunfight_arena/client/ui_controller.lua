-- ================================================================================================
-- GUNFIGHT ARENA LITE - UI CONTROLLER CLIENT
-- ================================================================================================

local UIController = {}

local uiState = {
    mainUIVisible = false,
    pendingZoneSelection = false
}

local function ReleaseFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    uiState.mainUIVisible = false
    uiState.pendingZoneSelection = false
    
    if Config.DebugClient then
        print('^3[GF-UI]^0 Focus libéré')
    end
end

RegisterNUICallback('closeUI', function(_, cb)
    if Config.DebugClient then
        print('^3[GF-UI]^0 Callback: closeUI')
    end
    
    ReleaseFocus()
    TriggerEvent('gfarena:ui:closed')
    cb('ok')
end)

RegisterNUICallback('zoneSelected', function(data, cb)
    if Config.DebugClient then
        print('^3[GF-UI]^0 Callback: zoneSelected - zone=' .. tostring(data and data.zone))
    end
    
    if not data or not data.zone then
        cb('error')
        return
    end
    
    if uiState.pendingZoneSelection then
        cb('pending')
        return
    end
    
    uiState.pendingZoneSelection = true
    
    local zoneId = tonumber(data.zone)
    if not zoneId then
        uiState.pendingZoneSelection = false
        cb('invalid')
        return
    end
    
    -- CRITIQUE: Fermer l'UI et libérer le focus AVANT d'envoyer la requête
    ReleaseFocus()
    SendNUIMessage({ action = "close" })
    
    if Config.DebugClient then
        print('^2[GF-UI]^0 Envoi joinRequest pour zone ' .. zoneId)
    end
    
    TriggerServerEvent('gfarena:joinRequest', zoneId)
    
    SetTimeout(3000, function()
        uiState.pendingZoneSelection = false
    end)
    
    cb('ok')
end)

function UIController.ShowMainUI(zones)
    if uiState.mainUIVisible then return end
    
    if Config.DebugClient then
        print('^2[GF-UI]^0 ShowMainUI avec ' .. #zones .. ' zones')
    end
    
    uiState.mainUIVisible = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = "show",
        zones = zones or {}
    })
end

function UIController.CloseMainUI()
    ReleaseFocus()
    SendNUIMessage({ action = "close" })
end

function UIController.UpdateZonePlayers(zones)
    if uiState.mainUIVisible then
        SendNUIMessage({
            action = "updateZonePlayers",
            zones = zones or {}
        })
    end
end

function UIController.AddKillFeedMessage(message)
    if not message then return end
    SendNUIMessage({
        action = "killFeed",
        message = message
    })
end

function UIController.ClearKillFeed()
    SendNUIMessage({ action = "clearKillFeed" })
end

function UIController.ShowExitHud()
    SendNUIMessage({ action = "showExitHud" })
end

function UIController.HideExitHud()
    SendNUIMessage({ action = "hideExitHud" })
end

function UIController.IsMainUIVisible()
    return uiState.mainUIVisible
end

RegisterNetEvent('gfarena:ui:closed')
AddEventHandler('gfarena:ui:closed', function()
    ReleaseFocus()
end)

CreateThread(function()
    Wait(500)
    ReleaseFocus()
    if Config.DebugClient then
        print('^2[GF-UI]^0 Controller initialisé')
    end
end)

_G.UIController = UIController
return UIController
