-- ═══════════════════════════════════════════════════════════════════════════
-- CVC CONVOY - Blocage du drop d'armes pendant le mode CVC
-- ═══════════════════════════════════════════════════════════════════════════
local function IsCVCBlockedItem_Drop(itemName)
	local blockedItems = {
		['weapon_smg'] = true,
		['weapon_pistol50'] = true,
		['weapon_sawnoffshotgun'] = true,
		['weapon_compactrifle'] = true,
		['weapon_pistol'] = true,
		['smg_ammo'] = true,
		['pistol_ammo'] = true,
		['shotgun_ammo'] = true,
		['rifle_ammo'] = true,
	}
	return blockedItems[itemName:lower()] or false
end

local function IsPlayerInCVCMode_Drop(playerId)
	if GetResourceState('cvc_convoy') == 'started' then
		local inMode = exports['cvc_convoy']:IsPlayerInMode(playerId)
		return inMode == true
	end
	return false
end
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent(Config.InventoryPrefix .. ':server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount, fromInventoryIsClothesInventory, toInventoryIsClothesInventory, craftingKey)
	local src = source
	local Player = GetPlayerFromId(src)
	local identifier = GetPlayerIdentifier(src)
	fromSlot = tonumber(fromSlot)
	toSlot = tonumber(toSlot)
	fromAmount = tonumber(fromAmount)
	fromSlot = tonumber(fromSlot)
	toSlot = tonumber(toSlot)
	assert(fromSlot, 'fromSlot is nil')
	assert(toSlot, 'toSlot is nil')
	assert(fromAmount, 'fromAmount is nil')
	if fromAmount < 0 then
		SendWebhook(Webhooks.exploit, 'SetInventoryData (exploit attempt)', 7393279, ([[
			Player: %s
			Identifier: %s
			Reason: Gave negative amount, its not possible.
			Amount: %s
		]]):format(GetPlayerName(src), identifier, fromAmount))
		return Error('SetInventoryData', 'This player is trying to exploit the inventory. You can ban this player from the server.', src, 'identifier', identifier)
	end
	fromAmount = math.max(fromAmount, 1)

	if (fromInventory == 'player' or fromInventory == 'hotbar') and (SplitStr(toInventory, '-')[1] == 'itemshop' or toInventory == 'crafting' or toInventory == 'customcrafting') then
		return
	end

	if fromInventoryIsClothesInventory and toInventoryIsClothesInventory then
		return
	end

	if (SplitStr(fromInventory, '-')[1] == 'selling') then
		return
	end

	if fromInventoryIsClothesInventory then
		local clotheItems = GetClotheItems(src)
		local item = clotheItems[fromSlot]
		if not item then
			Error('SetInventoryData', 'Clothing', 'Item not found', src, fromSlot)
			return
		end
		local itemIsClothPart = checkItemIsClothingPart(item.name)
		if not itemIsClothPart then
			TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_CANT_MOVE'), 'inform')
			return
		end
		local data = table.find(Config.ClothingSlots, function(v)
			if v.slot == fromSlot then
				return true
			end
			return false
		end)
		item.info.armor = GetPedArmour(GetPlayerPed(src))
		if data then
			TriggerClientEvent('inventory:takeoffClothing', src, data)
		end

		AddItem(src, item.name, 1, toSlot, item.info, nil, nil, nil, true)
		RemoveFromClothes(identifier, fromSlot, item.name, 1)
		TriggerClientEvent(Config.InventoryPrefix .. ':saveClothes', src)
		return
	elseif toInventoryIsClothesInventory then
		local item = GetItemBySlot(src, fromSlot)
		if not item then return end
		local itemIsClothPart = checkItemIsClothingPart(item.name)
		if not itemIsClothPart then
			TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_CANT_MOVE'), 'inform')
			return
		end
		UseItem(item.name, src, item)
		AddToClothes(identifier, item.name, item.info)
		RemoveItem(src, item.name, 1, fromSlot, nil, true)
		TriggerClientEvent(Config.InventoryPrefix .. ':saveClothes', src)
		return
	end

	if SplitStr(toInventory, '-')[1] == 'selling' then
		if fromInventory ~= 'player' and fromInventory ~= 'hotbar' then return end
		local fromItemData = GetItemBySlot(src, fromSlot)
		fromAmount = tonumber(fromAmount) and tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local sell_id = SplitStr(toInventory, '-')[2]
			local toItemData = SellItems[sell_id].items[toSlot]
			Debug(toItemData.name, fromItemData.name)
			if toItemData and toItemData.name == fromItemData.name then
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
				local price, account = getPriceItemForSelling(fromItemData.name)
				if not price then return end
				if fromAmount == 0 then
					return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_SELLING_AMOUNT'), 'error')
				end
				AddAccountMoney(src, account, price * fromAmount)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, price * fromAmount .. ' ' .. Lang('INVENTORY_NOTIFICATION_SELLING_SUCCESS'), 'success')
				SendWebhook(Webhooks.sell, 'Item Sale', 7393279, '**' .. GetPlayerName(src) .. '(id: ' .. src .. ') sold an item!**\n**Name:** ' .. fromItemData.name .. '\n**Price:** ' .. price * fromAmount .. '\n**Amount:** ' .. fromAmount)
			else
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_SELLING_BAD_ITEM'), 'error')
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_SELLING_BAD_ITEM'), 'error')
		end
		return
	end

	if fromInventory == 'player' or fromInventory == 'hotbar' then
		local fromItemData = GetItemBySlot(src, fromSlot)
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			if toInventory == 'player' or toInventory == 'hotbar' then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
							AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. toItemData.name .. '\n**Amount:** ' .. toAmount .. ' with name: ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount)
						end
					else
						print('Dupe Blocked - 1')
					end
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
			elseif SplitStr(toInventory, '-')[1] == 'otherplayer' then
				local playerId = tonumber(SplitStr(toInventory, '-')[2])
				local toItemData = Inventories[playerId][toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
				if toItemData then
					local itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(playerId, itemInfo['name'], toAmount, toSlot, nil, true)
						TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, toItemData, toAmount, 'remove')
						AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
						TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
					end
				end
				local itemInfo = ItemList[fromItemData.name:lower()]
				AddItem(playerId, itemInfo['name'], fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
			elseif SplitStr(toInventory, '-')[1] == 'trunk' then
				local plate = SplitStr(toInventory, '-')[2]
				local toItemData = Trunks[plate].items[toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
				if toItemData then
					local itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							Debug('trunk 132')
							local success = RemoveItemFromOtherInventory('trunk', plate, toSlot, itemInfo['name'], toAmount, src)
							if not success then
								return Error('SetInventoryData', 'Trunk', 'Item not found', src, toSlot)
							end
							AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**With name:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
						end
					else
						print('Dupe Blocked - 3')
					end
				end
				local itemInfo = ItemList[fromItemData.name:lower()]
				AddItemToOtherInventory('trunk', plate, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)
				SendWebhook(Webhooks.trunk, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in trunk!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
			elseif SplitStr(toInventory, '-')[1] == 'glovebox' then
				local plate = SplitStr(toInventory, '-')[2]
				local toItemData = Gloveboxes[plate].items[toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
				if toItemData then
					local itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							Debug('trunk 159')
							local success = RemoveItemFromOtherInventory('glovebox', plate, toSlot, itemInfo['name'], toAmount, src)
							if not success then
								return Error('SetInventoryData', 'Glovebox', 'Item not found', src, fromSlot)
							end
							AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**With name:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
						end
					else
						print('Dupe Blocked - 4')
					end
				end
				local itemInfo = ItemList[fromItemData.name:lower()]
				AddItemToOtherInventory('glovebox', plate, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)
				SendWebhook(Webhooks.glovebox, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in glovebox!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
			elseif SplitStr(toInventory, '-')[1] == 'stash' then
				local stashId = SplitStr(toInventory, '-')[2]
				local toItemData = Stashes[stashId].items[toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
				if toItemData then
					local itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							Debug('186')
							local success = RemoveItemFromOtherInventory('stash', stashId, toSlot, toItemData.name, toAmount, src)
							if not success then
								return Error('SetInventoryData', 'Stash', 'Item not found', src, fromSlot)
							end
							-- PATCH: Mise à jour explicite après RemoveItemFromOtherInventory (swap player<->stash)
							if Stashes[stashId] and Stashes[stashId].items then
								Stashes[stashId].items[toSlot] = nil
							end
							AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**With name:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Stash id:** ' .. stashId)
						end
					else
						print('Dupe Blocked - 5')
					end
				end
				local itemInfo = ItemList[fromItemData.name:lower()]
				AddItemToOtherInventory('stash', stashId, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)
				-- PATCH: Mise à jour explicite de Stashes après ajout d'item (player -> stash)
				if Stashes[stashId] and Stashes[stashId].items then
					local existingItem = Stashes[stashId].items[toSlot]
					-- FIX DUPLICATION: Ne PAS re-additionner, AddItemToOtherInventory l'a déjà fait
					if existingItem and existingItem.name == fromItemData.name then
						-- L'item existe déjà, AddItemToOtherInventory a déjà mis à jour le montant
						-- On synchronise juste count = amount sans re-additionner
						Stashes[stashId].items[toSlot].count = Stashes[stashId].items[toSlot].amount
						print('[QS-INVENTORY/STASH-OK] Item: ' .. fromItemData.name .. ' x' .. Stashes[stashId].items[toSlot].amount .. ' -> slot ' .. toSlot)
					else
						-- Nouveau slot ou swap (on a déjà vidé le slot dans le swap)
						Stashes[stashId].items[toSlot] = {
							name = fromItemData.name,
							amount = fromAmount,
							count = fromAmount,
							slot = toSlot,
							type = fromItemData.type or 'item',
							weight = fromItemData.weight or 0,
							label = fromItemData.label or fromItemData.name,
							description = fromItemData.description or '',
							image = fromItemData.image or (fromItemData.name .. '.png'),
							unique = fromItemData.unique or false,
							useable = fromItemData.useable or true,
							info = fromItemData.info or {},
							created = fromItemData['created'] or os.time(),
							rare = fromItemData.rare or 'common'
						}
						print('[QS-INVENTORY/STASH-ADD] Item ajouté au stash: ' .. fromItemData.name .. ' x' .. fromAmount .. ' -> slot ' .. toSlot)
					end
				end
				SendWebhook(Webhooks.stash, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in stash!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Stash id:** ' .. stashId)
			elseif SplitStr(toInventory, '_')[1] == 'garbage' then
				local garbageId = SplitStr(toInventory, '_')[2]
				local toItemData = GarbageItems[garbageId].items[toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
				if toItemData then
					local itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							RemoveFromGarbage(garbageId, toSlot, itemInfo['name'], toAmount)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, toItemData, toAmount, 'remove')
							AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**With name:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Garbage id:** ' .. garbageId)
						end
					else
						print('Dupe Blocked - 6')
					end
				end
				local itemInfo = ItemList[fromItemData.name:lower()]
				AddToGarbage(garbageId, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'])
				SendWebhook(Webhooks.garbage, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in garbage!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Garbage id:** ' .. garbageId)
			elseif SplitStr(toInventory, '-')[1] == 'traphouse' then
				-- Traphouse
				local traphouseId = SplitStr(toInventory, '_')[2]
				local toItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, toSlot)
				local IsItemValid = exports['qb-traphouse']:CanItemBeSaled(fromItemData.name:lower())
				if IsItemValid then
					RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
					TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
					TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
					if toItemData then
						local itemInfo = ItemList[toItemData.name:lower()]
						toAmount = tonumber(toAmount) or toItemData.amount
						if toItemData.amount >= toAmount then
							if toItemData.name ~= fromItemData.name then
								exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo['name'], toAmount)
								TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, toItemData, toAmount, 'remove')
								AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
								TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
								SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**With name:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Traphouse id:** ' .. traphouseId)
							end
						else
							print('Dupe Blocked - 7')
						end
					end
					local itemInfo = ItemList[fromItemData.name:lower()]
					exports['qb-traphouse']:AddHouseItem(traphouseId, toSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)
					SendWebhook(Webhooks.swap, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in traphouse!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Traphouse id:** ' .. traphouseId)
				else
					TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_CANT_SELL'), 'error')
				end
			else
				-- drop
				-- CVC CONVOY: Bloquer le drop d'armes/munitions pendant le mode CVC
				if IsPlayerInCVCMode_Drop(src) and IsCVCBlockedItem_Drop(fromItemData.name) then
					TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, '~r~Vous ne pouvez pas jeter vos armes/munitions pendant le mode CVC', 'error')
					TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
					return
				end

				toInventoryFormatter = SplitStr(toInventory, '-')[2]
				toInventory = tonumber(toInventoryFormatter)
				if toInventory == nil or toInventory == 0 then
					CreateNewDrop(src, fromSlot, toSlot, fromAmount, fromItemData['created'])
					Debug('[SetInventoryData, function CreateNewDrop]', fromSlot, toSlot, fromAmount, fromItemData['created'])
					TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
					SendWebhook(Webhooks.drop, 'Create New Drop', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') create new drop!**\n**Name:** ' .. fromItemData['name'] .. '\n**Amount:** ' .. fromAmount)
				else
					local toItemData = Drops[toInventory].items[toSlot]
					RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
					TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
					TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
					if toItemData then
						local itemInfo = ItemList[toItemData.name:lower()]
						toAmount = tonumber(toAmount) or toItemData.amount
						if toItemData.amount >= toAmount then
							if toItemData.name ~= fromItemData.name then
								AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
								TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'add')
								RemoveFromDrop(toInventory, fromSlot, itemInfo['name'], toAmount)
								SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**With name:** ' .. fromItemData.name .. '\n**mount:** ' .. fromAmount .. '\n**Drop id:** ' .. toInventory)
							end
						else
							print('Dupe Blocked - 8')
						end
					end
					local itemInfo = ItemList[fromItemData.name:lower()]
					AddToDrop(toInventory, toSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'])
					SendWebhook(Webhooks.drop, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in drop!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Drop id:** ' .. toInventory)
					if itemInfo['name'] == 'radio' then
						TriggerClientEvent('Radio.Set', src, false)
					elseif itemInfo['name'] == 'money' and Config.Framework == 'esx' then
						local money = GetItemTotalAmount(src, 'money')
						Player.setAccountMoney('money', money, 'dropped')
					elseif itemInfo['name'] == 'black_money' and Config.Framework == 'esx' then
						local money = GetItemTotalAmount(src, 'black_money')
						Player.setAccountMoney('black_money', money, 'dropped')
					end
					TriggerClientEvent(Config.InventoryPrefix .. ':ClearWeapons', src)
				end
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_GIVE_DONT_HAVE'), 'error')
		end
	elseif SplitStr(fromInventory, '-')[1] == 'otherplayer' then
		local playerId = tonumber(SplitStr(fromInventory, '-')[2])
		local fromItemData = Inventories[playerId][fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = ItemList[fromItemData.name:lower()]
			if toInventory == 'player' or toInventory == 'hotbar' then
				local toItemData = GetItemBySlot(src, toSlot)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, fromItemData, fromAmount, 'remove')
				RemoveItem(playerId, itemInfo['name'], fromAmount, fromSlot, nil, true)
				SendWebhook(Webhooks.robbery, 'Deposit Item (robbery)', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in inventory (robbery)!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Otherplayer id:** ' .. playerId)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', playerId, fromItemData.name)
				if toItemData then
					itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
						TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'remove')
						AddItem(playerId, itemInfo['name'], toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
						TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, toItemData, toAmount, 'add')
					end
				end
				-- Weapon Parts
				if fromItemData.type == 'weapon' and Config.CanStealWeaponParts then
					local chance = math.random(1, 100)
					if chance <= Config.WeaponPartStealChance then
						Debug('The complete weapon was stolen with a probability of:', chance)
						AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
					else
						Debug('The theft of the weapon was failed with a probability of:', chance, 'random items added!')
						RemoveItem(src, fromItemData.name, fromAmount, toSlot, nil, true)

						for i = 1, 5 do
							local randomItem = Config.AvailableWeaponParts[math.random(1, #Config.AvailableWeaponParts)]
							AddItem(src, randomItem, math.random(1, 5))
						end

						Wait(200)
						TriggerClientEvent(Config.InventoryPrefix .. ':client:forceCloseInventory', src)
						TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_STEAL_BROKEN_WEAPON'), 'inform')
					end
				else
					AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
					TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'add')
				end
				-- Weapon Parts
			else
				local toItemData = Inventories[playerId][toSlot]
				RemoveItem(playerId, itemInfo['name'], fromAmount, fromSlot, nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, fromItemData, fromAmount, 'remove')
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							RemoveItem(playerId, itemInfo['name'], toAmount, toSlot, nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, toItemData, toAmount, 'remove')
							AddItem(playerId, itemInfo['name'], toAmount, fromSlot, toItemData.info, nil, fromItemData['created'], nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, toItemData, toAmount, 'add')
						end
					else
						print('Dupe Blocked - 10')
					end
				end
				itemInfo = ItemList[fromItemData.name:lower()]
				AddItem(playerId, itemInfo['name'], fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', playerId, fromItemData, fromAmount, 'add')
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
		end
	elseif SplitStr(fromInventory, '-')[1] == 'trunk' then
		local plate = SplitStr(fromInventory, '-')[2]
		local fromItemData = Trunks[plate].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		Debug('fromSlot', fromSlot, 'toSlot', toSlot, 'fromAmount', fromAmount, 'toAmount', toAmount)
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = ItemList[fromItemData.name:lower()]
			if toInventory == 'player' or toInventory == 'hotbar' then
				Debug('380')
				local toItemData = GetItemBySlot(src, toSlot)
				local success = RemoveItemFromOtherInventory('trunk', plate, fromSlot, itemInfo['name'], fromAmount, src)
				if not success then
					return Error('SetInventoryData', 'Trunk', 'Item not found', src, fromSlot)
				end
				-- TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'remove')
				SendWebhook(Webhooks.trunk, 'Remove Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') remove item from trunk!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
				if toItemData then
					itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'remove')
							AddItemToOtherInventory('trunk', plate, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. toItemData.name .. '\n**Amount:** ' .. toAmount .. '\n**With item:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**Plate:** ' .. plate)
						end
					else
						print('Dupe Blocked - 11')
					end
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'add')
			else
				Debug('405')
				local toItemData = Trunks[plate].items[toSlot]
				local success = RemoveItemFromOtherInventory('trunk', plate, fromSlot, itemInfo['name'], fromAmount, src)
				if not success then
					return Error('SetInventoryData', 'Trunk', 'Item not found', src, fromSlot)
				end
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							Debug('trunk 410')
							RemoveItemFromOtherInventory('trunk', plate, toSlot, itemInfo['name'], toAmount, src)
							AddItemToOtherInventory('trunk', plate, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
						end
					else
						print('Dupe Blocked - 12')
					end
				end
				itemInfo = ItemList[fromItemData.name:lower()]
				AddItemToOtherInventory('trunk', plate, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)
				SendWebhook(Webhooks.trunk, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in trunk!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
		end
	elseif SplitStr(fromInventory, '-')[1] == 'glovebox' then
		local plate = SplitStr(fromInventory, '-')[2]
		local fromItemData = Gloveboxes[plate].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = ItemList[fromItemData.name:lower()]
			if toInventory == 'player' or toInventory == 'hotbar' then
				local toItemData = GetItemBySlot(src, toSlot)
				Debug('439')
				local success = RemoveItemFromOtherInventory('glovebox', plate, fromSlot, itemInfo['name'], fromAmount, src)
				if not success then
					return Error('SetInventoryData', 'Glovebox', 'Item not found', src, fromSlot)
				end
				SendWebhook(Webhooks.glovebox, 'Remove Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') remove item from glovebox!**\nName:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
				if toItemData then
					itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'remove')
							AddItemToOtherInventory('glovebox', plate, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: *' .. src .. ')* swapped item!**\n**Name:** ' .. toItemData.name .. '\n**Amount:** ' .. toAmount .. '\n**With item:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. toAmount .. '\n**Plate:** ' .. plate)
						end
					else
						print('Dupe Blocked - 13')
					end
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'add')
			else
				local toItemData = Gloveboxes[plate].items[toSlot]
				Debug('463')
				local success = RemoveItemFromOtherInventory('glovebox', plate, fromSlot, itemInfo['name'], fromAmount, src)
				if not success then
					return Error('SetInventoryData', 'Glovebox', 'Item not found', src, fromSlot)
				end
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							Debug('trunk 473')
							RemoveItemFromOtherInventory('glovebox', plate, toSlot, itemInfo['name'], toAmount, src)
							AddItemToOtherInventory('glovebox', plate, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
						end
					else
						print('Dupe Blocked - 14')
					end
				end
				itemInfo = ItemList[fromItemData.name:lower()]
				AddItemToOtherInventory('glovebox', plate, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)
				SendWebhook(Webhooks.glovebox, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in glovebox!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Plate:** ' .. plate)
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
		end
	elseif SplitStr(fromInventory, '-')[1] == 'stash' then
		local stashId = SplitStr(fromInventory, '-')[2]
		local fromItemData = Stashes[stashId].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = ItemList[fromItemData.name:lower()]
			if toInventory == 'player' or toInventory == 'hotbar' then
				local toItemData = GetItemBySlot(src, toSlot)
				Debug('496')
				local success = RemoveItemFromOtherInventory('stash', stashId, fromSlot, itemInfo['name'], fromAmount, src)
				if not success then
					return Error('SetInventoryData', 'Stash', 'Item not found', src, fromSlot)
				end
				-- PATCH: Mise à jour explicite de Stashes après RemoveItemFromOtherInventory
				if Stashes[stashId] and Stashes[stashId].items then
					if Stashes[stashId].items[fromSlot] then
						if Stashes[stashId].items[fromSlot].amount <= fromAmount then
							Stashes[stashId].items[fromSlot] = nil
						else
							Stashes[stashId].items[fromSlot].amount = Stashes[stashId].items[fromSlot].amount - fromAmount
							Stashes[stashId].items[fromSlot].count = Stashes[stashId].items[fromSlot].amount
						end
					end
				end
				SendWebhook(Webhooks.stash, 'Remove Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') remove item from stash!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Stash id:** ' .. stashId)

				if toItemData then
					itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'remove')
							AddItemToOtherInventory('stash', stashId, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
							-- PATCH: Mise à jour explicite après AddItemToOtherInventory (swap)
							if Stashes[stashId] and Stashes[stashId].items then
								Stashes[stashId].items[fromSlot] = {
									name = toItemData.name,
									amount = toAmount,
									count = toAmount,
									slot = fromSlot,
									type = toItemData.type or 'item',
									weight = toItemData.weight or 0,
									label = toItemData.label or toItemData.name,
									description = toItemData.description or '',
									image = toItemData.image or (toItemData.name .. '.png'),
									unique = toItemData.unique or false,
									useable = toItemData.useable or true,
									info = toItemData.info or {},
									created = fromItemData['created'] or os.time(),
									rare = toItemData.rare or 'common'
								}
							end
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. toItemData.name .. '\n**Amount:** ' .. toAmount .. '\n**With item:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Stash id:** ' .. stashId)
						end
					else
						print('Dupe Blocked - 15')
					end
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'add')
			else
				-- MOUVEMENT INTERNE DANS LE STASH (stash vers stash)
				local toItemData = Stashes[stashId].items[toSlot]
				Debug('522 - Mouvement interne stash: fromSlot=' .. fromSlot .. ' toSlot=' .. toSlot)

				-- Sauvegarder les données AVANT les modifications
				local savedFromItem = nil
				local savedToItem = nil
				if fromItemData then
					savedFromItem = {
						name = fromItemData.name,
						amount = fromAmount,
						count = fromAmount,
						slot = toSlot, -- nouveau slot
						type = fromItemData.type or 'item',
						weight = fromItemData.weight or 0,
						label = fromItemData.label or fromItemData.name,
						description = fromItemData.description or '',
						image = fromItemData.image or (fromItemData.name .. '.png'),
						unique = fromItemData.unique or false,
						useable = fromItemData.useable or true,
						info = fromItemData.info or {},
						created = fromItemData['created'] or os.time(),
						rare = fromItemData.rare or 'common'
					}
				end
				if toItemData then
					savedToItem = {
						name = toItemData.name,
						amount = tonumber(toAmount) or toItemData.amount,
						count = tonumber(toAmount) or toItemData.amount,
						slot = fromSlot, -- nouveau slot
						type = toItemData.type or 'item',
						weight = toItemData.weight or 0,
						label = toItemData.label or toItemData.name,
						description = toItemData.description or '',
						image = toItemData.image or (toItemData.name .. '.png'),
						unique = toItemData.unique or false,
						useable = toItemData.useable or true,
						info = toItemData.info or {},
						created = toItemData['created'] or os.time(),
						rare = toItemData.rare or 'common'
					}
				end

				local success = RemoveItemFromOtherInventory('stash', stashId, fromSlot, itemInfo['name'], fromAmount, src)
				if not success then
					return Error('SetInventoryData', 'Stash', 'Item not found', src, fromSlot)
				end
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							Debug('532')
							RemoveItemFromOtherInventory('stash', stashId, toSlot, itemInfo['name'], toAmount, src)
							AddItemToOtherInventory('stash', stashId, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
						end
					else
						print('Dupe Blocked - 16')
					end
				end
				itemInfo = ItemList[fromItemData.name:lower()]
				AddItemToOtherInventory('stash', stashId, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)

				-- PATCH FIX: Forcer la mise à jour de Stashes[stashId].items après mouvement interne
				-- On vérifie d'abord si les fonctions cryptées ont déjà fait le travail
				if Stashes[stashId] and Stashes[stashId].items and savedFromItem then
					-- Vérifier l'état actuel après les appels aux fonctions cryptées
					local currentFromSlot = Stashes[stashId].items[fromSlot]
					local currentToSlot = Stashes[stashId].items[toSlot]

					-- Cas 1: Stacking (même item au slot destination - était présent AVANT)
					if savedToItem and savedToItem.name == savedFromItem.name then
						Stashes[stashId].items[fromSlot] = nil
						local totalAmount = savedFromItem.amount + savedToItem.amount
						savedFromItem.amount = totalAmount
						savedFromItem.count = totalAmount
						Stashes[stashId].items[toSlot] = savedFromItem
						print('[QS-INVENTORY/STASH-STACK] Stacking: slot ' .. fromSlot .. ' -> slot ' .. toSlot .. ' | Total: ' .. totalAmount)

					-- Cas 2: Swap (items différents au slot destination)
					elseif savedToItem and savedToItem.name ~= savedFromItem.name then
						Stashes[stashId].items[fromSlot] = savedToItem
						Stashes[stashId].items[toSlot] = savedFromItem
						print('[QS-INVENTORY/STASH-SWAP] Swap: slot ' .. fromSlot .. ' <-> slot ' .. toSlot)

					-- Cas 3: Mouvement simple (slot destination était vide)
					else
						-- S'assurer que le fromSlot est bien vidé
						Stashes[stashId].items[fromSlot] = nil
						-- Mettre l'item au nouveau slot
						Stashes[stashId].items[toSlot] = savedFromItem
						print('[QS-INVENTORY/STASH-MOVE] Mouvement: slot ' .. fromSlot .. ' -> slot ' .. toSlot .. ' | Item: ' .. savedFromItem.name .. ' x' .. savedFromItem.amount)
					end

					-- Debug: compter les items
					local itemCount = 0
					for _ in pairs(Stashes[stashId].items) do itemCount = itemCount + 1 end
					print('[QS-INVENTORY/STASH] Total items après mouvement: ' .. itemCount)
				end

				SendWebhook(Webhooks.stash, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in stash!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Stash id:** ' .. stashId)
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
		end
	elseif SplitStr(fromInventory, '_')[1] == 'garbage' then
		local garbageId = SplitStr(fromInventory, '_')[2]
		local fromItemData = GarbageItems[garbageId].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = ItemList[fromItemData.name:lower()]
			if toInventory == 'player' or toInventory == 'hotbar' then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveFromGarbage(garbageId, fromSlot, itemInfo['name'], fromAmount)
				SendWebhook(Webhooks.garbage, 'Remove Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') remove item from drop!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Garbage id:** ' .. garbageId)
				if toItemData then
					itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'remove')
							AddToGarbage(garbageId, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'])
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** **' .. toItemData.name .. '\n**Amount:** ' .. toAmount .. '\n**With item:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Garbage id:** ' .. garbageId)
						end
					else
						print('Dupe Blocked - 17')
					end
				end
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'add')
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
			else
				local toItemData = GarbageItems[garbageId].items[toSlot]
				RemoveFromGarbage(garbageId, fromSlot, itemInfo['name'], fromAmount)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							RemoveFromGarbage(garbageId, toSlot, itemInfo['name'], toAmount)
							AddToGarbage(garbageId, fromSlot, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'])
						end
					else
						print('Dupe Blocked - 18')
					end
				end
				itemInfo = ItemList[fromItemData.name:lower()]
				AddToGarbage(garbageId, toSlot, fromSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'])
				SendWebhook(Webhooks.garbage, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in garbage!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Garbage id:** ' .. garbageId)
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
		end
	elseif SplitStr(fromInventory, '-')[1] == 'traphouse' then
		local traphouseId = SplitStr(fromInventory, '-')[2]
		local fromItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, fromSlot)
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = ItemList[fromItemData.name:lower()]
			if toInventory == 'player' or toInventory == 'hotbar' then
				local toItemData = GetItemBySlot(src, toSlot)
				exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo['name'], fromAmount)
				if toItemData then
					itemInfo = ItemList[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'remove')
							exports['qb-traphouse']:AddHouseItem(traphouseId, fromSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. toItemData.name .. '\n**Amount:** ' .. toAmount .. '\n**With item:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Stash id:** ' .. traphouseId)
						end
					else
						print('Dupe Blocked - 19')
					end
				end
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'add')
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
			else
				local toItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, toSlot)
				exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo['name'], fromAmount)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							exports['qb-traphouse']:RemoveHouseItem(traphouseId, toSlot, itemInfo['name'], toAmount)
							exports['qb-traphouse']:AddHouseItem(traphouseId, fromSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'], src)
						end
					else
						print('Dupe Blocked - 20')
					end
				end
				itemInfo = ItemList[fromItemData.name:lower()]
				exports['qb-traphouse']:AddHouseItem(traphouseId, toSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'], src)
				SendWebhook(Webhooks.traphouse, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in traphouse!\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Traphouse id:** ' .. traphouseId)
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
		end
	elseif SplitStr(fromInventory, '-')[1] == 'itemshop' then
		local shopType = SplitStr(fromInventory, '-')[2]
		local shop = RegisteredShops[shopType]
		if not shop or not shop.items then return Error('SetInventoryData', 'Wrong shop setup', 'Shop not found', src, fromSlot) end
		local itemData = shop.items[fromSlot]
		if not itemData or not itemData.name then return Error('SetInventoryData', 'Wrong shop setup', 'Item not found', src, fromSlot) end
		local itemInfo = ItemList[itemData.name:lower()]
		local price = tonumber((itemData.price * fromAmount))
		local money = GetAccountMoney(src, RegisteredShops[shopType].account or 'money')

		if GetResourceState('ps_mdt') == 'started' then
			local isWeapon = SplitStr(itemData.name, '_')[1] == 'weapon'
			local identifier = GetPlayerIdentifier(src)
			local InventoryFolder = 'nui://qs-inventory/html/images/'
			if isWeapon then
				itemData.info.serie = CreateSerialNumber()
				itemData.info.quality = 100
				exports['ps-mdt']:CreateWeaponInfo(itemData.info.serie, InventoryFolder .. itemData.image, itemData.description, GetUserName(identifier), itemData.type, itemData.name)
			end
		end

		if itemData.name == 'tradingcard_psa' then
			itemData.info = {
				serial = CreateSerialNumber(),
			}
		end

		if SplitStr(shopType, '_')[1] == 'Dealer' then
			local isWeapon = SplitStr(itemData.name, '_')[1] == 'weapon'
			if isWeapon then
				price = tonumber(itemData.price)
				if money >= price then
					if NotStoredItems(itemData.name, src, 1) then
						TriggerClientEvent(Config.InventoryPrefix .. ':client:forceCloseInventory', source)
						return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', source, Lang('INVENTORY_NOTIFICATION_CANT_TAKE_MORE') .. ' ' .. itemInfo['label'], 'inform')
					end
					RemoveAccountMoney(src, 'money', price or 0)
					itemData.info.serie = CreateSerialNumber()
					itemData.info.quality = 100
					AddItem(src, itemData.name, 1, toSlot, itemData.info, nil, nil, nil, true)
					TriggerClientEvent('qb-drugs:client:updateDealerItems', src, itemData, 1)
					TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, itemInfo['label'] .. ' ' .. Lang('INVENTORY_NOTIFICATION_BOUGHT'), 'success')
					SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. '** bought a ' .. itemInfo['label'] .. ' for €' .. price)
					if isWeapon then
						TriggerClientEvent(Config.InventoryPrefix .. ':client:forceCloseInventory', src)
					end
				else
					TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
					TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_MONEY'), 'error')
					return
				end
			else
				if money >= price then
					if NotStoredItems(itemData.name, src, fromAmount) then
						TriggerClientEvent(Config.InventoryPrefix .. ':client:forceCloseInventory', source)
						return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', source, Lang('INVENTORY_NOTIFICATION_CANT_TAKE_MORE') .. ' ' .. itemInfo['label'], 'inform')
					end
					RemoveAccountMoney(src, 'money', price or 0)
					AddItem(src, itemData.name, fromAmount, toSlot, itemData.info, nil, nil, nil, true)
					TriggerClientEvent('qb-drugs:client:updateDealerItems', src, itemData, fromAmount)
					TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, itemInfo['label'] .. ' ' .. Lang('INVENTORY_NOTIFICATION_BOUGHT'), 'success')
					SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. '** bought a ' .. itemInfo['label'] .. '  for €' .. price)
				else
					TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
					TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_MONEY'), 'error')
					return
				end
			end
		elseif SplitStr(shopType, '_')[1] == 'Itemshop' then
			if money >= price then
				RemoveAccountMoney(src, RegisteredShops[shopType].account, price or 0)
				local isWeapon = SplitStr(itemData.name, '_')[1] == 'weapon'
				if isWeapon then
					itemData.info.serie = CreateSerialNumber()
					itemData.info.quality = 100
				end
				AddItem(src, itemData.name, fromAmount, toSlot, itemData.info, nil, nil, nil, true)
				TriggerEvent('qb-shops:server:UpdateShopItems', shopType, itemData, fromAmount)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, itemInfo['label'] .. ' ' .. Lang('INVENTORY_NOTIFICATION_BOUGHT'), 'success')
				SendWebhook(Webhooks.bought, 'Shop item bought', 7393279, '**' .. GetPlayerName(src) .. '** bought a ' .. itemInfo['label'] .. ' for €' .. price)
				if isWeapon then
					TriggerClientEvent(Config.InventoryPrefix .. ':client:forceCloseInventory', src)
				end
			else
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_MONEY'), 'error')
				return
			end
		else
			if money >= price then
				RemoveAccountMoney(src, RegisteredShops[shopType].account, price or 0)
				TriggerEvent('qb-shops:server:UpdateShopItems', shopType, itemData, fromAmount)
				AddItem(src, itemData.name, fromAmount, toSlot, itemData.info, nil, nil, nil, true)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, itemInfo['label'] .. ' ' .. Lang('INVENTORY_NOTIFICATION_BOUGHT'), 'success')
				SendWebhook(Webhooks.bought, 'Shop item bought', 7393279, '**' .. GetPlayerName(src) .. '** bought a ' .. itemInfo['label'] .. ' for €' .. price)
			else
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_NO_MONEY'), 'error')
				return
			end
		end
	elseif fromInventory == 'crafting' then
		local itemData = OpenedSecondInventories[src].inventory[fromSlot]

		if hasCraftItems(src, itemData.costs, fromAmount) then
			if not NotStoredItems(itemData.name, src, fromAmount) then
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CraftItems', src, itemData.name, itemData.costs, itemData.points, fromAmount, toSlot, itemData.rep, itemData.time, itemData.chance)
				SendWebhook(Webhooks.crafting, 'Crafting item', 7393279, '**' .. GetPlayerName(src) .. '**\nItem crafted:** ' .. itemData.name .. '\n**Timer:** ' .. itemData.time * fromAmount .. '\n**Amount:** ' .. fromAmount)
				Debug('Started ' .. itemData.name .. ' with a delay time of ' .. itemData.time * fromAmount .. ', quantity ' .. fromAmount)
			else
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_CANT_TAKE_MORE') .. ' ' .. itemData.name, 'inform')
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEMS'), 'error')
		end
	elseif fromInventory == 'customcrafting' then
		local itemData = (CustomCraftingInfos)[fromSlot]
		if hasCraftItems(src, itemData.costs, fromAmount) then
			if not NotStoredItems(itemData.name, src, fromAmount) then
				TriggerClientEvent(Config.InventoryPrefix .. ':client:CraftItems', src, itemData.name, itemData.costs, itemData.points, fromAmount, toSlot, itemData.rep, itemData.time, itemData.chance)
			else
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_CANT_TAKE_MORE') .. ' ' .. itemData.name, 'inform')
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
			TriggerClientEvent('qs-inventory:sendMessage', src, Lang('CRAFTING_ERROR'), 'error')
		end
	else
		-- drop
		fromInventoryFormatter = SplitStr(fromInventory, '-')[2]
		fromInventory = tonumber(fromInventoryFormatter)
		local fromItemData = Drops[fromInventory].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = ItemList[fromItemData.name:lower()]
			if toInventory == 'player' or toInventory == 'hotbar' then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveFromDrop(fromInventory, fromSlot, itemInfo['name'], fromAmount)
				SendWebhook(Webhooks.drop, 'Remove Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') remove item from drop!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Drop id:** ' .. fromInventory)
				if toItemData then
					toAmount = tonumber(toAmount) and tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							RemoveItem(src, toItemData.name, toAmount, toSlot, nil, true)
							TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, toItemData, toAmount, 'remove')
							AddToDrop(fromInventory, toSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'])
							SendWebhook(Webhooks.swap, 'Swapped Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') swapped item!**\n**Name:** ' .. toItemData.name .. '\n**Amount:** ' .. toAmount .. '\n**With item:** ' .. fromItemData.name .. '\n**Amount:** ' .. fromAmount .. '\n**Dropid:** ' .. fromInventory)
							if itemInfo['name'] == 'radio' then
								TriggerClientEvent('Radio.Set', src, false)
							elseif itemInfo['name'] == 'money' and Config.Framework == 'esx' then
								local money = GetItemTotalAmount(src, 'money')
								Player.setAccountMoney('money', money, 'dropped')
							elseif itemInfo['name'] == 'black_money' and Config.Framework == 'esx' then
								local money = GetItemTotalAmount(src, 'black_money')
								Player.setAccountMoney('black_money', money, 'dropped')
							end
							TriggerClientEvent(Config.InventoryPrefix .. ':ClearWeapons', src)
						end
					else
						print('Dupe Blocked - 21')
					end
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, nil, fromItemData['created'], nil, true)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, fromItemData, fromAmount, 'add')
			else
				toInventoryFormatter = SplitStr(toInventory, '-')[2]
				toInventory = tonumber(toInventoryFormatter)
				local toItemData = Drops[toInventory].items[toSlot]
				RemoveFromDrop(fromInventory, fromSlot, itemInfo['name'], fromAmount)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.amount >= toAmount then
						if toItemData.name ~= fromItemData.name then
							itemInfo = ItemList[toItemData.name:lower()]
							RemoveFromDrop(toInventory, toSlot, itemInfo['name'], toAmount)
							AddToDrop(fromInventory, fromSlot, itemInfo['name'], toAmount, toItemData.info, fromItemData['created'])
							if itemInfo['name'] == 'radio' then
								TriggerClientEvent('Radio.Set', src, false)
							elseif itemInfo['name'] == 'money' and Config.Framework == 'esx' then
								local money = GetItemTotalAmount(src, 'money')
								Player.setAccountMoney('money', money, 'dropped')
							elseif itemInfo['name'] == 'black_money' and Config.Framework == 'esx' then
								local money = GetItemTotalAmount(src, 'black_money')
								Player.setAccountMoney('black_money', money, 'dropped')
							end
							TriggerClientEvent(Config.InventoryPrefix .. ':ClearWeapons', src)
						end
					else
						print('Dupe Blocked - 22')
					end
				end
				itemInfo = ItemList[fromItemData.name:lower()]
				AddToDrop(toInventory, toSlot, itemInfo['name'], fromAmount, fromItemData.info, fromItemData['created'])
				SendWebhook(Webhooks.drop, 'Deposit Item', 7393279, '**' .. GetPlayerName(src) .. ' (id: ' .. src .. ') deposit item in drop!**\n**Name:** ' .. itemInfo['name'] .. '\n**Amount:** ' .. fromAmount .. '\n**Drop id:** ' .. toInventory)
				if itemInfo['name'] == 'radio' then
					TriggerClientEvent('Radio.Set', src, false)
				elseif itemInfo['name'] == 'money' and Config.Framework == 'esx' then
					local money = GetItemTotalAmount(src, 'money')
					Player.setAccountMoney('money', money, 'dropped')
				elseif itemInfo['name'] == 'black_money' and Config.Framework == 'esx' then
					local money = GetItemTotalAmount(src, 'black_money')
					Player.setAccountMoney('black_money', money, 'dropped')
				end
				TriggerClientEvent(Config.InventoryPrefix .. ':ClearWeapons', src)
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_MISSING_ITEM'), 'error')
		end
	end
