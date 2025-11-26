# PHP 8.4 Synology DS920+ Port Constitution

## Core Principles

### I. Package Autonome
Le package SPK doit être entièrement autonome et ne pas dépendre des bibliothèques système DSM. Toutes les dépendances doivent être compilées et incluses dans le package pour garantir la portabilité et éviter les conflits avec le système hôte.

### II. Compatibilité DSM
Le package doit respecter les conventions Synology :
- Structure SPK standard (package.tgz, INFO, scripts)
- Scripts d'installation/désinstallation conformes
- Intégration avec le gestionnaire de paquets DSM
- Support des architectures cibles (x86_64 pour DS920+/Celeron J4125)

### III. Compilation Reproductible
Chaque build doit être reproductible :
- Scripts de build documentés et versionnés
- Versions exactes des dépendances spécifiées
- Environnement de compilation défini (toolchain, flags)
- Checksums des sources vérifiés

### IV. Sécurité
La sécurité est prioritaire :
- Compilation avec flags de hardening (RELRO, PIE, stack protector)
- Pas d'exécution en root
- Permissions minimales sur les fichiers
- Isolation des processus PHP

### V. Modularité des Extensions
Les extensions PHP doivent être gérées de manière modulaire :
- Toutes les extensions en shared (.so)
- Configuration claire des extensions activées
- Documentation des dépendances de chaque extension

## Architecture Cible

| Paramètre | Valeur |
|-----------|--------|
| NAS | Synology DS920+ |
| CPU | Intel Celeron J4125 (Gemini Lake) |
| Architecture | x86_64 (geminilake) |
| DSM | 7.2.2 |
| PHP Version | 8.4.15 |

## Structure du Projet

```
php84/
├── src/                    # Sources PHP et patches
├── deps/                   # Dépendances (openssl, libxml2, etc.)
├── scripts/                # Scripts de build
├── spk/                    # Fichiers du package SPK
│   ├── INFO               # Métadonnées du package
│   ├── PACKAGE_ICON*.png  # Icônes
│   ├── scripts/           # Scripts d'installation
│   └── conf/              # Configuration
├── build/                  # Répertoire de compilation
└── dist/                   # Packages générés
```

## Dépendances Requises

Les dépendances suivantes doivent être compilées :
- OpenSSL 3.x (cryptographie)
- libxml2 (XML)
- libsqlite3 (SQLite)
- zlib (compression)
- libcurl (HTTP client)
- oniguruma (regex PCRE)
- libzip (archives ZIP)
- libpng, libjpeg, freetype (GD)

## Workflow de Build

1. **Préparation** : Téléchargement et vérification des sources
2. **Dépendances** : Compilation des bibliothèques requises
3. **Configuration** : ./configure avec options appropriées
4. **Compilation** : make avec optimisations
5. **Test** : Validation des binaires générés
6. **Packaging** : Création du SPK

## Conventions de Versioning

Format : `8.4.X-Y` où :
- `8.4.X` = Version PHP upstream
- `Y` = Numéro de révision du package Synology

## Governance

- Cette constitution guide toutes les décisions de développement
- Les modifications majeures nécessitent une justification documentée
- La compatibilité ascendante du package doit être maintenue
- Les tests de non-régression sont obligatoires avant release

**Version**: 1.0.0 | **Ratified**: 2025-11-26 | **Last Amended**: 2025-11-26
