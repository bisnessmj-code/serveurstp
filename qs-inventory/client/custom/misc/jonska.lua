function JonskaItemThrow(item)
    local data = {
        name = item.name,           -- needed for adding and removing item
        label = item.label,         -- MUST HAVE!
        amount = item.amount,       -- needed for adding and removing item
        info = item.info,           -- needed for adding item
        created = item.created or 0 -- needed for adding item (if your inventory have decay system)
    }
    return exports['jonska-itemthrowing']:throwItem(data, item.name, item.amount)
end
