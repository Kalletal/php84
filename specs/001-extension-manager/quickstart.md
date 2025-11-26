# Quickstart: Extension Manager Development

**Feature**: 001-extension-manager
**Date**: 2025-11-26

## Prérequis

### Environnement de développement

1. **Docker** (pour la compilation croisée)
   ```bash
   docker --version  # >= 20.x
   ```

2. **Git** (pour cloner spksrc)
   ```bash
   git --version
   ```

3. **Synology NAS** (DS920+ pour les tests)
   - DSM 7.2.2 ou supérieur
   - Accès SSH activé
   - Compte administrateur

### Clone du framework spksrc

```bash
git clone https://github.com/SynoCommunity/spksrc.git
cd spksrc
```

---

## Structure du projet

```
php84/
├── cross/
│   └── php84/
│       ├── Makefile
│       ├── digests
│       └── patches/           # Patches optionnels
├── spk/
│   └── php84/
│       ├── Makefile
│       ├── PLIST
│       └── src/
│           ├── wizard/
│           │   └── install_uifile
│           ├── service-setup.sh
│           ├── dsm_config
│           └── ui/
│               ├── config
│               ├── PHP84Manager.js
│               └── cgi/
│                   ├── extensions.cgi
│                   ├── config.cgi
│                   └── service.cgi
└── deps/                      # Dépendances à compiler
```

---

## Étapes de développement

### 1. Initialiser l'environnement Docker

```bash
# Lancer le container de build
docker run -it --platform=linux/amd64 \
  -v $(pwd):/spksrc \
  -w /spksrc \
  ghcr.io/synocommunity/spksrc \
  /bin/bash
```

### 2. Compiler les dépendances

```bash
# OpenSSL 3.x
cd cross/openssl3 && make arch-geminilake-7.2 && cd ../..

# libxml2
cd cross/libxml2 && make arch-geminilake-7.2 && cd ../..

# Autres dépendances...
cd cross/sqlite && make arch-geminilake-7.2 && cd ../..
cd cross/curl && make arch-geminilake-7.2 && cd ../..
cd cross/oniguruma && make arch-geminilake-7.2 && cd ../..
cd cross/libzip && make arch-geminilake-7.2 && cd ../..
```

### 3. Compiler PHP 8.4

```bash
cd cross/php84
make arch-geminilake-7.2
```

### 4. Créer le package SPK

```bash
cd spk/php84
make arch-geminilake-7.2
```

### 5. Récupérer le package

```bash
ls -la packages/
# php84-8.4.15-1-geminilake-7.2.spk
```

---

## Test sur NAS

### Installation via SSH

```bash
# Copier le SPK sur le NAS
scp packages/php84-*.spk admin@nas:/tmp/

# Sur le NAS
ssh admin@nas
sudo synopkg install /tmp/php84-*.spk
```

### Installation via Package Center

1. Ouvrir Package Center
2. Paramètres > Sources de package > Ajouter
3. Ou: Installation manuelle > Parcourir > Sélectionner le .spk

### Vérification

```bash
# Vérifier l'installation
synopkg status php84

# Tester PHP
/var/packages/php84/target/bin/php -v
/var/packages/php84/target/bin/php -m
```

---

## Développement de l'interface

### Test du wizard

Le wizard est lu depuis `src/wizard/install_uifile`. Pour tester les modifications :

1. Modifier `install_uifile`
2. Rebuilder le SPK
3. Désinstaller puis réinstaller le package

### Test de l'interface de gestion

Pour développer l'interface ExtJS :

1. Modifier `src/ui/PHP84Manager.js`
2. Rebuilder le SPK
3. Réinstaller ou copier manuellement :
   ```bash
   scp src/ui/* admin@nas:/var/packages/php84/target/ui/
   ```
4. Rafraîchir DSM (F5)

### Test des CGI

```bash
# Test local des CGI (depuis le NAS)
cd /var/packages/php84/target/ui/cgi
./extensions.cgi

# Via curl
curl -b "id=<session>" \
  "http://nas:5000/webman/3rdparty/php84/cgi/extensions.cgi"
```

---

## Fichiers clés à créer

### cross/php84/Makefile

```makefile
PKG_NAME = php
PKG_VERS = 8.4.15
PKG_EXT = tar.xz
PKG_DIST_NAME = $(PKG_NAME)-$(PKG_VERS).$(PKG_EXT)
PKG_DIST_SITE = https://www.php.net/distributions
PKG_DIR = $(PKG_NAME)-$(PKG_VERS)

DEPENDS = cross/openssl3 cross/libxml2 cross/sqlite cross/curl
DEPENDS += cross/libzip cross/oniguruma cross/zlib

HOMEPAGE = https://www.php.net
COMMENT = PHP 8.4 with shared extensions
LICENSE = PHP-3.01

GNU_CONFIGURE = 1
CONFIGURE_ARGS = --prefix=$(STAGING_INSTALL_PREFIX)
CONFIGURE_ARGS += --enable-fpm
CONFIGURE_ARGS += --enable-shared
# ... (voir research.md pour la liste complète)

include ../../mk/spksrc.cross-cc.mk
```

### spk/php84/src/wizard/install_uifile

```json
[
  {
    "step_title": "Extensions - Base de données",
    "items": [{
      "type": "multiselect",
      "desc": "Sélectionnez les extensions",
      "subitems": [
        {"key": "ext_mysqli", "desc": "mysqli", "defaultValue": true},
        {"key": "ext_pdo_mysql", "desc": "pdo_mysql", "defaultValue": true}
      ]
    }]
  }
]
```

### spk/php84/src/ui/config

```json
{
  "SYNO.SDS.PHP84Manager.Instance": {
    "type": "app",
    "title": "PHP 8.4 Manager",
    "appWindow": "SYNO.SDS.PHP84Manager.MainWindow",
    "icon": "images/icon_{0}.png",
    "allUsers": false
  }
}
```

---

## Commandes utiles

### Build

```bash
# Build complet
make -C spk/php84 arch-geminilake-7.2

# Clean
make -C spk/php84 clean

# Générer checksums
make -C cross/php84 digests
```

### Debug

```bash
# Logs du package sur NAS
cat /var/packages/php84/var/log/php-fpm.log

# Status service
synopkg status php84

# Redémarrer service
synopkg restart php84
```

### NAS

```bash
# Liste des packages
synopkg list

# Info package
synopkg info php84

# Chemins importants
/var/packages/php84/target/     # Binaires
/var/packages/php84/var/        # Config utilisateur
/var/packages/php84/etc/        # Liens config
```

---

## Checklist de développement

- [ ] Environnement Docker fonctionnel
- [ ] Dépendances compilées
- [ ] PHP 8.4 compile avec extensions shared
- [ ] Wizard d'installation avec catégories
- [ ] Interface de gestion ExtJS créée
- [ ] CGI backend fonctionnels
- [ ] Tests sur NAS DS920+
- [ ] Redémarrage service fonctionne
- [ ] Documentation à jour
