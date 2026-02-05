local isAdminGiveItemOpen = false
local currentPlayers = {}
local currentItems = {}
local selectedPlayer = nil
local selectedItem = nil

-- Open the admin giveitem interface
RegisterNetEvent('inventory:admin:openGiveItemInterface', function()
    Debug('Opening admin interface...')
    if isAdminGiveItemOpen then
        return
    end

    isAdminGiveItemOpen = true
    SetNuiFocus(true, true)

    -- Get initial data
    GetOnlinePlayers()
    GetAllItems()

    -- Open the UI
    SendNUIMessage({
        action = 'openAdminGiveItem',
        data = {
            title = 'Admin Give Item System',
            subtitle = 'Player item giving system'
        }
    })
end)

-- Get online players
function GetOnlinePlayers()
    lib.callback('inventory:admin:getOnlinePlayers', false, function(players)
        currentPlayers = players
        SendNUIMessage({
            action = 'updatePlayers',
            data = players
        })
    end)
end

-- Get all items
function GetAllItems()
    local items = {}
    for itemName, itemData in pairs(ItemList) do
        table.insert(items, {
            name = itemName,
            label = itemData.label,
            type = itemData.type,
            weight = itemData.weight,
            unique = itemData.unique or false,
            image = itemData.image or 'default.png'
        })
    end

    -- Sort items alphabetically
    table.sort(items, function(a, b)
        return a.label < b.label
    end)

    SendNUIMessage({
        action = 'updateItems',
        data = items
    })
end

-- Search players
function SearchPlayers(searchTerm)
    lib.callback('inventory:admin:searchPlayers', false, function(players)
        currentPlayers = players
        SendNUIMessage({
            action = 'updatePlayers',
            data = players
        })
    end, searchTerm)
end

-- Search items
function SearchItems(searchTerm)
    local items = {}
    local searchLower = string.lower(searchTerm or '')

    for itemName, itemData in pairs(ItemList) do
        local itemLabelLower = string.lower(itemData.label)
        local itemNameLower = string.lower(itemName)

        if searchLower == '' or
            string.find(itemLabelLower, searchLower, 1, true) or
            string.find(itemNameLower, searchLower, 1, true) then
            table.insert(items, {
                name = itemName,
                label = itemData.label,
                type = itemData.type,
                weight = itemData.weight,
                unique = itemData.unique or false,
                image = itemData.image or 'default.png'
            })
        end
    end

    -- Sort items alphabetically
    table.sort(items, function(a, b)
        return a.label < b.label
    end)

    SendNUIMessage({
        action = 'updateItems',
        data = items
    })
end

function GiveItemToPlayer(targetId, itemName, amount, metadata)
    lib.callback('inventory:admin:giveItem', false, function(success, message)
        if success then
            SendTextMessage(message, 'success')
            CloseAdminGiveItemInterface()
        else
            SendTextMessage(message, 'error')
        end
    end, targetId, itemName, amount, metadata)
end

-- Close admin giveitem interface
function CloseAdminGiveItemInterface()
    Debug('Closing admin interface...')
    isAdminGiveItemOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeAdminGiveItem'
    })
end

-- NUI Callbacks
RegisterNUICallback('closeAdminGiveItem', function(data, cb)
    CloseAdminGiveItemInterface()
    cb('ok')
end)

RegisterNUICallback('searchPlayers', function(data, cb)
    SearchPlayers(data.searchTerm)
    cb('ok')
end)

RegisterNUICallback('searchItems', function(data, cb)
    SearchItems(data.searchTerm)
    cb('ok')
end)

RegisterNUICallback('selectPlayer', function(data, cb)
    selectedPlayer = data.player
    SendNUIMessage({
        action = 'updateSelectedPlayer',
        data = data.player
    })
    cb('ok')
end)

RegisterNUICallback('selectItem', function(data, cb)
    selectedItem = data.item
    SendNUIMessage({
        action = 'updateSelectedItem',
        data = data.item
    })
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    local player = data.player
    local item = data.item
    local amount = tonumber(data.amount) or 1
    local metadata = data.metadata or ''

    GiveItemToPlayer(player.id, item.name, amount, metadata)
    cb('ok')
end)
