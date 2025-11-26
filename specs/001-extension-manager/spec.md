# Feature Specification: Extension Manager

**Feature Branch**: `001-extension-manager`
**Created**: 2025-11-26
**Status**: Draft
**Input**: User description: "Pendant l'installation, l'utilisateur doit pouvoir choisir parmis une 100ène d'extensions classer par thème. Suite à l'installation, l'utilisateur, via le centre de paquet, doit pouvoir ouvrir une fenetre DSM pour gérer les extensions et redémarrer le service."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sélection des extensions à l'installation (Priority: P1)

Lors de l'installation du package PHP 8.4.15 via le Centre de paquets Synology, l'utilisateur parcourt plusieurs écrans de sélection d'extensions organisées par thème. Chaque écran présente les extensions en double colonnes avec une police compacte pour maximiser l'espace. L'utilisateur coche les extensions souhaitées puis termine l'installation.

**Why this priority**: C'est le point d'entrée principal. Sans cette fonctionnalité, l'utilisateur ne peut pas personnaliser son installation PHP.

**Independent Test**: Peut être testé en installant le package SPK et en vérifiant que les écrans de sélection apparaissent et que les extensions cochées sont effectivement installées.

**Acceptance Scenarios**:

1. **Given** l'utilisateur lance l'installation du package PHP 8.4.15 depuis le Centre de paquets, **When** il arrive aux écrans de sélection des extensions, **Then** il voit les extensions regroupées par thème en double colonnes avec une police compacte
2. **Given** l'utilisateur a coché plusieurs extensions dans différents thèmes, **When** il termine l'installation, **Then** seules les extensions sélectionnées sont activées dans PHP
3. **Given** l'utilisateur n'a coché aucune extension optionnelle, **When** il termine l'installation, **Then** PHP s'installe avec uniquement les extensions de base

---

### User Story 2 - Gestion post-installation des extensions (Priority: P1)

Après l'installation, l'utilisateur ouvre le Centre de paquets, sélectionne le package PHP 8.4 et clique sur le bouton "Ouvrir". Une fenêtre DSM dédiée (pas un onglet navigateur) s'ouvre, affichant la liste complète des extensions disponibles avec leur état actuel (activé/désactivé).

**Why this priority**: Essentielle pour permettre la modification de la configuration sans réinstallation complète.

**Independent Test**: Peut être testé en cliquant sur "Ouvrir" dans le Centre de paquets et en vérifiant qu'une fenêtre DSM s'ouvre avec l'interface de gestion.

**Acceptance Scenarios**:

1. **Given** le package PHP 8.4.15 est installé, **When** l'utilisateur clique sur "Ouvrir" dans le Centre de paquets, **Then** une fenêtre DSM séparée s'ouvre (pas un nouvel onglet navigateur)
2. **Given** la fenêtre de gestion est ouverte, **When** l'utilisateur consulte la liste, **Then** il voit toutes les extensions disponibles avec leur état actuel (cochées = activées)
3. **Given** certaines extensions ont été sélectionnées à l'installation, **When** l'utilisateur ouvre la fenêtre de gestion, **Then** ces extensions apparaissent comme activées (cochées)

---

### User Story 3 - Modification et application des changements (Priority: P1)

Dans la fenêtre de gestion, l'utilisateur modifie l'état des extensions (active/désactive) puis clique sur un bouton pour appliquer les changements. Le service PHP redémarre automatiquement pour prendre en compte la nouvelle configuration.

**Why this priority**: Sans cette fonctionnalité, la fenêtre de gestion serait inutile car les changements ne pourraient pas être appliqués.

**Independent Test**: Peut être testé en modifiant l'état d'une extension et en vérifiant que le changement est effectif après redémarrage du service.

**Acceptance Scenarios**:

1. **Given** l'utilisateur a modifié l'état d'une ou plusieurs extensions, **When** il clique sur le bouton d'application, **Then** le service PHP redémarre et la nouvelle configuration est active
2. **Given** l'utilisateur active une extension précédemment désactivée, **When** le service redémarre, **Then** l'extension est chargée et fonctionnelle
3. **Given** l'utilisateur désactive une extension, **When** le service redémarre, **Then** l'extension n'est plus chargée

---

### User Story 4 - Organisation thématique des extensions (Priority: P2)

Les extensions sont organisées en catégories thématiques logiques (Base de données, Cache, Cryptographie, Images, Compression, etc.) pour faciliter la navigation et la sélection tant à l'installation que dans la fenêtre de gestion.

**Why this priority**: Améliore l'expérience utilisateur mais le système fonctionne même avec une liste non catégorisée.

**Independent Test**: Peut être testé en vérifiant que chaque extension appartient à une catégorie cohérente et que les catégories sont clairement identifiables.

