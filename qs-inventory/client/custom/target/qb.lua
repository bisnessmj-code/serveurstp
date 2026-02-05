if not Config.UseTarget then
    return
end

local target_name = GetResourceState('ox_target'):find('started') and 'qtarget' or 'qb-target'

CreateThread(function()
    -- Selling
    for k, v in pairs(Config.SellItems) do
        exports[target_name]:AddBoxZone(k .. '_selling', vec3(v['coords'].x, v['coords'].y, v['coords'].z), 1.5, 1.5, {
            name = k .. '_selling',
            heading = 90.0,
            debugPoly = Config.ZoneDebug,
            minZ = v['coords'].z - 1,
            maxZ = v['coords'].z + 1,
        }, {
            options = {
                {
                    type = 'client',
                    icon = 'fa-solid fa-cash-register',
                    label = Lang('INVENTORY_TEXT_SELLING'),
                    canInteract = function(entity, distance, data)
                        return true
                    end,
                    action = function(entity)
                        local PawnshopItems = {}
                        PawnshopItems.label = k
                        PawnshopItems.items = v['items']
                        PawnshopItems.slots = #v['items']
                        TriggerServerEvent(Config.InventoryPrefix .. ':server:OpenInventory', 'selling', 'itemselling_' .. k, PawnshopItems)
                    end,
                },
            },
            distance = 2.5
        })
    end

    -- Crafting
    if Config.Crafting then
        for k, v in pairs(Config.CraftingTables) do
            exports[target_name]:AddBoxZone(k .. '_crafting', vec3(v.location.x, v.location.y, v.location.z), 2.5, 2.5, {
                name = k .. '_crafting',
                heading = 90.0,
                debugPoly = Config.ZoneDebug,
                minZ = v.location.z - 1,
                maxZ = v.location.z + 1,
            }, {
                options = {
                    {
                        type = 'client',
                        icon = 'fa-solid fa-hammer',
                        label = 'Crafting',
                        canInteract = function(entity, distance, data)
                            return true
                        end,
                        action = function(entity)
                            if isCrafting then return end
                            if v.isjob then
                                if IsPlayerAuthorized(v) then
                                    CurrentCrafting = k
                                    local crafting = {
                                        label = v.name,
                                        items = GeneralInfos(k)
                                    }
                                    TriggerServerEvent(Config.InventoryPrefix .. ':server:OpenInventory', 'crafting', math.random(1, 99), crafting)
                                end
                            else
                                CurrentCrafting = k
                                local crafting = {
                                    label = v.name,
                                    items = GeneralInfos(k)
                                }
                                TriggerServerEvent(Config.InventoryPrefix .. ':server:OpenInventory', 'crafting', math.random(1, 99), crafting)
                            end
                        end,
                    },
                },
                distance = 2.5
            })
        end
    end

    -- Vending shops
    if Config.Vendings then
        for k, v in pairs(Config.Vendings) do
            exports[target_name]:AddTargetModel(v['Model'], {
                options = {
                    {
                        icon = 'fa-solid fa-cash-register',
                        label = 'Vending',
                        action = function()
                            TriggerEvent(Config.InventoryPrefix .. ':client:openVending', { category = v['Category'] })
                        end
                    },
                },
                distance = 2.5
            })
        end
    end

    -- Gargabe Code
    exports[target_name]:AddTargetModel(Config.GarbageObjects, {
        options = {
            {
                icon = 'fa-solid fa-trash',
                label = 'Open Garbage',
                action = function()
                    ExecuteCommand('inventory')
                end
            },
        },
        distance = 1.0
    })
end)

function AddTargetEntity(entity, options, distance)
    distance = distance or 5.0
    exports[target_name]:AddTargetEntity(entity, {
        options = options,
        distance = distance
    })
end
