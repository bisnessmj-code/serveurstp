if Config.Framework ~= 'qb' then
    return
end

QBCore = exports['qb-core']:GetCoreObject()
if not Config.QBX then
    WeaponList = QBCore.Shared.Weapons
    ItemList = QBCore.Shared.Items
end

local playerLoaded = LocalPlayer.state['isLoggedIn']
function IsPlayerLoaded()
    return playerLoaded
end

function GetPlayerData()
    return QBCore.Functions.GetPlayerData()
end

function TriggerServerCallback(name, cb, ...)
    QBCore.Functions.TriggerCallback(name, cb, ...)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = GetPlayerData()
    LocalPlayer.state:set('inv_busy', false, true)
    Wait(1250)
    for k, data in pairs(Config.WeaponRepairPoints) do
        Config.WeaponRepairPoints[k].IsRepairing = data.IsRepairing
        Config.WeaponRepairPoints[k].RepairingData = data.RepairingData
    end
    if Config.Crafting then
        CreateBlips()
    end
    TriggerServerEvent(Config.InventoryPrefix .. ':server:OnLoadUpdateCash')
    Wait(5000)
    playerLoaded = true
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    LocalPlayer.state:set('inv_busy', true, true)
    RemoveAllNearbyDrops()
    for k in pairs(Config.WeaponRepairPoints) do
        Config.WeaponRepairPoints[k].IsRepairing = false
        Config.WeaponRepairPoints[k].RepairingData = {}
    end
    TriggerServerEvent('inventory:handleLogout')
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    if Config.Crafting then
        CreateBlips()
    end
end)

function GetPlayerIdentifier()
    return GetPlayerData().citizenid
end

function GetPlayersInArea()
    local playerPed = PlayerPedId()
    return QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(playerPed), 3.0)
end

function GetJobName()
    return GetPlayerData()?.job?.name
end

function GetJobGrade()
    return GetPlayerData().job.grade
end

function GetGang()
    return false
end

function GetGangLevel()
    return false
end

function SendTextMessage(msg, type)
    if type == 'inform' then
        lib.notify({
            title = 'Inventory',
            description = msg,
            type = 'inform'
        })
    end
    if type == 'error' then
        lib.notify({
            title = 'Inventory',
            description = msg,
            type = 'error'
        })
    end
    if type == 'success' then
        lib.notify({
            title = 'Inventory',
            description = msg,
            type = 'success'
        })
    end
end

function ShowHelpNotification(msg)
    AddTextEntry('helpNotification', msg)
    BeginTextCommandDisplayHelp('helpNotification')
    EndTextCommandDisplayHelp(0, true, true, -1)
end

local texts = {}
if GetResourceState('qs-textui') == 'started' then
    function DrawText3D(x, y, z, text, id, key)
        local _id = id
        if not texts[_id] then
            CreateThread(function()
                texts[_id] = 5
                while texts[_id] > 0 do
                    texts[_id] = texts[_id] - 1
                    Wait(0)
                end
                texts[_id] = nil
                exports['qs-textui']:DeleteDrawText3D(id)
                Debug('Deleted text', id)
            end)
            TriggerEvent('textui:DrawText3D', x, y, z, text, id, key)
        end
        texts[_id] = 5
    end
else
    function DrawText3D(x, y, z, text)
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        SetDrawOrigin(x, y, z, 0)
        DrawText(0.0, 0.0)
        local factor = text:len() / 370
        DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
        ClearDrawOrigin()
    end
end

function DrawText3Ds(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = string.len(text) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function ToggleHud(bool)
    if bool then
        Debug('Event to show the hud [client/custom/framework/esx.lua line 174]')
        DisplayRadar(true) -- You can enable or disable mini-map here
        if GetResourceState('qs-interface') == 'started' then
            exports['qs-interface']:ToggleHud(true)
        end
    else
        Debug('Event to hide the hud [client/custom/framework/esx.lua line 174]')
        DisplayRadar(false) -- You can enable or disable mini-map here
        if GetResourceState('qs-interface') == 'started' then
            exports['qs-interface']:ToggleHud(false)
        end
    end
end

function ProgressBar(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)
    if GetResourceState('qs-interface') == 'started' then
        local success = exports['qs-interface']:ProgressBar({
            duration = duration,
            label = label,
            position = 'bottom',
            useWhileDead = useWhileDead,
            canCancel = canCancel,
            disable = disableControls,
            anim = {
                dict = animation.animDict,
                clip = animation.anim,
                flag = animation?.flags
            },
            prop = prop
        })
        if success then
            onFinish()
        else
            onCancel()
        end
        return
    end
    if lib.progressCircle({
            duration = duration,
            label = label,
            position = 'bottom',
            useWhileDead = useWhileDead,
            canCancel = canCancel,
            disable = disableControls,
            anim = {
                dict = animation.animDict,
                clip = animation.anim,
                flag = animation?.flag
            },
            prop = prop
        }) then
        onFinish()
    else
        onCancel()
    end
end

function ProgressBarSync(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop)
    if GetResourceState('qs-interface') == 'started' then
        return exports['qs-interface']:ProgressBar({
            duration = duration,
            label = label,
            useWhileDead = useWhileDead,
            canCancel = canCancel,
            disable = disableControls,
            anim = animation,
            prop = prop
        })
    end
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = useWhileDead,
        canCancel = canCancel,
        disable = disableControls,
        anim = animation,
        prop = prop
    })
end

function DropMarker(coords)
    DrawMarker(20, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.15, 120, 10, 20, 155, false, false, false, 1, false, false, false)
end

function SetPlayerStatus(values)
    for name, value in pairs(values) do
        -- compatibility for ESX style values
        if value > 100 or value < -100 then
            value = value * 0.0001
        end

        if name == 'hunger' then
            TriggerServerEvent('inventory:consumables:addHunger', QBCore.Functions.GetPlayerData().metadata.hunger + value)
        elseif name == 'thirst' then
            TriggerServerEvent('inventory:consumables:addThirst', QBCore.Functions.GetPlayerData().metadata.thirst + value)
        elseif name == 'stress' then
            if value > 0 then
                TriggerServerEvent('hud:server:GainStress', value)
            else
                value = math.abs(value)
                TriggerServerEvent('hud:server:RelieveStress', value)
            end
        end
    end
end

function CanUseInventory()
    local check = false
    local data = GetPlayerData()
    if not data.metadata['isdead'] and not data.metadata['inlaststand'] and not data.metadata['ishandcuffed'] and not IsPauseMenuActive() then
        check = true
    end
    return check
end

function checkEntityDead(id, entity)
    local isDead = false
    TriggerServerCallback(Config.InventoryPrefix .. ':server:checkDead', function(result)
        isDead = result
    end, id)
    repeat Wait(250) until isDead ~= nil
    return isDead
end

function reputationCrafing(rep)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return 0 end

    local reputation = PlayerData.metadata[rep] or 0

    if reputation == nil then
        reputation = 0
    end

    return reputation
end

RegisterNetEvent('QBCore:Client:OnSharedUpdate', function(type, item, data)
    if type == 'Items' then
        ItemList[item] = data
    end
end)

RegisterNetEvent('QBCore:Client:OnSharedUpdateMultiple', function(type, data)
    if type == 'Items' then
        for k, v in pairs(data) do
            ItemList[k] = v
        end
    end
end)
