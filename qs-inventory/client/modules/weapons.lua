local PlayerData = GetPlayerData()
local CanShoot, MultiplierAmount = true, 0
CurrentWeaponData = {}

exports('GetCurrentWeapon', function()
    return CurrentWeaponData
end)

lib.callback.register('weapons:client:GetCurrentWeapon', function()
    return CurrentWeaponData
end)

CreateThread(function()
    while not Config.WeaponsOnVehicle do
        Wait(250)
        local playerPed = PlayerPedId()

        if IsPedInAnyVehicle(playerPed, false) then
            local playerVeh = GetVehiclePedIsIn(playerPed, false)
            TriggerEvent('weapons:ResetHolster')
            SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
            RemoveAllPedWeapons(playerPed, true)
            currentWeapon = nil
        end
    end
end)

RegisterNetEvent('weapons:client:SyncRepairShops', function(NewData, key)
    Config.WeaponRepairPoints[key].IsRepairing = NewData.IsRepairing
    Config.WeaponRepairPoints[key].RepairingData = NewData.RepairingData
end)

FiringWeapon = false
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 7) == 1 and not inInventory then
            if IsControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 24) then
                FiringWeapon = true
            elseif IsControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 24) and not inInventory then
                FiringWeapon = false
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local weapon = GetSelectedPedWeapon(ped)
        if WeaponList[weapon] and WeaponList[weapon]['name'] == 'weapon_unarmed' and FiringWeapon then
            FiringWeapon = false
        end
        Wait(500)
    end
end)

---@return AttachmentItem?
local function componentIsTint(component)
    local tints = GetConfigTints()
    local attachment = table.find(tints, function(tint)
        return tint.attachment == component
    end)
    return attachment
end

RegisterNetEvent('addAttachment', function(component, urltint)
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    local WeaponData = WeaponList[weapon]
    local tintData = componentIsTint(component)
    if tintData then
        if tintData.isUrlTint then
            for i = 1, #Config.WeaponTints do
                if tostring(weapon) == Config.WeaponTints[i].hash then
                    local txd = CreateRuntimeTxd(Config.WeaponTints[i].name)
                    local duiObj = CreateDui(urltint, 250, 250)
                    local dui = GetDuiHandle(duiObj)
                    CreateRuntimeTextureFromDuiHandle(txd, 'skin', dui)
                    while not IsDuiAvailable(duiObj) do Wait(150) end
                    AddReplaceTexture(Config.WeaponTints[i].ytd, Config.WeaponTints[i].texture, Config.WeaponTints[i].name, 'skin')
                    break
                end
            end
        else
            SetPedWeaponTintIndex(ped, weapon, tintData.tint)
        end
        return
    end
    GiveWeaponComponentToPed(ped, GetHashKey(WeaponData.name), GetHashKey(component))
end)

RegisterNetEvent('weapons:client:SetCurrentWeapon', function(data, bool)
    if data ~= false then
        CurrentWeaponData = data
    else
        CurrentWeaponData = {}
    end
    CanShoot = bool
end)

RegisterNetEvent('weapons:client:SetWeaponQuality', function(amount)
    if CurrentWeaponData and next(CurrentWeaponData) then
        TriggerServerEvent('weapons:server:SetWeaponQuality', CurrentWeaponData, amount)
        TriggerEvent('weapons:client:SetCurrentWeapon', CurrentWeaponData, true)
    end
end)

RegisterNetEvent('weapons:client:masterAmmo', function(amount, itemData)
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    if CurrentWeaponData and WeaponList[weapon] and WeaponList[weapon]['name'] ~= 'weapon_unarmed' then
        local weaponAmmoType = WeaponList[weapon]['ammotype']
        if not weaponAmmoType then
            SendTextMessage(Lang('INVENTORY_NOTIFICATION_NO_AMMO'), 'error')
            return
        end
        TriggerEvent('weapons:client:AddAmmo', weaponAmmoType, amount, itemData, true)
    else
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_NO_WEAPON'), 'error')
    end
end)

lib.callback.register('weapons:addAmmo', function(itemData)
    local ped = cache.ped
    if IsPedReloading(ped) then
        return
    end
    local weapon = GetSelectedPedWeapon(ped)
    if not CurrentWeaponData or not WeaponList[weapon] or WeaponList[weapon]['name'] == 'weapon_unarmed' then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_NO_WEAPON'), 'error')
        return
    end
    local total = GetAmmoInPedWeapon(ped, weapon)
    local retval = GetMaxAmmoInClip(ped, weapon, 1)
    local _, ammoclip = GetAmmoInClip(ped, weapon)
    local _, maxammo = GetMaxAmmo(ped, weapon)
    if IsPedInAnyVehicle(ped, false) and Config.ForceToOnlyOneMagazine then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_VEHICLE_ITEMS'), 'error')
        return
    end
    if Config.ForceToOnlyOneMagazine and total > 0 then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_MAGAZINE_LIMIT'), 'error')
        return
    end
    if not retval then
        return
    end
    retval = tonumber(retval)

    if maxammo ~= total then
        TriggerServerCallback('weapon:server:GetWeaponAmmo', function(ammo)
            if ammo then
                SetAmmoInClip(ped, weapon, 0)
                AddAmmoToPed(ped, weapon, retval + ammoclip)
                TriggerServerEvent('weapons:server:AddWeaponAmmo', CurrentWeaponData, total + retval)
                --TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, total + retval)
                TriggerServerEvent('weapons:server:removeWeaponAmmoItem', itemData)
            end
        end, CurrentWeaponData)
    else
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_MAX_AMMO'), 'error')
    end
