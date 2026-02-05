---@param item string
---@param source number
---@param amount number
function NotStoredItems(item, source, amount)
    if not amount then
        Debug('Amount not provided, set to 1', item, source)
        amount = 1
    end
    local itemsWithCommonLimit = {
        ['backpack'] = true,
        ['backpack2'] = true,
        ['briefcase'] = true,
        ['paramedicbag'] = true
        -- Add more backpack types here
    }

    local maxAllowed = Config.OnePerItem['backpack'] -- Default max for backpack

    if itemsWithCommonLimit[item] then
        local checkItem = GetItemTotalAmount(source, 'backpack')
        Debug('Check unique item ' .. item .. ', you have ' .. checkItem .. ', max: ' .. maxAllowed)
        return checkItem >= maxAllowed
    end

    maxAllowed = Config.OnePerItem[item]
    if maxAllowed then
        local checkItem = GetItemTotalAmount(source, item) + amount
        Debug('Check unique item ' .. item .. ', you have ' .. checkItem .. ', max: ' .. maxAllowed)
        return checkItem > maxAllowed
    end

    return false
end