**Acceptance Scenarios**:

1. **Given** l'utilisateur parcourt les écrans d'installation, **When** il consulte une catégorie, **Then** toutes les extensions affichées sont liées au thème de la catégorie
2. **Given** l'utilisateur cherche une extension spécifique, **When** il connaît son domaine d'application, **Then** il peut la trouver dans la catégorie thématique correspondante

---

### Edge Cases

- Que se passe-t-il si une extension a des dépendances sur une autre extension non sélectionnée ? Le système doit avertir l'utilisateur et proposer d'activer automatiquement les dépendances
- Que se passe-t-il si le redémarrage du service échoue ? Le système doit afficher un message d'erreur explicite et proposer de restaurer la configuration précédente
- Que se passe-t-il si l'utilisateur ferme la fenêtre de gestion avec des modifications non appliquées ? Le système doit demander confirmation avant de fermer
- Comment gérer les extensions incompatibles entre elles ? Le système doit empêcher la sélection simultanée et afficher une explication

## Requirements *(mandatory)*

### Functional Requirements

#### Installation

- **FR-001**: Le système DOIT afficher les extensions disponibles lors de l'installation du package SPK
- **FR-002**: Les extensions DOIVENT être organisées par catégories thématiques dans l'installeur
- **FR-003**: L'affichage DOIT utiliser une disposition en double colonnes pour optimiser l'espace
- **FR-004**: La police utilisée DOIT être suffisamment compacte pour afficher un maximum d'extensions par écran
- **FR-005**: L'utilisateur DOIT pouvoir sélectionner/désélectionner individuellement chaque extension
- **FR-006**: Le système DOIT supporter environ 100 extensions réparties sur plusieurs écrans si nécessaire
- **FR-007**: Les sélections de l'utilisateur DOIVENT être persistées et appliquées lors de l'installation

#### Fenêtre de gestion post-installation

- **FR-008**: Le Centre de paquets DOIT afficher un bouton "Ouvrir" pour le package PHP 8.4
- **FR-009**: Le bouton "Ouvrir" DOIT lancer une fenêtre DSM native (pas un onglet navigateur externe)
- **FR-010**: La fenêtre de gestion DOIT afficher toutes les extensions disponibles avec leur état actuel
- **FR-011**: L'utilisateur DOIT pouvoir activer/désactiver chaque extension via des cases à cocher
- **FR-012**: La fenêtre DOIT proposer un bouton pour appliquer les modifications
- **FR-013**: L'application des modifications DOIT redémarrer le service PHP automatiquement
- **FR-014**: Le système DOIT afficher un indicateur de progression pendant le redémarrage

#### Gestion des dépendances et conflits

- **FR-015**: Le système DOIT détecter les dépendances entre extensions
- **FR-016**: Le système DOIT avertir l'utilisateur si une extension désactivée est requise par une autre
- **FR-017**: Le système DOIT proposer d'activer automatiquement les extensions dépendantes
- **FR-018**: Le système DOIT empêcher les configurations incompatibles connues

### Key Entities

- **Extension**: Représente un module PHP (.so), possède un nom, une description, une catégorie thématique, un état (activé/désactivé), et potentiellement des dépendances vers d'autres extensions
- **Catégorie thématique**: Regroupement logique d'extensions (ex: "Base de données", "Cache", "Sécurité"), possède un nom et un ordre d'affichage
- **Configuration PHP**: État global des extensions activées, stockée de manière persistante, appliquée au service PHP
- **Service PHP**: Processus système gérant l'exécution PHP, peut être redémarré pour appliquer les changements de configuration

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'utilisateur peut visualiser et parcourir les ~100 extensions en moins de 2 minutes lors de l'installation
- **SC-002**: L'utilisateur peut modifier l'état d'une extension et appliquer le changement en moins de 30 secondes
- **SC-003**: 95% des utilisateurs trouvent l'extension recherchée dans la catégorie attendue du premier coup
- **SC-004**: Le redémarrage du service après modification s'effectue en moins de 10 secondes
- **SC-005**: La fenêtre de gestion s'ouvre en moins de 3 secondes après clic sur "Ouvrir"
- **SC-006**: Aucune erreur de configuration ne survient lorsque l'utilisateur suit les recommandations de dépendances du système

## Assumptions

- DSM 7.2.2 supporte l'ouverture de fenêtres DSM natives via le bouton "Ouvrir" du Centre de paquets
- Le format SPK permet d'intégrer des écrans de configuration multi-pages à l'installation
- Les extensions PHP peuvent être activées/désactivées dynamiquement via la modification de la configuration sans recompilation
- Le service PHP peut être redémarré programmatiquement depuis l'interface DSM
- L'utilisateur a les droits administrateur nécessaires pour modifier la configuration PHP
