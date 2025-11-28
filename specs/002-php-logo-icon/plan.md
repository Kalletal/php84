# Implementation Plan: PHP Logo Icon Update

**Branch**: `002-php-logo-icon` | **Date**: 2025-11-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-php-logo-icon/spec.md`

## Summary

Remplacer les icônes actuelles du package PHP84 par le logo officiel PHP (ellipse lavande avec texte "php" noir). Le SVG source sera téléchargé depuis Wikimedia Commons et converti en PNG aux différentes tailles requises par DSM (72x72, 256x256) et l'interface Extension Manager (16-72px).

## Technical Context

**Language/Version**: Bash (scripts de conversion)
**Primary Dependencies**: ImageMagick (convert) pour conversion SVG→PNG
**Storage**: N/A (fichiers statiques PNG)
**Testing**: Vérification visuelle après installation du SPK
**Target Platform**: Synology DSM 7.2+ (geminilake)
**Project Type**: Single (assets statiques)
**Performance Goals**: N/A (fichiers statiques)
**Constraints**: PNG RGB 16-bit, proportions ellipse conservées
**Scale/Scope**: 8 fichiers PNG à générer

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Status | Notes |
|----------|--------|-------|
| I. Package Autonome | N/A | Pas de nouvelles dépendances runtime |
| II. Compatibilité DSM | PASS | Respect des conventions PACKAGE_ICON*.png |
| III. Compilation Reproductible | PASS | Script de génération des icônes documenté |
| IV. Sécurité | N/A | Pas d'impact sécurité |
| V. Modularité Extensions | N/A | Pas d'impact sur les extensions |

**Constitution Check Result**: PASS - Aucune violation

## Project Structure

### Documentation (this feature)

```text
specs/002-php-logo-icon/
├── plan.md              # This file
├── research.md          # SVG source verification, license, conversion method
├── quickstart.md        # Quick implementation guide
└── checklists/
    └── requirements.md  # Spec validation checklist
```

### Source Code (repository root)

```text
spk/php84/src/
├── PACKAGE_ICON.PNG         # 72x72 - Centre de paquets
├── PACKAGE_ICON_256.PNG     # 256x256 - HiDPI
└── ui/images/
    ├── php84_16.png         # 16x16 - UI icons
    ├── php84_24.png         # 24x24
    ├── php84_32.png         # 32x32
    ├── php84_48.png         # 48x48
    ├── php84_64.png         # 64x64
    └── php84_72.png         # 72x72
```

**Structure Decision**: Remplacement in-place des fichiers PNG existants. Pas de nouvelle structure.

## Complexity Tracking

> Aucune violation de constitution - section non applicable.

---

## Phase 0: Research

### Findings

#### 1. Source SVG

- **URL**: https://upload.wikimedia.org/wikipedia/commons/2/27/PHP-logo.svg
- **License**: CC BY-SA 4.0 (usage autorisé avec attribution)
- **Dimensions originales**: 711 x 384 pixels (ratio ~1.85:1)
- **Description**: Ellipse horizontale violet/lavande avec texte "php" en noir

#### 2. Conversion Method

- **Outil**: ImageMagick `convert` (déjà installé sur le système)
- **Commande**: `convert -background none -resize WxH input.svg output.png`
- **Alternative**: `rsvg-convert` si meilleure qualité nécessaire

#### 3. Gestion des proportions

Le logo PHP est une ellipse horizontale (ratio ~1.85:1). Pour les icônes carrées DSM :
- **Option A**: Centrer l'ellipse dans un carré avec fond transparent
- **Option B**: Recadrer pour remplir le carré (déformation)
- **Décision**: Option A - Conserver les proportions, centrer dans carré

#### 4. Tailles requises

| Fichier | Taille | Usage |
|---------|--------|-------|
| PACKAGE_ICON.PNG | 72x72 | Centre de paquets (standard) |
| PACKAGE_ICON_256.PNG | 256x256 | Centre de paquets (HiDPI) |
| php84_16.png | 16x16 | Icône mini (tree view) |
| php84_24.png | 24x24 | Toolbar |
| php84_32.png | 32x32 | Liste |
| php84_48.png | 48x48 | Grid view |
| php84_64.png | 64x64 | Grande icône |
| php84_72.png | 72x72 | Titre application |

---

## Phase 1: Implementation Design

### Task Breakdown

#### T001: Download SVG source
- Télécharger le SVG depuis Wikimedia Commons
- Vérifier l'intégrité du fichier
- Stocker temporairement pour conversion

#### T002: Generate Package Center icons
- Convertir SVG → PACKAGE_ICON.PNG (72x72)
- Convertir SVG → PACKAGE_ICON_256.PNG (256x256)
- Conserver proportions, fond transparent, centrer

#### T003: Generate UI icons
- Convertir SVG pour toutes les tailles UI (16, 24, 32, 48, 64, 72)
- Même traitement que T002

#### T004: Replace existing icons
- Sauvegarder les anciennes icônes (optionnel)
- Copier les nouvelles icônes aux emplacements corrects

#### T005: Rebuild and test SPK
- Rebuilder le package avec les nouvelles icônes
- Tester l'affichage dans le Centre de paquets
- Tester l'affichage dans l'Extension Manager

### Conversion Script

```bash
#!/bin/bash
# generate-php-icons.sh

SVG_URL="https://upload.wikimedia.org/wikipedia/commons/2/27/PHP-logo.svg"
SVG_FILE="php-logo.svg"
DEST_PKG="spk/php84/src"
DEST_UI="spk/php84/src/ui/images"

# Download SVG
curl -sL "$SVG_URL" -o "$SVG_FILE"

# Package Center icons (square, centered)
convert -background none -gravity center -extent 72x72 -resize 72x72 "$SVG_FILE" "$DEST_PKG/PACKAGE_ICON.PNG"
convert -background none -gravity center -extent 256x256 -resize 256x256 "$SVG_FILE" "$DEST_PKG/PACKAGE_ICON_256.PNG"

# UI icons
for SIZE in 16 24 32 48 64 72; do
    convert -background none -gravity center -extent ${SIZE}x${SIZE} -resize ${SIZE}x${SIZE} "$SVG_FILE" "$DEST_UI/php84_${SIZE}.png"
done

# Cleanup
rm "$SVG_FILE"

echo "Icons generated successfully"
```

### Dependencies

- ImageMagick (`convert`) - déjà installé
- curl - pour téléchargement SVG
- Aucune nouvelle dépendance runtime dans le SPK

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| SVG source indisponible | Bloquant | Télécharger et versionner le SVG localement |
| Qualité conversion basse résolution | Visuel | Tester lisibilité à 16x16, ajuster si nécessaire |
| Transparence mal rendue | Visuel | Tester sur fond clair et sombre |
