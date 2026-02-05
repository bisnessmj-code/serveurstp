# 🔧 Migration du Système de Coffre (Stash)

## Problème résolu

Le problème était que les items n'étaient pas persistants après un restart du serveur. La cause :
- Le script utilisait une table SQL personnalisée `redzone_stash`
- Les items étaient "injectés" manuellement dans qs-inventory après l'ouverture
- Cette méthode d'injection échouait car le stash n'était pas correctement initialisé dans qs-inventory

## Solution appliquée

Le système a été modifié pour utiliser **directement la table native de qs-inventory** :
- Les items sont maintenant stockés dans la table `stash_items` (utilisée par qs-inventory)
- qs-inventory charge automatiquement les items depuis cette table
- Plus besoin d'injection manuelle complexe

## Étapes d'installation

### 1. Exécuter le script SQL de migration

Exécutez le fichier `sql/migration_stash_items.sql` dans votre base de données :

```bash
# Via HeidiSQL, phpMyAdmin ou ligne de commande MySQL
mysql -u votre_user -p votre_database < sql/migration_stash_items.sql
```

Ce script va :
- Créer la table `stash_items` si elle n'existe pas
- Migrer automatiquement les données de `redzone_stash` vers `stash_items`
- Conserver l'ancienne table pour sécurité (vous pourrez la supprimer manuellement après vérification)

### 2. Vérifier la migration

Connectez-vous à votre base de données et exécutez :

```sql
SELECT * FROM stash_items WHERE stash LIKE 'rzstash_%';
```

Vous devriez voir vos coffres migrés avec leurs items.

### 3. Restart du serveur

```
restart redzone
```

### 4. Test

1. Connectez-vous au serveur
2. Allez dans le redzone
3. Ouvrez votre coffre
4. Vérifiez que vos items sont présents
5. Ajoutez/retirez des items
6. Déconnectez-vous et reconnectez-vous → les items doivent être là
7. **Restart le serveur** → les items doivent toujours être là ✅

### 5. Nettoyage (optionnel)

Une fois que vous avez vérifié que tout fonctionne correctement pendant plusieurs jours, vous pouvez supprimer l'ancienne table :

```sql
DROP TABLE IF EXISTS `redzone_stash`;
```

## Changements techniques

### Avant
- Table personnalisée : `redzone_stash` avec colonne `identifier`
- Injection manuelle des items via `AddToStash`
- Complexité élevée avec vérifications de doublons

### Après
- Table native : `stash_items` avec colonne `stash`
- Chargement automatique par qs-inventory
- Code simplifié et plus fiable

## Commandes de debug

### Afficher le contenu d'un coffre
```
redzone_debugstash [player_id]
```

### Vider le coffre d'un joueur (admin)
```
redzone_clearstash [player_id]
```

### Forcer la sauvegarde de tous les coffres ouverts
```
redzone_savestash
```

## Fonctionnalités conservées

✅ Sauvegarde automatique à la fermeture du coffre
✅ Sauvegarde périodique toutes les 60 secondes
✅ Sauvegarde à la déconnexion du joueur
✅ Sauvegarde à l'arrêt de la ressource
✅ Un coffre unique par joueur (lié à son identifier)
✅ Limite de poids et slots configurables

## Support

Si vous rencontrez des problèmes :
1. Vérifiez que la table `stash_items` existe dans votre BDD
2. Vérifiez les logs serveur pour des erreurs SQL
3. Utilisez `redzone_debugstash [player_id]` pour voir l'état du coffre
4. Vérifiez que qs-inventory est bien installé et à jour

## Notes importantes

- Les anciens items dans `redzone_stash` sont **automatiquement migrés**
- La migration est **idempotente** (vous pouvez la relancer plusieurs fois sans risque)
- Les items sont maintenant gérés de façon native par qs-inventory
- Compatibilité totale avec les futures mises à jour de qs-inventory
