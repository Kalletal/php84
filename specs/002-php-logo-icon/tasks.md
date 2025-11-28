# Implementation Tasks: PHP Logo Icon Update

**Feature**: 002-php-logo-icon
**Branch**: `002-php-logo-icon`
**Generated**: 2025-11-28
**Total Tasks**: 14
**Completed**: 14 | **Remaining**: 0

## User Stories Summary

| Story | Priority | Description | Tasks |
|-------|----------|-------------|-------|
| US1 | P1 | Logo PHP dans le Centre de paquets | 3 |
| US2 | P2 | Logo PHP dans l'Extension Manager | 2 |

---

## Phase 1: Setup (Préparation)

**Goal**: Télécharger le SVG source et vérifier les prérequis.

- [x] T001 Télécharger le logo PHP SVG depuis https://upload.wikimedia.org/wikipedia/commons/2/27/PHP-logo.svg vers /tmp/php-logo.svg
- [x] T002 Vérifier que ImageMagick (convert) est disponible pour la conversion SVG→PNG

---

## Phase 2: User Story 1 - Logo PHP dans le Centre de paquets (P1)

**Goal**: Afficher le logo officiel PHP dans le Centre de paquets Synology DSM.

**Independent Test**: Ouvrir le Centre de paquets DSM, vérifier que le logo PHP (ellipse lavande avec "php" noir) s'affiche correctement à côté du package PHP84.

### Implementation

- [x] T003 [US1] Convertir SVG → PACKAGE_ICON.PNG (72x72) dans spk/php84/src/PACKAGE_ICON.PNG
- [x] T004 [US1] Convertir SVG → PACKAGE_ICON_256.PNG (256x256) dans spk/php84/src/PACKAGE_ICON_256.PNG
- [x] T005 [US1] Vérifier visuellement les icônes générées (lisibilité, proportions, transparence)

**Checkpoint**: Les icônes Package Center sont prêtes. Le logo doit être visible et net à 72x72 et 256x256.

---

## Phase 3: User Story 2 - Logo PHP dans l'Extension Manager (P2)

**Goal**: Afficher le logo officiel PHP dans l'application Extension Manager (fenêtre DSM).

**Independent Test**: Cliquer sur "Ouvrir" dans le Centre de paquets pour PHP84, vérifier que l'icône dans la barre de titre et la barre des tâches DSM affiche le logo PHP.

### Implementation

- [x] T006 [P] [US2] Convertir SVG → php84_16.png (16x16) dans spk/php84/src/ui/images/php84_16.png
- [x] T007 [P] [US2] Convertir SVG → php84_24.png (24x24) dans spk/php84/src/ui/images/php84_24.png
- [x] T008 [P] [US2] Convertir SVG → php84_32.png (32x32) dans spk/php84/src/ui/images/php84_32.png
- [x] T009 [P] [US2] Convertir SVG → php84_48.png (48x48) dans spk/php84/src/ui/images/php84_48.png
- [x] T010 [P] [US2] Convertir SVG → php84_64.png (64x64) dans spk/php84/src/ui/images/php84_64.png
- [x] T011 [P] [US2] Convertir SVG → php84_72.png (72x72) dans spk/php84/src/ui/images/php84_72.png

**Checkpoint**: Toutes les icônes UI sont générées. Le logo doit être reconnaissable même à 16x16.

---

## Phase 4: Polish & Validation

**Goal**: Nettoyer, valider et préparer le SPK final.

- [x] T012 Supprimer le fichier SVG temporaire /tmp/php-logo.svg
- [x] T013 Rebuilder le package SPK avec les nouvelles icônes via spk/php84/scripts/build-spk.sh
- [x] T014 Tester l'installation sur NAS et vérifier l'affichage des icônes (Centre de paquets + Extension Manager)

---

## Dependencies Graph

```
Phase 1 (Setup)
    │
    ▼
┌─────────────────────────────────────┐
│                                     │
▼                                     ▼
Phase 2 (US1)                   Phase 3 (US2)
Package Center icons            UI Application icons
(T003-T005)                     (T006-T011) [Parallel]
    │                                 │
    └──────────────┬──────────────────┘
                   │
                   ▼
            Phase 4 (Polish)
            Build & Test SPK
            (T012-T014)
```

**Story Dependencies**:
- US1 (Package Center) : Indépendant après Phase 1
- US2 (Extension Manager) : Indépendant après Phase 1, peut être fait en parallèle avec US1

---

## Parallel Execution Opportunities

### Phase 1 - Setup
```
T001 (Download SVG) → T002 (Verify ImageMagick)
Sequential: T002 depends on nothing but T001 must complete first
```

### Phase 2 & 3 - User Stories (can run in parallel)
```
US1: T003 → T004 → T005 (sequential for verification)
US2: T006, T007, T008, T009, T010, T011 (all parallel - different files)
```

### Phase 4 - Polish
```
T012 → T013 → T014 (sequential: cleanup → build → test)
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

**Scope**: Logo dans le Centre de paquets uniquement
- Tasks: T001-T002 (Setup) + T003-T005 (US1) = 5 tâches
- Le package affiche le logo officiel PHP dans le Centre de paquets
- L'Extension Manager garde les anciennes icônes (acceptable)

### Full Implementation

1. **Phase 1**: Setup - Télécharger SVG, vérifier outils
2. **Phase 2+3**: User Stories en parallèle
   - US1: Générer icônes Package Center
   - US2: Générer icônes UI (6 tâches parallèles)
3. **Phase 4**: Rebuild SPK et test final

---

## File Mapping

| File Path | Tasks | User Story |
|-----------|-------|------------|
| /tmp/php-logo.svg | T001, T012 | Setup |
| spk/php84/src/PACKAGE_ICON.PNG | T003 | US1 |
| spk/php84/src/PACKAGE_ICON_256.PNG | T004 | US1 |
| spk/php84/src/ui/images/php84_16.png | T006 | US2 |
| spk/php84/src/ui/images/php84_24.png | T007 | US2 |
| spk/php84/src/ui/images/php84_32.png | T008 | US2 |
| spk/php84/src/ui/images/php84_48.png | T009 | US2 |
| spk/php84/src/ui/images/php84_64.png | T010 | US2 |
| spk/php84/src/ui/images/php84_72.png | T011 | US2 |

---

## Notes

- [P] tasks = fichiers différents, peuvent être exécutées en parallèle
- [US1]/[US2] = associe la tâche à une User Story
- Toutes les conversions utilisent: `convert -background none -gravity center -resize WxH -extent WxH`
- Le logo PHP a un ratio 1.85:1 (ellipse), il sera centré dans un carré avec fond transparent
