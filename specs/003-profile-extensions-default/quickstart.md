# Quickstart: Test du comportement des profils d'extensions

## Prérequis

- NAS Synology avec DSM 7.2+
- Accès SSH au NAS
- Package PHP84 désinstallé (pour test propre)

## Tests rapides

### Test 1: Profil Minimal sans extensions

1. Installer le SPK via le Centre de paquets
2. Sélectionner **Profil Minimal**
3. Ne cocher **aucune** extension optionnelle
4. Terminer l'installation
5. Ouvrir PHP 8.4 Manager

**Résultat attendu** : 0 extension activée dans la liste

**Vérification SSH** :
```bash
ls /var/packages/php84/var/etc/conf.d/
# Doit être vide ou ne contenir aucun fichier .ini
```

### Test 2: Profil Standard sans extensions

1. Désinstaller PHP84 (si installé)
2. Réinstaller avec **Profil Standard**
3. Ne cocher **aucune** extension optionnelle
4. Terminer l'installation

**Résultat attendu** : 0 extension activée

### Test 3: Profil Complet

1. Désinstaller PHP84 (si installé)
2. Réinstaller avec **Profil Complet**
3. Terminer l'installation

**Résultat attendu** : ~142 extensions activées (toutes)

**Vérification SSH** :
```bash
ls /var/packages/php84/var/etc/conf.d/*.ini | wc -l
# Doit afficher ~142
```

### Test 4: Profil Minimal avec sélection

1. Désinstaller PHP84
2. Réinstaller avec **Profil Minimal**
3. Cocher **APCu** et **Redis**
4. Terminer l'installation

**Résultat attendu** : 3 extensions activées (APCu, Redis, igbinary - dépendance de Redis)

## Logs de débogage

Consulter les logs d'installation :
```bash
cat /var/packages/php84/var/log/install.log
```

Vérifier les variables du wizard reçues :
```bash
# Si le logging est activé dans postinst
grep "wizard_" /var/packages/php84/var/log/install.log
```

## Build et déploiement rapide

```bash
# Sur la machine de build
cd /home/gilles/ProjetSPK/php84/spk/php84
./scripts/build-spk.sh

# Copier sur le NAS
scp dist/php84-*.spk user@nas:/tmp/

# Sur le NAS (SSH)
sudo synopkg install /tmp/php84-*.spk
```
