# Research: Comportement par défaut des extensions selon le profil

**Feature**: 003-profile-extensions-default
**Date**: 2025-11-28

## 1. Analyse du problème

### Symptôme observé

Lorsqu'on choisit les profils "Minimal" ou "Standard" **sans sélectionner d'extensions optionnelles**, l'Extension Manager affiche des extensions activées "au hasard" après l'installation.

### Cause racine identifiée

**Le bug est dû à un problème de nommage des variables d'environnement du wizard.**

Dans le fichier `postinst` (lignes 285-297), le code vérifie les variables :
```bash
if [ "$profile_complete" = "true" ]; then
    # ...
elif [ "$profile_minimal" = "true" ]; then
    # ...
```

**MAIS** : DSM ne passe pas ces variables directement. Selon la [documentation Synology](https://help.synology.com/developer-guide/synology_package/wizard/WIZARD_UIFILES_v2.html), les clés définies dans `install_uifile.sh` peuvent être passées :
1. **Sans préfixe** (comportement par défaut DSM 7.2)
2. **Avec préfixe `wizard_`** (convention spksrc/SynoCommunity)
3. **Avec préfixe `pkgwizard_`** (ancienne convention)

### Vérification dans le code actuel

**Wizard (`install_uifile.sh`)** - Clés définies :
```json
"key": "profile_minimal"
"key": "profile_standard"
"key": "profile_complete"
"key": "min_apcu"
"key": "std_redis"
// etc.
```

**Postinst** - Variables attendues :
```bash
$profile_minimal
$profile_complete
$min_apcu
$std_redis
```

### Diagnostic

Le problème est que **les variables ne sont pas initialisées** correctement. Quand une variable shell n'est pas définie :
- `[ "$profile_complete" = "true" ]` → FAUX
- `[ "$profile_minimal" = "true" ]` → FAUX
- Le code tombe dans le `else` → profil "Standard" par défaut

Mais ensuite, les fonctions `enable_profile_standard()` et `enable_profile_minimal()` activent quand même leurs extensions de base, car elles sont appelées inconditionnellement.

## 2. Flux de données Wizard → Postinst

### Comment DSM passe les variables du wizard

D'après la [documentation WIZARD_UIFILES](https://help.synology.com/developer-guide/synology_package/wizard/WIZARD_UIFILES_v2.html) :

> "Once these components are selected, their keys will be set in the script environment variables with true, false, or text values."

**Format des variables** :
- `singleselect` → une seule variable à `true`, les autres à `false`
- `multiselect` → chaque case cochée = `true`, non cochée = `false`

### Convention de nommage

| Source | Préfixe | Exemple |
|--------|---------|---------|
| DSM natif | aucun | `$profile_minimal` |
| spksrc | `wizard_` | `$wizard_profile_minimal` |
| Ancien DSM | `pkgwizard_` | `$pkgwizard_profile_minimal` |

**Recommandation** : Utiliser le préfixe `wizard_` pour compatibilité avec spksrc et clarté du code.

## 3. Solution proposée

### Option A : Préfixer les clés dans le wizard (RETENUE)

Modifier `install_uifile.sh` pour utiliser le préfixe `wizard_` :

```json
"key": "wizard_profile_minimal"
"key": "wizard_profile_standard"
"key": "wizard_profile_complete"
"key": "wizard_min_apcu"
```

Et adapter `postinst` :
```bash
if [ "$wizard_profile_complete" = "true" ]; then
```

**Avantages** :
- Convention standard spksrc
- Variables explicitement nommées
- Pas d'ambiguïté avec d'autres variables

### Option B : Debug des variables reçues

Ajouter un logging pour voir exactement quelles variables sont disponibles :
```bash
log "Environment variables:"
env | grep -i wizard >> "${LOG_FILE}"
env | grep -i profile >> "${LOG_FILE}"
```

### Option C : Valeurs par défaut explicites

Initialiser les variables avec des valeurs par défaut :
```bash
profile_minimal="${profile_minimal:-false}"
profile_standard="${profile_standard:-false}"
profile_complete="${profile_complete:-false}"
```

## 4. Comportement attendu par profil

### Profil Minimal (sans sélection)

| État | Extensions activées |
|------|---------------------|
| Attendu | 0 (aucune) |
| Actuel (bug) | 7+ (extensions de base) |

**Correction** : Si `wizard_profile_minimal=true` ET aucune extension cochée → ne rien activer.

### Profil Standard (sans sélection)

| État | Extensions activées |
|------|---------------------|
| Attendu | 0 (aucune) |
| Actuel (bug) | 23+ (extensions web) |

**Correction** : Si `wizard_profile_standard=true` ET aucune extension cochée → ne rien activer.

### Profil Complet

| État | Extensions activées |
|------|---------------------|
| Attendu | Toutes (~142) |
| Actuel | Toutes (correct) |

**Pas de changement nécessaire.**

## 5. Architecture de la solution

### Fichiers impactés

| Fichier | Modification |
|---------|--------------|
| `src/wizard/install_uifile.sh` | Préfixer les clés avec `wizard_` |
| `src/scripts/postinst` | Utiliser les variables préfixées, logique conditionnelle |

### Logique révisée du postinst

```
SI wizard_profile_complete = true
    → Activer TOUTES les extensions
SINON SI wizard_profile_minimal = true
    → Activer UNIQUEMENT les extensions cochées dans min_*
SINON (standard par défaut)
    → Activer UNIQUEMENT les extensions cochées dans std_*
FIN SI
```

**Point clé** : Les profils Minimal et Standard n'activent plus d'extensions "de base" automatiquement. Seules les extensions explicitement cochées sont activées.

## 6. Gestion des mises à jour

### Préservation des extensions existantes

Lors d'une mise à jour (`SYNOPKG_PKG_STATUS=UPGRADE`), le comportement doit être :
- **Conserver** les extensions déjà activées
- **Ne pas** réinitialiser selon le profil original

**Implémentation** :
```bash
if [ "$SYNOPKG_PKG_STATUS" = "UPGRADE" ]; then
    log "Upgrade: preserving existing extensions"
    # Ne pas modifier conf.d/
else
    # Nouvelle installation: appliquer la logique wizard
fi
```

## 7. Références

- [Synology WIZARD_UIFILES v2](https://help.synology.com/developer-guide/synology_package/wizard/WIZARD_UIFILES_v2.html)
- [Synology Script Environment Variables](https://help.synology.com/developer-guide/synology_package/script_env_var.html)
- [spksrc Service Support](https://github.com/SynoCommunity/spksrc/wiki/Service-Support)
- [spksrc transmission service-setup.sh](https://github.com/SynoCommunity/spksrc/blob/master/spk/transmission/src/service-setup.sh) - exemple d'utilisation de `wizard_` prefix
- [spksrc minio service-setup.sh](https://github.com/SynoCommunity/spksrc/blob/master/spk/minio/src/service-setup.sh) - exemple de stockage des variables wizard

## 8. Décisions

| Question | Décision | Justification |
|----------|----------|---------------|
| Préfixe des variables | `wizard_` | Convention spksrc standard |
| Extensions par défaut Minimal | Aucune | Respect de la demande utilisateur |
| Extensions par défaut Standard | Aucune | Respect de la demande utilisateur |
| Extensions par défaut Complet | Toutes | Comportement attendu du profil |
| Mise à jour | Préserver | Ne pas casser les configurations existantes |
