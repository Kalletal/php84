# Feature Specification: Comportement par défaut des extensions selon le profil

**Feature Branch**: `003-profile-extensions-default`
**Created**: 2025-11-28
**Status**: Draft
**Input**: Actuellement, quand on choisit les profils minimal ou standard et quand on ne choisit aucune extension dans ces profils, l'Extension Manager active des extensions au hasard, à l'installation. Il faudrait que si l'on ne choisit aucune extension dans les profils minimal ou standard, aucune extension ne soit activée dans l'Extension Manager. Par contre, quand on choisit le profil complet, toutes les extensions doivent être activées, par défaut, dans l'Extension Manager.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Installation avec profil Minimal sans extensions (Priority: P1)

L'administrateur installe le package PHP84 en choisissant le profil "Minimal" et ne sélectionne aucune extension supplémentaire. Après l'installation, aucune extension PHP ne doit être activée dans l'Extension Manager.

**Why this priority**: C'est le comportement de base attendu pour les profils légers. Actuellement, le système active des extensions de manière aléatoire, ce qui est le bug principal à corriger.

**Independent Test**: Installer le package PHP84 avec le profil Minimal sans cocher d'extensions, puis ouvrir l'Extension Manager et vérifier qu'aucune extension n'est activée.

**Acceptance Scenarios**:

1. **Given** l'utilisateur installe PHP84 via le Centre de paquets, **When** il sélectionne le profil "Minimal" et ne coche aucune extension optionnelle, **Then** après installation, l'Extension Manager affiche 0 extension activée.
2. **Given** le profil Minimal est sélectionné sans extensions, **When** l'installation se termine, **Then** le fichier de configuration PHP ne charge aucun module d'extension.

---

### User Story 2 - Installation avec profil Standard sans extensions (Priority: P1)

L'administrateur installe le package PHP84 en choisissant le profil "Standard" et ne sélectionne aucune extension supplémentaire. Après l'installation, aucune extension PHP ne doit être activée dans l'Extension Manager.

**Why this priority**: Même priorité que US1 car c'est le même bug affectant un profil différent.

**Independent Test**: Installer le package PHP84 avec le profil Standard sans cocher d'extensions, puis ouvrir l'Extension Manager et vérifier qu'aucune extension n'est activée.

**Acceptance Scenarios**:

1. **Given** l'utilisateur installe PHP84 via le Centre de paquets, **When** il sélectionne le profil "Standard" et ne coche aucune extension optionnelle, **Then** après installation, l'Extension Manager affiche 0 extension activée.
2. **Given** le profil Standard est sélectionné sans extensions, **When** l'installation se termine, **Then** le fichier de configuration PHP ne charge aucun module d'extension.

---

### User Story 3 - Installation avec profil Complet (Priority: P1)

L'administrateur installe le package PHP84 en choisissant le profil "Complet". Après l'installation, toutes les extensions PHP disponibles doivent être activées par défaut dans l'Extension Manager.

**Why this priority**: Le profil Complet doit activer toutes les extensions pour offrir un environnement PHP complet immédiatement fonctionnel.

**Independent Test**: Installer le package PHP84 avec le profil Complet, puis ouvrir l'Extension Manager et vérifier que toutes les extensions disponibles sont activées.

**Acceptance Scenarios**:

1. **Given** l'utilisateur installe PHP84 via le Centre de paquets, **When** il sélectionne le profil "Complet", **Then** après installation, l'Extension Manager affiche toutes les extensions comme activées.
2. **Given** le profil Complet est sélectionné, **When** l'installation se termine, **Then** le fichier de configuration PHP charge tous les modules d'extension disponibles.

---

### User Story 4 - Installation avec profil Minimal/Standard avec extensions sélectionnées (Priority: P2)

L'administrateur installe le package PHP84 en choisissant le profil "Minimal" ou "Standard" et sélectionne manuellement certaines extensions. Après l'installation, seules les extensions explicitement sélectionnées doivent être activées.

**Why this priority**: Ce scénario est moins critique car l'utilisateur fait un choix explicite, mais doit fonctionner correctement.

**Independent Test**: Installer le package PHP84 avec le profil Minimal, cocher 3 extensions spécifiques, puis vérifier que seules ces 3 extensions sont activées.

**Acceptance Scenarios**:

1. **Given** l'utilisateur installe PHP84 avec le profil Minimal, **When** il sélectionne les extensions "curl", "json" et "mbstring", **Then** après installation, seules ces 3 extensions sont activées dans l'Extension Manager.
2. **Given** l'utilisateur installe PHP84 avec le profil Standard, **When** il sélectionne 5 extensions spécifiques, **Then** après installation, exactement ces 5 extensions sont activées.

---

### Edge Cases

- Que se passe-t-il si l'utilisateur change de profil pendant l'assistant d'installation ? Le système doit réinitialiser la liste des extensions selon le nouveau profil.
- Que se passe-t-il en cas de mise à jour du package ? Les extensions précédemment activées doivent être préservées, quel que soit le profil original.
- Que se passe-t-il si une extension sélectionnée a des dépendances ? Les extensions dépendantes doivent être automatiquement activées.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT n'activer aucune extension lorsque le profil "Minimal" est sélectionné sans extensions cochées.
- **FR-002**: Le système DOIT n'activer aucune extension lorsque le profil "Standard" est sélectionné sans extensions cochées.
- **FR-003**: Le système DOIT activer toutes les extensions disponibles lorsque le profil "Complet" est sélectionné.
- **FR-004**: Le système DOIT activer uniquement les extensions explicitement sélectionnées par l'utilisateur pour les profils Minimal et Standard.
- **FR-005**: Le système DOIT préserver les extensions activées lors d'une mise à jour du package.
- **FR-006**: Le système DOIT gérer automatiquement les dépendances entre extensions (activer les extensions requises).
- **FR-007**: Le système DOIT synchroniser l'état des extensions entre l'installation (wizard) et l'Extension Manager.

### Key Entities

- **Profil d'installation**: Définit le comportement par défaut des extensions (Minimal, Standard, Complet).
- **Extension PHP**: Module chargeable dynamiquement, avec état activé/désactivé et dépendances potentielles.
- **Configuration des extensions**: Fichier(s) stockant l'état des extensions activées, persisté entre les sessions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% des installations avec profil Minimal sans sélection d'extensions aboutissent à 0 extension activée.
- **SC-002**: 100% des installations avec profil Standard sans sélection d'extensions aboutissent à 0 extension activée.
- **SC-003**: 100% des installations avec profil Complet aboutissent à l'activation de toutes les extensions disponibles.
- **SC-004**: Le nombre d'extensions activées après installation correspond exactement au nombre sélectionné par l'utilisateur (pour profils Minimal/Standard).
- **SC-005**: Aucune extension n'est activée "au hasard" lors de l'installation.

## Assumptions

- Le wizard d'installation DSM permet de passer la liste des extensions sélectionnées au script d'installation.
- Le fichier de configuration des extensions est accessible en écriture lors de l'installation.
- Les trois profils (Minimal, Standard, Complet) sont déjà implémentés dans le wizard d'installation.
- L'Extension Manager lit l'état des extensions depuis un fichier de configuration centralisé.
