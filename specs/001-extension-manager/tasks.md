# Implementation Tasks: Extension Manager

**Feature**: 001-extension-manager
**Branch**: `001-extension-manager`
**Generated**: 2025-11-26
**Updated**: 2025-11-28
**Total Tasks**: 74 (67 original + 7 bug fixes)
**Completed**: 74 | **Remaining**: 0

## User Stories Summary

| Story | Priority | Description | Tasks |
|-------|----------|-------------|-------|
| US1 | P1 | Sélection des extensions à l'installation | 12 |
| US2 | P1 | Gestion post-installation (fenêtre DSM) | 14 |
| US3 | P1 | Modification et application des changements | 10 |
| US4 | P2 | Organisation thématique des extensions | 6 |

---

## Phase 1: Setup (Environment & Project Structure)

**Goal**: Configurer l'environnement de développement spksrc et créer la structure du projet.

- [x] T001 Cloner le repository spksrc dans le répertoire de travail
- [x] T002 [P] Configurer Docker pour la compilation croisée geminilake-7.2
- [x] T003 [P] Créer la structure cross/php84/ avec Makefile vide dans cross/php84/Makefile
- [x] T004 [P] Créer la structure spk/php84/ avec Makefile vide dans spk/php84/Makefile
- [x] T005 [P] Créer le répertoire spk/php84/src/ avec sous-dossiers (conf/, scripts/, wizard/, ui/)
- [x] T006 [P] Créer le fichier digests vide dans cross/php84/digests
- [x] T007 Vérifier que le toolchain geminilake-7.2 est disponible dans spksrc

---

## Phase 2: Foundational (Core Dependencies & PHP Build)

**Goal**: Compiler PHP 8.4.15 et toutes ses dépendances pour l'architecture geminilake.
**Blocking**: Toutes les User Stories dépendent de cette phase.

### Dépendances de base

- [x] T008 Compiler zlib pour geminilake-7.2 via cross/zlib
- [x] T009 Compiler OpenSSL 3.x pour geminilake-7.2 via cross/openssl3
- [x] T010 [P] Compiler libxml2 pour geminilake-7.2 via cross/libxml2
- [x] T011 [P] Compiler sqlite pour geminilake-7.2 via cross/sqlite
- [x] T012 Compiler curl (dépend openssl) pour geminilake-7.2 via cross/curl
- [x] T013 [P] Compiler oniguruma pour geminilake-7.2 via cross/oniguruma
- [x] T014 [P] Compiler libzip pour geminilake-7.2 via cross/libzip
- [x] T015 [P] Compiler ICU pour geminilake-7.2 via cross/icu
- [x] T016 [P] Compiler freetype pour geminilake-7.2 via cross/freetype
- [x] T017 [P] Compiler libpng pour geminilake-7.2 via cross/libpng
- [x] T018 [P] Compiler libjpeg pour geminilake-7.2 via cross/libjpeg

### PHP Core Build

- [x] T019 Télécharger les sources PHP 8.4.15 et générer les checksums dans cross/php84/digests
- [x] T020 Créer le Makefile complet cross/php84/Makefile avec CONFIGURE_ARGS pour extensions shared
- [x] T021 Ajouter les dépendances DEPENDS dans cross/php84/Makefile
- [x] T022 Compiler PHP 8.4.15 avec toutes les extensions en shared (.so) via make arch-geminilake-7.2
- [x] T023 Vérifier que tous les fichiers .so sont générés dans lib/php/modules/
- [x] T024 Créer le fichier PLIST listant tous les fichiers installés dans cross/php84/PLIST

### Extensions PECL (optionnel)

- [x] T025 [P] Créer cross/php84-redis/Makefile pour l'extension Redis
- [x] T026 [P] Créer cross/php84-apcu/Makefile pour l'extension APCu
- [x] T027 [P] Créer cross/php84-imagick/Makefile pour l'extension Imagick
- [x] T028 Compiler les extensions PECL sélectionnées

---

## Phase 3: User Story 1 - Sélection des extensions à l'installation (P1)

