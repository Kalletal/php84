# Research: Extension Manager for PHP 8.4 SPK

**Feature**: 001-extension-manager
**Date**: 2025-11-26
**Status**: Complete

## Executive Summary

Ce document consolide les recherches effectuées pour implémenter le gestionnaire d'extensions PHP 8.4 sur Synology DS920+ avec le framework spksrc.

---

## 1. Framework spksrc

### Decision: Utiliser spksrc pour la compilation croisée

**Rationale**:
- Framework mature et maintenu par SynoCommunity
- Support natif de l'architecture geminilake (DS920+)
- Système de Makefiles hiérarchique bien documenté
- Gestion automatique des toolchains et dépendances

**Alternatives considérées**:
- Compilation manuelle : Plus complexe, moins reproductible
- Docker natif : Pas de support des toolchains Synology

### Structure du projet spksrc

```
spksrc/
├── cross/php84/           # Compilation croisée PHP
│   ├── Makefile           # Définition du build
│   ├── digests            # Checksums SHA256
│   └── PLIST              # Liste des fichiers installés
├── spk/php84/             # Package SPK
│   ├── Makefile           # Définition du package
│   ├── src/
│   │   ├── service-setup.sh
│   │   ├── wizard/
│   │   │   └── install_uifile    # Wizard JSON
│   │   └── dsm_config
│   └── PLIST
└── mk/                    # Infrastructure Makefile
    ├── spksrc.common.mk
    ├── spksrc.cross-cc.mk
    └── spksrc.spk.mk
```

### Commandes de build

```bash
# Build pour geminilake (DS920+)
cd cross/php84 && make arch-geminilake-7.2

# Build du package SPK
cd spk/php84 && make arch-geminilake-7.2
```

---

## 2. Architecture cible : Geminilake

### Decision: Cibler uniquement geminilake-7.2

**Rationale**:
- DS920+ utilise Intel Celeron J4125 (Gemini Lake)
- Architecture x86_64 avec toolchain geminilake-7.2
- DSM 7.2.2 requiert `os_min_ver="7.0-40000"`

**Spécifications**:
| Paramètre | Valeur |
|-----------|--------|
| Architecture | geminilake |
| CPU | Intel Celeron J4125 |
| Toolchain | syno-geminilake-7.2 |
| DSM min | 7.0-40000 |
| ABI | x86_64-linux-gnu |

**CFLAGS recommandés**:
```makefile
ADDITIONAL_CFLAGS = -O2 -fPIC -march=silvermont -mtune=silvermont
ADDITIONAL_CFLAGS += -DSYNO_ENVIRONMENT
```

---

## 3. Wizard d'installation (WIZARD_UIFILES)

### Decision: Format JSON avec steps conditionnels via JavaScript

**Rationale**:
- Format JSON supporté DSM 6.x - 7.x
- Support des steps conditionnels via `activate_v2` et `deactivate_v2`
- Scripts shell `.sh` pour génération dynamique
- `multiselect` permet checkboxes multiples

