if GetResourceState('evo-k9-v2') ~= 'started' then
    return
end

function evok9CheckPlayerInventoryItems(playerId)
    return exports['qs-inventory']:GetInventory(playerId)
end

exports('evok9CheckPlayerInventoryItems', evok9CheckPlayerInventoryItems)

function evok9CheckInventoryItems(Identifier, InvType, cb)
    if not Identifier or not InvType then
        return cb({})
    end

    local queries = {
        trunk = 'SELECT * FROM inventory_trunk WHERE plate = @identifier',
        glovebox = 'SELECT * FROM inventory_glovebox WHERE plate = @identifier'
    }
    local query = queries[InvType]

    if not query then
        return cb({})
    end

    MySQL.Async.fetchAll(query, { ['@identifier'] = Identifier }, function(result)
        if result[1] and result[1].items then
            local items = json.decode(result[1].items) or {}

            if type(items) ~= "table" then
                return cb({})
            end

            local FormattedItems = {}

            for _, v in pairs(items) do
                table.insert(FormattedItems, {
                    name = v.name or 'unknown',
                    label = v.label or v.name or 'Unknown Item',
                    amount = v.amount or 1,
                    weight = v.weight or 0,
                    image = v.image or 'default.png',
                    unique = v.unique or false,
                    info = v.info or {},
                    slot = v.slot or 0
                })
            end

            return cb(FormattedItems)
        else
            return cb({})
        end
    end)
end

exports('evok9CheckInventoryItems', evok9CheckInventoryItems)