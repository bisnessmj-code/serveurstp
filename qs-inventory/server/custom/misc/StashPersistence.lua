-- =====================================================
-- QS-INVENTORY PATCH - Persistance des Stash
-- =====================================================
-- Ce fichier implémente les fonctions pour la sauvegarde
-- et le chargement des stash depuis la BDD MySQL
-- Compatible avec le format qs-inventory
-- =====================================================

print('[QS-INVENTORY/STASH] Chargement du module de persistance...')

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

-- Fonction utilitaire pour compter les éléments d'une table
if not table.length then
    function table.length(T)
        local count = 0
        if T and type(T) == 'table' then
            for _ in pairs(T) do
                count = count + 1
            end
        end
        return count
    end
end

-- =====================================================
-- SAUVEGARDE DES STASH
-- =====================================================

---Sauvegarde les items d'un stash en BDD
---@param stashId string L'ID du stash
---@param items table Les items à sauvegarder (format: {[slot] = itemData})
function SaveStashItems(stashId, items)
    if not stashId then
        print('[QS-INVENTORY/STASH] ERREUR SaveStashItems: stashId manquant')
        return
    end

    print('[QS-INVENTORY/STASH] ========================================')
    print('[QS-INVENTORY/STASH] Sauvegarde du stash: ' .. stashId)

    -- Convertir les items au format JSON compatible
    -- qs-inventory utilise des slots numériques comme clés
    local itemsToSave = {}
    local itemCount = 0

    if items and type(items) == 'table' then
        for slot, item in pairs(items) do
            if item and type(item) == 'table' and item.name then
                -- S'assurer que le slot est un nombre
                local slotNum = tonumber(slot) or slot
                itemsToSave[tostring(slotNum)] = {
                    name = item.name,
                    amount = item.amount or item.count or 1,
                    count = item.count or item.amount or 1,
                    slot = slotNum,
                    type = item.type or 'item',
                    weight = item.weight or 0,
                    label = item.label or item.name,
                    description = item.description or '',
                    image = item.image or (item.name .. '.png'),
                    unique = item.unique or false,
                    useable = item.useable or true,
                    info = item.info or {},
                    created = item.created or os.time(),
                    rare = item.rare or 'common'
                }
                itemCount = itemCount + 1
                -- Debug: afficher chaque item sauvegardé
                print('[QS-INVENTORY/STASH]   Slot ' .. slotNum .. ': ' .. item.name .. ' x' .. (item.amount or item.count or 1))
            elseif item and type(item) == 'table' then
                -- Item malformé - log pour debug
                print('[QS-INVENTORY/STASH] WARN: Item ignoré au slot ' .. tostring(slot) .. ' - pas de name (type: ' .. type(item.name) .. ')')
            elseif item ~= nil then
                -- Valeur non-table dans un slot
                print('[QS-INVENTORY/STASH] WARN: Valeur non-table au slot ' .. tostring(slot) .. ' (type: ' .. type(item) .. ')')
            end
        end
    else
        print('[QS-INVENTORY/STASH] WARN: items est nil ou pas une table!')
    end

    local itemsJson = json.encode(itemsToSave)

    print('[QS-INVENTORY/STASH] Total items à sauvegarder: ' .. itemCount)
    print('[QS-INVENTORY/STASH] ========================================')

    -- Utiliser INSERT ... ON DUPLICATE KEY UPDATE pour upsert
    MySQL.Async.execute([[
        INSERT INTO stash_items (stash, items)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE items = VALUES(items)
    ]], {stashId, itemsJson}, function(rowsChanged)
        if rowsChanged then
            print('[QS-INVENTORY/STASH] Stash sauvegardé: ' .. stashId .. ' (' .. itemCount .. ' items)')
        else
            print('[QS-INVENTORY/STASH] ERREUR lors de la sauvegarde de: ' .. stashId)
        end
    end)
end

-- =====================================================
-- CHARGEMENT DES STASH
-- =====================================================