**Documentation officielle** : [WIZARD_UIFILES 7.2.2](https://help.synology.com/developer-guide/synology_package/wizard/WIZARD_UIFILES_v2.html)

### Types de fichiers wizard

| Fichier | Usage |
|---------|-------|
| `install_uifile` | JSON statique pour installation |
| `install_uifile.sh` | Script générant JSON dynamiquement |
| `upgrade_uifile` | Pour les mises à jour |
| `uninstall_uifile` | Pour la désinstallation |

### Format de base

```json
[
  {
    "step_title": "Titre du step",
    "items": [{
      "type": "multiselect",
      "desc": "Description",
      "subitems": [
        {"key": "ma_cle", "desc": "Label", "defaultValue": true}
      ]
    }]
  }
]
```

### Propriétés avancées des steps

| Propriété | Description |
|-----------|-------------|
| `step_title` | Titre affiché |
| `invalid_next_disabled` | Désactive "Suivant" si validation échoue |
| `invalid_next_disabled_v2` | Version DSM 7+ |
| `activate_v2` | **Fonction JS exécutée à l'entrée du step** |
| `deactivate_v2` | **Fonction JS exécutée à la sortie du step** |

### Propriétés des items/subitems

| Propriété | Description |
|-----------|-------------|
| `hidden` | Cache l'élément (boolean) |
| `disabled` | Désactive l'élément (boolean) |
| `defaultValue` | Valeur par défaut |
| `validator` | Fonction de validation `{"fn": "..."}` |
| `emptyText` | Placeholder pour textfield |

### Navigation conditionnelle entre steps

Les steps conditionnels sont possibles grâce aux fonctions JavaScript `activate_v2` et `deactivate_v2`.

**Exemple de navigation conditionnelle** (extrait de roundcube) :

```javascript
// Dans deactivate_v2 - Définir le prochain step selon une condition
{
    var currentStep = arguments[0];
    var wizardDialog = currentStep.owner;

    // Trouver les steps par leur titre
    var step1 = findStepByTitle(wizardDialog, "Step 1");
    var step2 = findStepByTitle(wizardDialog, "Step 2");
    var step3 = findStepByTitle(wizardDialog, "Step 3");

    // Récupérer la valeur d'un checkbox
    var option = step1.getComponent("ma_cle").checked;

    // Rediriger selon le choix
    if (option) {
        step1.nextId = step2.itemId;  // Aller vers step2
    } else {
        step1.nextId = step3.itemId;  // Sauter step2, aller vers step3
    }
}
```

**Exemple dans activate_v2** - Forcer la navigation :

```javascript
{
    var currentStep = arguments[0];
    var wizardDialog = currentStep.owner;
    var targetStep = findStepByTitle(wizardDialog, "Target Step");

    if (condition) {
        wizardDialog.goBack(previousStep.itemId);
        wizardDialog.goNext(targetStep.itemId);
    }
}
```

### Fonctions utilitaires JavaScript

```javascript
// Trouver un step par son titre
function findStepByTitle(wizardDialog, title) {
    for (var i = wizardDialog.customuiIds.length - 1; i >= 0; i--) {
        var step = wizardDialog.getStep(wizardDialog.customuiIds[i]);
        if (title === step.headline) {
            return step;
        }
    }
    return null;
}

// Récupérer la valeur d'un composant
var value = step.getComponent("key").checked;      // Pour checkbox
var value = step.getComponent("key").getValue();   // Pour textfield

// Activer/désactiver un composant
step.getComponent("key").setDisabled(true);
step.getComponent("key").setValue("nouvelle valeur");
```

### Script shell dynamique (install_uifile.sh)

Pour générer le wizard dynamiquement :

```bash
#!/bin/bash

quote_json() {
    sed -e 's|\\|\\\\|g' -e 's|\"|\\\"|g'
}

# Fonction JavaScript pour navigation conditionnelle
jsNavigate=$(/bin/cat<<EOF
{
    var currentStep = arguments[0];
    var wizardDialog = currentStep.owner;
    // Logique de navigation...
}
EOF
)

PAGE=$(/bin/cat<<EOF
{
    "step_title": "Mon Step",
    "deactivate_v2": "$(echo "$jsNavigate" | quote_json)",
    "items": [...]
}
EOF
)

echo "[$PAGE]" > "${SYNOPKG_TEMP_LOGFILE}"
```

### Accès aux valeurs dans les scripts

Les valeurs sont disponibles comme variables d'environnement :
```bash
# Dans postinst
if [ "${ext_mysqli}" = "true" ]; then
    echo "extension=mysqli.so" >> "$PHP_INI"
fi
```

### Sources

- [WIZARD_UIFILES 7.2.2 - Synology Developer Guide](https://help.synology.com/developer-guide/synology_package/wizard/WIZARD_UIFILES_v2.html)
- [SynoCommunity/spksrc - roundcube wizard](https://github.com/SynoCommunity/spksrc/blob/master/spk/roundcube/src/wizard/install_uifile.sh) - Exemple complet avec steps conditionnels

---

## 4. Interface DSM native (Application)

### Decision: Application ExtJS 3.4 avec fenêtre DSM

**Rationale**:
- DSM utilise ExtJS 3.4 nativement
- Fenêtre DSM native (pas onglet navigateur) via `dsmuidir`
- API CGI backend pour la gestion

**Configuration requise**:

**INFO file**:
```bash
dsmuidir="ui"
dsmappname="SYNO.SDS.PHP84Manager.Instance"
```

**ui/config** (JSON):
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

**Structure ui/**:
```
ui/
├── config                 # Définition application
├── PHP84Manager.js        # Code ExtJS principal
├── style.css              # Styles
├── images/icon_*.png      # Icônes (16,24,32,48,64,72)
└── cgi/
    ├── config.cgi         # Gestion configuration
    └── service.cgi        # Contrôle service
```

### API Service

```bash
# Redémarrage service (depuis CGI)
synopkg restart php84
# ou
systemctl restart pkg-php84-php-fpm.service
```

---

## 5. Extensions PHP 8.4

### Decision: ~100 extensions en shared (.so), catégorisées

**Catégories et extensions retenues**:

#### Base de données (15 extensions)
- mysqli, pdo_mysql, pdo_pgsql, pdo_sqlite, pgsql
- sqlite3, pdo, dba, odbc, pdo_odbc
- pdo_dblib, pdo_firebird (optionnelles)

#### Cache & Performance (6 extensions)
- opcache (recommandé par défaut)
- apcu, redis, memcached (PECL)
- igbinary, msgpack (PECL)

#### Texte & Encodage (5 extensions)
- mbstring (défaut), iconv, intl
- gettext, ctype

#### XML & Documents (8 extensions)
- xml, dom, simplexml, xmlreader, xmlwriter
- xsl, soap, libxml

#### Images (3 extensions)
- gd (défaut), exif
- imagick (PECL)

#### Compression (4 extensions)
- zlib (défaut), zip, bz2, zstd

#### Cryptographie (3 extensions)
- openssl (défaut), sodium
- hash (intégré)

#### Réseau (5 extensions)
- curl (défaut), ftp, sockets
- ldap, snmp

#### Système (6 extensions)
- pcntl, posix, shmop
- sysvmsg, sysvsem, sysvshm

#### Math (3 extensions)
- bcmath (défaut), gmp, decimal

#### Fichiers (3 extensions)
- fileinfo (défaut), filter, phar

#### Autres (5 extensions)
- calendar, tokenizer, readline
- tidy, enchant

#### PECL populaires (10 extensions)
- xdebug, mongodb, yaml
- swoole, grpc, protobuf
- ssh2, gnupg, timezonedb, trader

**Total**: ~76 extensions bundled + ~24 PECL = 100 extensions

### Dépendances par extension

| Extension | Bibliothèques requises |
|-----------|----------------------|
| mysqli | libmysqlclient / libmariadb |
| pdo_pgsql | libpq |
| gd | libpng, libjpeg, libfreetype, libwebp |
| curl | libcurl, libssl |
| intl | libicu (>= 69) |
| zip | libzip (>= 1.2.0) |
| mbstring | liboniguruma |
| xml/dom | libxml2 (>= 2.9.4) |
| xsl | libxslt |
| ldap | libldap, libsasl2 |
| imagick | ImageMagick libs |
| redis | hiredis (optionnel) |
| memcached | libmemcached |

---

## 6. Structure des fichiers SPK

### Decision: Structure conforme DSM 7

**Rationale**:
- DSM 7 impose `conf/privilege` obligatoire
- Chemins spécifiques pour données persistantes
- Service user dédié (pas root)

**Structure package.tgz**:
```
package.tgz/
├── INFO                          # Métadonnées
├── conf/
│   ├── privilege                 # OBLIGATOIRE DSM 7
│   └── resource                  # Config service
├── scripts/
│   ├── start-stop-status         # Contrôle service
│   ├── postinst                  # Post-installation
│   ├── preuninst                 # Pré-désinstallation
│   └── postupgrade               # Post-mise à jour
├── ui/                           # Application DSM
│   ├── config
│   ├── PHP84Manager.js
│   └── cgi/
└── target/                       # Fichiers applicatifs
    ├── bin/php
    ├── sbin/php-fpm
    ├── lib/php/modules/*.so      # Extensions
    └── etc/php/
        ├── php.ini
        ├── php-fpm.conf
        └── conf.d/               # Configs extensions
```

**conf/privilege**:
```json
{
  "defaults": {
    "run-as": "package"
  }
}
```

### Chemins DSM 7

| Variable | Chemin | Usage |
|----------|--------|-------|
| SYNOPKG_PKGDEST | /var/packages/php84/target | Binaires |
| SYNOPKG_PKGVAR | /var/packages/php84/var | Config utilisateur |
| SYNOPKG_PKGTMP | /volume1/@apptemp/php84 | Fichiers temp |

---

## 7. Versioning des packages

### Decision: Format 8.4.X-Y

**Rationale**:
- Conforme aux conventions Synology
- Permet plusieurs révisions par version PHP

**Exemple**:
- `8.4.15-1` : Première release de PHP 8.4.15
- `8.4.15-2` : Correction de bug dans le packaging
- `8.4.16-1` : Mise à jour vers PHP 8.4.16

**Dans INFO**:
```bash
version="8.4.15-1"
```

**Incrémentation automatique**:
Le script de build incrémentera automatiquement le dernier chiffre à chaque build.

---

## 8. Gestion des dépendances entre extensions

### Decision: Fichier JSON de métadonnées

**Structure** (`extensions.json`):
```json
{
  "mysqli": {
    "name": "mysqli",
    "category": "database",
    "description": "MySQL Improved Extension",
    "default": true,
    "depends": [],
    "conflicts": []
  },
  "pdo_mysql": {
    "name": "pdo_mysql",
    "category": "database",
    "description": "PDO MySQL Driver",
    "default": true,
    "depends": ["pdo"],
    "conflicts": []
  },
  "gd": {
    "name": "gd",
    "category": "image",
    "description": "Image Processing",
    "default": true,
    "depends": [],
    "conflicts": []
  }
}
```

**Logique de validation**:
1. À la sélection d'une extension, vérifier ses dépendances
2. Proposer d'activer automatiquement les dépendances manquantes
3. Empêcher la désactivation si d'autres extensions en dépendent

---

## 9. Workflow de build complet

### Étapes

1. **Préparation environnement Docker**
```bash
docker run -it --platform=linux/amd64 \
  -v $(pwd):/spksrc ghcr.io/synocommunity/spksrc /bin/bash
```

2. **Compilation des dépendances**
```bash
cd cross/openssl3 && make arch-geminilake-7.2
cd cross/libxml2 && make arch-geminilake-7.2
# ... autres dépendances
```

3. **Compilation PHP**
```bash
cd cross/php84 && make arch-geminilake-7.2
```

4. **Compilation extensions PECL**
```bash
cd cross/php84-redis && make arch-geminilake-7.2
# ... autres extensions
```

5. **Création du SPK**
```bash
cd spk/php84 && make arch-geminilake-7.2
```

6. **Vérification**
```bash
ls -la ../../packages/php84-*.spk
```

---

## 10. Tests et validation

### Checklist de validation

- [ ] Package s'installe sans erreur
- [ ] Wizard affiche toutes les extensions par catégorie
- [ ] Sélections wizard correctement appliquées
- [ ] Bouton "Ouvrir" lance fenêtre DSM native
- [ ] Interface affiche état correct des extensions
- [ ] Modification + redémarrage fonctionne
- [ ] php -m liste les extensions activées
- [ ] php-fpm démarre correctement
- [ ] Logs dans /var/packages/php84/var/log/

---

## 11. Privilèges DSM 7 - Configuration Non-Root

### Contexte et problématique

DSM 7 impose des restrictions strictes sur les privilèges des paquets tiers. Les paquets ne peuvent plus s'exécuter en tant que root par défaut, et toute demande de privilèges élevés nécessite une signature Synology ou un token de développement.

**Références officielles**:
- [Synology Developer Guide - Privilege](https://help.synology.com/developer-guide/privilege/preface.html)
- [Synology Developer Guide - Privilege Config](https://help.synology.com/developer-guide/privilege/privilege_config.html)
- [DSM 7 Support Framework Design (SynoCommunity)](https://github.com/SynoCommunity/spksrc/issues/4215)

### Structure du fichier conf/privilege

**Format complet documenté**:
```json
{
  "defaults": {
    "run-as": "package" | "root"
  },
  "username": "string",
  "groupname": "string",
  "ctrl-script": [{
    "action": "preinst|postinst|preuninst|postuninst|preupgrade|postupgrade|start|stop",
    "run-as": "package" | "root"
  }],
  "executable": [{
    "relpath": "string",
    "run-as": "package" | "root"
  }],
  "tool": [{
    "relpath": "string",
    "user": "string",
    "group": "string",
    "permission": "0755",
    "capabilities": "string"
  }]
}
```

### Options de run-as

| Valeur | Comportement |
|--------|-------------|
| `package` | Applique `chown` à l'utilisateur/groupe du paquet ; scripts exécutés avec UID du paquet |
| `root` | Applique `chown` à root ; scripts exécutés avec UID root (nécessite signature Synology) |

### Configuration minimale pour paquet non-root

Pour un paquet vraiment non-root, utiliser la configuration **la plus simple possible** :

```json
{
  "defaults": {
    "run-as": "package"
  }
}
```

**Important** : Ne PAS inclure `ctrl-script` avec `"run-as": "root"` car cela déclenche l'erreur "high privileges" pour les paquets non signés.

### Restrictions des paquets non-root

1. **Commandes interdites dans les scripts** :
   - `chown` - Changement de propriétaire (nécessite root)
   - `chmod` sur fichiers système
   - Création de symlinks dans `/usr/local/bin` ou `/usr/syno/`
   - Redémarrage de services système (nginx, etc.)

2. **Directives INFO interdites** :
   - `instuninst_restart_services` - Redémarre des services à l'install/désinstall
   - `startstop_restart_services` - Redémarre des services au start/stop

3. **Alternatives pour les opérations privilégiées** :
   - Utiliser `conf/resource` avec `usr-local-linker` pour les symlinks
   - Les permissions des fichiers dans `SYNOPKG_PKGVAR` sont gérées automatiquement par DSM

### Fichier conf/resource

Pour créer des symlinks dans `/usr/local/bin` sans privilèges root :

```json
{
  "usr-local-linker": {
    "bin": ["bin/php", "bin/phpize"],
    "sbin": ["sbin/php-fpm"]
  }
}
```

DSM créera automatiquement les symlinks lors de l'installation.

### Token de développement (workaround)

Pour les paquets nécessitant vraiment des privilèges root pendant le développement :

1. DSM > Support Center > Support Services
2. Cliquer "Generate Logs" → télécharge `debug.dat`
3. Extraire le token et le placer dans `/var/packages/syno_dev_token`

**Attention** : Cette méthode nécessite une intervention manuelle sur chaque NAS cible.

### Erreurs courantes et solutions

| Erreur | Cause | Solution |
|--------|-------|----------|
| "Package runs as root" | `ctrl-script` avec `run-as: root` | Supprimer ou utiliser `run-as: package` |
| "High privileges" | Demande de privilèges non autorisée | Simplifier conf/privilege |
| "Failed to chown" | chown dans postinst | Supprimer les commandes chown |
| "Permission denied" | chmod sur fichiers système | Utiliser uniquement SYNOPKG_PKGVAR |

### Exemple de paquet PHP-FPM non-root

**conf/privilege** (minimal) :
```json
{
  "defaults": {
    "run-as": "package"
  }
}
```

**conf/resource** :
```json
{
  "usr-local-linker": {
    "bin": ["bin/php", "bin/phpize", "bin/php-config", "bin/pecl"],
    "sbin": ["sbin/php-fpm"]
  }
}
```

**Points clés pour PHP-FPM** :
- Le socket doit être dans `SYNOPKG_PKGVAR/run/` (pas `/var/run/`)
- L'utilisateur PHP-FPM doit être l'utilisateur du paquet (`sc-php84`)
- Nginx doit être configuré manuellement pour utiliser le nouveau chemin de socket

### Sources additionnelles

- [DSM 7 Packages High Privileges Error](https://github.com/SynoCommunity/spksrc/issues/4170)
- [Package Root Bypass Discussion](https://github.com/SynologyOpenSource/pkgscripts-ng/issues/28)
- [Stack Overflow - Privileges Elevation DSM7](https://stackoverflow.com/questions/67968190/privileges-elevation-on-dsm7)
- [SynoForum - Deploy nginx config](https://www.synoforum.com/threads/how-to-deploy-a-nginx-config.5268/)
- [SynoCommunity Wiki - Service Support](https://github.com/SynoCommunity/spksrc/wiki/Service-Support)

---

## 12. Debugging du démarrage de paquet DSM 7

### Erreur courante : Code 272 "Failed to run script"

**Symptôme typique** :
```json
{
  "action": "start",
  "error": {
    "code": 272,
    "description": "Failed to run script, script=[start]"
  },
  "stage": "start_failed",
  "status": "start_failed",
  "status_code": 272,
  "status_description": "failed to start on previous startup"
}
```

### Causes identifiées pour PHP84

#### Problème 1 : Directive STARTSTOP_RESTART_SERVICE dans INFO.sh

**Fichier** : `spk/php84/src/INFO.sh` ligne 21
```bash
STARTSTOP_RESTART_SERVICE="nginx"  # INTERDIT pour paquets non-root!
```

**Explication** : Cette directive demande au système de redémarrer nginx lors du start/stop du paquet. Cette opération nécessite des privilèges root, ce qui est impossible pour un paquet avec `run-as: package`.

**Solution** : Supprimer complètement cette ligne ou la commenter.

#### Problème 2 : Commandes chown/chmod dans service-setup.sh

**Fichier** : `spk/php84/src/service-setup.sh` lignes 37-45
```bash
# Ces commandes ÉCHOUENT silencieusement sans privilèges root :
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${SYNOPKG_PKGVAR}" 2>/dev/null
chmod 755 "${SYNOPKG_PKGVAR}"
chmod 755 "${SYNOPKG_PKGVAR}/run"
# etc...
```

**Explication** : `chown` et `chmod` sur les répertoires système nécessitent des privilèges root. DSM 7 gère automatiquement les permissions pour `SYNOPKG_PKGVAR`.

**Solution** : Supprimer ces commandes. DSM 7 gère les permissions automatiquement.

#### Problème 3 : Script start-stop-status personnalisé

Le script `start-stop-status` personnalisé peut entrer en conflit avec le framework spksrc qui utilise `service-setup.sh`.

**Solution** : Choisir UNE méthode :
- Soit utiliser le framework spksrc avec `service-setup.sh` et `SERVICE_COMMAND`
- Soit utiliser un script `start-stop-status` personnalisé (sans `service-setup.sh`)

### Méthodes de debugging

#### 1. Exécution manuelle du script start

```bash
# Se connecter en SSH puis :
sudo /var/packages/php84/scripts/start-stop-status start
echo "Exit code: $?"
```

#### 2. Vérification des logs

```bash
# Logs du système de paquets
cat /var/log/synopkg.log | grep php84

# Logs du paquet (si créés)
cat /var/packages/php84/var/log/service.log

# Logs de PHP-FPM
cat /var/packages/php84/var/log/php-fpm.log
```

#### 3. Test de la configuration PHP-FPM

```bash
# Tester la configuration PHP-FPM
/var/packages/php84/target/sbin/php-fpm \
  -c /var/packages/php84/var/etc/php.ini \
  -y /var/packages/php84/var/etc/php-fpm.conf \
  -t
```

#### 4. Vérification des permissions

```bash
# Vérifier les permissions du répertoire var
ls -la /var/packages/php84/var/

# Vérifier l'utilisateur du paquet
id sc-php84
```

#### 5. Vérification de l'existence des fichiers de config

```bash
# Ces fichiers DOIVENT exister après postinst
ls -la /var/packages/php84/var/etc/php.ini
ls -la /var/packages/php84/var/etc/php-fpm.conf
ls -la /var/packages/php84/var/etc/php-fpm.d/www.conf
```

### Codes de retour du script start-stop-status

| Code | Signification |
|------|---------------|
| 0 | Paquet en cours d'exécution |
| 1 | Programme mort, fichier PID existe dans `/var/run` |
| 2 | Programme mort, fichier verrou existe dans `/var/lock` |
| 3 | Paquet non actif |
| 4 | État indéterminé |
| 150 | Paquet corrompu, réinstallation requise |

### Configuration service-setup.sh correcte pour DSM 7

**Version corrigée sans commandes privilégiées** :

```bash
#!/bin/bash
# Service configuration for spksrc framework

SERVICE_COMMAND="${SYNOPKG_PKGDEST}/sbin/php-fpm"
SERVICE_COMMAND_ARGS="-c ${SYNOPKG_PKGVAR}/etc/php.ini -y ${SYNOPKG_PKGVAR}/etc/php-fpm.conf"

# PHP-FPM gère son propre fichier PID
SVC_WRITE_PID=no
SVC_BACKGROUND=no

# PID file location
PID_FILE="${SYNOPKG_PKGVAR}/run/php-fpm.pid"

service_prestart() {
    # Créer les répertoires (DSM gère les permissions automatiquement)
    mkdir -p "${SYNOPKG_PKGVAR}/run"
    mkdir -p "${SYNOPKG_PKGVAR}/log"
    mkdir -p "${SYNOPKG_PKGVAR}/tmp"

    # NE PAS utiliser chown ou chmod !

    # Vérifier la configuration
    if [ ! -f "${SYNOPKG_PKGVAR}/etc/php-fpm.conf" ]; then
        echo "ERROR: PHP-FPM configuration not found"
        return 1
    fi

    return 0
}
```

### Variables d'environnement disponibles

| Variable | Description |
|----------|-------------|
| `SYNOPKG_PKGNAME` | Nom du paquet (php84) |
| `SYNOPKG_PKGDEST` | Répertoire d'installation (`/var/packages/php84/target`) |
| `SYNOPKG_PKGVAR` | Répertoire de données utilisateur (`/var/packages/php84/var`) |
| `SYNOPKG_PKGBASE` | Répertoire de base (`/var/packages/php84`) |
| `SYNOPKG_PKGHOME` | Répertoire home (`/var/packages/php84/home`) |

### Checklist de résolution

- [ ] Supprimer `STARTSTOP_RESTART_SERVICE` de INFO.sh
- [ ] Supprimer les commandes `chown` et `chmod` de service-setup.sh
- [ ] Vérifier que php-fpm.conf et php.ini sont créés dans postinst
- [ ] S'assurer que le répertoire php-fpm.d/ existe avec www.conf
- [ ] Vérifier les permissions du binaire php-fpm (doit être exécutable)
- [ ] Tester manuellement la commande php-fpm avec ses arguments
- [ ] Vérifier les logs pour identifier l'erreur exacte

### Sources additionnelles

- [Stack Overflow - Package won't start/stop](https://stackoverflow.com/questions/69856156/package-wont-start-stop-in-synology-dms-7-0-1-when-using-synopkg)
- [SynoCommunity - DSM 7 support framework design](https://github.com/SynoCommunity/spksrc/issues/4215)
- [SynoCommunity - High privileges error](https://github.com/SynoCommunity/spksrc/issues/4170)
- [Synology Developer Guide - Scripts](https://help.synology.com/developer-guide/synology_package/scripts.html)
- [Synology Developer Guide - Breaking Changes](https://help.synology.com/developer-guide/breaking_changes.html)

---

## Sources

- [SynoCommunity/spksrc GitHub](https://github.com/SynoCommunity/spksrc)
- [spksrc Wiki - DSM 7.0](https://github.com/SynoCommunity/spksrc/wiki/DSM-7.0)
- [spksrc Wiki - Service Support](https://github.com/SynoCommunity/spksrc/wiki/Service-Support)
- [Synology Developer Guide DSM 7](https://help.synology.com/developer-guide/)
- [Synology Developer Guide - Privilege](https://help.synology.com/developer-guide/privilege/preface.html)
- [Synology Developer Guide - Privilege Config](https://help.synology.com/developer-guide/privilege/privilege_config.html)
- [Synology Developer Guide - Scripts](https://help.synology.com/developer-guide/synology_package/scripts.html)
- [Synology Developer Guide - Breaking Changes](https://help.synology.com/developer-guide/breaking_changes.html)
- [WIZARD_UIFILES Documentation](https://help.synology.com/developer-guide/synology_package/wizard/WIZARD_UIFILES_v2.html)
- [PHP 8.4 Extensions Manual](https://www.php.net/manual/en/extensions.php)
- [PHP Configure Options](https://www.php.net/manual/en/configure.about.php)
- [DigitalBox98/SimpleExtJSApp](https://github.com/DigitalBox98/SimpleExtJSApp)
