# Data Model: Extension Manager

**Feature**: 001-extension-manager
**Date**: 2025-11-26

## Entités principales

### 1. Extension

Représente un module PHP chargeable dynamiquement.

```
Extension
├── id: string                    # Identifiant unique (ex: "mysqli")
├── name: string                  # Nom d'affichage (ex: "MySQLi")
├── description: string           # Description courte
├── version: string               # Version de l'extension
├── category: CategoryId          # Référence à la catégorie
├── enabled: boolean              # État actuel (activé/désactivé)
├── default: boolean              # Activé par défaut à l'installation
├── filename: string              # Nom du fichier .so (ex: "mysqli.so")
├── dependencies: ExtensionId[]   # Extensions requises
├── conflicts: ExtensionId[]      # Extensions incompatibles
├── libraries: string[]           # Bibliothèques système requises
└── priority: number              # Ordre de chargement (0 = premier)
```

**Règles de validation**:
- `id` doit être unique et alphanumérique avec underscores
- `filename` doit se terminer par `.so`
- Si `dependencies` non vides, toutes doivent être activées avant cette extension
- `priority` détermine l'ordre dans php.ini (extensions core d'abord)

### 2. Category (Catégorie thématique)

Regroupement logique d'extensions pour l'affichage.

```
Category
├── id: string                    # Identifiant (ex: "database")
├── name: string                  # Nom d'affichage (ex: "Base de données")
├── description: string           # Description de la catégorie
├── order: number                 # Ordre d'affichage (1 = premier)
└── icon: string                  # Icône optionnelle
```

**Catégories définies**:

| ID | Nom | Ordre |
|----|-----|-------|
| database | Base de données | 1 |
| cache | Cache & Performance | 2 |
| text | Texte & Encodage | 3 |
| xml | XML & Documents | 4 |
| image | Images | 5 |
| compression | Compression | 6 |
| crypto | Cryptographie | 7 |
| network | Réseau | 8 |
| system | Système | 9 |
| math | Mathématiques | 10 |
| file | Fichiers | 11 |
| misc | Autres | 12 |
| pecl | Extensions PECL | 13 |

### 3. Configuration

État global de la configuration PHP.

```
Configuration
├── version: string               # Version du schéma config
├── php_version: string           # Version PHP (ex: "8.4.15")
├── last_modified: timestamp      # Date dernière modification
├── extensions: Map<ExtensionId, ExtensionState>
└── settings: PHPSettings
```

**ExtensionState**:
```
ExtensionState
├── enabled: boolean
└── config: Map<string, string>   # Config spécifique extension
```

**PHPSettings**:
```
PHPSettings
├── memory_limit: string          # ex: "128M"
├── max_execution_time: number    # ex: 30
├── upload_max_filesize: string   # ex: "64M"
├── post_max_size: string         # ex: "64M"
└── timezone: string              # ex: "Europe/Paris"
```

### 4. Service

État du service PHP-FPM.

```
Service
├── status: ServiceStatus         # running | stopped | restarting | error
├── pid: number | null            # PID du processus principal
├── uptime: number                # Secondes depuis démarrage
├── last_restart: timestamp       # Date dernier redémarrage
└── error_message: string | null  # Message d'erreur si status=error
```

**ServiceStatus** enum:
- `running` : Service actif
- `stopped` : Service arrêté
- `restarting` : Redémarrage en cours
- `error` : Erreur au démarrage

---

## Relations

```
┌─────────────┐       ┌──────────────┐
│  Category   │◄──────│  Extension   │
└─────────────┘   N:1 └──────────────┘
                            │
                            │ depends_on (N:M)
                            ▼
                      ┌──────────────┐
                      │  Extension   │
                      └──────────────┘

┌───────────────┐     ┌──────────────┐
│ Configuration │────►│ExtensionState│
└───────────────┘ 1:N └──────────────┘
        │
        │ 1:1
        ▼
┌───────────────┐
│  PHPSettings  │
└───────────────┘

┌───────────────┐
│    Service    │ (singleton)
└───────────────┘
```

---

## Stockage

### Fichiers de configuration

