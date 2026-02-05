# PNJ Sync Module

Module de gestion des sessions réseau.

## Installation

```cfg
ensure pnj-sync

# Permissions admin
add_ace group.admin pnjsync.admin allow
add_principal identifier.steam:110000xxxxxxxxx group.admin
```

## Commandes

### /sblock [adresse] [raison]
Bloquer une adresse de façon permanente.

```
/sblock 192.168.1.100 Comportement toxique
/sblock 45.67.89.123 Cheat détecté
```

### /sunblock [adresse]
Débloquer une adresse.

```
/sunblock 192.168.1.100
```

### /splayer [id] [raison]
Bloquer l'adresse d'un joueur connecté via son ID serveur.

```
/splayer 5 Insultes répétées
/splayer 12 AFK farming
```

### /stemp [adresse] [durée] [raison]
Blocage temporaire.

**Durées disponibles:**
- `1h` - 1 heure
- `1d` - 1 jour
- `1w` - 1 semaine
- `1mo` - 1 mois

```
/stemp 192.168.1.100 1d Spam vocal
/stemp 45.67.89.123 1w Triche mineure
/stemp 10.20.30.40 2h Timeout
```

### /slist [page]
Afficher la liste des adresses bloquées.

```
/slist
/slist 2
```

### /scheck [adresse]
Vérifier si une adresse est bloquée.

```
/scheck 192.168.1.100
```

### /shelp
Afficher l'aide des commandes.

## Configuration

Modifier `shared/config.lua` pour:
- Changer les noms des commandes
- Activer les logs Discord
- Passer en stockage MySQL
- Modifier les messages

## Stockage

Par défaut: fichier JSON (`data/cache.json`)

Pour MySQL, modifier dans `config.lua`:
```lua
Config.Database = {
    Type = 'mysql',
    MySQL = {
        TableName = 'pnj_sync_cache',
    },
}
```

## Webhook Discord

```lua
Config.Logs.Discord = {
    Enabled = true,
    WebhookURL = 'https://discord.com/api/webhooks/xxx/xxx',
}
```
Ok j'aimerai ajuster deux trois trucs enfaite ce script doit être dans l'ombre ça veux dire quoi,           lorsque je ban j'aimerai que le message ça sois pas un message de ban genre je voudrais que l'on met     
  une fake donné en mode c'est une erreur fivem car ça sera juste pour ban les cheateurs pour essayez       
  de faire en sorte qu'il comprennent même pas qu'il sont ban et j'aimerai par contre que lorsque je        
  ban il y a pas de message dans le chat car on voit l'ip etc dans le chat je veux vraiment que ça sois     
  vraiment discret je dois pas affiche comme quoi je l'ai ban au pire du pire dans les logs de la           
  console du tx on l'affiche mais c'est tout et lorsqu'il se reconnecte pareil il devra voir comme si       
  c'était une erreur fivem   