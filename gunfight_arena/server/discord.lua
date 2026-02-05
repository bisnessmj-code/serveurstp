-- ================================================================================================
-- GUNFIGHT ARENA - DISCORD LEADERBOARD WEBHOOK
-- ================================================================================================

local Discord = {}

local WEBHOOK_URL = GetConvar("gfarena_discord_webhook", "")
local LOGO_URL = "https://r2.fivemanage.com/65OINTV6xwj2vOK7XWptj/logo.png"
local EMBED_COLOR = 16711680 -- Rouge (#FF0000)

print("^3[GF-Arena]^0 Chargement du module Discord...")

if WEBHOOK_URL == "" then
    print("^1[GF-Arena] ATTENTION: Aucun webhook Discord configuré. Ajoute 'set gfarena_discord_webhook' dans ton server.cfg^0")
end

-- ================================================================================================
-- ENVOYER LE LEADERBOARD SUR DISCORD
-- ================================================================================================

function Discord.SendLeaderboard()
    if WEBHOOK_URL == "" then
        print("^1[GF-Arena] Webhook Discord non configuré.^0")
        return
    end

    Stats.GetLeaderboard(15, function(results)
        if not results or #results == 0 then
            if Config.DebugServer then
                Utils.Log("Discord: Aucune donnée pour le leaderboard", "warning")
            end
            return
        end

        local lines = {}
        for i, player in ipairs(results) do
            local kd = player.deaths > 0 and math.floor((player.kills / player.deaths) * 100) / 100 or player.kills
            local medal = ""
            if i == 1 then medal = "🥇"
            elseif i == 2 then medal = "🥈"
            elseif i == 3 then medal = "🥉"
            else medal = "`#" .. i .. "`"
            end

            local license = player.license or "inconnu"
            local shortLicense = string.sub(license, 9, 19) .. "..."

            lines[#lines + 1] = string.format(
                "%s **%s** — `%d` kills · `%d` deaths · K/D `%.2f`",
                medal, shortLicense, player.kills, player.deaths, kd
            )
        end

        local description = table.concat(lines, "\n")
        local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

        local payload = json.encode({
            username = "Gunfight Arena",
            avatar_url = LOGO_URL,
            embeds = {{
                title = "🏆  CLASSEMENT GUNFIGHT ARENA",
                description = description,
                color = EMBED_COLOR,
                thumbnail = {
                    url = LOGO_URL
                },
                footer = {
                    text = "Gunfight Arena • Mis à jour"
                },
                timestamp = timestamp
            }}
        })

        PerformHttpRequest(WEBHOOK_URL, function(statusCode, response, headers)
            if statusCode >= 200 and statusCode < 300 then
                print("^2[GF-Arena]^0 Leaderboard Discord envoyé avec succès!")
            else
                print(("^1[GF-Arena] Erreur webhook Discord: %d^0"):format(statusCode))
            end
        end, "POST", payload, {["Content-Type"] = "application/json"})
    end)
end

-- ================================================================================================
-- COMMANDE ADMIN POUR ENVOYER LE LEADERBOARD
-- ================================================================================================

RegisterCommand("gfarena_leaderboard", function(source, args, rawCommand)
    if source ~= 0 then
        -- Vérifier si c'est un admin (depuis la console ou joueur admin)
        if not IsPlayerAceAllowed(source, "command.gfarena_leaderboard") then
            return
        end
    end
    Discord.SendLeaderboard()
end, true)

-- ================================================================================================
-- ENVOI AUTOMATIQUE TOUTES LES 30 MINUTES
-- ================================================================================================

CreateThread(function()
    -- Attendre que le serveur soit bien démarré
    Wait(10000)

    if WEBHOOK_URL ~= "" then
        Discord.SendLeaderboard()
    end

    while true do
        Wait(1800000) -- 30 minutes
        if WEBHOOK_URL ~= "" then
            Discord.SendLeaderboard()
        end
    end
end)

_G.Discord = Discord

print("^2[GF-Arena]^0 Module Discord chargé avec succès!")

return Discord
