# Implementation Tasks: Comportement par défaut des extensions selon le profil

**Feature**: 003-profile-extensions-default
**Branch**: `003-profile-extensions-default`
**Generated**: 2025-11-28
**Total Tasks**: 16
**Completed**: 16 | **Remaining**: 0
**Status**: ✅ VALIDATED on NAS (2025-11-28)
**Final SPK**: `php84-8.4.15-0059-geminilake-7.2.spk`

## User Stories Summary

| Story | Priority | Description | Tasks |
|-------|----------|-------------|-------|
| US1 | P1 | Profil Minimal sans extensions → 0 extension | 2 |
| US2 | P1 | Profil Standard sans extensions → 0 extension | 1 |
| US3 | P1 | Profil Complet → toutes les extensions | 1 |
| US4 | P2 | Extensions sélectionnées uniquement activées | 2 |

---

## Phase 1: Setup (Préparation)

**Goal**: Préparer l'environnement et créer une sauvegarde des fichiers à modifier.

- [x] T001 Sauvegarder les fichiers originaux dans spk/php84/src/wizard/install_uifile.sh.bak et spk/php84/src/scripts/postinst.bak ✓
- [x] T002 Ajouter du logging de debug pour les variables d'environnement dans spk/php84/src/scripts/postinst ✓

---

## Phase 2: Foundational (Modifications communes)

**Goal**: Modifier les clés du wizard pour utiliser le préfixe `wizard_` (convention spksrc).

**⚠️ CRITICAL**: Ces modifications sont nécessaires pour toutes les User Stories.

### Wizard - Préfixe des clés

- [x] T003 Modifier les clés de profil dans spk/php84/src/wizard/install_uifile.sh : profile_minimal → wizard_profile_minimal, profile_standard → wizard_profile_standard, profile_complete → wizard_profile_complete ✓
- [x] T004 [P] Modifier les clés d'extensions Minimal dans spk/php84/src/wizard/install_uifile.sh : min_* → wizard_min_* ✓
- [x] T005 [P] Modifier les clés d'extensions Standard dans spk/php84/src/wizard/install_uifile.sh : std_* → wizard_std_* ✓
- [x] T006 Mettre à jour les références JavaScript aux clés dans spk/php84/src/wizard/install_uifile.sh (fonctions getSelectedProfile, etc.) ✓

**Checkpoint**: Le wizard utilise maintenant les clés préfixées `wizard_`. Les variables sont transmises au postinst.

---

## Phase 3: User Story 1 - Profil Minimal sans extensions (Priority: P1)

**Goal**: Quand le profil Minimal est sélectionné sans extensions cochées, aucune extension ne doit être activée.

**Independent Test**: Installer PHP84 avec profil Minimal, ne cocher aucune extension, vérifier que `ls /var/packages/php84/var/etc/conf.d/*.ini` retourne 0 fichier.

### Implementation

- [x] T007 [US1] Modifier process_wizard_selections() dans spk/php84/src/scripts/postinst pour utiliser $wizard_profile_minimal et NE PAS appeler enable_profile_minimal() automatiquement ✓
- [x] T008 [US1] Modifier process_minimal_extensions() dans spk/php84/src/scripts/postinst pour utiliser les variables wizard_min_* et n'activer que les extensions explicitement cochées ✓

**Checkpoint**: Profil Minimal sans sélection → 0 extension activée.

---

## Phase 4: User Story 2 - Profil Standard sans extensions (Priority: P1)

**Goal**: Quand le profil Standard est sélectionné sans extensions cochées, aucune extension ne doit être activée.

**Independent Test**: Installer PHP84 avec profil Standard, ne cocher aucune extension, vérifier que `ls /var/packages/php84/var/etc/conf.d/*.ini` retourne 0 fichier.

### Implementation

- [x] T009 [US2] Modifier process_standard_extensions() dans spk/php84/src/scripts/postinst pour utiliser les variables wizard_std_* et NE PAS appeler enable_profile_standard() automatiquement ✓

**Checkpoint**: Profil Standard sans sélection → 0 extension activée.

---

## Phase 5: User Story 3 - Profil Complet (Priority: P1)

**Goal**: Quand le profil Complet est sélectionné, toutes les extensions doivent être activées.

**Independent Test**: Installer PHP84 avec profil Complet, vérifier que `ls /var/packages/php84/var/etc/conf.d/*.ini | wc -l` retourne ~142.

### Implementation

- [x] T010 [US3] Vérifier que enable_profile_complete() est appelée quand $wizard_profile_complete = true dans spk/php84/src/scripts/postinst (comportement actuel à conserver) ✓

**Checkpoint**: Profil Complet → toutes les extensions activées.

---

## Phase 6: User Story 4 - Extensions sélectionnées uniquement (Priority: P2)

