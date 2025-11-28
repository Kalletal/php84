# Research: PHP Logo Icon Update

**Feature**: 002-php-logo-icon
**Date**: 2025-11-28

## 1. Source SVG Analysis

### Source URL
- **URL**: https://upload.wikimedia.org/wikipedia/commons/2/27/PHP-logo.svg
- **Type**: SVG (Scalable Vector Graphics)
- **Origin**: Wikimedia Commons

### License
- **License**: CC BY-SA 4.0 (Creative Commons Attribution-ShareAlike)
- **Usage**: Autorisé pour usage dans un projet open source
- **Attribution**: "PHP Logo" by Colin Viebrock, licensed under CC BY-SA 4.0

### Dimensions
- **Original Size**: 711 x 384 pixels
- **Aspect Ratio**: ~1.85:1 (ellipse horizontale)
- **Colors**:
  - Fond ellipse: #8892BF (lavande/violet clair)
  - Texte "php": #000000 (noir)

## 2. DSM Icon Requirements

### Breaking Change DSM 7.0

**IMPORTANT**: DSM 7.0 a introduit un changement majeur pour les icônes de packages.

| Version DSM | PACKAGE_ICON.PNG | Source |
|-------------|------------------|--------|
| DSM 6.x | 72x72 pixels | [spksrc #907](https://github.com/SynoCommunity/spksrc/issues/907) |
| DSM 7.0+ | **64x64 pixels** | [Breaking Changes](https://help.synology.com/developer-guide/breaking_changes.html) |

> "Change `PACKAGE_ICON.PNG` from 72x72 to 64x64" - Synology Developer Guide

### Package Center Icons

| Fichier | Taille DSM 7 | Format | Usage |
|---------|--------------|--------|-------|
| PACKAGE_ICON.PNG | **64x64** | PNG RGBA | Liste des paquets |
| PACKAGE_ICON_256.PNG | 256x256 | PNG RGBA | Détail paquet, HiDPI |

**Conventions importantes**:
- Noms en **MAJUSCULES** avec extension `.PNG` (sensible à la casse)
- Le fichier doit être à la **racine du SPK** (pas dans un sous-dossier)
- DSM cache et redimensionne les icônes automatiquement

### Cache des icônes DSM

DSM stocke les icônes extraites dans:
```
/volume1/@tmp/synopkg/lfs/image/INST/{package}/{version}/
├── thumb_64.png   ← Généré depuis PACKAGE_ICON.PNG
└── thumb_256.png  ← Généré depuis PACKAGE_ICON_256.PNG
```

Si ce dossier est **vide**, DSM n'a pas réussi à extraire les icônes du SPK.

### Diagnostic du problème (2025-11-28)

**Symptôme**: Icône non mise à jour dans le Package Center malgré nouveaux fichiers dans le SPK.

**Investigation**:
```bash
# Le dossier cache existe mais est VIDE
$ ls /volume1/@tmp/synopkg/lfs/image/INST/php84/8.4.15-0054/
(aucun fichier)
```

**Causes probables**:
1. ~~Taille incorrecte (72x72 au lieu de 64x64 pour DSM 7)~~ - Non, 64x64 "or larger" accepté
2. **Nom de fichier incorrect** - DSM attend `.PNG` (majuscule), nous avions `.png` (minuscule)
3. Format PNG corrompu ou incompatible

### UI Application Icons

| Fichier | Taille | Usage |
|---------|--------|-------|
| php84_16.png | 16x16 | Tree view, petites listes |
| php84_24.png | 24x24 | Toolbar icons |
| php84_32.png | 32x32 | Listes standard |
| php84_48.png | 48x48 | Grid view |
| php84_64.png | 64x64 | Grandes icônes |
| php84_72.png | 72x72 | Titre fenêtre DSM |

## 3. Conversion Strategy

### Problème: Ratio non carré

Le logo PHP est une ellipse horizontale (1.85:1) mais DSM attend des icônes carrées (1:1).

### Solution retenue: Centrer avec padding transparent

```
┌─────────────────┐
│                 │
│   ┌─────────┐   │
│   │  php    │   │  ← Logo centré
│   └─────────┘   │
│                 │
└─────────────────┘
     256x256
```

**Avantages**:
- Conserve les proportions originales
- Pas de déformation
- Logo reconnaissable à toutes tailles

**Inconvénients**:
- Utilise moins d'espace disponible
- Logo plus petit visuellement

### Alternative rejetée: Remplir le carré

Déformerait l'ellipse en cercle, perdant l'identité visuelle du logo PHP.

## 4. Conversion Tools

### ImageMagick (convert) - Retenu

**Disponibilité**: Installé sur le système (`/usr/bin/convert`)

**Commande**:
```bash
convert -background none -gravity center -resize 256x256 -extent 256x256 input.svg output.png
```

**Paramètres**:
- `-background none`: Fond transparent
- `-gravity center`: Centre l'image
- `-resize WxH`: Redimensionne en conservant le ratio
- `-extent WxH`: Étend au canvas carré

### Alternatives considérées

| Outil | Avantage | Inconvénient |
|-------|----------|--------------|
| rsvg-convert | Meilleur rendu SVG | Non installé |
| Inkscape | Haute qualité | Lourd, CLI complexe |
| cairosvg | Python, portable | Nécessite installation |

**Décision**: ImageMagick suffit pour cette tâche simple.

## 5. Quality Considerations

### Lisibilité petites tailles

À 16x16 pixels, le texte "php" sera difficilement lisible. Cependant:
- L'ellipse lavande reste reconnaissable
- La forme suffit pour l'identification

### Test recommandé

Après génération, vérifier visuellement:
1. Lisibilité à 72x72 et 256x256 ✓
2. Forme reconnaissable à 16x16 et 24x24 ✓
3. Transparence correcte sur fond clair et sombre ✓

## 6. Current Icons Analysis

### Icônes actuelles

```bash
$ file spk/php84/src/PACKAGE_ICON*.png
PACKAGE_ICON.PNG:     PNG image data, 72 x 72, 16-bit/color RGB
PACKAGE_ICON_256.PNG: PNG image data, 256 x 256, 16-bit/color RGB
```

**Format actuel**: PNG 16-bit RGB (pas d'alpha/transparence)

### Décision format cible

- **Avec transparence**: PNG 32-bit RGBA pour fond transparent autour de l'ellipse
- **Alternative**: PNG RGB avec fond blanc si transparence pose problème

## 7. Implementation Checklist

- [x] Source SVG identifiée et licence vérifiée
- [x] Outil de conversion disponible (ImageMagick)
- [x] Tailles requises documentées
- [x] Stratégie de conversion décidée (centrer avec padding)
- [ ] Script de conversion créé
- [ ] Icônes générées
- [ ] Tests visuels effectués

## 8. References

- [PHP Logo on Wikimedia](https://commons.wikimedia.org/wiki/File:PHP-logo.svg)
- [Synology Package Developer Guide](https://help.synology.com/developer-guide/)
- [Synology Breaking Changes DSM 7](https://help.synology.com/developer-guide/breaking_changes.html)
- [Synology First Package Guide](https://help.synology.com/developer-guide/getting_started/first_package.html)
- [spksrc - SynoCommunity](https://github.com/SynoCommunity/spksrc)
- [SPK Package Format - Package Origin](https://packageorigin.com/reference/spk/)
- [ImageMagick SVG Support](https://imagemagick.org/script/formats.php#svg)

## 9. Solution implémentée (2025-11-28)

### Correction du script build-spk.sh

Le problème était que le script utilisait `.png` (minuscule) dans l'archive tar, mais DSM attend `.PNG` (majuscule) pour certaines opérations.

**Modification**: Renommer les fichiers avec extension `.PNG` majuscule avant inclusion dans le SPK.

```bash
# Avant (ne fonctionnait pas)
for icon in src/PACKAGE_ICON*.png; do

# Après (correction)
for icon in src/PACKAGE_ICON*.PNG; do
```

### Commandes de conversion mises à jour

```bash
# PACKAGE_ICON.PNG (64x64 pour DSM 7)
convert -background none -gravity center -resize 64x64 -extent 64x64 php-logo.svg PACKAGE_ICON.PNG

# PACKAGE_ICON_256.PNG
convert -background none -gravity center -resize 256x256 -extent 256x256 php-logo.svg PACKAGE_ICON_256.PNG
```

### Résultat final (2025-11-28)

**Version**: php84-8.4.15-0056-geminilake-7.2.spk

**Fichiers corrigés**:
- `src/PACKAGE_ICON.PNG` (72x72, 4813 bytes) - Extension MAJUSCULE
- `src/PACKAGE_ICON_256.PNG` (256x256, 26106 bytes) - Extension MAJUSCULE
- `src/ui/images/icon_all.png` - Remplacé par logo PHP
- `src/ui/images/icon_category.png` - Remplacé par logo PHP

**Test validé**:
- Icône visible dans le Centre de paquets DSM
- Icône visible dans l'Extension Manager
