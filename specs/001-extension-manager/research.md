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

### Decision: Application ExtJS avec fenêtre DSM native

**IMPORTANT - Découverte DSM 7.2** (2025-11-27):
DSM 7.x utilise une version hybride d'ExtJS supportant à la fois la syntaxe ExtJS 3 (`Ext.extend`) et ExtJS 4+ (`Ext.define`). Pour les applications natives DSM, il est **recommandé d'utiliser `Ext.define`** car c'est le pattern utilisé par les applications Synology officielles et les démos.

**Sources de référence**:
- [DSM7DemoSPK](https://github.com/toafez/DSM7DemoSPK) - Demo officielle DSM 7
- [SimpleExtJSApp](https://github.com/DigitalBox98/SimpleExtJSApp) - Application ExtJS exemple
- [SynoAppsDocs](https://github.com/DigitalBox98/SynoAppsDocs) - Documentation framework

### Configuration ui/config DSM 7 (Format correct)

Le fichier `ui/config` doit définir **trois entrées** minimum :

```json
{
    "PHP84Manager.js": {
        "SYNO.SDS.PHP84Manager.Application": {
            "type": "app",
            "title": "PHP 8.4 Extension Manager",
            "appWindow": "SYNO.SDS.PHP84Manager.MainWindow",
            "desc": "Gestionnaire d'extensions PHP 8.4",
            "icon": "images/php84_{0}.png",
            "allowMultiInstance": false,
            "allowStandalone": true,
            "allowSharing": false,
            "allUsers": true,
            "grantPrivilege": "all",
            "advanceGrantPrivilege": true,
            "depend": ["SYNO.SDS.PHP84Manager.MainWindow"]
        },
        "SYNO.SDS.PHP84Manager.MainWindow": {
            "type": "lib",
            "title": "PHP 8.4 Extension Manager",
            "icon": "images/php84_{0}.png",
            "depend": ["SYNO.SDS.PHP84Manager.Utils"]
        },
        "SYNO.SDS.PHP84Manager.Utils": []
    }
}
```

**Propriétés importantes**:

| Propriété | Description |
|-----------|-------------|
| `type: "app"` | Application principale (affichée dans le menu) |
| `type: "lib"` | Bibliothèque/fenêtre (non affichée dans le menu) |
| `appWindow` | Classe de la fenêtre principale |
| `depend` | Dépendances de classes (ordre de chargement) |
| `allowMultiInstance` | Autoriser plusieurs fenêtres |
| `grantPrivilege` | "all" pour tous les privilèges |
| `advanceGrantPrivilege` | Autoriser privilèges avancés |

### Structure JavaScript DSM 7 (Format correct)

**IMPORTANT**: Utiliser `Ext.define` au lieu de `Ext.extend` !

```javascript
// Déclarer le namespace Utils (OBLIGATOIRE)
Ext.namespace("SYNO.SDS.PHP84Manager.Utils");

// Application principale
Ext.define("SYNO.SDS.PHP84Manager.Application", {
    extend: "SYNO.SDS.AppInstance",
    appWindowName: "SYNO.SDS.PHP84Manager.MainWindow",
    constructor: function() {
        this.callParent(arguments);
    }
});

// Fenêtre principale
Ext.define("SYNO.SDS.PHP84Manager.MainWindow", {
    extend: "SYNO.SDS.AppWindow",
    constructor: function(config) {
        this.appInstance = config.appInstance;
        // Appeler le parent avec la config ExtJS 3 style
        SYNO.SDS.PHP84Manager.MainWindow.superclass.constructor.call(this, Ext.apply({
            layout: "fit",
            resizable: true,
            maximizable: true,
            minimizable: true,
            width: 900,
            height: 600,
            // Contenu via iframe (recommandé) ou HTML direct
            html: SYNO.SDS.PHP84Manager.Utils.getMainHtml()
        }, config));
    },

    onOpen: function() {
        SYNO.SDS.PHP84Manager.MainWindow.superclass.onOpen.apply(this, arguments);
    },

    onClose: function() {
        SYNO.SDS.PHP84Manager.MainWindow.superclass.onClose.apply(this, arguments);
        this.doClose();
        return true;
    }
});

// Utilitaires
Ext.apply(SYNO.SDS.PHP84Manager.Utils, function() {
    return {
        getMainHtml: function() {
            // iframe avec timestamp anti-cache
            return '<iframe src="webman/3rdparty/php84/index.cgi?t=' +
                   new Date().getTime() +
                   '" style="width:100%;height:100%;border:none;margin:0"/>';
        }
    };
}());
```

### Architecture recommandée DSM 7

**Option 1: iframe (Recommandée)**
- L'application DSM charge un iframe
- Le contenu est une page CGI/HTML standard
- Plus simple à développer et déboguer
- Moins de contraintes ExtJS

**Option 2: ExtJS natif complet**
- Composants ExtJS purs dans la fenêtre
- Plus complexe mais meilleure intégration DSM
- Nécessite connaissance approfondie d'ExtJS

### INFO file (dsmappname)

```bash
dsmuidir="ui"
dsmappname="SYNO.SDS.PHP84Manager.Application"
```

**IMPORTANT**: `dsmappname` doit correspondre exactement au nom de la classe `type: "app"` dans le config !

### Structure ui/ complète

```
ui/
├── config                    # Définition application (JSON)
├── PHP84Manager.js           # Classes ExtJS
├── style.css                 # Styles (optionnel)
├── index.cgi                 # Page principale (si iframe)
├── images/
│   ├── php84_16.png          # Icônes multiples tailles
│   ├── php84_24.png
│   ├── php84_32.png
│   ├── php84_48.png
│   ├── php84_64.png
│   └── php84_72.png
└── cgi/
    ├── extensions.cgi        # API extensions
    └── service.cgi           # API service

```

### Debugging problème "chargement infini"

Si l'application affiche une barre de chargement infinie :

1. **Vérifier la console navigateur** (F12) pour erreurs JavaScript
2. **Vérifier le format config** - doit avoir les 3 entrées (app, lib, utils)
3. **Vérifier le JavaScript** - utiliser `Ext.define` pas `Ext.extend`
4. **Vérifier les dépendances** - chaîne `depend` correcte
5. **Vérifier dsmappname** - doit correspondre au nom de classe `type: "app"`

### API Service

```bash
# Redémarrage service (depuis CGI)
synopkg restart php84
# ou
systemctl restart pkg-php84-php-fpm.service
```

### Changements DSM 7.2 (IMPORTANT)

**Breaking Change DSM 7.2** : Synology a désactivé le paramètre `type=legacy` qui permettait aux applications tierces de s'afficher dans des fenêtres iframe intégrées au bureau DSM. Selon le support technique Synology :

> "the legacy is not supported since DSM7.2 due to security concerns"

**Workaround** : Créer une application ExtJS qui génère un élément iframe en interne. C'est exactement ce que fait DSM7DemoSPK et FileBot.

**Configuration privilege requise pour DSM 7.2** :
```json
{
    "defaults": {
        "run-as": "package"
    },
    "username": "packagename",
    "join-groupname": "system"
}
```

### Exécution de scripts CGI dans webman/3rdparty (CRITIQUE)

**IMPORTANT** : Le serveur web DSM (nginx sur port 5000/5001) n'a **PAS** de module PHP chargé. Les fichiers PHP ne sont pas exécutés - le code source brut est affiché.

**Solutions pour exécuter du code dans webman/3rdparty** :

#### Option 1 : Script Bash CGI (Recommandé - utilisé par DSM7DemoSPK)

```bash
#!/bin/bash
# index.cgi

# Authentication
syno_login=$(/usr/syno/synoman/webman/login.cgi)
if ! echo ${syno_login} | grep -q '"success":true'; then
    echo "Content-type: text/html"
    echo ""
    echo "Access denied"
    exit
fi

# Generate HTML
echo "Content-type: text/html; charset=UTF-8"
echo ""
echo "<!DOCTYPE html><html><body>"
echo "<h1>Mon Application</h1>"
# ... génération HTML via echo ...
echo "</body></html>"
```

#### Option 2 : CGI Router pour PHP

Pour exécuter du PHP, il faut un "router CGI" bash qui appelle `php-cgi` :

```bash
#!/bin/bash
# router.cgi
export REDIRECT_STATUS=1
export SCRIPT_FILENAME="/var/packages/myapp/target/ui/page.php"
/usr/bin/php-cgi -d open_basedir=none "$SCRIPT_FILENAME"
```

**Configuration nginx requise** (nécessite privilèges root - difficile en DSM 7) :

```nginx
location ~ ^/webman/3rdparty/myapp/.*\.php {
    root /usr/syno/synoman;
    include scgi_params;
    rewrite .*\.php /webman/3rdparty/myapp/router.cgi break;
    scgi_pass synoscgi;
}
```

Fichier à placer dans `/usr/syno/share/nginx/conf.d/` (nécessite root).

#### Option 3 : Bash qui appelle PHP CLI

```bash
#!/bin/bash
# index.cgi
echo "Content-type: text/html; charset=UTF-8"
echo ""
/usr/bin/php /var/packages/myapp/target/ui/page.php
```

**Note** : Les warnings PHP s'afficheront avant le HTML.

### Authentification DSM

Vérifier l'authentification utilisateur :

```bash
# Méthode 1 : login.cgi (retourne JSON)
syno_login=$(/usr/syno/synoman/webman/login.cgi)

# Méthode 2 : authenticate.cgi (retourne username si connecté)
user=$(/usr/syno/synoman/webman/modules/authenticate.cgi)
```

### Structure recommandée pour index.cgi (Bash)

Basé sur DSM7DemoSPK :

```bash
#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin

app_name="php84"

# Auth check
syno_login=$(/usr/syno/synoman/webman/login.cgi)
login_success=$(echo "${syno_login}" | grep -o '"success":[^,]*' | cut -d: -f2)
[[ "${login_success}" != "true" ]] && { echo "Access denied"; exit; }

# HTML output
echo "Content-type: text/html; charset=UTF-8"
echo ""
cat << 'HTML'
<!DOCTYPE html>
<html>
<head><title>PHP 8.4 Extension Manager</title></head>
<body>
<!-- Interface HTML ici -->
</body>
</html>
HTML
```

### Sources DSM 7 App Development

- [DSM7DemoSPK GitHub](https://github.com/toafez/DSM7DemoSPK) - **RÉFÉRENCE PRINCIPALE**
- [Desktop Application Guide](https://help.synology.com/developer-guide/integrate_dsm/desktopapp.html)
- [Application Config Guide](https://help.synology.com/developer-guide/integrate_dsm/config.html)
- [Application Authentication](https://help.synology.com/developer-guide/integrate_dsm/web_authentication.html)
- [SynoForum DSM UI Framework](https://www.synoforum.com/threads/dsm-ui-framework.7779/)
- [SynoForum nginx config](https://www.synoforum.com/threads/how-to-deploy-a-nginx-config.5268/)
- [DSM CGI Router Wiki](https://github.com/vletroye/SynoPackages/wiki/DSM-CGI-Router-6.x)
- [SimpleExtJSApp GitHub](https://github.com/DigitalBox98/SimpleExtJSApp)
- [FileBot DSM 7.2 Solution](https://www.filebot.net/forums/viewtopic.php?t=13826)
- [Rob's Embedded PHP App](http://www.robvanaarle.com/blog/2014/08/embedded-php-app-without-dependencies-for-synology-nas/)

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

## 13. Authentification CGI pour DSM 7 (CRITIQUE)

### Contexte et mécanisme

DSM utilise un système d'authentification basé sur les cookies de session et un token CSRF (SynoToken). Pour les applications tierces accessibles via `webman/3rdparty/`, il est **obligatoire** de vérifier l'authentification de l'utilisateur.

**Documentation officielle** : [Application Authentication](https://help.synology.com/developer-guide/integrate_dsm/web_authentication.html)

### Le script authenticate.cgi

Le script `/usr/syno/synoman/webman/modules/authenticate.cgi` est la méthode officielle pour vérifier l'authentification :

- **Retour** : Le nom d'utilisateur si connecté, **rien** si non authentifié
- **Prérequis** : Variables d'environnement HTTP correctement configurées

### Variables d'environnement requises

Pour que `authenticate.cgi` fonctionne correctement, les variables suivantes doivent être présentes :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `HTTP_COOKIE` | Cookie de session DSM | `id=I716T8OPG6qVIM6A6Y6N7X4803` |
| `HTTP_X_SYNO_TOKEN` | Token CSRF (header) | `9WuK4Cf50Vw7Q` |
| `QUERY_STRING` | Paramètres GET (avec SynoToken) | `SynoToken=9WuK4Cf50Vw7Q` |
| `REMOTE_ADDR` | Adresse IP du client | `192.168.1.100` |
| `SERVER_ADDR` | Adresse IP du serveur | `192.168.1.1` |

**Important** : Lorsque le CGI est appelé depuis le serveur web DSM (nginx/scgi), ces variables sont **automatiquement** définies. Le problème survient lors d'appels manuels en CLI.

### Obtenir le SynoToken

Le SynoToken peut être obtenu de deux façons :

#### 1. Via login.cgi (depuis le navigateur)
```bash
curl "http://nas:5000/webman/login.cgi"
# Retourne: {"SynoToken": "9WuK4Cf50Vw7Q", "result": "success", "success": true}
```

#### 2. Via l'API SYNO.API.Auth
```bash
curl "https://nas:5001/webapi/auth.cgi?api=SYNO.API.Auth&version=3&method=login&account=admin&passwd=password&format=cookie"
```

### Transmission du SynoToken

Le token peut être transmis de deux manières :

1. **Query string** : `?SynoToken=9WuK4Cf50Vw7Q`
2. **Header HTTP** : `X-SYNO-TOKEN: 9WuK4Cf50Vw7Q`

### Implémentation Bash CGI (Recommandée)

```bash
#!/bin/bash
# authenticate.cgi retourne le username si connecté, rien sinon

# Méthode 1 : Appel direct (variables d'env héritées du serveur web)
user=$(/usr/syno/synoman/webman/modules/authenticate.cgi)

if [ -z "$user" ]; then
    echo "Content-type: text/html"
    echo ""
    echo "Access denied"
    exit 1
fi

# L'utilisateur est authentifié, continuer...
echo "Content-type: text/html"
echo ""
echo "Hello $user"
```

### Implémentation PHP (via CGI wrapper)

```php
<?php
// Méthode recommandée : passer les variables d'environnement
$synoToken = $_GET['SynoToken'] ?? '';
putenv('QUERY_STRING=SynoToken=' . $synoToken);

$user = shell_exec('/usr/syno/synoman/webman/modules/authenticate.cgi');

if (empty(trim($user))) {
    http_response_code(403);
    die('Access denied');
}

// Utilisateur authentifié
echo "Hello " . htmlspecialchars($user);
```

### Alternative : login.cgi pour vérification simple

Pour une vérification simple sans récupérer le username :

```bash
#!/bin/bash
syno_login=$(/usr/syno/synoman/webman/login.cgi)

# Vérifier si "success":true est présent
if echo "$syno_login" | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
    # Authentifié
    echo "OK"
else
    # Non authentifié
    echo "Access denied"
    exit 1
fi
```

**Attention** : `login.cgi` retourne JSON avec `"success": true` si connecté, mais nécessite que les cookies soient transmis.

### Problèmes courants et solutions

#### Problème 1 : "Access denied" même depuis DSM

**Cause** : Les cookies de session ne sont pas transmis dans l'iframe.

**Solution** : Vérifier que l'iframe utilise le même domaine/port que DSM :
```javascript
src: 'webman/3rdparty/php84/index.cgi'  // Chemin relatif, même origine
```

#### Problème 2 : authenticate.cgi ne retourne rien

**Cause** : Variables d'environnement manquantes (HTTP_COOKIE, QUERY_STRING).

**Solution** : S'assurer que le CGI est appelé via le serveur web, pas directement en CLI.

**Test en CLI** (simuler l'environnement) :
```bash
HTTP_COOKIE="id=VOTRE_SESSION_ID" \
QUERY_STRING="SynoToken=VOTRE_TOKEN" \
REMOTE_ADDR="127.0.0.1" \
/usr/syno/synoman/webman/modules/authenticate.cgi
```

#### Problème 3 : grep -oP non disponible (busybox)

**Cause** : Synology utilise busybox qui n'a pas les regex Perl.

**Solution** : Utiliser sed au lieu de grep -oP :
```bash
# Au lieu de :
# action=$(echo "$POST_DATA" | grep -oP 'action=\K[^&]*')

# Utiliser :
action=$(echo "$POST_DATA" | sed -n 's/.*action=\([^&]*\).*/\1/p')
```

#### Problème 4 : POST requests échouent silencieusement

**Cause** : CONTENT_LENGTH non défini ou read échoue.

**Solution** :
```bash
if [ "$REQUEST_METHOD" = "POST" ]; then
    if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ]; then
        read -n "$CONTENT_LENGTH" POST_DATA
    fi
    # Traiter POST_DATA...
fi
```

### synoAuth - Solution tierce

Le projet [synoAuth](https://github.com/kavod/synoAuth) fournit une API d'authentification réutilisable :

**Endpoint** : `/webman/3rdparty/synoAuth/?SynoToken=XXX`

**Retour JSON** :
```json
{
    "username": "admin",
    "usergroups": ["administrators", "users"]
}
```

**Validation** : Le token est validé contre l'adresse IP et le cookie de session.

### Projets de référence pour l'authentification

| Projet | Type | Description |
|--------|------|-------------|
| [DSM7DemoSPK](https://github.com/toafez/DSM7DemoSPK) | Bash CGI | Demo officieuse DSM 7, authentification via login.cgi |
| [SimpleExtJSApp](https://github.com/DigitalBox98/SimpleExtJSApp) | Multi-langage | Exemples Python, Perl, Bash avec authenticate.cgi |
| [synoAuth](https://github.com/kavod/synoAuth) | Python/JS | API d'authentification réutilisable |
| [ultimo-synology-ds](https://github.com/robvanaarle/ultimo-synology-ds) | PHP | SDK PHP pour Synology avec auth |
| [filebot-node](https://github.com/filebot/filebot-node) | Node.js | Application DSM avec auth complète |

### Script CGI complet avec authentification robuste

```bash
#!/bin/bash
# Authentification DSM 7 compatible - Multi-méthodes

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/syno/bin:/usr/syno/sbin

AUTH_OK="false"

# Méthode 1 : authenticate.cgi (méthode officielle)
if [ "$AUTH_OK" = "false" ]; then
    user=$(/usr/syno/synoman/webman/modules/authenticate.cgi 2>/dev/null)
    if [ -n "$user" ]; then
        AUTH_OK="true"
        AUTH_USER="$user"
    fi
fi

# Méthode 2 : login.cgi (fallback)
if [ "$AUTH_OK" = "false" ]; then
    syno_login=$(/usr/syno/synoman/webman/login.cgi 2>/dev/null)
    if echo "$syno_login" | grep -q '"success"'; then
        AUTH_OK="true"
    fi
fi

# Méthode 3 : Vérifier cookie de session DSM
if [ "$AUTH_OK" = "false" ] && [ -n "$HTTP_COOKIE" ]; then
    if echo "$HTTP_COOKIE" | grep -qE '(^|;)[[:space:]]*id='; then
        AUTH_OK="true"
    fi
fi

# Refuser si non authentifié
if [ "$AUTH_OK" = "false" ]; then
    echo "Content-type: application/json"
    echo ""
    echo '{"error": "Access denied", "authenticated": false}'
    exit 1
fi

# Continuer avec le traitement normal...
echo "Content-type: text/html"
echo ""
echo "Authenticated as: ${AUTH_USER:-unknown}"
```

### Recommandations finales

1. **Toujours tester depuis le navigateur** - Les tests CLI nécessitent de simuler l'environnement web complet

2. **Utiliser des chemins relatifs dans les iframes** - `webman/3rdparty/pkg/` au lieu de chemins absolus

3. **Logger les erreurs** - Ajouter des logs pour le debugging :
   ```bash
   echo "[$(date)] Auth check: HTTP_COOKIE=$HTTP_COOKIE" >> /tmp/myapp-debug.log
   ```

4. **Privilégier authenticate.cgi** - Plus fiable que login.cgi pour obtenir le username

5. **Gérer les timeouts de session** - Les sessions DSM expirent, prévoir un message user-friendly

### Sources

- [Synology Developer Guide - Web Authentication](https://help.synology.com/developer-guide/integrate_dsm/web_authentication.html)
- [Synology DSM Web Authentication with PHP](http://www.robvanaarle.com/blog/2014/08/synology-dsm-web-authentication-with-php/)
- [DSM Login Web API Guide (PDF)](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Os/DSM/All/enu/DSM_Login_Web_API_Guide_enu.pdf)
- [GitHub - synoAuth](https://github.com/kavod/synoAuth)
- [GitHub - DSM7DemoSPK](https://github.com/toafez/DSM7DemoSPK)
- [GitHub - SimpleExtJSApp](https://github.com/DigitalBox98/SimpleExtJSApp)
- [Synology Forum - Authentication in DSM 6](https://forum.synology.com/enu/viewtopic.php?t=122283)
- [SynoForum - How to open SPK for DSM 7.0](https://www.synoforum.com/threads/how-to-open-spk-for-dsm-7-0.5261/)
- [GitHub - DSM CGI Router](https://github.com/vletroye/SynoPackages/wiki/DSM-CGI-Router-6.x)

---

## 14. Permissions CGI et ecriture de fichiers dans DSM 7 (CRITIQUE)

### Probleme identifie : Le CGI ne peut pas ecrire de fichiers

**Symptome** : Lors du clic sur un toggle pour activer/desactiver une extension, l'operation echoue silencieusement ou retourne une erreur de permission.

**Cause racine** : Les scripts CGI dans DSM 7 s'executent sous l'utilisateur **'http'** et non sous l'utilisateur du package (sc-php84).

### Architecture d'execution des CGI dans DSM 7

| Composant | Description |
|-----------|-------------|
| Serveur web | nginx (depuis DSM 6.x) |
| Handler CGI | synoscgi via socket `/run/synoscgi.sock` |
| Utilisateur CGI | **'http'** (et non root ou sc-packagename) |
| Processus | synocgid (sessions) + synoscgi (dispatch) |

**Flux de requete HTTP** :
```
Navigateur → nginx:5000/5001 → synoscgi → script CGI (user: http)
```

**Reference** : [A Journey into Synology NAS — Part 4: HTTP Request Processing Flow](https://medium.com/@cq674350529/a-journey-into-synology-nas-part-4-http-request-processing-flow-and-vulnerability-analysis-c415dea89aaf)

### Pourquoi le CGI ne peut pas ecrire

Le repertoire `/var/packages/php84/var/etc/conf.d/` appartient a l'utilisateur `sc-php84` avec des permissions standard (755). L'utilisateur `http` n'a pas les droits d'ecriture sur ce repertoire.

```bash
# Structure des permissions par defaut
/var/packages/php84/var/         # Appartient a sc-php84:sc-php84
/var/packages/php84/var/etc/     # Appartient a sc-php84:sc-php84 (755)
/var/packages/php84/var/etc/conf.d/  # Appartient a sc-php84:sc-php84 (755)
```

### Solutions possibles

#### Solution 1 : Permissions chmod 777 sur conf.d (SIMPLE)

Dans le script `postinst`, creer le repertoire `conf.d` avec des permissions ouvertes :

```bash
# Dans postinst ou service_postinst()
mkdir -p "${SYNOPKG_PKGVAR}/etc/conf.d"
chmod 777 "${SYNOPKG_PKGVAR}/etc/conf.d"
```

**Avantages** :
- Simple a implementer
- Fonctionne immediatement

**Inconvenients** :
- Securite reduite (tout utilisateur peut ecrire)
- Les fichiers crees appartiennent a 'http'

#### Solution 2 : ACL avec setfacl (RECOMMANDEE)

Utiliser les ACL pour donner les droits d'ecriture specifiquement a l'utilisateur 'http' :

```bash
# Dans postinst
mkdir -p "${SYNOPKG_PKGVAR}/etc/conf.d"
setfacl -m u:http:rwx "${SYNOPKG_PKGVAR}/etc/conf.d"
setfacl -d -m u:http:rw "${SYNOPKG_PKGVAR}/etc/conf.d"  # Default pour nouveaux fichiers
```

**Avantages** :
- Plus securise (droits specifiques a 'http')
- Les permissions standard restent 755

**Inconvenients** :
- `setfacl` peut ne pas etre disponible sur tous les NAS
- Complexite supplementaire

**Verification** :
```bash
getfacl /var/packages/php84/var/etc/conf.d
```

#### Solution 3 : Groupe partage (COMPLEXE)

Ajouter l'utilisateur 'http' au groupe du package ou vice-versa.

```bash
# Dans postinst (necessite privileges)
usermod -a -G http sc-php84
# ou
usermod -a -G sc-php84 http
```

**Note** : Cette approche est limitee car DSM 7 restreint les modifications de groupes pour les packages non-root.

#### Solution 4 : Service backend avec socket (AVANCEE)

Au lieu d'ecrire directement depuis le CGI, utiliser un service backend qui s'execute sous sc-php84 :

1. Le CGI envoie des commandes via un socket Unix
2. Un service daemon (sous sc-php84) ecoute le socket
3. Le service effectue les operations de fichiers

```bash
# Architecture
CGI (http) --socket--> Service (sc-php84) --write--> conf.d/
```

**Reference** : [DSM7DemoSPK](https://github.com/toafez/DSM7DemoSPK) utilise une approche similaire avec `app_permissions.sh`.

### Configuration privilege pour permettre chmod dans postinst

Le fichier `conf/privilege` doit permettre au script postinst de modifier les permissions :

```json
{
  "defaults": {
    "run-as": "package"
  }
}
```

**Important** : Les commandes `chmod` sont generalement autorisees dans postinst car elles s'appliquent aux fichiers du package. Seul `chown` est restreint pour les packages non-root.

### Test de verification

Pour verifier si le CGI peut ecrire :

```bash
# En SSH sur le NAS
sudo -u http touch /var/packages/php84/var/etc/conf.d/test.ini
# Si erreur "Permission denied" → Le probleme est confirme
```

### Implementation recommandee pour PHP84

**Modification de `postinst` ou `service-setup.sh`** :

```bash
service_postinst() {
    # Creer les repertoires de configuration
    mkdir -p "${SYNOPKG_PKGVAR}/etc/conf.d"

    # SOLUTION : Permettre a l'utilisateur 'http' d'ecrire dans conf.d
    # Option A : chmod 777 (simple mais moins securise)
    chmod 777 "${SYNOPKG_PKGVAR}/etc/conf.d"

    # Option B : setfacl (plus securise si disponible)
    # if command -v setfacl >/dev/null 2>&1; then
    #     setfacl -m u:http:rwx "${SYNOPKG_PKGVAR}/etc/conf.d"
    #     setfacl -d -m u:http:rw "${SYNOPKG_PKGVAR}/etc/conf.d"
    # else
    #     chmod 777 "${SYNOPKG_PKGVAR}/etc/conf.d"
    # fi

    # Copier les fichiers de configuration par defaut...
}
```

### Autres packages affectes par ce probleme

| Package | Solution utilisee |
|---------|-------------------|
| Config File Editor | Non compatible DSM 7 |
| SABnzbd | Permissions manuelles via DSM |
| Radarr/Sonarr | System internal user permissions |
| DSM7DemoSPK | Script app_permissions.sh avec Task Scheduler |

### Comportement specifique DSM 7 avec les ACL

- DSM 7 utilise un systeme hybride ACL/Unix permissions
- Les ACL sont prioritaires sur les permissions Unix
- Le caractere '+' dans `ls -l` indique des ACL actives
- `synoacltool` permet de manipuler les ACL specifiques a Synology

```bash
# Supprimer les ACL d'un repertoire
synoacltool -del /var/packages/php84/var/etc/conf.d

# Verifier les ACL
synoacltool -get /var/packages/php84/var/etc/conf.d
```

### Sources section 14

- [SynoForum - DSM 7 New permissions issues](https://www.synoforum.com/threads/dsm-7-new-permissions-issues.9090/)
- [SynoCommunity Wiki - Permission Management](https://github.com/SynoCommunity/spksrc/wiki/Permission-Management)
- [SynoCommunity Issue #4215 - DSM 7 support framework design](https://github.com/SynoCommunity/spksrc/issues/4215)
- [SynoForum - How to deploy nginx config](https://www.synoforum.com/threads/how-to-deploy-a-nginx-config.5268/)
- [GitHub - DSM CGI Router 6.x](https://github.com/vletroye/SynoPackages/wiki/DSM-CGI-Router-6.x)
- [Stack Overflow - Privileges elevation on DSM7](https://stackoverflow.com/questions/67968190/privileges-elevation-on-dsm7)
- [SynoForum - chmod not working DSM 7.1](https://www.synoforum.com/threads/chmod-not-working-all-files-and-folders-777.10421/)
- [Config File Editor pour DSM](https://www.sil51.com/informatique/nas-synology/config-file-editor-pour-dsm.html)

---

## 15. Redemarrage de service depuis CGI dans DSM 7 (CRITIQUE)

### Probleme identifie : Le CGI ne peut pas redemarrer le service

**Symptome** : Lors du clic sur "Apply & Restart", le toggle fonctionne mais le redemarrage du service echoue avec l'erreur 263.

**Cause racine** : Le script CGI s'execute en tant que l'utilisateur `http`. Cet utilisateur n'a pas les permissions pour executer `synopkg restart`.

```bash
# Test de permission
sudo -u http /usr/syno/bin/synopkg restart php84
# Resultat: Failed to restart package [php84], err=[263]
```

### Solutions possibles

#### Solution 1 : API SYNO.Core.Package.Control (RECOMMANDEE)

Synology expose une API Web pour controler les packages. Cette API peut etre appelee depuis le CGI avec les cookies de session existants.

**API disponible** :
- Endpoint : `/webapi/entry.cgi`
- API : `SYNO.Core.Package.Control`
- Methodes : `start`, `stop` (pas de `restart` direct)
- Authentification : Necessite `authLevel: 1` (admin)
- SynoToken : Requis pour protection CSRF

**Implementation** :

```bash
# 1. Obtenir le SynoToken depuis login.cgi
SYNO_TOKEN=$(/usr/syno/synoman/webman/login.cgi 2>/dev/null | grep -o '"SynoToken"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)

# 2. Appeler l'API pour stop puis start (= restart)
curl -s -b "id=${SESSION_ID}" \
  -H "X-SYNO-TOKEN: ${SYNO_TOKEN}" \
  "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=stop&id=${PKG_NAME}"

curl -s -b "id=${SESSION_ID}" \
  -H "X-SYNO-TOKEN: ${SYNO_TOKEN}" \
  "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=start&id=${PKG_NAME}"
```

**Avantages** :
- Utilise l'API officielle Synology
- Respecte le modele de securite DSM
- Fonctionne avec la session utilisateur existante

**Inconvenients** :
- Necessite d'extraire le SynoToken
- Deux appels API (stop + start)

#### Solution 2 : Configuration sudoers (ALTERNATIVE)

Creer un fichier sudoers pour permettre a l'utilisateur `http` d'executer synopkg.

**Configuration** (necessite acces root) :

```bash
# Creer le fichier sudoers (ATTENTION: pas de point dans le nom!)
echo 'http ALL=(ALL) NOPASSWD: /usr/syno/bin/synopkg restart php84' | sudo tee /etc/sudoers.d/php84_restart

# Verifier les permissions
sudo chmod 440 /etc/sudoers.d/php84_restart
```

**Important** : Le nom du fichier sudoers ne doit PAS contenir de point (`.`), sinon sudo l'ignore silencieusement.

**Utilisation dans le CGI** :

```bash
sudo /usr/syno/bin/synopkg restart "$PKG_NAME"
```

**Avantages** :
- Simple a utiliser une fois configure
- Commande directe synopkg

**Inconvenients** :
- Necessite une configuration manuelle par l'utilisateur
- Modification de /etc/sudoers.d (risque securite)
- Non portable entre installations

#### Solution 3 : Signal USR2 a PHP-FPM (LIMITEE)

PHP-FPM supporte le signal USR2 pour recharger sa configuration.

```bash
# L'utilisateur php84 peut envoyer le signal
sudo -u php84 kill -USR2 $(cat /var/packages/php84/var/run/php-fpm.pid)
```

**Limitation** : L'utilisateur `http` ne peut pas envoyer de signal au processus php84.

#### Solution 4 : Scheduled Task + Flag File (WORKAROUND)

1. Le CGI cree un fichier flag : `/var/packages/php84/var/restart.flag`
2. Une tache planifiee (Task Scheduler) verifie ce flag toutes les minutes
3. Si le flag existe, la tache redémarre le service et supprime le flag

**Avantages** :
- Pas besoin de permissions speciales pour le CGI
- Configuration via DSM GUI

**Inconvenients** :
- Delai de jusqu'a 1 minute avant le redemarrage
- Configuration manuelle requise

### Implementation recommandee : API SYNO.Core.Package.Control

**Code CGI complet pour le restart** :

```bash
elif [ "$action" = "restart" ]; then
    # Methode 1: Essayer synopkg directement (au cas ou sudoers est configure)
    if /usr/syno/bin/synopkg restart "$PKG_NAME" >/dev/null 2>&1; then
        echo "{\"success\":true,\"message\":\"Service restarted\"}"
        exit 0
    fi

    # Methode 2: Utiliser l'API SYNO.Core.Package.Control
    # Obtenir le SynoToken
    SYNO_TOKEN=$(/usr/syno/synoman/webman/login.cgi 2>/dev/null | grep -o '"SynoToken"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)

    if [ -n "$SYNO_TOKEN" ] && [ -n "$HTTP_COOKIE" ]; then
        # Stop puis Start = Restart
        STOP_RESULT=$(curl -s -b "$HTTP_COOKIE" \
            -H "X-SYNO-TOKEN: $SYNO_TOKEN" \
            "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=stop&id=${PKG_NAME}" 2>/dev/null)

        sleep 2

        START_RESULT=$(curl -s -b "$HTTP_COOKIE" \
            -H "X-SYNO-TOKEN: $SYNO_TOKEN" \
            "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=start&id=${PKG_NAME}" 2>/dev/null)

        if echo "$START_RESULT" | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
            echo "{\"success\":true,\"message\":\"Service restarted via API\"}"
        else
            echo "{\"success\":true,\"manual\":true,\"message\":\"Changes saved. Please restart PHP 8.4 from Package Center.\"}"
        fi
    else
        echo "{\"success\":true,\"manual\":true,\"message\":\"Changes saved. Please restart PHP 8.4 from Package Center.\"}"
    fi
fi
```

### Commandes de diagnostic

```bash
# Verifier si http peut utiliser synopkg
sudo -u http /usr/syno/bin/synopkg restart php84

# Verifier si php84 peut envoyer un signal
sudo -u php84 kill -USR2 $(cat /var/packages/php84/var/run/php-fpm.pid)

# Tester l'API SYNO.Core.Package.Control
SYNO_TOKEN=$(/usr/syno/synoman/webman/login.cgi | grep -o '"SynoToken"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
echo "SynoToken: $SYNO_TOKEN"

# Lister les packages via API
curl -s "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package&version=1&method=list"
```

### Sources section 15

- [GitHub - kwent/syno SYNO.Core.Package.lib](https://github.com/kwent/syno/blob/master/definitions/DSM/6.0/7321/SYNO.Core.Package.lib)
- [Synology DSM Login Web API Guide](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Os/DSM/All/enu/DSM_Login_Web_API_Guide_enu.pdf)
- [Stack Overflow - Package won't start/stop with synopkg](https://stackoverflow.com/questions/69856156/package-wont-start-stop-in-synology-dms-7-0-1-when-using-synopkg)
- [BeatificaBytes - Sudoer file dots issue](https://www.beatificabytes.be/sudoer-file-not-working-on-synology-due-to-dots-in-its-name/)
- [Zarino - Starting/stopping Synology packages](https://zarino.co.uk/post/synology-package-start-stop/)
- [DannyDa - Restart services in DSM 7](https://dannyda.com/2022/11/09/how-to-use-command-manually-restart-start-stop-services-in-synology-dsm-7-and-newer-versions/)
- [SynoForum - DSM 7.2 API clarification](https://www.synoforum.com/threads/dsm-7-2-api-clarification.11349/)
- [Synology Developer Guide - Web Authentication](https://help.synology.com/developer-guide/integrate_dsm/web_authentication.html)

---

## 16. API SYNO.Core.Package - Documentation complète (CRITIQUE)

### Vue d'ensemble

L'API `SYNO.Core.Package` est l'API interne de Synology pour la gestion des packages DSM. Bien que non officiellement documentée par Synology, elle est utilisée par le Package Center et peut être exploitée par les applications tierces.

**Bibliothèque** : `/usr/syno/synoman/webman/modules/PkgManApp/SYNO.Core.Package.so`

**Utilisateurs autorisés** : `admin.local`, `admin.domain`, `admin.ldap`

**Niveau d'authentification** : 1 (admin requis)

### Liste complète des APIs de gestion de packages

| API | Méthodes | Description |
|-----|----------|-------------|
| `SYNO.Core.Package` | list, get | Liste et détails des packages |
| `SYNO.Core.Package.Control` | start, stop | Contrôle des services |
| `SYNO.Core.Package.Installation` | status, cancel, check, upload, install, clean, delete | Installation de packages |
| `SYNO.Core.Package.Installation.Download` | - | Téléchargement depuis serveur |
| `SYNO.Core.Package.Server` | - | Gestion des sources de packages |
| `SYNO.Core.Package.Setting` | - | Paramètres du Package Center |
| `SYNO.Core.Package.Setting.Volume` | - | Volume d'installation |
| `SYNO.Core.Package.Uninstallation` | - | Désinstallation |
| `SYNO.Core.Package.Info` | - | Informations sur les packages |
| `SYNO.Core.Package.Feed` | - | Gestion des flux de packages |

### API SYNO.Core.Package.Control - Détails

**Endpoint** : `/webapi/entry.cgi`

**Méthodes disponibles** (version 1) :

| Méthode | Description | Paramètres |
|---------|-------------|------------|
| `start` | Démarrer un package | `id` (nom du package) |
| `stop` | Arrêter un package | `id` (nom du package) |

**Note** : Il n'y a pas de méthode `restart` directe. Pour redémarrer, il faut appeler `stop` puis `start`.

**Exemples d'appels** :

```bash
# Arrêter un package
curl -s -b "id=${SESSION_COOKIE}" \
  -H "X-SYNO-TOKEN: ${SYNO_TOKEN}" \
  "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=stop&id=php84"

# Démarrer un package
curl -s -b "id=${SESSION_COOKIE}" \
  -H "X-SYNO-TOKEN: ${SYNO_TOKEN}" \
  "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=start&id=php84"
```

**Réponse succès** :
```json
{"success": true}
```

**Réponse erreur** :
```json
{"error": {"code": 105}, "success": false}
```

### API SYNO.Core.Package.Installation - Détails

**Méthodes disponibles** (version 1) :

| Méthode | Description | Attributs spéciaux |
|---------|-------------|-------------------|
| `status` | État de l'installation | grantByDefault: true |
| `cancel` | Annuler l'installation | grantByDefault: true |
| `check` | Vérifier avant installation | grantByDefault: true |
| `upload` | Uploader un fichier SPK | allowUpload: true, deferUpload: true |
| `install` | Installer le package | grantByDefault: true |
| `clean` | Nettoyer fichiers temp | grantByDefault: true |
| `delete` | Supprimer | grantByDefault: true |

### Workflow d'installation de package via API

#### Étape 1 : Authentification

```bash
# Obtenir le SynoToken et la session
curl -s "http://nas:5000/webapi/auth.cgi?api=SYNO.API.Auth&version=6&method=login&account=admin&passwd=password&format=cookie"
# Réponse: {"data":{"did":"...","is_portal_port":false,"sid":"..."},"success":true}

# Ou via login.cgi pour obtenir le token
curl -s "http://nas:5000/webman/login.cgi"
# Réponse: {"SynoToken":"9WuK4Cf50Vw7Q","result":"success","success":true}
```

#### Étape 2 : Upload du fichier SPK

```bash
curl -X POST \
  -b "id=${SESSION_ID}" \
  -H "X-SYNO-TOKEN: ${SYNO_TOKEN}" \
  -F "api=SYNO.Core.Package.Installation" \
  -F "method=upload" \
  -F "version=1" \
  -F "file=@/chemin/vers/package.spk" \
  "http://nas:5000/webapi/entry.cgi"
```

**Important** : Le paramètre `file` doit être en **dernier** dans les données multipart.

**Réponse** :
```json
{
  "data": {
    "task_id": "SYNO.Core.Package.Installation_XXXX",
    "blChecking": false,
    ...
  },
  "success": true
}
```

#### Étape 3 : Vérification (check)

```bash
curl -s -b "id=${SESSION_ID}" \
  -H "X-SYNO-TOKEN: ${SYNO_TOKEN}" \
  "http://nas:5000/webapi/entry.cgi?api=SYNO.Core.Package.Installation&version=1&method=check&task_id=${TASK_ID}"
```

#### Étape 4 : Installation

```bash
curl -s -b "id=${SESSION_ID}" \
  -H "X-SYNO-TOKEN: ${SYNO_TOKEN}" \
  "http://nas:5000/webapi/entry.cgi?api=SYNO.Core.Package.Installation&version=1&method=install&task_id=${TASK_ID}&volume_path=/volume1"
```

### Implémentation Python de référence (synology-api)

La bibliothèque Python [synology-api](https://github.com/N4S4/synology-api) implémente ces APIs. Voici les méthodes clés :

```python
from synology_api import core_package

# Connexion
pkg = core_package.Package(
    ip_address='192.168.1.100',
    port='5000',
    username='admin',
    password='password',
    secure=False
)

# Lister les packages installés
installed = pkg.list_installed()

# Upload un fichier SPK
result = pkg.upload_package_file('/chemin/vers/package.spk', progress_bar=True)

# Installation complète (avec gestion des dépendances)
result = pkg.easy_install('nom_package', volume_path='/volume1')

# Contrôle du service (via SYNO.Core.Package.Control)
pkg.start_package('php84')
pkg.stop_package('php84')
```

### Méthodes de la classe Package (synology-api)

| Méthode | Description | API utilisée |
|---------|-------------|--------------|
| `get_package(id)` | Détails d'un package | SYNO.Core.Package |
| `list_installed()` | Liste packages installés | SYNO.Core.Package |
| `list_installable()` | Liste packages disponibles | SYNO.Core.Package |
| `upload_package_file()` | Upload SPK | SYNO.Core.Package.Installation |
| `check_installation()` | Vérifier installation | SYNO.Core.Package.Installation |
| `install_package()` | Installer | SYNO.Core.Package.Installation |
| `download_package()` | Télécharger depuis URL | SYNO.Core.Package.Installation.Download |
| `easy_install()` | Installation complète | Multiple APIs |
| `uninstall_package()` | Désinstaller | SYNO.Core.Package.Uninstallation |

### Implémentation CGI pour restart (Solution complète)

Voici l'implémentation recommandée pour le fichier `index.cgi` :

```bash
#!/bin/bash
# Fonction de restart via API SYNO.Core.Package.Control

restart_service() {
    local PKG_NAME="$1"

    # Obtenir le SynoToken depuis le JSON de login.cgi
    local login_json=$(/usr/syno/synoman/webman/login.cgi 2>/dev/null)
    local SYNO_TOKEN=$(echo "$login_json" | sed -n 's/.*"SynoToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    if [ -z "$SYNO_TOKEN" ]; then
        echo '{"success":false,"error":"Cannot get SynoToken"}'
        return 1
    fi

    # Extraire le cookie de session (déjà disponible dans HTTP_COOKIE)
    # Format attendu: id=XXXXX;...

    # Stop le package
    local stop_result=$(curl -s -b "$HTTP_COOKIE" \
        -H "X-SYNO-TOKEN: $SYNO_TOKEN" \
        "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=stop&id=${PKG_NAME}" 2>/dev/null)

    # Attendre l'arrêt complet
    sleep 2

    # Start le package
    local start_result=$(curl -s -b "$HTTP_COOKIE" \
        -H "X-SYNO-TOKEN: $SYNO_TOKEN" \
        "http://127.0.0.1:5000/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=start&id=${PKG_NAME}" 2>/dev/null)

    # Vérifier le résultat
    if echo "$start_result" | grep -q '"success"[[:space:]]*:[[:space:]]*true'; then
        echo '{"success":true,"message":"Service restarted via API"}'
        return 0
    else
        echo '{"success":false,"error":"API call failed","manual":true,"message":"Please restart from Package Center"}'
        return 1
    fi
}

# Utilisation dans le handler d'action
if [ "$action" = "restart" ]; then
    restart_service "php84"
fi
```

### Implémentation JavaScript côté client

Pour appeler l'API directement depuis le navigateur (dans l'iframe) :

```javascript
async function restartService(packageName) {
    try {
        // Stop
        const stopResponse = await fetch(
            `/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=stop&id=${packageName}`,
            {
                method: 'GET',
                credentials: 'include'  // Important: inclure les cookies
            }
        );

        await new Promise(resolve => setTimeout(resolve, 2000));  // Wait 2s

        // Start
        const startResponse = await fetch(
            `/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=start&id=${packageName}`,
            {
                method: 'GET',
                credentials: 'include'
            }
        );

        const result = await startResponse.json();
        return result.success;
    } catch (error) {
        console.error('Restart failed:', error);
        return false;
    }
}

// Avec SynoToken (plus sécurisé)
async function restartServiceWithToken(packageName) {
    // Obtenir le SynoToken
    const loginResponse = await fetch('/webman/login.cgi', { credentials: 'include' });
    const loginData = await loginResponse.json();
    const synoToken = loginData.SynoToken;

    // Stop avec token
    await fetch(
        `/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=stop&id=${packageName}`,
        {
            method: 'GET',
            credentials: 'include',
            headers: { 'X-SYNO-TOKEN': synoToken }
        }
    );

    await new Promise(resolve => setTimeout(resolve, 2000));

    // Start avec token
    const startResponse = await fetch(
        `/webapi/entry.cgi?api=SYNO.Core.Package.Control&version=1&method=start&id=${packageName}`,
        {
            method: 'GET',
            credentials: 'include',
            headers: { 'X-SYNO-TOKEN': synoToken }
        }
    );

    return (await startResponse.json()).success;
}
```

### Codes d'erreur API courants

| Code | Signification |
|------|---------------|
| 100 | Unknown error |
| 101 | Invalid parameter |
| 102 | API does not exist |
| 103 | Method does not exist |
| 104 | This API version is not supported |
| 105 | Permission denied |
| 106 | Session timeout |
| 107 | Session interrupted by duplicate login |
| 119 | SID not found |
| 263 | Package operation failed |

### Debugging des appels API

```bash
# Lister les APIs disponibles
curl -s "http://nas:5000/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query&query=all" | python3 -m json.tool

# Vérifier si SYNO.Core.Package existe
curl -s "http://nas:5000/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query&query=SYNO.Core.Package,SYNO.Core.Package.Control,SYNO.Core.Package.Installation"

# Tester l'authentification
curl -s "http://nas:5000/webman/login.cgi" -b "id=YOUR_SESSION_COOKIE"

# Lister les packages (test API)
curl -s -b "id=YOUR_SESSION_COOKIE" \
  -H "X-SYNO-TOKEN: YOUR_TOKEN" \
  "http://nas:5000/webapi/entry.cgi?api=SYNO.Core.Package&version=1&method=list"
```

### Sources section 16

- [GitHub - kwent/syno SYNO.Core.Package.lib](https://github.com/kwent/syno/blob/master/definitions/DSM/6.0/7321/SYNO.Core.Package.lib) - Définitions API
- [GitHub - N4S4/synology-api](https://github.com/N4S4/synology-api) - Wrapper Python avec +300 APIs
- [Synology NAS API Python Documentation - Supported APIs](https://n4s4.github.io/synology-api/docs/apis) - Liste des APIs supportées
- [SynoForum - DSM 7.2 API clarification](https://www.synoforum.com/threads/dsm-7-2-api-clarification.11349/) - Détails authentification DSM 7.2
- [Synology DSM Login Web API Guide](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Os/DSM/All/enu/DSM_Login_Web_API_Guide_enu.pdf) - Documentation officielle
- [Stack Overflow - Synology NAS API](https://stackoverflow.com/questions/16355814/how-to-access-synology-nas-drive-using-api) - Exemples d'utilisation
- [synology-api PyPI](https://pypi.org/project/synology-api/) - Package Python

---

## 17. Processus Background et Daemonization sur Synology DSM (CRITIQUE)

### Problématique

Lancer un processus en arrière-plan depuis un script CGI sur Synology DSM est complexe car :
1. Le CGI doit retourner une réponse HTTP rapidement
2. Le processus enfant doit survivre à la fin du CGI
3. Les file descriptors stdin/stdout/stderr doivent être fermés pour libérer la connexion HTTP

### BusyBox sur Synology DSM

Synology DSM utilise une version personnalisée de **BusyBox** avec des applets limités :

> "The latest version of BusyBox officially available has far more applets available than the one provided by Synology. They custom build theirs to limit security and stability issues."

**Vérifier si `setsid` est disponible** :
```bash
busybox --list | grep setsid
# ou simplement
which setsid
```

Si `setsid` n'est pas disponible, des alternatives existent.

### Méthodes de Daemonization

#### 1. Avec `setsid` (si disponible)

```bash
setsid sh -c "sleep 2; curl ...; sleep 3; curl ..." &
```

`setsid` crée une nouvelle session de processus, complètement indépendante du shell parent.

#### 2. Avec `nohup` (standard sur DSM)

```bash
nohup sh -c "commands" </dev/null >/dev/null 2>&1 &
```

**Note** : Sur DSM, `nohup` seul peut ne pas suffire. Les file descriptors doivent être explicitement redirigés.

#### 3. Double sous-shell (pattern recommandé pour CGI)

```bash
( ( sleep 2; curl ...; sleep 3; curl ... ) & )
```

Ce pattern crée une sous-shell qui lance une autre sous-shell en background.

#### 4. Fermeture explicite des File Descriptors (SOLUTION LA PLUS FIABLE)

```bash
(
    # Fermer et rediriger stdin/stdout/stderr vers /dev/null
    exec 0</dev/null
    exec 1>/dev/null
    exec 2>/dev/null

    # Le code ici est complètement détaché
    sleep 2
    curl -s "http://..." >/dev/null 2>&1
    sleep 3
    curl -s "http://..." >/dev/null 2>&1
) &
```

**C'est la solution la plus fiable pour les scripts CGI** car elle :
- Ferme explicitement les 3 file descriptors standards
- Libère immédiatement la connexion HTTP
- Permet au CGI de retourner sa réponse

### Le problème du CGI et du "Double Fork"

Quand un CGI lance un processus en background avec `&`, le serveur web (Apache/nginx/synoscgi) peut :
1. Attendre que tous les processus enfants terminent
2. Garder la connexion HTTP ouverte tant que stdout/stderr ne sont pas fermés

**Solution classique - Double Fork** :
```python
# Fork 1 - Le parent retourne immédiatement
if os.fork():
    # Parent - sort et retourne la réponse HTTP
    sys.exit(0)

# Enfant 1 - devient leader de session
os.setsid()

# Fork 2 - Évite de devenir un zombie
if os.fork():
    sys.exit(0)

# Enfant 2 - Le vrai daemon
# Fermer tous les file descriptors
os.closerange(0, 1024)
# Rouvrir vers /dev/null
os.open("/dev/null", os.O_RDWR)  # stdin (fd 0)
os.open("/dev/null", os.O_WRONLY)  # stdout (fd 1)
os.open("/dev/null", os.O_WRONLY)  # stderr (fd 2)
```

### Solution Bash pour CGI sur Synology

```bash
#!/bin/bash
# Script CGI qui lance un processus en background

# ... traitement CGI ...

if [ "$action" = "restart" ]; then
    # Méthode 1: Avec exec et sous-shell (RECOMMANDÉ)
    (
        exec 0</dev/null
        exec 1>/dev/null
        exec 2>/dev/null
        sleep 2
        curl -s -b "$COOKIE" -H "X-SYNO-TOKEN: $TOKEN" "$STOP_URL"
        sleep 3
        curl -s -b "$COOKIE" -H "X-SYNO-TOKEN: $TOKEN" "$START_URL"
    ) &

    # Réponse immédiate au client
    echo '{"success":true}'
fi
```

### Commande `at` comme Alternative

Si disponible, la commande `at` permet de planifier une exécution :

```bash
echo "curl -s ... && sleep 3 && curl -s ..." | at now + 1 minute
```

**Vérifier disponibilité** : `which at`

### Gestion des Services sur DSM 7

DSM 7 utilise **systemd** pour la gestion des services :

```bash
# Commandes systemctl
systemctl start <service>
systemctl stop <service>
systemctl restart <service>

# Commandes Synology spécifiques
synopkg start <package>
synopkg stop <package>
synopkg restart <package>

# Ou via synoservicecfg (nécessite sudo)
sudo synoservicecfg --restart <service>
```

### Processus persistants après logout SSH

Depuis DSM 3.0, les processus lancés depuis SSH sont tués à la déconnexion. Solutions :

1. **screen** : `screen -dmS session_name command`
2. **tmux** : `tmux new-session -d 'command'`
3. **nohup avec redirection complète** : `nohup command </dev/null >/dev/null 2>&1 &`
4. **Task Scheduler DSM** : Panneau de configuration > Planificateur de tâches

### Création de Service Systemd (DSM 7+)

Pour un daemon permanent, créer `/etc/systemd/system/myservice.service` :

```ini
[Unit]
Description=My Background Service
After=network.target

[Service]
Type=simple
User=http
ExecStart=/path/to/script.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Puis :
```bash
systemctl daemon-reload
systemctl enable myservice
systemctl start myservice
```

### Sources section 17

- [Synology Forum - Background process kill after logoff](https://forum.synology.com/enu/viewtopic.php?t=35092)
- [Synology Forum - Non-Busybox CLI](https://forum.synology.com/enu/viewtopic.php?t=116786)
- [GitHub Gist - How to run scripts in background](https://gist.github.com/hazcod/a74e0e3c3381a18f8421)
- [GitHub Gist - Synology NAS program at startup](https://gist.github.com/SanCoder-Q/f3755435e6e8bd46ba95bf0ec54ae1a4)
- [Stack Overflow - Start background process from CGI](https://stackoverflow.com/questions/6024472/start-background-process-daemon-from-cgi-script)
- [Stack Overflow - Running CGI as background process](https://stackoverflow.com/questions/1952900/running-c-cgi-script-as-background-process)
- [Unix Stack Exchange - Totally fork a shell command](https://unix.stackexchange.com/questions/28809/how-to-totally-fork-a-shell-command-that-is-using-redirection)
- [GitHub Gist - Daemonization code double-fork](https://gist.github.com/ionelmc/5038117)
- [Marius Hosting - Basic Command Lines DSM 7](https://mariushosting.com/synology-basic-command-lines-for-dsm-7/)
- [DannyDa - Restart services in DSM 7](https://dannyda.com/2022/11/09/how-to-use-command-manually-restart-start-stop-services-in-synology-dsm-7-and-newer-versions/)
- [Zarino - Starting/stopping Synology packages](https://zarino.co.uk/post/synology-package-start-stop/)
- [Linux Hint - Start/Stop Synology Package CLI](https://linuxhint.com/start-stop-synology-package-command-line/)

---

## 18. Restrictions de Sécurité DSM 7 et Redémarrage de Service (CRITIQUE)

### Changements majeurs de sécurité dans DSM 7

DSM 7 a introduit des restrictions de sécurité majeures pour les packages tiers :

> "Migration from DSM6 to DSM7 has increased security: now declaring a package running with root privileges is forbidden (except for those written by Synology itself)."

**Restrictions appliquées** :
- `"run-as": "root"` dans `conf/privilege` n'est **plus autorisé**
- La demande d'adhésion aux groupes `root` ou `administrators` est **bloquée**
- Seuls les packages Synology officiels conservent ces droits

### Impact sur le redémarrage de service depuis CGI

Le CGI s'exécute en tant que **utilisateur `http`** avec des permissions très limitées :

1. **Pas d'accès sudo** - L'utilisateur `http` ne peut pas exécuter de commandes privilégiées
2. **Pas de synopkg** - Nécessite des privilèges admin
3. **Pas de systemctl** - Nécessite des privilèges root
4. **API SYNO.Core.Package.Control** - Seule méthode viable (utilise les credentials de l'utilisateur DSM connecté)

### Commandes de gestion de services sur DSM 7

| Commande | Utilisation | Privilèges requis |
|----------|-------------|-------------------|
| `synopkg restart <pkg>` | Redémarrer un package | admin/root |
| `synopkgctl stop/start <pkg>` | Contrôle package DSM 7 | admin/root |
| `systemctl restart <service>` | Redémarrer un service systemd | root |
| `synosystemctl restart <service>` | Wrapper Synology pour systemctl | root |
| `/var/packages/<pkg>/scripts/start-stop-status` | Script direct | package user |

### Configuration des privilèges (conf/privilege)

```json
{
  "defaults": {
    "run-as": "package"
  },
  "ctrl-script": [
    {"action": "start", "run-as": "package"},
    {"action": "stop", "run-as": "package"}
  ]
}
```

**Note** : `ctrl-script` ne s'applique qu'aux scripts du package (`start-stop-status`), pas aux CGI.

### Analyse des packages SynoCommunity

En analysant le code de **dnscrypt-proxy** (SynoCommunity) :
- Le CGI (`cgi.go`) gère uniquement la configuration des fichiers
- **Aucune fonction de redémarrage de service** n'est implémentée dans le CGI
- L'utilisateur doit redémarrer manuellement depuis Package Center

> "Le code fourni ne contient pas de logique de redémarrage du service."

### Solutions possibles pour le redémarrage

#### 1. API SYNO.Core.Package.Control (méthode actuelle)

```javascript
// Côté JavaScript - utilise les credentials de l'utilisateur DSM
fetch('/webman/login.cgi')  // Obtenir SynoToken
fetch('/webapi/entry.cgi?api=SYNO.Core.Package.Control&method=stop&id=php84')
fetch('/webapi/entry.cgi?api=SYNO.Core.Package.Control&method=start&id=php84')
```

**Problème** : La fenêtre se ferme quand le package s'arrête, le JavaScript ne peut pas continuer.

#### 2. Processus background depuis CGI

```bash
(
    exec 0</dev/null
    exec 1>/dev/null
    exec 2>/dev/null
    sleep 2
    curl -s -b "$COOKIE" -H "X-SYNO-TOKEN: $TOKEN" "$STOP_URL"
    sleep 3
    curl -s -b "$COOKIE" -H "X-SYNO-TOKEN: $TOKEN" "$START_URL"
) &
```

**Problème** : Le sous-shell peut ne pas hériter correctement les variables ou être tué par synoscgi.

#### 3. Signal PHP-FPM (USR2)

```bash
# Reload gracieux de PHP-FPM sans redémarrer le package
kill -USR2 $(cat /var/packages/php84/var/run/php-fpm.pid)
```

**Problème** : L'utilisateur `http` n'a pas les permissions d'envoyer de signal au processus php-fpm.

#### 4. Fichier flag + service watcher

Créer un service qui surveille un fichier flag et redémarre quand demandé :

```bash
# Service watcher (dans start-stop-status)
while true; do
    if [ -f "/var/packages/php84/var/reload_flag" ]; then
        rm -f "/var/packages/php84/var/reload_flag"
        # Reload PHP-FPM
        kill -USR2 $FPM_PID
    fi
    sleep 5
done
```

**Avantage** : Le CGI peut créer le fichier flag, le service (qui a les permissions) fait le reload.

#### 5. Message utilisateur (solution de repli)

Si aucune méthode automatique ne fonctionne :
- Sauvegarder les modifications (fonctionne)
- Afficher un message : "Redémarrez PHP 8.4 depuis Package Center pour appliquer les changements"

### Recommandation finale

**La méthode la plus fiable sur DSM 7** semble être :

1. **Option A** : Utiliser un **fichier flag** que le service principal surveille
2. **Option B** : Informer l'utilisateur de **redémarrer manuellement** depuis Package Center
3. **Option C** : Implémenter un **signal handler** dans PHP-FPM wrapper pour reload sur SIGHUP/USR2

Le redémarrage automatique depuis un CGI sur DSM 7 est intentionnellement difficile pour des raisons de sécurité.

### Sources section 18

- [Stack Overflow - Privileges elevation on DSM7](https://stackoverflow.com/questions/67968190/privileges-elevation-on-dsm7)
- [Synology Developer Guide - Privilege Config](https://help.synology.com/developer-guide/privilege/privilege_config.html)
- [Synology Developer Guide - Breaking Changes](https://help.synology.com/developer-guide/breaking_changes.html)
- [SynoCommunity spksrc - DNSCrypt Proxy CGI](https://github.com/SynoCommunity/spksrc/blob/master/spk/dnscrypt-proxy/src/ui/cgi.go)
- [GitHub Gist - Restart Docker on DSM 7.x](https://gist.github.com/NatLee/1caf52f2ab685e109f90494f31346e84)
- [SynoCommunity spksrc - Service Support Wiki](https://github.com/SynoCommunity/spksrc/wiki/Service-Support)
- [SynoForum - DSM 7.0 Package privilege Escalation](https://community.synology.com/enu/forum/20/post/140589)

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
