function AddToStash(stashId, slot, otherslot, itemName, amount, info, created)
    return AddItemToOtherInventory('stash', stashId, slot, otherslot, itemName, amount, info, created)
end

exports('AddToStash', AddToStash)
