lib.callback.register('inventory:admin:getOnlinePlayers', function(source)
    if not PlayerIsAdmin(source) then
        return {}
    end

    local players = {}
    local esxPlayers = FrameworkGetPlayers()

    for _, playerId in ipairs(esxPlayers) do
        local identifier = GetPlayerIdentifier(playerId)
        if identifier then
            table.insert(players, {
                id = playerId,
                name = GetPlayerName(playerId),
                identifier = identifier,
                coords = GetEntityCoords(GetPlayerPed(playerId))
            })
        end
    end

    return players
end)

-- Admin give item function
lib.callback.register('inventory:admin:giveItem', function(source, targetId, itemName, amount, metadata)
    if not PlayerIsAdmin(source) then
        return false, Lang('INVENTORY_ADMIN_NO_PERMISSION')
    end
    targetId = tonumber(targetId)

    local targetPlayer = GetPlayerFromId(targetId)
    if not targetPlayer then
        return false, Lang('INVENTORY_ADMIN_TARGET_NOT_FOUND')
    end

    if not ItemList[itemName] then
        return false, Lang('INVENTORY_ADMIN_INVALID_ITEM')
    end

    local itemData = ItemList[itemName]
    local finalAmount = tonumber(amount) or 1

    -- Check if item is unique and amount is more than 1
    if itemData.unique and finalAmount > 1 then
        return false, Lang('INVENTORY_ADMIN_ITEM_UNIQUE')
    end

    -- Parse metadata if provided
    local parsedMetadata = {}
    if metadata and metadata ~= '' then
        local success, result = pcall(json.decode, metadata)
        if success and type(result) == 'table' then
            parsedMetadata = result
        end
    end

    -- Give the item
    local success = AddItem(targetId, itemName, finalAmount, false, parsedMetadata)

    if success then
        -- Log the action
        local adminName = GetPlayerName(source)
        local targetName = GetPlayerName(targetId)
        local itemLabel = itemData.label

        Debug(string.format('^3[ADMIN GIVEITEM]^7 %s (%d) gave %d x %s to %s (%d)',
            adminName, source, finalAmount, itemLabel, targetName, targetId))

        -- Send webhook if configured
        if Webhooks and Webhooks.admin then
            SendWebhook(Webhooks.admin, 'Admin Give Item', 7393279,
                string.format('**%s** (ID: %d) gave **%d x %s** to **%s** (ID: %d)',
                    adminName, source, finalAmount, itemLabel, targetName, targetId))
        end

        -- Notify both players with string.format and Lang
        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', source,
            string.format('%d x %s ' .. Lang('INVENTORY_ADMIN_NOTIFICATION_SUCCESSFULLY_GIVEN'), finalAmount, itemLabel), 'success')

        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', targetId,
            string.format(Lang('INVENTORY_ADMIN_NOTIFICATION_GIVEN_TO') .. ' %d x %s ', finalAmount, itemLabel), 'inform')

        -- Update target player's inventory
        TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', targetId, true)

        return true, string.format('%d x %s ' .. Lang('INVENTORY_ADMIN_NOTIFICATION_RECEIVED'), finalAmount, itemLabel)
    else
        return false, Lang('INVENTORY_ADMIN_ITEM_NOT_GIVEN')
    end
end)


RegisterCommand('admin_giveitem', function(source, args, rawCommand)
    if not PlayerIsAdmin(source) then
        TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', source, Lang('INVENTORY_ADMIN_NO_PERMISSION'), 'error')
        return
    end

    TriggerClientEvent('inventory:admin:openGiveItemInterface', source)
end, false)

-- Search players by name or ID
lib.callback.register('inventory:admin:searchPlayers', function(source, searchTerm)
    if not PlayerIsAdmin(source) then
        return {}
    end

    local players = {}
    local esxPlayers = FrameworkGetPlayers()
    local searchLower = string.lower(searchTerm or '')

    for _, playerId in ipairs(esxPlayers) do
        local identifier = GetPlayerIdentifier(playerId)
        if identifier then
            local playerName = GetPlayerName(playerId)
            local playerNameLower = string.lower(playerName)

            if searchLower == '' or
                string.find(playerNameLower, searchLower, 1, true) or
                tostring(playerId) == searchTerm or
                string.find(string.lower(identifier), searchLower, 1, true) then
                table.insert(players, {
                    id = playerId,
                    name = playerName,
                    identifier = identifier,
                    coords = GetEntityCoords(GetPlayerPed(playerId))
                })
            end
        end
    end

    return players
end)
