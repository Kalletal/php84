# Implementation Plan: Comportement par défaut des extensions selon le profil

**Branch**: `003-profile-extensions-default` | **Date**: 2025-11-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-profile-extensions-default/spec.md`

## Summary

Corriger le comportement du wizard d'installation pour que les profils Minimal et Standard n'activent aucune extension par défaut (sauf celles explicitement sélectionnées), tandis que le profil Complet active toutes les extensions. Le bug actuel vient d'un problème de transmission des variables du wizard vers le script postinst.

## Technical Context

**Language/Version**: Bash (POSIX shell), JavaScript (ExtJS dans wizard)
**Primary Dependencies**: DSM Package Framework, WIZARD_UIFILES API
**Storage**: Fichiers .ini dans `conf.d/`, fichier `config.json`
**Testing**: Tests manuels d'installation sur NAS
**Target Platform**: Synology DSM 7.2+ (geminilake x86_64)
**Project Type**: SPK Package (Synology)
**Performance Goals**: N/A (scripts d'installation)
**Constraints**: POSIX shell compatible, pas de dépendances externes
**Scale/Scope**: 2 fichiers à modifier

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Statut | Commentaire |
|----------|--------|-------------|
| I. Package Autonome | PASS | Pas de nouvelles dépendances |
| II. Compatibilité DSM | PASS | Utilise les API standard WIZARD_UIFILES |
| III. Compilation Reproductible | N/A | Modification de scripts uniquement |
| IV. Sécurité | PASS | Pas de changement de permissions |
| V. Modularité des Extensions | PASS | Améliore le contrôle des extensions |

**Gate Result**: PASS - Aucune violation des principes de la constitution.

## Project Structure

### Documentation (this feature)

```text
specs/003-profile-extensions-default/
├── spec.md              # Spécification fonctionnelle
├── plan.md              # Ce fichier
├── research.md          # Analyse du bug et solution
├── data-model.md        # N/A (pas de données)
├── quickstart.md        # Guide de test rapide
└── tasks.md             # Tâches d'implémentation (à générer)
```

### Source Code (fichiers impactés)

```text
spk/php84/src/
├── wizard/
│   └── install_uifile.sh    # Modifier les clés du wizard (préfixe wizard_)
└── scripts/
    └── postinst             # Modifier la logique de traitement des profils
```

## Complexity Tracking

Aucune violation de la constitution à justifier.

## Phase 0: Research Summary

**Résumé des découvertes** (voir [research.md](research.md)) :

1. **Cause du bug** : Les variables du wizard (`profile_minimal`, `profile_standard`, etc.) ne sont pas correctement transmises au script `postinst`.

2. **Solution retenue** : Préfixer toutes les clés du wizard avec `wizard_` (convention spksrc standard).

3. **Comportement cible** :
   - Profil Minimal sans sélection → 0 extension
   - Profil Standard sans sélection → 0 extension
   - Profil Complet → toutes les extensions

## Phase 1: Design

### Changements dans install_uifile.sh

**Avant** :
```json
"key": "profile_minimal"
"key": "min_apcu"
```

**Après** :
```json
"key": "wizard_profile_minimal"
"key": "wizard_min_apcu"
```

### Changements dans postinst

**Avant** (lignes 285-297) :
```bash
if [ "$profile_complete" = "true" ]; then
    enable_profile_complete
elif [ "$profile_minimal" = "true" ]; then
    enable_profile_minimal
    process_minimal_extensions
else
    enable_profile_standard
    process_standard_extensions
fi
```

**Après** :
```bash
if [ "$wizard_profile_complete" = "true" ]; then
    log "Profile: COMPLETE - Enabling all extensions"
    enable_profile_complete
elif [ "$wizard_profile_minimal" = "true" ]; then
    log "Profile: MINIMAL"
    # N'activer QUE les extensions explicitement cochées
    process_minimal_extensions
elif [ "$wizard_profile_standard" = "true" ]; then
    log "Profile: STANDARD"
    # N'activer QUE les extensions explicitement cochées
    process_standard_extensions
else
    log "Profile: NONE SELECTED - No extensions enabled"
    # Aucune extension par défaut si aucun profil sélectionné
fi
```

### Suppression des fonctions de profil de base

Les fonctions `enable_profile_minimal()` et `enable_profile_standard()` ne doivent **plus** être appelées automatiquement. Seules les extensions cochées (`wizard_min_*`, `wizard_std_*`) doivent être activées.

### Gestion des mises à jour

```bash
# En début de process_wizard_selections()
if [ "$SYNOPKG_PKG_STATUS" = "UPGRADE" ]; then
    log "Upgrade detected: preserving existing extension configuration"
    return 0
fi
```

## Phase 2: Implementation Tasks

Les tâches seront générées via `/speckit.tasks`. Aperçu :

1. **T001** : Modifier `install_uifile.sh` - préfixer les clés
2. **T002** : Modifier `postinst` - adapter les noms de variables
3. **T003** : Modifier `postinst` - supprimer l'activation automatique des extensions de base
4. **T004** : Ajouter la détection de mise à jour
5. **T005** : Tester profil Minimal sans extensions
6. **T006** : Tester profil Standard sans extensions
7. **T007** : Tester profil Complet
8. **T008** : Tester mise à jour avec préservation des extensions

## Quickstart

Voir [quickstart.md](quickstart.md) pour les instructions de test rapide.

## Artifacts Generated

- [x] research.md - Analyse du bug et documentation de la solution
- [ ] data-model.md - N/A (pas de modèle de données)
- [ ] contracts/ - N/A (pas d'API)
- [x] quickstart.md - Guide de test
- [ ] tasks.md - À générer via `/speckit.tasks`