**Goal**: Permettre à l'utilisateur de sélectionner ~100 extensions organisées par thème lors de l'installation.
**Independent Test**: Installer le SPK et vérifier que le wizard s'affiche avec les catégories et que les sélections sont appliquées.

### Données extensions

- [x] T029 [US1] Créer le fichier extensions.json avec les ~100 extensions et 13 catégories dans spk/php84/src/conf/extensions.json
- [x] T030 [US1] Définir les dépendances entre extensions dans extensions.json
- [x] T031 [US1] Définir les valeurs par défaut (defaultValue) pour chaque extension dans extensions.json

### Wizard d'installation

- [x] T032 [US1] Créer le step 1 du wizard (Base de données) dans spk/php84/src/wizard/install_uifile
- [x] T033 [P] [US1] Créer le step 2 du wizard (Cache & Performance) dans install_uifile
- [x] T034 [P] [US1] Créer les steps 3-6 du wizard (Texte, XML, Images, Compression) dans install_uifile
- [x] T035 [P] [US1] Créer les steps 7-10 du wizard (Crypto, Réseau, Système, Math) dans install_uifile
- [x] T036 [P] [US1] Créer les steps 11-13 du wizard (Fichiers, Autres, PECL) dans install_uifile
- [x] T037 [US1] Ajouter le style CSS compact pour double colonnes dans install_uifile

### Scripts d'installation

