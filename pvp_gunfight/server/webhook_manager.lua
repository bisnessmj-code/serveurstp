-- ========================================
-- PVP GUNFIGHT - WEBHOOK MANAGER SÉCURISÉ
-- Version 1.0.2 - FIX LUA 5.4 + PERMISSIONS ESX
-- ========================================

DebugServer('Module Webhook Manager charge')

-- ========================================
-- CONFIGURATION
-- ========================================
local WEBHOOK_KEY = GetConvar('gfranked_webhook_key', '')
local WEBHOOK_CACHE = {}
local CACHE_DURATION = 300000 -- 5 minutes

-- ========================================
-- 🔧 FONCTION: VÉRIFIER PERMISSIONS ADMIN ESX
-- ========================================
local function IsAdmin(source)
    if source == 0 then
        return true -- Console = admin
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end
    
    local group = xPlayer.getGroup()
    
    -- Liste des groupes admin autorisés
    local adminGroups = {
        ['admin'] = true,
        ['superadmin'] = true,
        ['_superadmin'] = true,
        ['owner'] = true,
        ['fondateur'] = true
    }
    
    return adminGroups[group] == true
end

-- Configuration
local DISCORD_CONFIG = {
    defaultAvatar = Config.Discord.defaultAvatar or 'https://cdn.discordapp.com/embed/avatars/0.png',
    avatarSize = Config.Discord.avatarSize or 128,
    avatarFormat = Config.Discord.avatarFormat or 'png'
}

-- ========================================
-- 🔧 SYSTÈME DE CHIFFREMENT XOR (LUA 5.4)
-- ========================================
local function XORCipher(data, key)
    if not data or data == '' then return '' end
    if not key or key == '' then 
        print('^1[WEBHOOK ERROR] Clé de chiffrement manquante!^0')
        return data 
    end
    
    local result = {}
    local keyLen = #key
    
    for i = 1, #data do
        local dataByte = string.byte(data, i)
        local keyByte = string.byte(key, ((i - 1) % keyLen) + 1)
        -- 🔧 FIX LUA 5.4: Utiliser l'opérateur ~ au lieu de bit.bxor
        result[i] = string.char(dataByte ~ keyByte)
    end
    
    return table.concat(result)
end

-- Encoder en Base64 (pour stockage sûr)
local function Base64Encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do 
            r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') 
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do 
            c = c + (x:sub(i, i) == '1' and 2^(6 - i) or 0) 
        end
        return b:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- Décoder depuis Base64
local function Base64Decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do 
            r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') 
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do 
            c = c + (x:sub(i, i) == '1' and 2^(8 - i) or 0) 
        end
        return string.char(c)
    end))
end

-- ========================================
-- FONCTIONS DE CHIFFREMENT/DÉCHIFFREMENT
-- ========================================
local function EncryptWebhook(url)
    if not url or url == '' then return '' end
    
    local encrypted = XORCipher(url, WEBHOOK_KEY)
    local encoded = Base64Encode(encrypted)
    
    return encoded
end

local function DecryptWebhook(encoded)
    if not encoded or encoded == '' then return nil end
    
    local success, decoded = pcall(Base64Decode, encoded)
    if not success then
        print('^1[WEBHOOK ERROR] Échec décodage Base64^0')
        return nil
    end
    
    local decrypted = XORCipher(decoded, WEBHOOK_KEY)
    
    return decrypted
end

-- ========================================
-- VALIDATION WEBHOOK
-- ========================================
local function ValidateWebhookURL(url)
    if not url or url == '' then return false end
    
    -- Vérifier format Discord webhook
    local pattern = "^https://discord%.com/api/webhooks/%d+/[%w%-_]+$"
    
    if not string.match(url, pattern) then
        return false
    end
    
    return true
end