| Fichier | Contenu | Emplacement |
|---------|---------|-------------|
| extensions.json | Métadonnées extensions | /var/packages/php84/target/etc/php/ |
| config.json | Configuration utilisateur | /var/packages/php84/var/ |
| php.ini | Configuration PHP runtime | /var/packages/php84/var/etc/ |
| conf.d/*.ini | Configs extensions actives | /var/packages/php84/var/etc/conf.d/ |

### Format extensions.json

```json
{
  "version": "1.0",
  "extensions": {
    "mysqli": {
      "name": "MySQLi",
      "description": "MySQL Improved Extension",
      "category": "database",
      "default": true,
      "filename": "mysqli.so",
      "dependencies": [],
      "conflicts": [],
      "libraries": ["libmysqlclient"],
      "priority": 50
    },
    "pdo_mysql": {
      "name": "PDO MySQL",
      "description": "PDO MySQL Driver",
      "category": "database",
      "default": true,
      "filename": "pdo_mysql.so",
      "dependencies": ["pdo"],
      "conflicts": [],
      "libraries": ["libmysqlclient"],
      "priority": 51
    }
  },
  "categories": {
    "database": {
      "name": "Base de données",
      "description": "Extensions pour bases de données",
      "order": 1
    }
  }
}
```

### Format config.json (utilisateur)

```json
{
  "version": "1.0",
  "php_version": "8.4.15",
  "last_modified": "2025-11-26T10:30:00Z",
  "extensions": {
    "mysqli": {"enabled": true},
    "pdo_mysql": {"enabled": true},
    "pdo_pgsql": {"enabled": false},
    "opcache": {"enabled": true, "config": {"memory_consumption": "128"}},
    "xdebug": {"enabled": false}
  },
  "settings": {
    "memory_limit": "256M",
    "max_execution_time": 60,
    "upload_max_filesize": "64M",
    "post_max_size": "64M",
    "timezone": "Europe/Paris"
  }
}
```

---

## États et transitions

### Extension State Machine

```
                    ┌─────────────────┐
                    │    DISABLED     │
                    └────────┬────────┘
                             │
                    enable() │ ▲ disable()
                             ▼ │
                    ┌─────────────────┐
                    │    ENABLED      │
                    └─────────────────┘
```

**Contraintes de transition**:

**enable()**:
- Pré-condition: Toutes les dépendances sont ENABLED
- Post-condition: Fichier .ini créé dans conf.d/
- Action: Ajouter `extension=<filename>` dans conf.d/

**disable()**:
- Pré-condition: Aucune autre extension ENABLED ne dépend de celle-ci
- Post-condition: Fichier .ini supprimé de conf.d/
- Action: Supprimer le fichier conf.d/<ext>.ini

### Service State Machine

```
          stop()              start()
    ┌────────────┐       ┌────────────┐
    │            ▼       │            ▼
┌───────┐   ┌─────────┐   ┌─────────────┐
│RUNNING│◄──│ STOPPED │◄──│ RESTARTING  │
└───┬───┘   └─────────┘   └──────┬──────┘
    │                            ▲
    │        restart()           │
    └────────────────────────────┘

         error
    ┌─────────┐
    │  ERROR  │◄─── (depuis n'importe quel état)
    └─────────┘
```

---

## Validation des données

### Extension

```
validate_extension(ext):
  - id: non vide, alphanumérique + underscore
  - name: non vide, max 50 caractères
  - filename: termine par .so
  - category: existe dans categories
  - dependencies: toutes existent
  - conflicts: toutes existent
  - priority: 0-100
```

### Configuration change

```
validate_config_change(old_config, new_config):
  for each extension changed:
    if enabling:
      - verify all dependencies enabled
      - verify no conflicts with enabled extensions
    if disabling:
      - verify no enabled extension depends on it

  return errors[] or success
```

---

## Indexation et recherche

### Index recommandés

1. **Extensions par catégorie**: Pour affichage groupé
   ```
   index: category -> Extension[]
   ```

2. **Extensions par état**: Pour filtrage rapide
   ```
   index: enabled -> Extension[]
   ```

3. **Graphe de dépendances**: Pour validation
   ```
   index: extension_id -> dependent_extensions[]
   ```

### Requêtes fréquentes

| Requête | Index utilisé |
|---------|---------------|
| Lister extensions d'une catégorie | category index |
| Lister extensions activées | enabled index |
| Vérifier si peut désactiver | dependency graph |
| Obtenir extensions à activer | dependency graph (BFS) |
