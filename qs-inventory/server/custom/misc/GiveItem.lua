local function TransferMoney(itemName, source, target)
	if Config.Framework ~= 'esx' then return end
	if itemName ~= 'money' and itemName ~= 'black_money' then return end

	local Player = GetPlayerFromId(source)
	local money = GetItemTotalAmount(source, itemName)
	Player.setAccountMoney(itemName, money, 'dropped')

	local targetPlayer = GetPlayerFromId(target)
	local targetMoney = GetItemTotalAmount(target, itemName)
	targetPlayer.setAccountMoney(itemName, targetMoney, 'dropped')

	local itemType = (itemName == 'money') and 'Money' or 'Black money'
	Debug(itemType .. ' sent by src: ' .. json.encode(money) .. ', target: ' .. json.encode(targetMoney))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CVC CONVOY - Blocage du transfert d'armes pendant le mode CVC
-- ═══════════════════════════════════════════════════════════════════════════
local function IsCVCBlockedItem(itemName)
	-- Liste des armes et munitions CVC bloquées
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

local function IsPlayerInCVCMode(playerId)
	-- Vérifier si le resource cvc_convoy est démarré et si le joueur est dans le mode
	if GetResourceState('cvc_convoy') == 'started' then
		local inMode = exports['cvc_convoy']:IsPlayerInMode(playerId)
		return inMode == true
	end
	return false
end
-- ═══════════════════════════════════════════════════════════════════════════

RegisterServerEvent(Config.InventoryPrefix .. ':server:GiveItem', function(target, name, amount, slot)
	local src = source
	target = tonumber(target)
	local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target)))

	-- CVC CONVOY: Bloquer le transfert d'armes/munitions pendant le mode CVC
	if IsPlayerInCVCMode(src) and IsCVCBlockedItem(name) then
		return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, '~r~Vous ne pouvez pas donner vos armes/munitions pendant le mode CVC', 'error')
	end

	if src == target then return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_CANT_GIVE'), 'error') end
	if dist > 2 then return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_GIVE_FAR'), 'error') end
	local item = GetItemBySlot(src, slot)
	if not item then
		TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_GIVE_NOT_FOUND'), 'error')
		return
	end
	if item.name ~= name then
		TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_GIVE_INCORRECT'), 'error')
		return
	end

	if not amount then
		return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_TRADE_EMPTY_INPUT'), 'error')
	end

	if amount <= item.amount then
		if amount == 0 then
			amount = item.amount
		end

		if NotStoredItems(item.name, target, amount) then
			TriggerClientEvent(Config.InventoryPrefix .. ':client:forceCloseInventory', src)
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_CANT_TAKE_MORE_OTHER') .. ' ' .. item.name, 'inform')
			return TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', target, Lang('INVENTORY_NOTIFICATION_CANT_TAKE_MORE') .. ' ' .. item.name, 'inform')
		end

		if RemoveItem(src, item.name, amount, item.slot) then
			if AddItem(target, item.name, amount, false, item.info, nil, item.created) then
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', target, Lang('INVENTORY_NOTIFICATION_GIVE_RECEIVED') .. ' ' .. amount .. ' ' .. item.label, 'inform')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', target, true)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_GAVE') .. ' ' .. amount .. ' ' .. item.label, 'inform')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, true)
				local itemObject = ItemList[item.name:lower()].object or Config.ItemDropObject
				TriggerClientEvent(Config.InventoryPrefix .. ':client:giveAnim', src, itemObject)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:giveAnim', target)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:closeinv', target)
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', src, item, amount, 'remove')
				TriggerEvent(Config.InventoryPrefix .. ':server:updateCash', target, item, amount, 'add')
				TransferMoney(item.name, src, target)
				SendWebhook(Webhooks.giveitem, 'Give Item To Player (Trade)', 7393279, '**' .. GetPlayerName(src) .. '(id: ' .. src .. ') sent a item to player: ' .. target .. '!**\nName:** ' .. item.name .. '**\nAmount:** ' .. amount)
			else
				AddItem(src, item.name, amount, item.slot, item.info, nil, item.created)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_OTHER_INVENTORY_FULL'), 'error')
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', src, false)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:UpdatePlayerInventory', target, false)
				TriggerClientEvent(Config.InventoryPrefix .. ':client:closeinv', target)
			end
		else
			TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_INVALID_AMOUNT'), 'error')
		end
	else
		TriggerClientEvent(Config.InventoryPrefix .. ':client:sendTextMessage', src, Lang('INVENTORY_NOTIFICATION_INVALID_AMOUNT'), 'error')
	end
end)
