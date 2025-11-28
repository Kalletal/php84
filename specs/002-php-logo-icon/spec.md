# Feature Specification: PHP Logo Icon Update

**Feature Branch**: `002-php-logo-icon`
**Created**: 2025-11-28
**Status**: Draft
**Input**: User description: "il faudrait modifier l'icône dans le centre de paquet en mettant celle ci : https://upload.wikimedia.org/wikipedia/commons/2/27/PHP-logo.svg"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Official PHP Logo in Package Center (Priority: P1)

En tant qu'utilisateur du NAS Synology, je veux voir le logo officiel PHP dans le Centre de paquets afin de reconnaître facilement le package PHP84 parmi les autres paquets installés.

**Why this priority**: L'icône est l'élément visuel principal permettant d'identifier rapidement le package. Un logo officiel renforce la crédibilité et la reconnaissance du package.

**Independent Test**: Ouvrir le Centre de paquets DSM, naviguer vers les paquets installés, et vérifier que le logo PHP officiel (fond violet/lavande avec "php" en noir) s'affiche correctement.

**Acceptance Scenarios**:

1. **Given** le package PHP84 est installé, **When** l'utilisateur ouvre le Centre de paquets, **Then** le logo officiel PHP s'affiche à côté du nom du package
2. **Given** le package PHP84 apparaît dans la liste des paquets, **When** l'utilisateur regarde l'icône, **Then** le logo PHP est net et lisible à toutes les tailles d'affichage (72px, 256px)

---

### User Story 2 - View PHP Logo in DSM Application (Priority: P2)

En tant qu'utilisateur, je veux voir le logo officiel PHP dans l'application Extension Manager (accessible via le bouton "Ouvrir") pour une cohérence visuelle avec le Centre de paquets.

**Why this priority**: La cohérence visuelle entre le Centre de paquets et l'application améliore l'expérience utilisateur, mais n'est pas bloquante pour l'utilisation.

**Independent Test**: Cliquer sur "Ouvrir" dans le Centre de paquets et vérifier que l'icône de l'application dans la barre de titre correspond au logo PHP officiel.

**Acceptance Scenarios**:

1. **Given** l'utilisateur clique sur "Ouvrir" pour PHP84, **When** la fenêtre Extension Manager s'ouvre, **Then** l'icône dans la barre de titre est le logo PHP officiel
2. **Given** plusieurs fenêtres DSM sont ouvertes, **When** l'utilisateur regarde la barre des tâches DSM, **Then** le logo PHP permet d'identifier rapidement la fenêtre PHP84

---

### Edge Cases

- Que se passe-t-il si l'icône source (SVG) n'est pas accessible lors du build ?
- Comment le logo s'affiche-t-il sur un fond sombre (thème DSM sombre) ?
- Le logo reste-t-il lisible à petite taille (16x16, 24x24 pixels) ?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le package DOIT afficher le logo officiel PHP (fond lavande avec texte "php" noir) dans le Centre de paquets Synology
- **FR-002**: Le logo DOIT être fourni dans toutes les tailles requises par DSM : PACKAGE_ICON.PNG (72x72) et PACKAGE_ICON_256.PNG (256x256)
- **FR-003**: Le logo DOIT être converti depuis le SVG source (https://upload.wikimedia.org/wikipedia/commons/2/27/PHP-logo.svg) en format PNG
- **FR-004**: Les icônes de l'interface Extension Manager (ui/images/) DOIVENT également utiliser le logo officiel PHP pour les tailles 16x16, 24x24, 32x32, 48x48, 64x64, 72x72
- **FR-005**: Le logo DOIT conserver ses proportions originales (ellipse horizontale) sans déformation

### Key Entities

- **PACKAGE_ICON.PNG**: Icône principale du package (72x72 pixels) affichée dans le Centre de paquets
- **PACKAGE_ICON_256.PNG**: Icône haute résolution (256x256 pixels) pour les écrans Retina/HiDPI
- **ui/images/**: Ensemble d'icônes pour l'application Extension Manager (multiples tailles)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% des icônes du package utilisent le logo officiel PHP (fond lavande, texte "php" noir)
- **SC-002**: Le logo est reconnaissable et lisible à toutes les tailles d'affichage (de 16x16 à 256x256 pixels)
- **SC-003**: Le package s'installe correctement et affiche l'icône dans le Centre de paquets sans erreur
- **SC-004**: L'icône s'affiche correctement dans les thèmes DSM clair et sombre

## Assumptions

- Le logo PHP officiel est disponible sous licence libre permettant son utilisation dans un package open source
- Le format SVG source peut être converti en PNG avec une qualité suffisante pour toutes les tailles requises
- DSM accepte les icônes PNG avec transparence (fond transparent autour de l'ellipse)

## Out of Scope

- Modification du logo PHP (couleurs, forme, texte)
- Animation de l'icône
- Icônes personnalisées pour différentes versions de PHP
