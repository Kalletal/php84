# Implementation Plan: Extension Manager

**Branch**: `001-extension-manager` | **Date**: 2025-11-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-extension-manager/spec.md`

## Summary

Implémenter un gestionnaire d'extensions PHP 8.4.15 pour Synology DS920+ permettant :
1. La sélection de ~100 extensions organisées par thème lors de l'installation via wizard SPK
2. Une interface DSM native (fenêtre, pas onglet) pour gérer les extensions post-installation
3. Le redémarrage automatique du service PHP-FPM lors des modifications

**Approche technique** : Utilisation du framework spksrc pour la compilation croisée, wizard JSON multi-étapes, application ExtJS 3.4 avec backend CGI.

## Technical Context

**Language/Version**: C (PHP 8.4.15), Bash (scripts), JavaScript/ExtJS 3.4 (UI DSM)
**Primary Dependencies**: spksrc framework, OpenSSL 3.x, libxml2, libcurl, libzip, oniguruma, zlib, ICU
**Storage**: Fichiers JSON (config.json, extensions.json) dans /var/packages/php84/var/
**Testing**: Tests manuels sur DS920+, validation wizard, tests CGI
**Target Platform**: Synology DS920+ (geminilake/x86_64), DSM 7.2.2
**Project Type**: Package SPK avec UI DSM intégrée
**Performance Goals**: Wizard < 2min parcours, redémarrage < 10s, ouverture fenêtre < 3s
**Constraints**: Compilation croisée obligatoire, toutes extensions en .so (shared), pas de root
**Scale/Scope**: ~100 extensions, 13 catégories, 1 utilisateur admin

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Status | Conformité |
|----------|--------|------------|
| I. Package Autonome | PASS | Toutes dépendances compilées et incluses |
| II. Compatibilité DSM | PASS | Structure SPK standard, scripts conformes, DSM 7.2.2 |
| III. Compilation Reproductible | PASS | Makefiles spksrc versionnés, checksums digests |
| IV. Sécurité | PASS | Pas de root (run-as: package), permissions minimales |
| V. Modularité Extensions | PASS | Toutes extensions en shared (.so) |

**Post-Phase 1 Re-check**: Conforme - aucune violation détectée.

## Project Structure

### Documentation (this feature)

```text
specs/001-extension-manager/
├── plan.md              # This file
├── research.md          # Phase 0: Recherche spksrc, DSM, extensions
├── data-model.md        # Phase 1: Modèle de données
├── quickstart.md        # Phase 1: Guide de démarrage
├── contracts/           # Phase 1: API CGI, wizard schema
│   ├── cgi-api.md
│   └── wizard-schema.json
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 (via /speckit.tasks)
```

### Source Code (repository root)

```text
php84/
├── cross/
│   └── php84/
│       ├── Makefile              # Build PHP avec extensions shared
│       ├── digests               # Checksums SHA256
│       ├── PLIST                 # Liste fichiers installés
│       └── patches/              # Patches optionnels
│
├── spk/
│   └── php84/
│       ├── Makefile              # Définition package SPK
│       ├── PLIST
│       └── src/
│           ├── INFO.sh           # Métadonnées package
│           ├── service-setup.sh  # Configuration service
│           ├── conf/
│           │   ├── privilege     # Permissions DSM 7
│           │   └── resource      # Config ressources
│           ├── scripts/
│           │   ├── start-stop-status
│           │   ├── postinst
│           │   ├── preuninst
│           │   └── postupgrade
│           ├── wizard/
│           │   └── install_uifile    # Wizard JSON (13 steps)
│           └── ui/
│               ├── config            # Définition app DSM
│               ├── PHP84Manager.js   # UI ExtJS
│               ├── style.css
│               ├── images/           # Icônes 16-72px
│               └── cgi/
│                   ├── extensions.cgi
│                   ├── config.cgi
│                   ├── service.cgi
│                   └── validate.cgi
│
├── deps/                         # Dépendances compilées
│   ├── openssl3/
│   ├── libxml2/
│   ├── sqlite/
│   ├── curl/
│   ├── libzip/
│   ├── oniguruma/
│   ├── icu/
│   └── ...
│
└── dist/                         # Packages générés
    └── php84-8.4.15-X-geminilake-7.2.spk
```

**Structure Decision**: Structure spksrc standard avec séparation cross/ (compilation) et spk/ (packaging). L'interface DSM est intégrée dans spk/php84/src/ui/.

## Complexity Tracking

Aucune violation de la constitution détectée. Le projet suit les principes établis.

## Implementation Phases Overview

### Phase 1: Infrastructure (Completed in /speckit.plan)
- [x] Research.md: Recherche spksrc, DSM API, extensions PHP
- [x] Data-model.md: Modèle Extension, Category, Configuration, Service
- [x] Contracts: API CGI, wizard schema
- [x] Quickstart.md: Guide de développement

### Phase 2: Core Development (via /speckit.tasks)
- [ ] Configuration environnement spksrc
- [ ] Compilation dépendances (openssl, libxml2, etc.)
- [ ] Makefile cross/php84 avec extensions shared
- [ ] Wizard install_uifile multi-steps
- [ ] Scripts d'installation SPK
- [ ] Interface DSM ExtJS
- [ ] CGI backend
- [ ] Tests et validation

### Phase 3: Deployment
- [ ] Build final SPK
- [ ] Tests sur DS920+
- [ ] Documentation utilisateur

## Key Technical Decisions

| Decision | Choix | Rationale |
|----------|-------|-----------|
| Framework build | spksrc | Standard SynoCommunity, toolchains intégrés |
| Architecture | geminilake-7.2 | DS920+ Intel Celeron J4125 |
| UI Framework | ExtJS 3.4 | Natif DSM, fenêtre intégrée |
| Backend | CGI Bash/Python | Simple, pas de dépendances serveur |
| Storage config | JSON files | Léger, lisible, pas de BDD |
| Extensions | 100% shared (.so) | Conformité constitution |

## Dependencies Graph

```
openssl3 ─┬─> curl ───────────────────────┐
          └─> php84 ──────────────────────┤
libxml2 ────> php84                       │
sqlite ─────> php84                       │
libzip ─────> php84                       │
oniguruma ──> php84 (mbstring)            │
icu ────────> php84 (intl)                │
zlib ───────> php84                       │
                                          │
          ┌───────────────────────────────┘
          ▼
       spk/php84 ──> php84-8.4.15-X.spk
```

## Next Steps

Exécuter `/speckit.tasks` pour générer la liste des tâches d'implémentation détaillées.
