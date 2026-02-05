if Config.Framework ~= 'esx' then
    return
end

ESX = exports['es_extended']:getSharedObject()

userTable = 'users'
Identifier = 'identifier'
VehicleTable = 'owned_vehicles'
es_extended = 'es_extended'
WeaponList = WeaponList
ItemList = FormatItems(ItemList)

StarterItems = {
    ['radio'] = 1,
    ['armor'] = 3,
}

RegisterNetEvent('esx:playerLoaded', function(id, player)
    local inventory = LoadInventory(id, player.identifier)
    Inventories[id] = inventory

    local player = GetPlayerFromId(id)
    local money = GetItemTotalAmount(id, 'money')
    local black_money = GetItemTotalAmount(id, 'black_money')

    player.setAccountMoney('money', money, 'dropped')
    player.setAccountMoney('black_money', black_money, 'dropped')
    InitDrops(id)
    InitPlacedItems(id)
end)

function RegisterServerCallback(name, cb)
    ESX.RegisterServerCallback(name, cb)
end

function GetPlayerFromId(source)
    return ESX.GetPlayerFromId(source)
end

function GetPlayerSourceFromIdentifier(identifier)
    local player = ESX.GetPlayerFromIdentifier(identifier)
    if not player then
        return nil
    end
    return ESX.GetPlayerFromIdentifier(identifier).source
end

function GetPlayerFromIdentifier(identifier)
    return ESX.GetPlayerFromIdentifier(identifier)
end

function PlayerIsAdmin(source)
    if source == 0 then
        return true
    end
    local player = GetPlayerFromId(source)
    return player.getGroup() == 'admin' or player.getGroup() == 'superadmin'
end

function FrameworkGetPlayers()
    return ESX.GetPlayers()
end

function GetPlayerIdentifier(source)
    local player = GetPlayerFromId(source)
    if not player then return Wait(100) end
    return player.identifier
end

function GetJobName(source)
    local player = GetPlayerFromId(source)
    if not player then
        Debug('Player not found', source)
        return 'unemployed'
    end
    return player?.getJob().name
end

function GetJobGrade(source)
    local player = GetPlayerFromId(source)
    if not player then
        Debug('Player not found', source)
        return 0
    end
    return player.getJob().grade
end

function GetAccountMoney(source, account)
    local player = GetPlayerFromId(source)
    return player.getAccount(account).money
end

function SetAccountMoney(source, account)
    local player = GetPlayerFromId(source)
    return player.setAccountMoney(account)
end

function AddAccountMoney(source, account, amount)
    local player = GetPlayerFromId(source)
    if not player then
        Debug('AddAccountMoney Player not found', source)
        return
    end
    player.addAccountMoney(account, amount)
end

function GetItems(player)
    return player.getInventory()
end

function GetItem(player, item)
    return player.getInventoryItem(item)
end

function RemoveAccountMoney(source, account, amount)
    local player = GetPlayerFromId(source)
    player.removeAccountMoney(account, amount)
end

function GetUserName(identifier)
    local query = 'SELECT firstname, lastname, dateofbirth, sex FROM users WHERE identifier = ?'
    local queryParams = { identifier }

    local result = MySQL.prepare.await(query, queryParams)
    if result then
        local fullName = result.firstname .. (result.lastname and ' ' .. result.lastname or '')

        local userDetails = {
            citizenid = nil,
            firstname = result.firstname or 'Player',
            lastname = result.lastname or '',
            birthdate = result.dateofbirth,
            gender = result.sex,
            nationality = nil,
        }

        return fullName, userDetails
    else
        return '', {}
    end
end

function IsVehicleOwnedAbleToOpen(plate, id)
    local val = false
    local Player = GetPlayerFromId(id)
    if Player then
        local result = MySQL.Sync.fetchAll('SELECT * FROM  ' .. VehicleTable .. " WHERE `plate` = '" .. plate .. "' LIMIT 1")
        if (result and result[1] ~= nil) then
            if result[1].owner == Player.identifier then
                val = true
            else
                val = false
            end
        else
            val = true
        end
        return val
    else
        return val
    end
end

AddEventHandler('esx:onAddInventoryItem', function(source, itemName, amount)
    -- You can test this code here
    -- Debug('Test event esx:onAddInventoryItem:', itemName)
end)

AddEventHandler('esx:onRemoveInventoryItem', function(source, itemName, amount)
    -- You can test this code here
    -- Debug('Test event esx:onRemoveInventoryItem:', itemName)
end)

-- Don't toch
Accounts = { black_money = 0, money = 0 }

RegisterServerEvent('qs-inventory:server:updateItem', function(item, data)
    if source ~= 0 or source ~= '' then
        return
    end

    if not ItemList[item] then
        return
    end

    ItemList[item] = data
    TriggerClientEvent('qs-inventory:client:updateItem', -1, item, data)
end)

---@param source number
---@param items table
function UpdateFrameworkInventory(source, items)
    Debug('UpdateFrameworkInventory', source, items)
end