end)

RegisterNetEvent('weapons:client:AddAmmo', function(ammoType, amount, itemData, masterAmmo)
    local ped = PlayerPedId()
    if IsPedReloading(ped) then
        return -- SendTextMessage('Do not spam the reload', 'error')
    end
    local weapon = GetSelectedPedWeapon(ped)
    if not CurrentWeaponData or not WeaponList[weapon] or WeaponList[weapon]['name'] == 'weapon_unarmed' then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_NO_WEAPON'), 'error')
        return
    end
    local weaponAmmoType = type(WeaponList[weapon]['ammotype']) == 'table' and WeaponList[weapon]['ammotype'] or { WeaponList[weapon]['ammotype'] }
    if not table.includes(weaponAmmoType, ammoType:upper()) then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_NO_AMMO'), 'error')
        return
    end
    local total = GetAmmoInPedWeapon(ped, weapon)
    local retval = GetMaxAmmoInClip(ped, weapon, 1)
    local _, ammoclip = GetAmmoInClip(ped, weapon)
    local _, maxammo = GetMaxAmmo(ped, weapon)
    if IsPedInAnyVehicle(ped, false) and Config.ForceToOnlyOneMagazine then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_VEHICLE_ITEMS'), 'error')
        return
    end
    if Config.ForceToOnlyOneMagazine and total > 0 then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_MAGAZINE_LIMIT'), 'error')
        return
    end
    if retval then
        retval = tonumber(retval)
        itemData = lib.callback.await('weapons:GetWeaponAmmoItem', 0, ammoType, masterAmmo)

        if not itemData then
            print('Nice try forehead :)')
            return
        end

        if maxammo ~= total then
            TriggerServerCallback('weapon:server:GetWeaponAmmo', function(ammo)
                if ammo then
                    SetAmmoInClip(ped, weapon, 0)
                    AddAmmoToPed(ped, weapon, retval + ammoclip)
                    TriggerServerEvent('weapons:server:AddWeaponAmmo', CurrentWeaponData, total + retval)
                    --TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, total + retval)
                    TriggerServerEvent('weapons:server:removeWeaponAmmoItem', itemData)
                end
            end, CurrentWeaponData)
        else
            SendTextMessage(Lang('INVENTORY_NOTIFICATION_MAX_AMMO'), 'error')
        end
    end
end)

RegisterNetEvent('weapons:client:ConfigureTint')
AddEventHandler('weapons:client:ConfigureTint', function(ItemData)
    TintItemData = ItemData
    SetFocus(true)
    SendNUIMessage({
        action = 'showTintMenu'
    })
end)

function closeGui()
    SetFocus(false)
    SendNUIMessage({ action = 'hide' })
end

RegisterNUICallback('quit', function(data, cb)
    closeGui()
    TintItemData = {}
    cb('ok')
end)

RegisterNUICallback('addtinturl', function(data, cb)
    closeGui()
    SendTextMessage(Lang('INVENTORY_NOTIFICATION_CUSTOM_TINT_ADDED') .. ' ' .. data.urldatatint, 'success')
    local tinturl = tostring(data.urldatatint)
    TriggerServerEvent('weapons:server:AddUrlTint', TintItemData, tinturl)
    Wait(5)
    TintItemData = {}
    cb('ok')
end)

RegisterNetEvent('weapons:client:EquipAttachment', function(ItemData, attachment, WeaponData)
    if WeaponData then
        TriggerServerEvent('weapons:server:EquipAttachment', ItemData, WeaponData, Config.WeaponAttachments[WeaponData.name:upper()][attachment], true)
        return
    end
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    local WeaponData = WeaponList[weapon]
    if weapon == `WEAPON_UNARMED` then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_NO_WEAPON'), 'error')
        return
    end
    WeaponData.name = WeaponData.name:upper()
    if not Config.WeaponAttachments[WeaponData.name] then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_ATTACHMENT_NOT_COMPATIBLE'), 'error')
        return
    end
    if not Config.WeaponAttachments[WeaponData.name][attachment] then
        SendTextMessage(Lang('INVENTORY_NOTIFICATION_ATTACHMENT_NOT_COMPATIBLE'), 'error')
        return
    end
    if Config.WeaponAttachments[WeaponData.name][attachment]['item'] == ItemData.name then
        TriggerServerEvent('weapons:server:EquipAttachment', ItemData, CurrentWeaponData, Config.WeaponAttachments[WeaponData.name][attachment])
        return
    end
    SendTextMessage(Lang('INVENTORY_NOTIFICATION_ATTACHMENT_NOT_COMPATIBLE'), 'error')
end)

