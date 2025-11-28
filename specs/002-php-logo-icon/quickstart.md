# Quickstart: PHP Logo Icon Update

**Feature**: 002-php-logo-icon
**Estimated time**: 10 minutes

## Prerequisites

- ImageMagick installé (`convert` command)
- curl installé
- Accès internet (téléchargement SVG)

## Quick Implementation

### Step 1: Download and convert icons

```bash
cd /home/gilles/ProjetSPK/php84

# Download SVG
curl -sL "https://upload.wikimedia.org/wikipedia/commons/2/27/PHP-logo.svg" -o php-logo.svg

# Generate Package Center icons
convert -background none -gravity center -resize 72x72 -extent 72x72 php-logo.svg spk/php84/src/PACKAGE_ICON.PNG
convert -background none -gravity center -resize 256x256 -extent 256x256 php-logo.svg spk/php84/src/PACKAGE_ICON_256.PNG

# Generate UI icons
for SIZE in 16 24 32 48 64 72; do
    convert -background none -gravity center -resize ${SIZE}x${SIZE} -extent ${SIZE}x${SIZE} php-logo.svg spk/php84/src/ui/images/php84_${SIZE}.png
done

# Cleanup
rm php-logo.svg
```

### Step 2: Verify icons

```bash
# Check file sizes
file spk/php84/src/PACKAGE_ICON*.PNG spk/php84/src/ui/images/php84_*.png

# Visual check - open in image viewer
xdg-open spk/php84/src/PACKAGE_ICON_256.PNG
```

### Step 3: Rebuild SPK

```bash
./spk/php84/scripts/build-spk.sh
```

### Step 4: Test on NAS

1. Upload new SPK to NAS
2. Update/reinstall package
3. Verify icon in Package Center
4. Open Extension Manager, verify icon in title bar

## Verification Checklist

- [ ] PACKAGE_ICON.PNG is 72x72 with PHP logo
- [ ] PACKAGE_ICON_256.PNG is 256x256 with PHP logo
- [ ] All php84_*.png files have PHP logo
- [ ] Logo visible on light and dark backgrounds
- [ ] Package installs without errors
- [ ] Icon displays correctly in Package Center
