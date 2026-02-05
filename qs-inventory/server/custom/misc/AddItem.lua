function AddItem(source, item, amount, slot, info, data, created, lastinventory, disableAutoShowBox)
    local originalamount <const> = tonumber(amount) or 1
    local originalslot <const> = slot
    local originalcreated <const> = created
    local originaldata <const> = data
    local originalinfo <const> = info

    if not source then return Error('Could not find [source] in AddItem.') end
    if not item then return Error('Could not find [item] in AddItem.') end

    if type(amount) == 'number' and amount < 1 then
        return Debug('You cannot give an item with an amount less than 1!')
    end

    local inventory = lastinventory or Inventories[source]
    local totalUsedSlots, totalWeight = GetTotalUsedSlots(source)
    local itemInfo = ItemList[item:lower()]
    local time = os.time()

    if not itemInfo then
        return false
    end

    if not created then
        itemInfo['created'] = time
    else
        itemInfo['created'] = created
    end

    if not itemInfo then
        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', source, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
        return false
    end

    amount = tonumber(amount) or 1
    slot = tonumber(slot) or GetFirstSlotByItem(inventory, item)
    info = info or {}
    itemInfo['created'] = created or time

    if type(info) ~= 'table' then
        info = {}
    end

    info.quality = info.quality or 100

    if data then
        info.showItemData = true
        itemInfo['unique'] = true
    end

    if itemInfo['type'] == 'weapon' then
        info.serie = info.serie or CreateSerialNumber()
        info.quality = info.quality or 100
    end

    if NotStoredItems(item, source, amount) then
        TriggerClientEvent(Config.InventoryPrefix .. ':client:forceCloseInventory', source)
        return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', source, Lang('INVENTORY_NOTIFICATION_CANT_TAKE_MORE') .. ' ' .. itemInfo['label'], 'inform')
    end

    local newWeight = (totalWeight + (itemInfo['weight'] * amount))

    if newWeight > Config.InventoryWeight.weight then
        return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', source, Lang('INVENTORY_NOTIFICATION_TOO_HEAVY') .. ' ' .. itemInfo['label'], 'error')
    end

    if (slot and inventory[slot]) and (inventory[slot].name:lower() == item:lower()) and (itemInfo['type'] == 'item' and not itemInfo['unique']) then
        inventory[slot].amount = inventory[slot].amount + amount
        TriggerEvent('esx:onAddInventoryItem', source, item, amount)
        TriggerClientEvent('esx:addInventoryItem', source, item, amount)

        TriggerEvent('qb-inventory:server:itemAdded', source, item, amount, inventory[slot].amount)
        TriggerClientEvent('qb-inventory:client:itemAdded', source, item, amount, inventory[slot].amount)

        if inventory[slot] and inventory[slot].name == 'money' and Config.Framework == 'esx' then
            local player = GetPlayerFromId(source)
            local money = GetItemTotalAmount(source, 'money')
            player.setAccountMoney('money', money, 'dropped')
        end
        if inventory[slot] and inventory[slot].name == 'black_money' and Config.Framework == 'esx' then
            local player = GetPlayerFromId(source)
            local money = GetItemTotalAmount(source, 'black_money')
            player.setAccountMoney('black_money', money, 'dropped')
        end
        if not ContainsItem(itemsToCheck, inventory[slot].name) then
            Debug("Add item update slot Item added to player's inventory:", source, 'Item:', inventory[slot].name, 'Amount:', inventory[slot].amount, 'disable', disableAutoShowBox)
            if not disableAutoShowBox then
                local itemData = ItemList[inventory[slot].name]
                itemData.count = amount
                TriggerClientEvent('qs-inventory:client:ItemBox', source, itemData, 'add')
            end
        end
        UpdateFrameworkInventory(source, inventory, true)
        UpdateInventoryState(source)
        return true
    elseif not itemInfo['unique'] and slot or slot and inventory[slot] == nil then
        inventory[slot] = ItemInfo({
            name = itemInfo['name'],
            amount = amount,
            slot = slot,
            info = info
        })
        TriggerEvent('esx:onAddInventoryItem', source, item, amount)
        TriggerClientEvent('esx:addInventoryItem', source, item, amount)

        TriggerEvent('qb-inventory:server:itemAdded', source, item, amount, amount)
        TriggerClientEvent('qb-inventory:client:itemAdded', source, item, amount, amount)

        if inventory[slot] and inventory[slot].name == 'money' and Config.Framework == 'esx' then
            local player = GetPlayerFromId(source)
            local money = GetItemTotalAmount(source, 'money')
            player.setAccountMoney('money', money, 'dropped')
        end
        if inventory[slot] and inventory[slot].name == 'black_money' and Config.Framework == 'esx' then
            local player = GetPlayerFromId(source)
            local money = GetItemTotalAmount(source, 'black_money')
            player.setAccountMoney('black_money', money, 'dropped')
        end
        if not ContainsItem(itemsToCheck, inventory[slot].name) then
            Debug("Add Item new slot ::: Item added to player's inventory:", source, 'Item:', inventory[slot].name, 'Amount:', inventory[slot].amount, 'disableauto', disableAutoShowBox)
            if not disableAutoShowBox then
                local itemData = ItemList[inventory[slot].name]
                itemData.count = amount
                TriggerClientEvent('qs-inventory:client:ItemBox', source, itemData, 'add')
            end
        end
        UpdateFrameworkInventory(source, inventory, true)
        UpdateInventoryState(source)
        return true
    elseif itemInfo['unique'] or (not slot or slot == nil) or itemInfo['type'] == 'weapon' then
        local added = false
        for _ = 1, amount do
            for i = 1, Config.InventoryWeight.slots, 1 do
                if inventory[i] == nil then
                    TriggerEvent('esx:onAddInventoryItem', source, item, 1)
                    TriggerClientEvent('esx:addInventoryItem', source, item, 1)

                    TriggerEvent('qb-inventory:server:itemAdded', source, item, amount, 1)
                    TriggerClientEvent('qb-inventory:client:itemAdded', source, item, amount, 1)
                    inventory[i] = ItemInfo({
                        name = itemInfo['name'],
                        amount = 1,
                        slot = i,
                        info = info
                    })
                    if inventory[slot] and inventory[slot].name == 'money' and Config.Framework == 'esx' then
                        local player = GetPlayerFromId(source)
                        local money = GetItemTotalAmount(source, 'money')
                        player.setAccountMoney('money', money, 'dropped')
                    end
                    if inventory[slot] and inventory[slot].name == 'black_money' and Config.Framework == 'esx' then
                        local player = GetPlayerFromId(source)
                        local money = GetItemTotalAmount(source, 'black_money')
                        player.setAccountMoney('black_money', money, 'dropped')
                    end

                    if not ContainsItem(itemsToCheck, inventory[i].name) then
                        Debug("add item create new slot ::: added to player's inventory:", source, 'Item:', inventory[i].name, 'Amount:', inventory[i].amount, 'disable', disableAutoShowBox)
                        if not disableAutoShowBox then
                            local itemData = ItemList[inventory[i].name]
                            itemData.count = 1
                            TriggerClientEvent('qs-inventory:client:ItemBox', source, itemData, 'add')
                        end
                    end

                    local nextAmmount <const> = originalamount - 1
                    if nextAmmount > 0 then
                        AddItem(source, item, nextAmmount, originalslot, originalinfo, originaldata, originalcreated, inventory)
                    end
                    UpdateFrameworkInventory(source, inventory, true)
                    UpdateInventoryState(source)
                    added = true
                    break
                end
            end
            if added then
                break
            end
        end
        return added
    end
    return false
end

exports('AddItem', AddItem)
