local function IsWeaponBlocked(WeaponName)
    local retval = false
    for _, name in pairs(Config.DurabilityBlockedWeapons) do
        if name == WeaponName then
            retval = true
            break
        end
    end
    return retval
end

local function HasAttachment(component, attachments)
    local retval = false
    local key = nil
    for k, v in pairs(attachments) do
        if v.component == component then
            key = k
            retval = true
        end
    end
    return retval, key
end

local function GetAttachmentType(attachments)
    local attype = nil
    for _, v in pairs(attachments) do
        attype = v.type
    end
    return attype
end

function Split(s, delimiter)
    if type(s) ~= 'string' then
        Error('The other inventory name is broken! `s` is not a string. S is', s, 'Please fix it. it need to be a string.')
        return {}
    end
    result = {};
    if not s then return Wait(100) end
    for match in (s .. delimiter):gmatch('(.-)' .. delimiter) do
        table.insert(result, match);
    end
    return result;
end

RegisterNetEvent('weapons:reloadWeapon', function(ammoType)
    local src = source
    local player = GetPlayerFromId(src)
    local items = GetItems(player)
    if not ammoType then
        Error('Your weapons.lua is broken! AMMO_TYPE is not found. Please follow our docs and use our qb-core if it needs!')
        return
    end
    ammoType = type(ammoType) == 'table' and ammoType or { ammoType }
    local ammoItems = {}
    for k, v in pairs(ammoType) do
        local item = table.find(Config.AmmoItems, function(item) return item.type == v end)
        if item then
            ammoItems[#ammoItems + 1] = item.item
        end
    end
    local item
    for k, v in pairs(items) do
        if v.name == table.find(Config.AmmoItems, function(item) return item.isForEveryWeapon end).item then
            item = v
            break
        end
        if table.includes(ammoItems, v.name) then
            item = v
            break
        end
    end
    if not item then
        return
    end
    lib.callback.await('weapons:addAmmo', src, item)
end)

lib.callback.register('weapons:GetWeaponAmmoItem', function(source, ammoType, checkMaster)
    local player = GetPlayerFromId(source)
    local items = GetItems(player)
    if not ammoType then
        Error('Your weapons.lua is broken! AMMO_TYPE is not found. Please follow our docs and use our qb-core if it needs!')
        return
    end
    ammoType = type(ammoType) == 'table' and ammoType or { ammoType }
    local ammoItems = {}
    for k, v in pairs(ammoType) do
        local item = table.find(Config.AmmoItems, function(item) return item.type == v end)
        if item then
            ammoItems[#ammoItems + 1] = item.item
        end
    end
    Debug('ammoType', ammoType)
    for k, v in pairs(items) do
        if checkMaster and v.name == table.find(Config.AmmoItems, function(item) return item.isForEveryWeapon end).item then
            return v
        end
        if table.includes(ammoItems, v.name) then
            return v
        end
    end
    return false
end)

RegisterServerCallback('weapon:server:GetWeaponAmmo', function(source, cb, WeaponData)
    local retval = 0
    if WeaponData then
        local ItemData = GetItemBySlot(source, WeaponData.slot)
        if ItemData then
            retval = ItemData.info.ammo and ItemData.info.ammo or 0
        end
    end
    cb(retval, WeaponData.name)
end)

RegisterServerCallback('weapons:server:RemoveAttachment', function(source, cb, AttachmentData, ItemData)
    local src = source
    local Inventory = GetItems(GetPlayerFromId(src))
    Debug('Attachmentdata', AttachmentData)
    local AttachmentComponent = Config.WeaponAttachments[ItemData.name:upper()][AttachmentData.attachment]
    if Inventory[ItemData.slot] then
        if Inventory[ItemData.slot].info.attachments and next(Inventory[ItemData.slot].info.attachments) then
            Debug('AttachmentComponent:', AttachmentComponent)
            local HasAttach, key = HasAttachment(AttachmentComponent.component, Inventory[ItemData.slot].info.attachments)
            if HasAttach then
                if Inventory[ItemData.slot].info.tinturl and AttachmentComponent.item == 'weapontint_url' then
                    local info = {}
                    info.urltint = tostring(Inventory[ItemData.slot].info.tinturl)
                    AddItem(src, 'weapontint_url', 1, false, info)
                end
                if AttachmentComponent.item ~= 'weapontint_url' then
                    AddItem(src, AttachmentComponent.item, 1)
                end
                table.remove(Inventory[ItemData.slot].info.attachments, key)
                SetItemMetadata(src, ItemData.slot, Inventory[ItemData.slot].info)
                TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_ATTACHMENT_REMOVED') .. ' ' .. ItemList[AttachmentComponent.item].label, 'success')
                cb(Inventory[ItemData.slot].info.attachments)
                if Config.RemoveTintAfterRemoving then
                    if AttachmentData.tint or AttachmentData.tinturl then
                        Debug('An Tint was permanently removed')
                        RemoveItem(src, AttachmentData.item, 1)
                    end
                end
                Wait(200)
                TriggerClientEvent(Config.InventoryPrefix .. ':RefreshWeaponAttachments', src, Inventory[ItemData.slot], false, AttachmentComponent.component)
                TriggerClientEvent(Config.InventoryPrefix .. ':RefreshWeaponAttachments', src)
            else
                cb(false)
            end
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

RegisterServerCallback('weapons:server:RepairWeapon', function(source, cb, RepairPoint, data)
    local src = source
    local Player = GetPlayerFromId(src)
    local identifier = GetPlayerIdentifier(src)
    local minute = 60 * 1000
    local Timeout = math.random(5 * minute, 10 * minute)
    local WeaponData = WeaponList[GetHashKey(data.name)]
    local items = GetItems(Player)

    if items[data.slot] then
        if items[data.slot].info.quality then
            if items[data.slot].info.quality ~= 100 then
                local cash = GetAccountMoney(src, 'money')
                if cash >= Config.WeaponRepairCosts[WeaponData.weapontype] then
                    items[data.slot].info.quality = 100
                    SetItemMetadata(src, data.slot, items[data.slot].info)
                    TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, data.name)
                    TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_TEXT_REPAIR_REPAIRED'), 'error')
                    RemoveAccountMoney(src, 'money', Config.WeaponRepairCosts[WeaponData.weapontype])
                    cb(true)
                else
                    TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_MONEY'), 'error')
                    cb(false)
                end
            else
                TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_BROKEN'), 'error')
                cb(false)
            end
        else
            TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_BROKEN'), 'error')
            cb(false)
        end
    else
        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_WEAPON'), 'error')
        TriggerClientEvent('weapons:client:SetCurrentWeapon', src, {}, false)
        cb(false)
    end
end)

RegisterServerCallback('prison:server:checkThrowable', function(source, cb, weapon)
    local Player = GetPlayerFromId(source)

    if not Player then return cb(false) end
    local throwable = false
    for _, v in pairs(Config.Throwables) do
        if WeaponList[weapon].name == 'weapon_' .. v then
            RemoveItem(source, v, 1)
            throwable = true
            break
        end
    end
    cb(throwable)
end)

RegisterNetEvent('weapons:server:UpdateWeaponAmmo', function(CurrentWeaponData, amount)
    local src = source
    local Player = GetPlayerFromId(src)
    local items = GetItems(Player)
    amount = tonumber(amount)
    if CurrentWeaponData then
        if items[CurrentWeaponData.slot] then
            items[CurrentWeaponData.slot].info.ammo = amount
            local success = SetItemMetadata(src, CurrentWeaponData.slot, items[CurrentWeaponData.slot].info)
            Debug('weapons:server:UpdateWeaponAmmo', success)
        else
            Debug('CurrentWeaponData is nil')
        end
    else
        Debug('CurrentWeaponData is nil')
    end
end)

RegisterNetEvent('weapons:server:TakeBackWeapon', function(k)
    local src = source
    local itemdata = Config.WeaponRepairPoints[k].RepairingData.WeaponData
    itemdata.info.quality = 100
    AddItem(src, itemdata.name, 1, nil, itemdata.info)
    Config.WeaponRepairPoints[k].IsRepairing = false
    Config.WeaponRepairPoints[k].RepairingData = {}
    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[k], k)
end)

---@param data ServerProgressBar
function ProgressBarSync(src, data)
    return lib.callback.await('inventory:progressBarSync', src, data)
end

CreateUsableItem('weapon_repairkit', function(source, item)
    local src = source
    local Player = GetPlayerFromId(src)
    local items = GetItems(Player)
    local currentWeapon = lib.callback.await('weapons:client:GetCurrentWeapon', src)
    if not currentWeapon then
        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_REPAIR_HANDS'), 'error')
        return
    end
    if currentWeapon?.info?.quality == 100 then
        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_REPAIR_ERROR'), 'error')
        return
    end
    local success = ProgressBarSync(src, {
        label = Lang('INVENTORY_PROGRESS_REPAIR'),
        name = 'weapon_repairkit',
        duration = 1000,
        useWhileDead = false,
        canCancel = true,
        disableControls = { move = true, car = true, mouse = false, combat = true },
    })
    if success then
        RemoveItem(src, item.name, 1, item.slot)
        local item = items[currentWeapon.slot]
        if item.name == currentWeapon.name then
            local quality = item.info.quality
            item.info.quality = quality + Config.WeaponRepairItemAddition
            if item.info.quality > 100 then
                item.info.quality = 100
            end
            SetItemMetadata(src, currentWeapon.slot, item.info)
            TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_TEXT_REPAIR_REPAIRED'), 'success')
        else
            Error('Item name and current weapon name do not match. probably player change the slot after use the weapon.')
        end
        Debug('current weapon', currentWeapon)
    end
end)
RegisterNetEvent('weapons:server:SetWeaponQuality', function(data, hp)
    local src = source
    local Player = GetPlayerFromId(src)
    local items = GetItems(Player)
    local WeaponSlot = items[data.slot]
    WeaponSlot.info.quality = hp
    SetItemMetadata(src, data.slot, WeaponSlot.info)
end)

exports('GetCurrentWeapon', function(source)
    local currentWeapon = lib.callback.await('weapons:client:GetCurrentWeapon', source)
    return currentWeapon
end)

RegisterNetEvent('weapons:server:UpdateWeaponQuality', function(data, RepeatAmount, ammo)
    local src = source
    local Player = GetPlayerFromId(src)
    local items = GetItems(Player)
    local WeaponData = WeaponList[GetHashKey(data.name)]
    local WeaponSlot = items[data.slot]
    local DecreaseAmount = Config.DurabilityMultiplier[data.name] or 0.15
    if WeaponSlot then
        if not IsWeaponBlocked(WeaponData.name) then
            if WeaponSlot.info.quality then
                for _ = 1, RepeatAmount, 1 do
                    if data.name == 'weapon_petrolcan' then
                        local customQuality = ammo * 100
                        if customQuality >= 1 then
                            WeaponSlot.info.quality = customQuality / 4500
                        else
                            WeaponSlot.info.quality = 0
                            WeaponSlot.info.ammo = 0
                            TriggerClientEvent(Config.InventoryPrefix .. ':client:UseWeapon', src, data, false)
                            TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NEED_REPAIR'), 'inform')
                        end
                    end
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = WeaponSlot.info.quality - DecreaseAmount
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent(Config.InventoryPrefix .. ':client:UseWeapon', src, data, false)
                        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NEED_REPAIR'), 'inform')
                        break
                    end
                end
            else
                WeaponSlot.info.quality = 100
                for _ = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = WeaponSlot.info.quality - DecreaseAmount
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent(Config.InventoryPrefix .. ':client:UseWeapon', src, data, false)
                        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NEED_REPAIR'), 'inform')
                        break
                    end
                end
            end
        end
    end
    SetItemMetadata(src, data.slot, WeaponSlot.info)
end)

RegisterNetEvent('weapons:server:EquipAttachment', function(ItemData, CurrentWeaponData, AttachmentData, sendData)
    local src = source
    local Player = GetPlayerFromId(src)
    local Inventory = GetItems(Player)
    local GiveBackItem = nil
    local tint = 'none'
    if ItemData?.info?.urltint ~= nil then
        tint = tostring(ItemData.info.urltint)
    end
    local attachmentInfo = table.find(Config.WeaponAttachmentItems, function(attachment)
        return attachment.item == AttachmentData.item
    end)
    if not attachmentInfo then
        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_ATTACHMENT_NOT_COMPATIBLE'), 'error')
        return
    end
    AttachmentData.type = attachmentInfo.type
    Debug('weapons:server:EquipAttachment', AttachmentData)
    if Inventory[CurrentWeaponData.slot] then
        if Inventory[CurrentWeaponData.slot].info.attachments and next(Inventory[CurrentWeaponData.slot].info.attachments) then
            local currenttype = GetAttachmentType(Inventory[CurrentWeaponData.slot].info.attachments)
            local HasAttach, key = HasAttachment(AttachmentData.component, Inventory[CurrentWeaponData.slot].info.attachments)
            if not HasAttach then
                if AttachmentData.type ~= nil and currenttype == AttachmentData.type then
                    for _, v in pairs(Inventory[CurrentWeaponData.slot].info.attachments) do
                        if v.type and v.type == currenttype then
                            GiveBackItem = tostring(v.item):lower()
                            table.remove(Inventory[CurrentWeaponData.slot].info.attachments, key)
                        end
                    end
                end
                Inventory[CurrentWeaponData.slot].info.attachments[#Inventory[CurrentWeaponData.slot].info.attachments + 1] = {
                    component = AttachmentData.component,
                    label = ItemList[AttachmentData.item].label,
                    item = AttachmentData.item,
                    type = AttachmentData.type,
                    tint = AttachmentData.tint,
                    urltint = tint
                }
                Inventory[CurrentWeaponData.slot].info.tinturl = tint
                TriggerClientEvent('addAttachment', src, AttachmentData.component, tint)
                SetItemMetadata(src, CurrentWeaponData.slot, Inventory[CurrentWeaponData.slot].info)
                RemoveItem(src, ItemData.name, 1, ItemData.slot)
                Debug('Attachment used: [' .. ItemData.name .. '], slot: [' .. json.encode(ItemData.slot) .. ']')
            else
                TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_ATTACHMENT_ALREADY') .. ' ' .. ItemList[AttachmentData.item].label .. ' ' .. Lang('INVENTORY_NOTIFICATION_ATTACHMENT_ON_YOUR'), 'error')
            end
        else
            Inventory[CurrentWeaponData.slot].info.attachments = {}
            Inventory[CurrentWeaponData.slot].info.attachments[#Inventory[CurrentWeaponData.slot].info.attachments + 1] = {
                component = AttachmentData.component,
                label = ItemList[AttachmentData.item].label,
                item = AttachmentData.item,
                type = AttachmentData.type,
                tint = AttachmentData.tint,
                urltint = tint
            }
            Inventory[CurrentWeaponData.slot].info.tinturl = tint
            TriggerClientEvent('addAttachment', src, AttachmentData.component, tint)
            SetItemMetadata(src, CurrentWeaponData.slot, Inventory[CurrentWeaponData.slot].info)
            RemoveItem(src, ItemData.name, 1, ItemData.slot)
            Debug('Attachment used: [' .. ItemData.name .. '], slot: [' .. json.encode(ItemData.slot) .. ']')
        end
    end

    if GiveBackItem then
        AddItem(src, GiveBackItem, 1)
        Wait(100)
    end

    if sendData then
        TriggerClientEvent(Config.InventoryPrefix .. ':RefreshWeaponAttachments', src, Inventory[CurrentWeaponData.slot], AttachmentData.component)
        Wait(100)
        TriggerClientEvent(Config.InventoryPrefix .. ':RefreshWeaponAttachments', src)
    end
end)

RegisterNetEvent('weapons:server:removeWeaponAmmoItem', function(item)
    local Player = GetPlayerFromId(source)

    if not Player or type(item) ~= 'table' or not item.name or not item.slot then return end

    RemoveItem(source, item.name, 1, item.slot)
end)

RegisterServerEvent('weapons:server:AddWeaponAmmo')
AddEventHandler('weapons:server:AddWeaponAmmo', function(CurrentWeaponData, amount)
    local src = source
    local amount = tonumber(amount)
    local inventory = Inventories[src]

    if CurrentWeaponData ~= nil then
        if inventory[CurrentWeaponData.slot] ~= nil then
            inventory[CurrentWeaponData.slot].info.ammo = amount
        end
        SetInventory(src, inventory)
    end
end)