---Charge les items d'un stash depuis la BDD (fonction synchrone)
---@param stashId string L'ID du stash
---@return table items Les items chargés (format: {[slot] = itemData})
function GetStashItems(stashId)
    if not stashId then
        print('[QS-INVENTORY/STASH] ERREUR GetStashItems: stashId manquant')
        return {}
    end

    print('[QS-INVENTORY/STASH] Chargement du stash: ' .. stashId)

    -- Requête synchrone pour charger les items
    local result = MySQL.Sync.fetchAll('SELECT items FROM stash_items WHERE stash = ?', {stashId})

    if result and result[1] and result[1].items then
        local itemsJson = result[1].items
        local itemsRaw = json.decode(itemsJson)

        if itemsRaw and type(itemsRaw) == 'table' then
            local items = {}
            local itemCount = 0

            -- Gérer les deux formats possibles:
            -- Format 1 (array): [{"slot":1,"name":"..."}, {"slot":2,"name":"..."}]
            -- Format 2 (object): {"1":{"name":"..."}, "2":{"name":"..."}}

            -- IMPORTANT: Toujours utiliser pairs() car les slots peuvent être non-consécutifs
            -- ipairs() s'arrête au premier nil, causant la perte des items après un slot vide
            for slot, item in pairs(itemsRaw) do
                if item and type(item) == 'table' and item.name then
                    local slotNum = tonumber(slot) or slot
                    items[slotNum] = item
                    -- S'assurer que le slot est défini dans l'item
                    items[slotNum].slot = slotNum
                    itemCount = itemCount + 1
                elseif item and type(item) == 'table' and item.slot and not item.name then
                    -- Cas où l'item a un slot mais pas de name (format array avec slot dans l'item)
                    print('[QS-INVENTORY/STASH] WARN: Item sans name au slot ' .. tostring(slot) .. ' - ignoré')
                end
            end

            print('[QS-INVENTORY/STASH] Stash chargé: ' .. stashId .. ' (' .. itemCount .. ' items)')
            return items
        end
    end

    print('[QS-INVENTORY/STASH] Stash vide ou inexistant: ' .. stashId)
    return {}
end

-- =====================================================
-- FONCTION GÉNÉRIQUE POUR TOUS LES TYPES D'INVENTAIRE
-- =====================================================

---Charge les items d'un inventaire selon son type
---@param invType string Le type d'inventaire ('stash', 'trunk', 'glovebox')
---@param id string L'ID de l'inventaire
---@return table items Les items chargés
function GetOtherInventoryItems(invType, id)
    if invType == 'stash' then
        return GetStashItems(id)
    elseif invType == 'trunk' then
        return GetTrunkItems(id)
    elseif invType == 'glovebox' then
        return GetGloveboxItems(id)
    end
    return {}
end

-- =====================================================
-- FONCTIONS POUR TRUNK ET GLOVEBOX (placeholder)
-- =====================================================

---Charge les items d'un trunk depuis la BDD
---@param trunkId string L'ID du trunk
---@return table items Les items chargés
function GetTrunkItems(trunkId)
    -- Utilise la table owned_vehicles ou vehicle_trunk selon votre config
    local result = MySQL.Sync.fetchAll('SELECT items FROM owned_vehicles WHERE plate = ?', {trunkId})
    if result and result[1] and result[1].items then
        local items = json.decode(result[1].items)
        if items then return items end
    end
    return {}
end

---Charge les items d'une glovebox depuis la BDD
---@param gloveboxId string L'ID de la glovebox
---@return table items Les items chargés
function GetGloveboxItems(gloveboxId)
    -- Utilise la table owned_vehicles ou glovebox selon votre config
    local result = MySQL.Sync.fetchAll('SELECT glovebox FROM owned_vehicles WHERE plate = ?', {gloveboxId})
    if result and result[1] and result[1].glovebox then
        local items = json.decode(result[1].glovebox)
        if items then return items end
    end
    return {}
end

---Sauvegarde les items d'un trunk
---@param trunkId string L'ID du trunk
---@param items table Les items à sauvegarder
function SaveOwnedVehicleItems(trunkId, items)
    if not trunkId then return end
    local itemsJson = json.encode(items or {})
    MySQL.Async.execute('UPDATE owned_vehicles SET items = ? WHERE plate = ?', {itemsJson, trunkId})
end

---Sauvegarde les items d'une glovebox
---@param gloveboxId string L'ID de la glovebox
---@param items table Les items à sauvegarder
function SaveOwnedGloveboxItems(gloveboxId, items)
    if not gloveboxId then return end
    local itemsJson = json.encode(items or {})
    MySQL.Async.execute('UPDATE owned_vehicles SET glovebox = ? WHERE plate = ?', {itemsJson, gloveboxId})
end

-- =====================================================
-- TRACK DES STASH OUVERTS
-- =====================================================
-- Important: Ces variables et fonctions doivent être définies ici
-- car StashPersistence.lua est chargé avant les autres fichiers

-- Track des stash ouverts par joueur: {[source] = stashId}
OpenStashByPlayer = OpenStashByPlayer or {}

-- Fonction pour enregistrer qu'un joueur a ouvert un stash
function RegisterOpenStash(src, stashId)
	OpenStashByPlayer[src] = stashId
	print('[QS-INVENTORY/STASH] Stash enregistré pour joueur ' .. src .. ': ' .. stashId)
end

-- Fonction pour obtenir le stash ouvert d'un joueur
function GetOpenStash(src)
	return OpenStashByPlayer[src]
end

-- Fonction pour fermer le stash d'un joueur
function CloseOpenStash(src)
	local stashId = OpenStashByPlayer[src]
	if stashId then
		OpenStashByPlayer[src] = nil
		return stashId
	end
	return nil
end

print('[QS-INVENTORY/STASH] Module de persistance chargé avec succès')