end)

-- In the future we will be use this. (In the W.I.P)

-- local function updateToItemData(src, inventoryType, toSlot, toAmount, fromItemData)
-- 	local toItemData = GetItemBySlot(src, toSlot)
-- 	if not toItemData then
-- 		Error('The player is trying to move an item that does not exist', src, 'inventoryType:', inventoryType, 'toSlot:', toSlot)
-- 		return false
-- 	end
-- 	toAmount = tonumber(toAmount) or toItemData.amount
-- 	if toItemData.amount < toAmount then
-- 		Error('The player is trying to move an item but the item does not have enough amount', src, 'toItemData:', toItemData, 'toAmount:', toAmount)
-- 		return false
-- 	end
-- 	if toItemData.name == fromItemData.name then
-- 		Error('The player is trying to move the same item', src, 'toItemData:', toItemData, 'fromItemData:', fromItemData)
-- 		return false
-- 	end
-- end

-- function SetInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount, fromInventoryIsClothesInventory, toInventoryIsClothesInventory, craftingKey)
-- 	local src = source
-- 	local player = GetPlayerFromId(src)
-- 	fromSlot = tonumber(fromSlot)
-- 	toSlot = tonumber(toSlot)
-- 	if not fromSlot or not toSlot then return Error('SetInventoryData', 'fromSlot or toSlot is nil', src) end
-- 	local identifier = GetPlayerIdentifier(src)
-- 	if not identifier then return Error('SetInventoryData', 'Identifier is nil', src) end
-- 	if (fromInventory == 'player' or fromInventory == 'hotbar') and (SplitStr(toInventory, '-')[1] == 'itemshop' or toInventory == 'crafting' or toInventory == 'customcrafting') then
-- 		return Debug('SetInventoryData', 'Player', 'ItemShop', 'Crafting', src)
-- 	end

