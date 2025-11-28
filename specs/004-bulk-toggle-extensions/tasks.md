# Tasks: Boutons d'activation/désactivation globale des extensions

**Feature**: 004-bulk-toggle-extensions
**Branch**: `004-bulk-toggle-extensions`
**Status**: COMPLETED
**Final SPK**: v0070

## Summary

Ajout des boutons "Tout activer" et "Tout désactiver" dans l'Extension Manager, avec gestion automatique des dépendances entre extensions.

---

## Completed Tasks

### T001: Ajouter les boutons HTML [DONE]
- **File**: `spk/php84/src/ui/index.cgi`
- **Changes**:
  - Ajout du style CSS `.btn-danger` (rouge)
  - Ajout des boutons dans la `filter-bar`:
    - "Tout activer" (vert, id=`enable-all-btn`)
    - "Tout désactiver" (rouge, id=`disable-all-btn`)
  - Espacement flexible entre filtres et boutons d'action

### T002: Implémenter les fonctions JavaScript de toggle en masse [DONE]
- **File**: `spk/php84/src/ui/index.cgi`
- **Changes**:
  - `toggleExtCore()`: Version Promise du toggle pour permettre await
  - `enableAllExtensions()`: Active toutes les extensions désactivées
  - `disableAllExtensions()`: Désactive toutes les extensions activées
  - Désactivation des boutons pendant l'opération
  - Message de confirmation à la fin

### T003: Implémenter le système de gestion des dépendances [DONE]
- **File**: `spk/php84/src/ui/index.cgi`
- **Changes**:
  - Carte des dépendances JavaScript:
    ```javascript
    dependencies = {
      'ev': ['sockets'],
      'event': ['sockets'],
      'msgpack': ['session'],
      'mysqli': ['mysqlnd'],
      'pdo_mysql': ['mysqlnd', 'pdo'],
      'redis': ['igbinary'],
      'memcached': ['igbinary', 'msgpack']
    }
    ```
  - Carte inverse pour les dépendants
  - Modification de `toggleExt()` pour:
    - Activer automatiquement les dépendances lors de l'activation
    - Désactiver automatiquement les dépendants lors de la désactivation

### T004: Implémenter l'ordre de chargement dans le backend [DONE]
- **File**: `spk/php84/src/ui/index.cgi`
- **Changes**:
  - `PRIORITY_CORE`: session, sockets, mysqlnd, pdo, igbinary (préfixe 20-)
  - `PRIORITY_DEPENDENT`: ev, event, msgpack, mysqli, pdo_mysql, redis, memcached (préfixe 70-)
  - `get_priority_prefix()`: Retourne le préfixe selon l'extension
  - `enable_ext()`: Supprime les anciens .ini avant de créer le nouveau avec bon préfixe

### T005: Corriger le script postinst pour l'ordre de chargement [DONE]
- **File**: `spk/php84/src/scripts/postinst`
- **Changes**:
  - Mise à jour de `enable_extension()` avec les mêmes préfixes que index.cgi:
    - 20- pour les extensions core
    - 50- pour les extensions standard
    - 70- pour les extensions dépendantes

### T006: Ajouter les librairies manquantes au package [DONE]
- **Files**: Copiées vers `spk/php84/src/target/lib/`
- **Libraries added**:
  - `librabbitmq.so.4` (pour amqp)
  - `libevent*.so` (pour event)
  - `libgpgme.so.11`, `libgpg-error.so.0`, `libassuan.so.0` (pour gnupg)
  - `libldap.so.2`, `liblber.so.2` (pour ldap)
  - `libodbc.so.2`, `libodbcinst.so.2` (pour odbc, pdo_odbc)
  - `libtidy.so.58` (pour tidy)
  - `libyaml-0.so.2` (pour yaml)
  - `libltdl.so.7` (pour odbc)
  - `libiconv.so.2` (pour odbc)

### T007: Supprimer l'extension incompatible seaslog [DONE]
- **Files modified**:
  - `spk/php84/src/conf/extensions.json`: Suppression de seaslog
  - `spk/php84/EXTENSIONS.md`: Mise à jour des compteurs et suppression de seaslog
- **Reason**: `seaslog.so` utilise `php_mkdir_ex` qui n'existe plus dans PHP 8.4

### T008: Mettre à jour la documentation des dépendances [DONE]
- **Files modified**:
  - `spk/php84/src/conf/extensions.json`: Ajout des dépendances pour ev, msgpack
  - `spk/php84/EXTENSIONS.md`: Mise à jour des tableaux de dépendances

---

## Test Criteria (All Passed)

- [x] Les deux boutons sont visibles dans la filter-bar
- [x] "Tout activer" active toutes les extensions
- [x] "Tout désactiver" désactive toutes les extensions
- [x] Les boutons sont désactivés pendant l'opération
- [x] Le compteur se met à jour en temps réel
- [x] Un message de confirmation s'affiche à la fin
- [x] Les dépendances sont activées automatiquement (ev → sockets)
- [x] Les dépendants sont désactivés automatiquement (sockets → ev)
- [x] Pas d'erreur `undefined symbol` à l'installation
- [x] Pas d'erreur `undefined symbol` avec "Tout activer"

---

## Build History

| Version | Changes |
|---------|---------|
| v0063 | Ajout des boutons "Tout activer/désactiver" |
| v0064 | Ajout des librairies manquantes |
| v0065 | Suppression de seaslog, ajout libiconv |
| v0066 | Système de dépendances JavaScript + préfixes backend |
| v0067 | Correction enable_ext pour supprimer anciens .ini |
| v0068 | Ajout libiconv pour odbc |
| v0069 | Ajout dépendance mysqli/mysqlnd |
| v0070 | **FINAL** - Correction préfixes dans postinst |

---

## Remaining Tasks

**Aucune** - Fonctionnalité complète et testée.

## Notes

Le système de préfixes doit rester synchronisé entre:
1. `index.cgi` (PRIORITY_CORE, PRIORITY_DEPENDENT, get_priority_prefix)
2. `postinst` (enable_extension case statement)

Tout ajout de nouvelle dépendance doit être fait dans les deux fichiers.
