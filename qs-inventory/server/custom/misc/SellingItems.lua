function getPriceItemForSelling(name)
	for k, v in pairs(Config.SellItems) do
		for s, x in pairs(v.items) do
			if x.name == name then
				return x.price, v.blip.account
			end
		end
	end
	return false
end

RegisterNetEvent(Config.InventoryPrefix .. ':server:RemoveItem', function(itemName, count)
	local src = source
	RemoveItem(src, itemName, count)
end)

function SetupSellingItems(shop, shopItems)
	local items = {}
	if shopItems ~= nil and next(shopItems) ~= nil then
		for k, item in pairs(shopItems) do
			local itemInfo = ItemInfo(item)
			if not itemInfo then return Error('There is an item that does not exist in this selling store!') end
			itemInfo.price = item.price
			items[item.slot] = itemInfo
		end
	end
	return items
end

---@param src number
---@param fromInventory string
---@param fromSlot number
---@param fromAmount number
---@param toInventory string
---@param toSlot number
---@return boolean
function SellItemToSelling(src, fromInventory, fromSlot, fromAmount, toInventory, toSlot)
	if fromInventory ~= 'player' and fromInventory ~= 'hotbar' then
		Debug('You can not sell items from this inventory', fromInventory)
		return false
	end
	local fromItemData = GetItemBySlot(src, fromSlot)
	fromAmount = tonumber(fromAmount) and tonumber(fromAmount) or fromItemData.amount
	if fromAmount == 0 then
		Notification(src, Lang('INVENTORY_NOTIFICATION_SELLING_AMOUNT'), 'error')
		return false
	end
	if not fromItemData or fromItemData.amount < fromAmount then
		Debug('You do not have this item or not enough amount', fromItemData, fromAmount)
		Notification(src, Lang('INVENTORY_NOTIFICATION_SELLING_BAD_ITEM'), 'error')
		return false
	end
	local sell_id = SplitStr(toInventory, '-')[2]
	local toItemData = SellItems[sell_id].items[toSlot]
	if not toItemData or toItemData.name ~= fromItemData.name then
		Debug('You can not sell this item to this slot', toItemData, fromItemData)
		Notification(src, Lang('INVENTORY_NOTIFICATION_SELLING_BAD_ITEM'), 'error')
		return false
	end
	RemoveItem(src, fromItemData.name, fromAmount, fromSlot)
	local price, account = getPriceItemForSelling(fromItemData.name)
	if not price then
		return false
	end
	AddAccountMoney(src, account, price * fromAmount)
	Notification(src, price * fromAmount .. ' ' .. Lang('INVENTORY_NOTIFICATION_SELLING_SUCCESS'), 'success')
	SendWebhook(Webhooks.sell, 'Item Sale', 7393279, '**' .. GetPlayerName(src) .. '(id: ' .. src .. ') sold an item!**\n**Name:** ' .. fromItemData.name .. '\n**Price:** ' .. price * fromAmount .. '\n**Amount:** ' .. fromAmount)
	Debug('Player is selling an item', src, fromItemData.name, fromAmount, price)
	return true
end