-- 	if fromInventoryIsClothesInventory and toInventoryIsClothesInventory then
-- 		return Debug('SetInventoryData', 'Clothing', 'Clothing', src)
-- 	end

-- 	if (SplitStr(fromInventory, '-')[1] == 'selling') then
-- 		return Debug('SetInventoryData', 'Selling', src)
-- 	end

-- 	if fromInventoryIsClothesInventory then
-- 		return RemoveClotheFromInventoryData(src, fromSlot, toSlot, identifier)
-- 	elseif toInventoryIsClothesInventory then
-- 		return AddClotheFromInventoryData(src, fromSlot, identifier)
-- 	end


-- 	local toInventorySplitted = SplitStr(toInventory, '-')[1]
-- 	if toInventorySplitted == 'selling' then
-- 		return SellItemToSelling(src, fromInventory, fromSlot, fromAmount, toInventory, toSlot)
-- 	end

-- 	if fromInventory == 'player' or fromInventory == 'hotbar' then
-- 		local fromItemData = GetItemBySlot(src, fromSlot)
-- 		fromAmount = tonumber(fromAmount) or fromItemData.amount
-- 		if not fromItemData or fromItemData.amount < fromAmount then
-- 			Error('The player is trying to move an item that does not exist or does not have enough amount', fromItemData, fromAmount)
-- 			Notification(src, Lang('INVENTORY_NOTIFICATION_GIVE_DONT_HAVE'), 'error')
-- 			return
-- 		end
-- 		local success = RemoveItem(src, fromItemData.name, fromAmount, fromSlot, nil, true)
-- 		if not success then
-- 			Error('The player is trying to move an item but remove item function return false', fromItemData, fromAmount, fromSlot)
-- 			Notification(src, Lang('INVENTORY_NOTIFICATION_GIVE_DONT_HAVE'), 'error')
-- 			return
-- 		end
-- 		TriggerClientEvent(Config.InventoryPrefix .. ':client:CheckWeapon', src, fromItemData.name)
-- 	end
-- end
