--[[
    =====================================================
    REDZONE LEAGUE - Fonctions Partagées
    =====================================================
    Ce fichier contient les fonctions utilisées
    à la fois côté client et côté serveur.
]]

Redzone = Redzone or {}
Redzone.Shared = {}

-- =====================================================
-- DÉTECTION CLIENT/SERVEUR
-- =====================================================

-- Vérifie si on est côté client ou serveur
local isServer = IsDuplicityVersion()

-- =====================================================
-- FONCTION DE DEBUG
-- =====================================================

---Affiche un message de debug si le mode debug est activé
---@param message string Le message à afficher
---@param ... any Arguments supplémentaires pour le formatage
function Redzone.Shared.Debug(message, ...)
    if not Config.Debug then return end

    local args = {...}
    local formattedMessage = message

    -- Si des arguments sont fournis, on les concatène
    if #args > 0 then
        for _, arg in ipairs(args) do
            formattedMessage = formattedMessage .. tostring(arg)
        end
    end

    -- Affichage avec timestamp (os.date disponible seulement côté serveur)
    local timestamp = ''
    if isServer then
        timestamp = os.date('%H:%M:%S')
    else
        -- Côté client, on utilise GetGameTimer
        local gameTime = GetGameTimer()
        local seconds = math.floor(gameTime / 1000)
        local minutes = math.floor(seconds / 60)
        local hours = math.floor(minutes / 60)
        timestamp = string.format('%02d:%02d:%02d', hours % 24, minutes % 60, seconds % 60)
    end

    print(string.format('[DEBUG][%s] %s', timestamp, formattedMessage))
end

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

---Vérifie si une valeur existe dans une table
---@param table table La table à vérifier
---@param value any La valeur à rechercher
---@return boolean exists True si la valeur existe
function Redzone.Shared.TableContains(table, value)
    if not table then return false end

    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

---Copie profonde d'une table
---@param original table La table à copier
---@return table copy La copie de la table
function Redzone.Shared.DeepCopy(original)
    local copy

    if type(original) == 'table' then
        copy = {}
        for key, value in next, original, nil do
            copy[Redzone.Shared.DeepCopy(key)] = Redzone.Shared.DeepCopy(value)
        end
        setmetatable(copy, Redzone.Shared.DeepCopy(getmetatable(original)))
    else
        copy = original
    end

    return copy
end

---Convertit un Vector4 en Vector3 (retire le heading)
---@param vec4 vector4 Le Vector4 à convertir
---@return vector3 vec3 Le Vector3 résultant
function Redzone.Shared.Vec4ToVec3(vec4)
    return vector3(vec4.x, vec4.y, vec4.z)
end

---Obtient le heading d'un Vector4
---@param vec4 vector4 Le Vector4
---@return number heading Le heading (rotation)
function Redzone.Shared.GetHeadingFromVec4(vec4)
    return vec4.w
end

---Calcule la distance entre deux points (Vector3)
---@param point1 vector3 Premier point
---@param point2 vector3 Deuxième point
---@return number distance La distance entre les deux points
function Redzone.Shared.GetDistance(point1, point2)
    return #(point1 - point2)
end

---Formate un temps en secondes vers un format lisible (MM:SS)
---@param seconds number Le temps en secondes
---@return string formatted Le temps formaté
function Redzone.Shared.FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format('%02d:%02d', mins, secs)
end

---Génère un identifiant unique
---@return string uuid L'identifiant unique généré
function Redzone.Shared.GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end)
end

---Valide les coordonnées (vérifie si elles sont valides)
---@param coords vector3|vector4 Les coordonnées à valider
---@return boolean valid True si les coordonnées sont valides
function Redzone.Shared.ValidateCoords(coords)
    if not coords then return false end

    -- Vérifie si c'est un vector3 ou vector4
    if type(coords) ~= 'vector3' and type(coords) ~= 'vector4' then
        return false
    end

    -- Vérifie que les valeurs ne sont pas NaN ou infinies
    if coords.x ~= coords.x or coords.y ~= coords.y or coords.z ~= coords.z then
        return false
    end

    return true
end

---Retourne un élément aléatoire d'une table
---@param table table La table source
---@return any element L'élément aléatoire
function Redzone.Shared.GetRandomElement(table)
    if not table or #table == 0 then return nil end
    return table[math.random(1, #table)]
end

-- =====================================================
-- CONSTANTES PARTAGÉES
-- =====================================================

Redzone.Shared.Constants = {
    -- États du joueur dans le redzone
    PlayerStates = {
        OUTSIDE = 0,        -- En dehors du redzone
        IN_MENU = 1,        -- Dans le menu
        TELEPORTING = 2,    -- En cours de téléportation
        IN_REDZONE = 3,     -- Dans le redzone
        LEAVING = 4,        -- En train de quitter
    },

    -- Événements
    Events = {
        PLAYER_JOINED = 'redzone:playerJoined',
        PLAYER_LEFT = 'redzone:playerLeft',
        OPEN_MENU = 'redzone:openMenu',
        CLOSE_MENU = 'redzone:closeMenu',
        START_TELEPORT = 'redzone:startTeleport',
        CANCEL_TELEPORT = 'redzone:cancelTeleport',
        COMPLETE_TELEPORT = 'redzone:completeTeleport',
    },

    -- Callbacks NUI
    NUI = {
        OPEN = 'redzone:nui:open',
        CLOSE = 'redzone:nui:close',
        SELECT_SPAWN = 'redzone:nui:selectSpawn',
        CONFIRM_RULES = 'redzone:nui:confirmRules',
    },
}

-- =====================================================
-- INITIALISATION
-- =====================================================

-- Initialisation du générateur de nombres aléatoires
-- os.time() disponible seulement côté serveur
if isServer then
    math.randomseed(os.time())
else
    -- Côté client, on utilise GetGameTimer
    math.randomseed(GetGameTimer())
end

-- Message de chargement
Redzone.Shared.Debug('[SHARED] Fichier partagé chargé avec succès')