function SplitStr(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    while delim_from do
        result[#result + 1] = string.sub(str, from, delim_from - 1)
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    result[#result + 1] = string.sub(str, from)
    return result
end

CreateThread(function()
    SetWeaponsNoAutoswap(true)
end)

LastUpdatedAmmoTime = nil
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` and CurrentWeaponData?.info and (IsControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 24)) then
            local weapon = GetSelectedPedWeapon(ped)
            local ammo = GetAmmoInPedWeapon(ped, weapon)
            TriggerServerEvent('weapons:server:UpdateWeaponAmmo', CurrentWeaponData, tonumber(ammo))
            CurrentWeaponData.info.ammo = ammo
            LastUpdatedAmmoTime = GetGameTimer()
            if MultiplierAmount > 0 then
                TriggerServerEvent('weapons:server:UpdateWeaponQuality', CurrentWeaponData, MultiplierAmount, ammo)
                MultiplierAmount = 0
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if CurrentWeaponData and next(CurrentWeaponData) then
            if IsPedShooting(ped) or IsControlJustPressed(0, 24) then
                local weapon = GetSelectedPedWeapon(ped)
                if CanShoot then
                    if weapon and weapon ~= 0 and WeaponList[weapon] then
                        TriggerServerCallback('prison:server:checkThrowable', function(result)
                            if result or GetAmmoInPedWeapon(ped, weapon) <= 0 then return end
                            MultiplierAmount += 1
                        end, weapon)
                        Wait(200)
                    end
                else
                    if weapon ~= `WEAPON_UNARMED` then
                        TriggerEvent(Config.InventoryPrefix .. ':client:CheckWeapon', WeaponList[weapon]['name'])
                        SendTextMessage(Lang('INVENTORY_NOTIFICATION_WEAPON_BROKEN'), 'error')
                        MultiplierAmount = 0
                    end
                end
            end
        end
        Wait(0)
    end
end)

RegisterNetEvent(Config.InventoryPrefix .. ':client:LegacyFuel', function(fuel)
    Debug('Your gasoline can has: %', fuel)
    TriggerServerEvent('weapons:server:UpdateWeaponAmmo', CurrentWeaponData, fuel)
    TriggerServerEvent('weapons:server:UpdateWeaponQuality', CurrentWeaponData, 1, fuel)
end)

---@param data ServerProgressBar
lib.callback.register('inventory:progressBarSync', function(data)
    Debug('Progress bar sync: ', data)
    local success = ProgressBarSync(data.name, data.label, data.duration, data.useWhileDead, data.canCancel, data.disableControls, data.anim, data.prop)
    return success
end)

CreateThread(function()
    while true do
        local inRange = false
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for k, data in pairs(Config.WeaponRepairPoints) do
            local distance = #(pos - data.coords)
            if distance < 10 then
                inRange = true
                if distance < 1 then
                    if data.IsRepairing then
                        if data.RepairingData.CitizenId ~= GetPlayerIdentifier() then
                            DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_NOT_AVAILABLE'))
                        else
                            if not data.RepairingData.Ready then
                                DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_REPAIRED'))
                            else
                                DrawText3D(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_TAKE'), 'repair_take1', 'E')
                            end
                        end
                    else
                        if CurrentWeaponData and next(CurrentWeaponData) then
                            if not data.RepairingData.Ready then
                                local WeaponData = WeaponList[GetHashKey(CurrentWeaponData.name)]
                                DrawText3D(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_PRICE') .. Config.WeaponRepairCosts[WeaponData.weapontype], 'repair_weapon', 'E')
                                if IsControlJustPressed(0, 38) then
                                    TriggerServerCallback('weapons:server:RepairWeapon', function(HasMoney)
                                        if HasMoney then
                                            CurrentWeaponData = {}
                                        end
                                    end, k, CurrentWeaponData)
                                end
                            else
                                if data.RepairingData.CitizenId ~= GetPlayerIdentifier() then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_NOT_AVAILABLE'))
                                else
                                    DrawText3D(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_TAKE'), 'repair_take2', 'E')
                                    if IsControlJustPressed(0, 38) then
                                        TriggerServerEvent('weapons:server:TakeBackWeapon', k, data)
                                    end
                                end
                            end
                        else
                            if data.RepairingData.CitizenId == nil then
                                DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_NO_WEAPON'))
                            elseif data.RepairingData.CitizenId == GetPlayerIdentifier() then
                                DrawText3D(data.coords.x, data.coords.y, data.coords.z, Lang('INVENTORY_TEXT_REPAIR_TAKE'), 'repair_take3', 'E')
                                if IsControlJustPressed(0, 38) then
                                    TriggerServerEvent('weapons:server:TakeBackWeapon', k, data)
                                end
                            end
                        end
                    end
                end
            end
        end
        if not inRange then
            Wait(1250)
        end
        Wait(3)
    end
end)