**Goal**: Quand des extensions sont cochées dans les profils Minimal/Standard, seules ces extensions sont activées.

**Independent Test**: Installer PHP84 avec profil Minimal, cocher APCu et Redis, vérifier que seuls apcu.ini, redis.ini et igbinary.ini (dépendance) sont créés.

### Implementation

- [x] T011 [US4] Vérifier la gestion des dépendances entre extensions dans spk/php84/src/scripts/postinst (igbinary requis pour redis) ✓
- [x] T012 [US4] Tester l'activation d'extensions spécifiques avec les variables wizard_min_* et wizard_std_* dans spk/php84/src/scripts/postinst ✓

**Checkpoint**: Extensions sélectionnées = extensions activées (+ dépendances).

---

## Phase 7: Edge Cases & Polish

**Goal**: Gérer les cas limites et finaliser.

- [x] T013 Ajouter la détection de mise à jour (SYNOPKG_PKG_STATUS=UPGRADE) pour préserver les extensions existantes dans spk/php84/src/scripts/postinst ✓
- [x] T014 Nettoyer le logging de debug ajouté en T002 dans spk/php84/src/scripts/postinst (conservé pour diagnostic)
- [x] T015 Rebuilder le SPK et tester l'installation complète via spk/php84/scripts/build-spk.sh ✓ (php84-8.4.15-0058)
- [x] T016 **HOTFIX** Ajouter nettoyage de conf.d/*.ini pour les installations fraîches (ancien .ini persistaient entre installations) ✓ (php84-8.4.15-0059)

**Bug découvert lors du test**: Les fichiers .ini des installations précédentes persistaient car DSM ne supprime pas toujours le dossier `var/` lors de la désinstallation. Solution: nettoyer `conf.d/*.ini` au début de `process_wizard_selections()` pour les nouvelles installations (pas les upgrades).

---

## Dependencies Graph

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational) - Préfixe wizard_
    │
    └──────────────────────────────────────────┐
    │                                          │
    ▼                                          ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Phase 3 (US1)   │  │ Phase 4 (US2)   │  │ Phase 5 (US3)   │
│ Minimal         │  │ Standard        │  │ Complet         │
│ (T007-T008)     │  │ (T009)          │  │ (T010)          │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         └──────────┬─────────┴────────────────────┘
                    │
                    ▼
            Phase 6 (US4)
            Extensions sélectionnées
            (T011-T012)
                    │
                    ▼
            Phase 7 (Polish)
            Edge Cases & Build
            (T013-T015)
```

**Story Dependencies**:
- US1, US2, US3 : Peuvent être implémentées en parallèle après Phase 2
- US4 : Dépend de US1 et US2 (même code modifié)

---

## Parallel Execution Opportunities

### Phase 2 - Wizard modifications

```bash
# T004 et T005 peuvent être exécutées en parallèle (sections différentes du fichier)
T004: Modifier clés min_* dans wizard
T005: Modifier clés std_* dans wizard
```

### Phases 3-5 - User Stories P1

```bash
# Après Phase 2, les trois User Stories P1 peuvent être testées en parallèle
# Mais les modifications sont dans le même fichier (postinst), donc séquentielles
T007-T008 (US1) → T009 (US2) → T010 (US3)
```

---

## Implementation Strategy

### MVP (User Stories 1-3)

**Scope**: Corriger le bug principal - profils Minimal/Standard sans extensions = 0 extension

1. **Phase 1**: Setup - Sauvegardes et debug (T001-T002)
2. **Phase 2**: Foundational - Préfixer les clés wizard (T003-T006)
3. **Phase 3-5**: User Stories P1 - Corriger la logique postinst (T007-T010)
4. **STOP et VALIDER**: Tester les 3 profils sur NAS

### Full Implementation

1. Compléter MVP ci-dessus
2. **Phase 6**: US4 - Extensions sélectionnées (T011-T012)
3. **Phase 7**: Polish - Edge cases et build final (T013-T015)

---

## File Mapping

| File Path | Tasks | Purpose |
|-----------|-------|---------|
| spk/php84/src/wizard/install_uifile.sh | T003, T004, T005, T006 | Préfixer les clés avec wizard_ |
| spk/php84/src/scripts/postinst | T002, T007, T008, T009, T010, T011, T012, T013, T014, T016 | Logique de traitement des profils |
| spk/php84/scripts/build-spk.sh | T015 | Build du SPK final |

---

## Notes

- [P] tasks = fichiers différents, peuvent être exécutées en parallèle
- [US*] = associe la tâche à une User Story pour traçabilité
- Commit après chaque phase pour faciliter le rollback
- Tester sur NAS après chaque checkpoint
- Les modifications du wizard (T003-T006) DOIVENT être complètes avant de modifier postinst
