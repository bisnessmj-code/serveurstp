local color = {} --[[@as Color]]

---@param data Color
RegisterNUICallback('updateColors', function(data, cb)
    color.primaryColor = data.primaryColor or color.primaryColor
    color.primaryOpacity = data.primaryOpacity or color.primaryOpacity
    color.secondaryColor = data.secondaryColor or color.secondaryColor
    color.secondaryOpacity = data.secondaryOpacity or color.secondaryOpacity
    color.borderColor = data.borderColor or color.borderColor
    color.borderOpacity = data.borderOpacity or color.borderOpacity
    color.borderRadius = data.borderRadius or color.borderRadius

    LocalPlayer.state:set('primaryColor', color.primaryColor, true)
    LocalPlayer.state:set('primaryOpacity', color.primaryOpacity, true)

    TriggerEvent('inventory:updateColors', color)
    cb(true)
end)

exports('getColors', function()
    return color
end)


local function handleThemeChange()
    local handler
    handler = AddEventHandler('inventory:updateColors', function()
        if not IsPlayerLoaded() then
            Debug('handleThemeChange', 'Player not loaded, skipping color update')
            return
        end

        Debug('handleThemeChange', 'Theme color updated successfully')

        RemoveEventHandler(handler)
        handler = nil
    end)
end

handleThemeChange()
TriggerEvent('inventory:updateColors')
