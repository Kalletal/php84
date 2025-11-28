# Feature Specification: Boutons d'activation/désactivation globale des extensions

**Feature Branch**: `004-bulk-toggle-extensions`
**Created**: 2025-11-28
**Status**: Draft
**Input**: User description: "Il faudrait également réjouter un bouton dans l'Extension Manager pour activer ou désactiver toutes les Extensions en une fois"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Activer toutes les extensions (Priority: P1)

En tant qu'administrateur, je veux pouvoir activer toutes les extensions PHP en un clic pour configurer rapidement un environnement de développement complet ou tester la compatibilité de toutes les extensions.

**Why this priority**: C'est l'action la plus demandée pour les utilisateurs qui veulent un environnement PHP complet sans avoir à cocher manuellement chaque extension parmi les ~142 disponibles.

**Independent Test**: Cliquer sur le bouton "Tout activer" et vérifier que toutes les extensions passent à l'état activé dans l'interface.

**Acceptance Scenarios**:

1. **Given** l'Extension Manager est ouvert avec 0 extension activée, **When** je clique sur "Tout activer", **Then** toutes les extensions (~142) passent à l'état "activé" visuellement
2. **Given** l'Extension Manager est ouvert avec 50 extensions activées, **When** je clique sur "Tout activer", **Then** les 92 extensions restantes passent également à l'état "activé"
3. **Given** je viens de cliquer sur "Tout activer", **When** l'opération est terminée, **Then** le compteur affiche "142 / 142 extensions activées"

---

### User Story 2 - Désactiver toutes les extensions (Priority: P1)

En tant qu'administrateur, je veux pouvoir désactiver toutes les extensions PHP en un clic pour revenir à un état minimal ou diagnostiquer des problèmes de compatibilité.

**Why this priority**: Également prioritaire car complémentaire à l'activation globale - permet de "repartir de zéro" rapidement.

**Independent Test**: Cliquer sur le bouton "Tout désactiver" et vérifier que toutes les extensions passent à l'état désactivé dans l'interface.

**Acceptance Scenarios**:

1. **Given** l'Extension Manager est ouvert avec 142 extensions activées, **When** je clique sur "Tout désactiver", **Then** toutes les extensions passent à l'état "désactivé" visuellement
2. **Given** l'Extension Manager est ouvert avec 50 extensions activées, **When** je clique sur "Tout désactiver", **Then** toutes les 50 extensions passent à l'état "désactivé"
3. **Given** je viens de cliquer sur "Tout désactiver", **When** l'opération est terminée, **Then** le compteur affiche "0 / 142 extensions activées"

---

### User Story 3 - Feedback visuel pendant l'opération (Priority: P2)

En tant qu'administrateur, je veux voir un indicateur de progression pendant l'activation/désactivation globale pour savoir que l'opération est en cours et quand elle est terminée.

**Why this priority**: Améliore l'expérience utilisateur mais n'est pas critique pour la fonctionnalité de base.

**Independent Test**: Déclencher une opération globale et observer l'indicateur visuel jusqu'à sa complétion.

**Acceptance Scenarios**:

1. **Given** je clique sur "Tout activer" ou "Tout désactiver", **When** l'opération démarre, **Then** les boutons deviennent désactivés (grisés) pour éviter les doubles clics
2. **Given** l'opération globale est en cours, **When** je regarde l'interface, **Then** je vois un indicateur que l'opération est en cours (ex: texte "En cours...")
3. **Given** l'opération globale est terminée, **When** le dernier toggle est traité, **Then** un message de confirmation s'affiche et les boutons redeviennent actifs

---

### Edge Cases

- Que se passe-t-il si une extension individuelle échoue pendant l'opération globale ? → L'opération continue avec les autres extensions et un message d'erreur signale les échecs
- Que se passe-t-il si l'utilisateur ferme la fenêtre pendant l'opération ? → Les extensions déjà traitées restent dans leur nouvel état
- Que se passe-t-il si toutes les extensions sont déjà activées et l'utilisateur clique sur "Tout activer" ? → L'opération se termine rapidement sans erreur (no-op)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: L'interface DOIT afficher un bouton "Tout activer" permettant d'activer toutes les extensions en une seule action
- **FR-002**: L'interface DOIT afficher un bouton "Tout désactiver" permettant de désactiver toutes les extensions en une seule action
- **FR-003**: Les boutons DOIVENT être désactivés pendant qu'une opération globale est en cours pour éviter les conflits
- **FR-004**: Le système DOIT mettre à jour l'affichage de chaque extension individuellement au fur et à mesure du traitement
- **FR-005**: Le système DOIT mettre à jour le compteur d'extensions activées après l'opération
- **FR-006**: Le système DOIT afficher un message de confirmation à la fin de l'opération globale
- **FR-007**: L'opération DOIT continuer même si une extension individuelle échoue, et les erreurs DOIVENT être signalées à l'utilisateur

### Key Entities

- **Extension**: Représente une extension PHP avec son état (activé/désactivé) et son fichier .so correspondant
- **Opération globale**: Action groupée affectant toutes les extensions, avec un état (en cours, terminée, erreur partielle)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'administrateur peut activer toutes les extensions (~142) en moins de 30 secondes au lieu de plusieurs minutes manuellement
- **SC-002**: L'administrateur peut désactiver toutes les extensions en moins de 30 secondes
- **SC-003**: 100% des extensions sont traitées lors d'une opération globale (pas d'extension oubliée)
- **SC-004**: L'interface reste responsive pendant l'opération (pas de gel de l'interface)
- **SC-005**: Le compteur d'extensions activées reflète correctement l'état final après l'opération

## Assumptions

- Les boutons seront placés dans la zone d'en-tête de l'Extension Manager, près du bouton "Appliquer & Recharger" existant
- L'opération globale utilisera le même mécanisme de toggle que les toggles individuels (appels séquentiels au backend CGI)
- Le rechargement de PHP-FPM reste une action séparée via le bouton "Appliquer & Recharger"

## Out of Scope

- Sélection partielle d'extensions (activer/désactiver par catégorie)
- Sauvegarde/restauration de profils d'extensions personnalisés
- Annulation d'une opération globale en cours