- [x] T038 [US1] Créer le script postinst qui lit les sélections wizard dans spk/php84/src/scripts/postinst
- [x] T039 [US1] Implémenter la génération des fichiers conf.d/*.ini selon les sélections dans postinst
- [x] T040 [US1] Créer le script preuninst pour nettoyage dans spk/php84/src/scripts/preuninst

---

## Phase 4: User Story 2 - Gestion post-installation (fenêtre DSM) (P1)

**Goal**: Créer une fenêtre DSM native accessible via le bouton "Ouvrir" du Centre de paquets.
**Independent Test**: Cliquer sur "Ouvrir" et vérifier qu'une fenêtre DSM s'ouvre avec la liste des extensions.

### Configuration DSM App

- [x] T041 [US2] Créer le fichier INFO.sh avec dsmuidir et dsmappname dans spk/php84/src/INFO.sh
- [x] T042 [US2] Créer le fichier conf/privilege pour DSM 7 dans spk/php84/src/conf/privilege
- [x] T043 [US2] Créer le fichier ui/config définissant l'application DSM dans spk/php84/src/ui/config

### Interface ExtJS

- [x] T044 [US2] Créer la classe SYNO.SDS.PHP84Manager.Instance dans spk/php84/src/ui/PHP84Manager.js
- [x] T045 [US2] Créer la classe SYNO.SDS.PHP84Manager.MainWindow dans PHP84Manager.js
- [x] T046 [US2] Implémenter le panel principal avec layout border dans PHP84Manager.js
- [x] T047 [US2] Créer le store Ext.data.JsonStore pour les extensions dans PHP84Manager.js
- [x] T048 [US2] Implémenter le grid avec checkboxes par catégorie dans PHP84Manager.js
- [x] T049 [US2] Ajouter la toolbar avec boutons Refresh/Apply dans PHP84Manager.js
- [x] T050 [US2] Créer le fichier style.css pour l'interface dans spk/php84/src/ui/style.css

### Assets

- [x] T051 [P] [US2] Créer les icônes 16x16, 24x24, 32x32 dans spk/php84/src/ui/images/
- [x] T052 [P] [US2] Créer les icônes 48x48, 64x64, 72x72 dans spk/php84/src/ui/images/

### CGI Backend - Lecture

- [x] T053 [US2] Créer le script extensions.cgi (GET) pour lister les extensions dans spk/php84/src/ui/cgi/extensions.cgi
- [x] T054 [US2] Créer le script config.cgi (GET) pour lire la configuration dans spk/php84/src/ui/cgi/config.cgi

---

## Phase 5: User Story 3 - Modification et application des changements (P1)

**Goal**: Permettre la modification des extensions et le redémarrage du service.
**Independent Test**: Modifier une extension, cliquer Apply, vérifier que php -m reflète le changement.

### CGI Backend - Écriture

- [x] T055 [US3] Implémenter POST dans extensions.cgi pour mise à jour des extensions
- [x] T056 [US3] Implémenter POST dans config.cgi pour mise à jour des paramètres
- [x] T057 [US3] Créer le script service.cgi pour contrôler le service PHP-FPM dans spk/php84/src/ui/cgi/service.cgi
- [x] T058 [US3] Créer le script validate.cgi pour validation des dépendances dans spk/php84/src/ui/cgi/validate.cgi

### Service Management

- [x] T059 [US3] Créer le script start-stop-status pour le service dans spk/php84/src/scripts/start-stop-status
- [x] T060 [US3] Créer le fichier service-setup.sh pour la configuration du service dans spk/php84/src/service-setup.sh
- [x] T061 [US3] Implémenter la fonction restart dans service.cgi avec synopkg restart

### UI Integration

- [x] T062 [US3] Implémenter le handler Apply dans PHP84Manager.js avec appel extensions.cgi POST
- [x] T063 [US3] Implémenter l'appel service.cgi restart après sauvegarde dans PHP84Manager.js
- [x] T064 [US3] Ajouter l'indicateur de progression (loading mask) pendant le redémarrage dans PHP84Manager.js

---

## Phase 6: User Story 4 - Organisation thématique (P2)

**Goal**: Organiser les extensions en catégories cohérentes avec navigation facilitée.
**Independent Test**: Vérifier que chaque extension est dans la bonne catégorie et que la navigation est intuitive.

- [x] T065 [US4] Réviser et valider le classement des extensions par catégorie dans extensions.json
- [x] T066 [US4] Ajouter les descriptions détaillées pour chaque catégorie dans extensions.json
- [x] T067 [US4] Implémenter le filtrage par catégorie dans le grid ExtJS dans PHP84Manager.js
- [x] T068 [US4] Ajouter un tree panel de navigation par catégorie dans PHP84Manager.js
- [x] T069 [US4] Implémenter la recherche d'extension par nom dans PHP84Manager.js
- [x] T070 [US4] Synchroniser l'organisation entre wizard et interface de gestion

---

## Phase 7: Polish & Integration

**Goal**: Finaliser le package, tests et documentation.

### Package SPK

- [x] T071 Créer le Makefile SPK complet dans spk/php84/Makefile
- [x] T072 Créer le fichier PLIST du SPK dans spk/php84/PLIST
- [x] T073 Ajouter les icônes du package (PACKAGE_ICON*.png) dans spk/php84/src/
- [x] T074 Générer le package SPK (php84-8.4.15-0001-geminilake-7.2.spk - 43 MB avec 101 extensions)

### Tests & Validation

- [x] T075 Tester l'installation complète sur DS920+ (v0015 - démarre correctement)
- [x] T076 Tester le wizard avec différentes combinaisons d'extensions
- [x] T077 Tester l'ouverture de la fenêtre DSM via "Ouvrir" (v0015 - fonctionne avec ui/config DSM 7)
- [x] T078 Tester la modification et le redémarrage du service via l'UI (v0015 - validé)
- [x] T079 Tester les cas d'erreur (dépendances, conflits) (v0015 - validé)
- [x] T080 Vérifier les performances (temps wizard < 2min, restart < 10s) (v0015 - validé)

### Documentation

- [x] T081 Créer le README.md utilisateur avec instructions d'installation
- [x] T082 Documenter les extensions disponibles et leurs dépendances (EXTENSIONS.md créé)

---

## Phase 8: Bug Fixes & Improvements (v0015)

**Goal**: Corrections de bugs identifiés lors des tests.
**Completed**: 2025-11-27

### Bug Fixes

- [x] T083 Corriger le problème de fichiers .ini en double (extensions chargées 2x)
- [x] T084 Unifier le format de nommage des .ini entre postinst et extensions.cgi (XX-ext.ini)
- [x] T085 Ajouter libmemcached.so.11 manquante pour l'extension memcached
- [x] T086 Corriger www.conf (supprimer user/group pour mode non-root)
- [x] T087 Créer script cleanup-nas.sh pour les installations existantes

### Improvements

- [x] T088 Ajouter fonction getExtensionPrefix() dans extensions.cgi pour ordre de chargement
- [x] T089 Ajouter nettoyage automatique des fichiers .ini legacy lors de l'activation

---

## Dependencies Graph

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational) ─────────────────────────────┐
    │                                                │
    ├───────────────┬───────────────┬───────────────┤
    ▼               ▼               ▼               ▼
Phase 3 (US1)   Phase 4 (US2)   Phase 5 (US3)   Phase 6 (US4)
Wizard Install  Fenêtre DSM     Apply Changes   Catégories
    │               │               │               │
    └───────────────┴───────────────┴───────────────┘
                            │
                            ▼
                    Phase 7 (Polish)
```

**Story Dependencies**:
- US1 (Wizard) : Indépendant après Phase 2
- US2 (Fenêtre DSM) : Indépendant après Phase 2
- US3 (Apply Changes) : Dépend partiellement de US2 (UI)
- US4 (Catégories) : Peut être fait en parallèle, améliore US1 et US2

---

## Parallel Execution Opportunities

### Phase 2 - Dépendances (après T008-T009)
```
T010 (libxml2) ─┐
T011 (sqlite)  ─┤
T013 (oniguruma)┼─> Parallèle
T014 (libzip)  ─┤
T015 (icu)     ─┤
T016-T18 (gd)  ─┘
```

### Phase 3 - Wizard Steps
```
T033 (Cache)    ─┐
T034 (Texte...) ─┼─> Parallèle (fichiers différents dans install_uifile)
T035 (Crypto...)─┤
T036 (PECL)     ─┘
```

### Phase 4 - Assets
```
T051 (icônes 16-32) ─┐
T052 (icônes 48-72) ─┴─> Parallèle
```

---

## Implementation Strategy

### MVP (Minimum Viable Product)

**Scope**: User Story 1 uniquement
- Wizard d'installation fonctionnel
- Sélection d'extensions appliquée
- PHP fonctionnel avec extensions choisies

**Tasks**: T001-T028 (Setup + Foundational) + T029-T040 (US1) = 40 tâches

### Incremental Delivery

1. **Iteration 1**: MVP (US1) - Wizard installation
2. **Iteration 2**: US2 - Fenêtre DSM (lecture seule)
3. **Iteration 3**: US3 - Modification et redémarrage
4. **Iteration 4**: US4 - Organisation améliorée
5. **Iteration 5**: Polish et tests finaux

---

## File Mapping

| File Path | Tasks | User Story |
|-----------|-------|------------|
| cross/php84/Makefile | T003, T020, T021 | Foundational |
| cross/php84/digests | T006, T019 | Foundational |
| cross/php84/PLIST | T024 | Foundational |
| spk/php84/Makefile | T004, T071 | Setup, Polish |
| spk/php84/src/INFO.sh | T041 | US2 |
| spk/php84/src/conf/privilege | T042 | US2 |
| spk/php84/src/conf/extensions.json | T029-T031, T065-T66 | US1, US4 |
| spk/php84/src/wizard/install_uifile | T032-T037 | US1 |
| spk/php84/src/scripts/postinst | T038-T039 | US1 |
| spk/php84/src/scripts/preuninst | T040 | US1 |
| spk/php84/src/scripts/start-stop-status | T059 | US3 |
| spk/php84/src/service-setup.sh | T060 | US3 |
| spk/php84/src/ui/config | T043 | US2 |
| spk/php84/src/ui/PHP84Manager.js | T044-T049, T062-T64, T67-T69 | US2, US3, US4 |
| spk/php84/src/ui/style.css | T050 | US2 |
| spk/php84/src/ui/images/ | T051-T052 | US2 |
| spk/php84/src/ui/cgi/extensions.cgi | T053, T055 | US2, US3 |
| spk/php84/src/ui/cgi/config.cgi | T054, T056 | US2, US3 |
| spk/php84/src/ui/cgi/service.cgi | T057, T061 | US3 |
| spk/php84/src/ui/cgi/validate.cgi | T058 | US3 |