local function MaskWebhookURL(url)
    if not url or url == '' then return 'Non configuré' end
    
    -- Masquer tout sauf les 10 derniers caractères
    if #url <= 20 then
        return string.rep('*', #url - 5) .. url:sub(-5)
    end
    
    return 'https://discord.com/api/webhooks/****/' .. url:sub(-10)
end

-- ========================================
-- GESTION BASE DE DONNÉES
-- ========================================
local function SaveWebhookToDB(mode, url, adminIdentifier, callback)
    local encrypted = EncryptWebhook(url)
    
    MySQL.single('SELECT id FROM pvp_webhooks WHERE mode = ?', {mode}, function(result)
        if result then
            -- Mise à jour
            MySQL.update('UPDATE pvp_webhooks SET webhook_url = ?, updated_by = ? WHERE mode = ?',
                {encrypted, adminIdentifier, mode}, function(affectedRows)
                    if affectedRows > 0 then
                        WEBHOOK_CACHE[mode] = {url = url, timestamp = GetGameTimer()}
                        print('^2[WEBHOOK] Webhook ' .. mode .. ' mis à jour avec succès^0')
                        callback(true)
                    else
                        print('^1[WEBHOOK ERROR] Échec mise à jour webhook ' .. mode .. '^0')
                        callback(false)
                    end
                end)
        else
            -- Insertion
            MySQL.insert('INSERT INTO pvp_webhooks (mode, webhook_url, updated_by) VALUES (?, ?, ?)',
                {mode, encrypted, adminIdentifier}, function(insertId)
                    if insertId then
                        WEBHOOK_CACHE[mode] = {url = url, timestamp = GetGameTimer()}
                        print('^2[WEBHOOK] Webhook ' .. mode .. ' créé avec succès^0')
                        callback(true)
                    else
                        print('^1[WEBHOOK ERROR] Échec création webhook ' .. mode .. '^0')
                        callback(false)
                    end
                end)
        end
    end)
end

local function LoadWebhookFromDB(mode, callback)
    -- Vérifier cache
    local cached = WEBHOOK_CACHE[mode]
    if cached and (GetGameTimer() - cached.timestamp) < CACHE_DURATION then
        callback(cached.url)
        return
    end
    
    MySQL.single('SELECT webhook_url FROM pvp_webhooks WHERE mode = ?', {mode}, function(result)
        if result and result.webhook_url then
            local decrypted = DecryptWebhook(result.webhook_url)
            
            if decrypted and ValidateWebhookURL(decrypted) then
                WEBHOOK_CACHE[mode] = {url = decrypted, timestamp = GetGameTimer()}
                callback(decrypted)
            else
                print('^1[WEBHOOK ERROR] Webhook ' .. mode .. ' corrompu ou invalide^0')
                callback(nil)
            end
        else
            callback(nil)
        end
    end)
end

local function DeleteWebhookFromDB(mode, callback)
    MySQL.update('DELETE FROM pvp_webhooks WHERE mode = ?', {mode}, function(affectedRows)
        if affectedRows > 0 then
            WEBHOOK_CACHE[mode] = nil
            print('^2[WEBHOOK] Webhook ' .. mode .. ' supprimé^0')
            callback(true)
        else
            print('^3[WEBHOOK] Aucun webhook ' .. mode .. ' à supprimer^0')
            callback(false)
        end
    end)
end

local function GetAllWebhooksFromDB(callback)
    MySQL.query('SELECT mode, webhook_url, updated_at, updated_by FROM pvp_webhooks ORDER BY FIELD(mode, "1v1", "2v2", "3v3", "4v4")', {}, function(results)
        local webhooks = {}
        
        if results then
            for i = 1, #results do
                local row = results[i]
                local decrypted = DecryptWebhook(row.webhook_url)
                
                webhooks[#webhooks + 1] = {
                    mode = row.mode,
                    url = decrypted,
                    masked = MaskWebhookURL(decrypted),
                    updated_at = row.updated_at,
                    updated_by = row.updated_by
                }
            end
        end
        
        callback(webhooks)
    end)
end

-- ========================================
-- COMMANDES ADMIN
-- ========================================

-- Commande : Définir un webhook
RegisterCommand('gfrankedsetwebhook', function(source, args)
    if source == 0 then
        print('^1[WEBHOOK] Cette commande doit être exécutée in-game^0')
        return
    end
    
    if not IsAdmin(source) then
        TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        TriggerClientEvent('esx:showNotification', source, '~y~Vous devez être admin ESX')
        return
    end
    
    if WEBHOOK_KEY == '' then
        TriggerClientEvent('esx:showNotification', source, '~r~Erreur: Clé de chiffrement manquante dans server.cfg!')
        print('^1[WEBHOOK ERROR] Clé gfranked_webhook_key manquante dans server.cfg^0')
        return
    end
    
    local mode = args[1]
    local url = args[2]
    
    if not mode or not url then
        TriggerClientEvent('esx:showNotification', source, '~r~Usage: /gfrankedsetwebhook [mode] [url]')
        TriggerClientEvent('esx:showNotification', source, '~b~Modes disponibles: 1v1, 2v2, 3v3, 4v4')
        return
    end
    
    mode = mode:lower()
    
    local validModes = {['1v1'] = true, ['2v2'] = true, ['3v3'] = true, ['4v4'] = true}
    if not validModes[mode] then
        TriggerClientEvent('esx:showNotification', source, '~r~Mode invalide! Utilisez: 1v1, 2v2, 3v3 ou 4v4')
        return
    end
    
    if not ValidateWebhookURL(url) then
        TriggerClientEvent('esx:showNotification', source, '~r~URL webhook Discord invalide!')
        TriggerClientEvent('esx:showNotification', source, '~y~Format: https://discord.com/api/webhooks/ID/TOKEN')
        return
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    TriggerClientEvent('esx:showNotification', source, '~b~Configuration du webhook ' .. mode .. '...')
    
    SaveWebhookToDB(mode, url, xPlayer.identifier, function(success)
        if success then
            TriggerClientEvent('esx:showNotification', source, '~g~✅ Webhook ' .. mode .. ' configuré avec succès!')
            TriggerClientEvent('esx:showNotification', source, '~b~Le webhook est maintenant chiffré et sécurisé')
            
            print('^2[WEBHOOK] Admin ' .. xPlayer.getName() .. ' (' .. xPlayer.getGroup() .. ') a configuré le webhook ' .. mode .. '^0')
        else
            TriggerClientEvent('esx:showNotification', source, '~r~❌ Erreur lors de la configuration du webhook')
        end
    end)
end, false)

-- Commande : Afficher les webhooks configurés
RegisterCommand('gfrankedshowwebhooks', function(source)
    if source == 0 then
        print('^1[WEBHOOK] Cette commande doit être exécutée in-game^0')
        return
    end
    
    if not IsAdmin(source) then
        TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        TriggerClientEvent('esx:showNotification', source, '~y~Vous devez être admin ESX')
        return
    end
    
    GetAllWebhooksFromDB(function(webhooks)
        if #webhooks == 0 then
            TriggerClientEvent('esx:showNotification', source, '~y~Aucun webhook configuré')
            return
        end
        
        TriggerClientEvent('esx:showNotification', source, '~b~===== WEBHOOKS CONFIGURÉS =====')
        
        for i = 1, #webhooks do
            local wh = webhooks[i]
            TriggerClientEvent('esx:showNotification', source, 
                string.format('~b~%s~w~: %s', wh.mode:upper(), wh.masked))
        end
        
        TriggerClientEvent('esx:showNotification', source, '~b~================================')
        
        -- Log console avec URLs complètes (sécurisé)
        print('^2[WEBHOOK] Liste des webhooks (demandée par admin ' .. GetPlayerName(source) .. '):^0')
        for i = 1, #webhooks do
            local wh = webhooks[i]
            print(string.format('^3  %s: %s^0', wh.mode:upper(), wh.masked))
        end
    end)
end, false)

-- Commande : Supprimer un webhook
RegisterCommand('gfrankeddeletewebhook', function(source, args)
    if source == 0 then
        print('^1[WEBHOOK] Cette commande doit être exécutée in-game^0')
        return
    end
    
    if not IsAdmin(source) then
        TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        TriggerClientEvent('esx:showNotification', source, '~y~Vous devez être admin ESX')
        return
    end
    
    local mode = args[1]
    
    if not mode then
        TriggerClientEvent('esx:showNotification', source, '~r~Usage: /gfrankeddeletewebhook [mode]')
        return
    end
    
    mode = mode:lower()
    
    DeleteWebhookFromDB(mode, function(success)
        if success then
            TriggerClientEvent('esx:showNotification', source, '~g~✅ Webhook ' .. mode .. ' supprimé')
            print('^2[WEBHOOK] Admin ' .. GetPlayerName(source) .. ' a supprimé le webhook ' .. mode .. '^0')
        else
            TriggerClientEvent('esx:showNotification', source, '~y~Webhook ' .. mode .. ' introuvable')
        end
    end)
end, false)

-- Commande : Tester un webhook
RegisterCommand('gfrankedtestwebhook', function(source, args)
    if source == 0 then
        print('^1[WEBHOOK] Cette commande doit être exécutée in-game^0')
        return
    end
    
    if not IsAdmin(source) then
        TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        TriggerClientEvent('esx:showNotification', source, '~y~Vous devez être admin ESX')
        return
    end
    
    local mode = args[1]
    
    if not mode then
        TriggerClientEvent('esx:showNotification', source, '~r~Usage: /gfrankedtestwebhook [mode]')
        return
    end
    
    mode = mode:lower()
    
    LoadWebhookFromDB(mode, function(url)
        if not url then
            TriggerClientEvent('esx:showNotification', source, '~r~Webhook ' .. mode .. ' non configuré')
            return
        end
        
        TriggerClientEvent('esx:showNotification', source, '~b~Test du webhook ' .. mode .. '...')
        
        local payload = json.encode({
            username = 'GFRanked Test',
            embeds = {{
                title = '🧪 Test Webhook ' .. mode:upper(),
                description = 'Ce webhook est correctement configuré et fonctionne!\n\n✅ Chiffrement: Actif\n✅ Connexion: OK',
                color = 5763719,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                footer = {
                    text = 'Test effectué par ' .. GetPlayerName(source)
                }
            }}
        })
        
        PerformHttpRequest(url, function(statusCode, responseBody, headers)
            if statusCode == 204 or statusCode == 200 then
                TriggerClientEvent('esx:showNotification', source, '~g~✅ Webhook ' .. mode .. ' fonctionne correctement!')
            else
                TriggerClientEvent('esx:showNotification', source, '~r~❌ Erreur webhook (Status: ' .. statusCode .. ')')
                print('^1[WEBHOOK ERROR] Test échoué pour ' .. mode .. ' (Status: ' .. statusCode .. ')^0')
            end
        end, 'POST', payload, {['Content-Type'] = 'application/json'})
    end)
end, false)

-- Commande : Aide
RegisterCommand('gfrankedwebhookhelp', function(source)
    if source == 0 then return end
    
    if not IsAdmin(source) then
        TriggerClientEvent('esx:showNotification', source, '~r~Permission refusée')
        TriggerClientEvent('esx:showNotification', source, '~y~Vous devez être admin ESX')
        return
    end
    
    TriggerClientEvent('esx:showNotification', source, '~b~===== COMMANDES WEBHOOK =====')
    TriggerClientEvent('esx:showNotification', source, '~y~/gfrankedsetwebhook [mode] [url]~w~ - Définir webhook')
    TriggerClientEvent('esx:showNotification', source, '~y~/gfrankedshowwebhooks~w~ - Voir webhooks')
    TriggerClientEvent('esx:showNotification', source, '~y~/gfrankeddeletewebhook [mode]~w~ - Supprimer webhook')
    TriggerClientEvent('esx:showNotification', source, '~y~/gfrankedtestwebhook [mode]~w~ - Tester webhook')
    TriggerClientEvent('esx:showNotification', source, '~b~Modes: 1v1, 2v2, 3v3, 4v4')
    TriggerClientEvent('esx:showNotification', source, '~b~==============================')
end, false)

-- ========================================
-- EXPORTS
-- ========================================
exports('GetWebhookURL', LoadWebhookFromDB)
exports('SetWebhookURL', SaveWebhookToDB)
exports('DeleteWebhook', DeleteWebhookFromDB)
exports('GetAllWebhooks', GetAllWebhooksFromDB)

-- ========================================
-- VÉRIFICATION DÉMARRAGE
-- ========================================
CreateThread(function()
    Wait(2000)
    
    if WEBHOOK_KEY == '' or #WEBHOOK_KEY < 16 then
        print('^1========================================^0')
        print('^1[WEBHOOK] ATTENTION: CLÉ DE CHIFFREMENT MANQUANTE!^0')
        print('^1========================================^0')
        print('^3Ajoutez dans votre server.cfg:^0')
        print('^2setr gfranked_webhook_key "VOTRE_CLE_SECRETE_LONGUE"^0')
        print('^3Utilisez une clé longue et complexe (minimum 16 caractères)^0')
        print('^1========================================^0')
    else
        print('^2[WEBHOOK] Système de chiffrement activé (Clé: ' .. #WEBHOOK_KEY .. ' caractères)^0')
        
        -- Charger tous les webhooks en cache au démarrage
        GetAllWebhooksFromDB(function(webhooks)
            print('^2[WEBHOOK] ' .. #webhooks .. ' webhook(s) chargé(s) depuis la base de données^0')
        end)
    end
end)

DebugSuccess('Module Webhook Manager initialisé (VERSION 1.0.2 - LUA 5.4 COMPATIBLE)')