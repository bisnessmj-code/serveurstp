local function getFirstItemInDrop(dropId)
	local drop = Drops[dropId]
	if drop and drop.items then
		for k, v in pairs(drop.items) do
			return v
		end
	end
	return nil
end

function TimeoutFunction(wait, fn)
	CreateThread(function()
		Wait(wait)
		fn()
	end)
end

function SaveOtherInventories()
	for inventoryName, inventory in pairs(UpdatedInventories) do
		for id, updated in pairs(inventory) do
			if updated then
				SaveOtherInventory(inventoryName, id)
				UpdatedInventories[inventoryName][id] = nil
			end
		end
	end
end

---@param inventoryName OtherInventoryTypes
---@param id string
function SaveOtherInventory(inventoryName, id)
	Debug('SaveOtherInventory', inventoryName, id)
	if inventoryName == 'stash' then
		SaveStashItems(id, Stashes[id].items)
	elseif inventoryName == 'trunk' then
		SaveOwnedVehicleItems(id, Trunks[id].items)
	elseif inventoryName == 'glovebox' then
		SaveOwnedGloveboxItems(id, Gloveboxes[id].items)
	elseif inventoryName == 'clothes' then
		local src = GetPlayerSourceFromIdentifier(id)
		if not src then
			Error('SaveOtherInventory', 'Player not found', id, 'inventoryName', inventoryName)
			return
		end
		SaveClotheItems(id, GetClotheItems(src))
	end
end

function HandleCloseSecondInventories(src, type, id)
	local IsVehicleOwned = IsVehicleOwned(id)
	Debug('HandleSaveSecondInventories', src, type, id, IsVehicleOwned)
	print('[QS-INVENTORY/SAVE] HandleCloseSecondInventories appelé - type: ' .. tostring(type) .. ' | id: ' .. tostring(id) .. ' | src: ' .. tostring(src))
	if type == 'trunk' then
		if not Trunks[id] then
			Debug('Trunk id not found', id)
			return
		end
		if IsVehicleOwned then
			SaveOwnedVehicleItems(id, Trunks[id].items)
		else
			Trunks[id].isOpen = false
		end
	elseif type == 'glovebox' then
		if not Gloveboxes[id] then return end
		if IsVehicleOwned then
			SaveOwnedGloveboxItems(id, Gloveboxes[id].items)
		else
			Gloveboxes[id].isOpen = false
		end
	elseif type == 'stash' then
		print('[QS-INVENTORY/SAVE] Type stash détecté - id: ' .. tostring(id))
		if not Stashes[id] then
			print('[QS-INVENTORY/SAVE] ERREUR: Stashes[' .. tostring(id) .. '] n\'existe pas!')
			return
		end
		print('[QS-INVENTORY/SAVE] Stashes[' .. tostring(id) .. '] trouvé, items: ' .. tostring(Stashes[id].items ~= nil))
		SaveStashItems(id, Stashes[id].items)
		Stashes[id].isOpen = false -- IMPORTANT: Libérer le stash pour pouvoir le rouvrir
		print('[QS-INVENTORY/SAVE] Stash libéré (isOpen = false)')
	elseif type == 'drop' then
		if Drops[id] then
			Drops[id].isOpen = false
			if Drops[id].items == nil or next(Drops[id].items) == nil then
				Drops[id] = nil
				TimeoutFunction(500, function()
					TriggerClientEvent(Config.InventoryPrefix .. ':client:RemoveDropItem', -1, id)
				end)
			else
				local dropItemsCount = table.length(Drops[id].items)
				local firstItem = getFirstItemInDrop(id)
				local dropObject = Config.ItemDropObject
				if firstItem then
					dropObject = dropItemsCount == 1 and ItemList[firstItem.name:lower()].object or Config.ItemDropObject
				end
				TimeoutFunction(500, function()
					TriggerClientEvent(Config.InventoryPrefix .. ':updateDropItems', -1, id, dropObject, dropItemsCount == 1 and firstItem or nil)
				end)
			end
		end
	elseif type == 'clothing' and Config.Clothing then
		local identifier = GetPlayerIdentifier(src)
		local clotheItems = GetClotheItems(src)
		if not clotheItems then return end
		SaveClotheItems(identifier, clotheItems)
	end
end

-- Fonction pour sauvegarder et fermer le stash d'un joueur
-- (OpenStashByPlayer et RegisterOpenStash sont définis dans StashPersistence.lua)
local function SaveAndClosePlayerStash(src)
	local stashId = GetOpenStash(src)
	if stashId and Stashes and Stashes[stashId] then
		print('[QS-INVENTORY/SAVE] ========================================')
		print('[QS-INVENTORY/SAVE] Fermeture du stash: ' .. stashId .. ' par joueur ' .. src)

		-- Debug: Afficher l'état de Stashes[stashId].items AVANT sauvegarde
		local itemCount = 0
		if Stashes[stashId].items then
			for slot, item in pairs(Stashes[stashId].items) do
				if item and item.name then
					itemCount = itemCount + 1
					print('[QS-INVENTORY/SAVE]   [AVANT] Slot ' .. tostring(slot) .. ': ' .. item.name .. ' x' .. (item.amount or item.count or 1))
				end
			end
		end
		print('[QS-INVENTORY/SAVE] Total items dans Stashes[stashId].items: ' .. itemCount)

		SaveStashItems(stashId, Stashes[stashId].items)
		Stashes[stashId].isOpen = false
		CloseOpenStash(src)
		print('[QS-INVENTORY/SAVE] Stash sauvegardé et libéré: ' .. stashId)
		print('[QS-INVENTORY/SAVE] ========================================')
	elseif stashId then
		print('[QS-INVENTORY/SAVE] WARN: Stash ' .. stashId .. ' introuvable dans Stashes')
		CloseOpenStash(src)
	end
end

RegisterNetEvent(Config.InventoryPrefix .. ':server:handleInventoryClosed', function(type, id)
	local src = source
	print('[QS-INVENTORY/SAVE] EVENT handleInventoryClosed reçu - type: ' .. tostring(type) .. ' | id: ' .. tostring(id))

	-- IMPORTANT: Si ce joueur avait un stash ouvert, le sauvegarder
	-- (car qs-inventory envoie parfois le mauvais type)
	if GetOpenStash and GetOpenStash(src) then
		SaveAndClosePlayerStash(src)
	end

	HandleCloseSecondInventories(src, type, id)
	UpdateFrameworkInventory(src, Inventories[src])
end)

-- Sauvegarder le stash si le joueur se déconnecte
AddEventHandler('playerDropped', function(reason)
	local src = source
	if GetOpenStash and GetOpenStash(src) then
		print('[QS-INVENTORY/SAVE] Joueur ' .. src .. ' déconnecté, sauvegarde du stash...')
		SaveAndClosePlayerStash(src)
	end
end)

-- AddEventHandler('onResourceStop', function(resource)
-- 	if resource == GetCurrentResourceName() then
-- 		SaveOtherInventories()
-- 	end
-- end)

-- RegisterCommand('save-inventories', function(source, args)
-- 	if source ~= 0 then
-- 		return Error(source, 'This command can use only by console')
-- 	end
-- 	SaveOtherInventories()
-- end)

-- CreateThread(function()
-- 	while true do
-- 		Wait(Config.SaveInventoryInterval)
-- 		SaveOtherInventories()
-- 	end
-- end)
