# Implementation Plan: Boutons d'activation/désactivation globale des extensions

**Branch**: `004-bulk-toggle-extensions` | **Date**: 2025-11-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-bulk-toggle-extensions/spec.md`

## Summary

Ajouter deux boutons "Tout activer" et "Tout désactiver" dans l'Extension Manager PHP 8.4 pour permettre l'activation ou la désactivation de toutes les extensions (~142) en un seul clic. L'implémentation utilise une approche côté client avec des appels séquentiels au backend existant pour assurer un feedback visuel en temps réel.

## Technical Context

**Language/Version**: Bash (CGI backend), HTML/CSS/JavaScript vanilla (frontend)
**Primary Dependencies**: Aucune nouvelle dépendance - réutilisation du code existant
**Storage**: Fichiers `.ini` dans `/var/packages/php84/var/etc/conf.d/`
**Testing**: Tests manuels sur NAS Synology DS920+
**Target Platform**: Synology DSM 7.2+ (navigateur web)
**Project Type**: Single file modification (index.cgi)
**Performance Goals**: Traitement de ~142 extensions en moins de 30 secondes
**Constraints**: Exécution séquentielle pour éviter surcharge serveur, interface responsive
**Scale/Scope**: ~142 extensions PHP

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Statut | Justification |
|----------|--------|---------------|
| I. Package Autonome | ✅ PASS | Pas de nouvelles dépendances |
| II. Compatibilité DSM | ✅ PASS | Utilise le même mécanisme CGI existant |
| III. Compilation Reproductible | ✅ PASS | Modification de script uniquement |
| IV. Sécurité | ✅ PASS | Réutilise l'authentification DSM existante |
| V. Modularité des Extensions | ✅ PASS | Utilise le même système de fichiers .ini |

**Gate Result**: ✅ PASS - Aucune violation de la constitution

## Project Structure

### Documentation (this feature)

```text
specs/004-bulk-toggle-extensions/
├── spec.md              # Spécification fonctionnelle
├── plan.md              # Ce fichier
├── research.md          # Recherche technique (décisions, alternatives)
├── quickstart.md        # Guide d'implémentation rapide
├── contracts/           # (vide - pas d'API REST formelle)
└── tasks.md             # À générer via /speckit.tasks
```

### Source Code (repository root)

```text
spk/php84/src/ui/
└── index.cgi            # Extension Manager - SEUL fichier à modifier
```

**Structure Decision**: Modification d'un seul fichier existant (`index.cgi`). Pas de nouveau fichier nécessaire car la fonctionnalité s'intègre directement dans l'interface existante.

## Implementation Approach

### Phase 1: Modifications CSS

Ajouter les styles pour le bouton "danger" (rouge) :
- `.btn-danger` avec fond rouge (#f44336)
- États hover et disabled

### Phase 2: Modifications HTML

Modifier la section `filter-bar` pour ajouter :
- Bouton "Tout activer" (vert, id=`enable-all-btn`)
- Bouton "Tout désactiver" (rouge, id=`disable-all-btn`)
- Espacement flexible entre filtres et boutons d'action

### Phase 3: Modifications JavaScript

1. **toggleExtAsync()**: Version Promise de toggleExt() pour permettre await
2. **enableAllExtensions()**: Boucle sur `.ext.disabled` et active chaque extension
3. **disableAllExtensions()**: Boucle sur `.ext.enabled` et désactive chaque extension

### Comportement attendu

1. Clic sur bouton → Boutons désactivés, texte "En cours..."
2. Traitement séquentiel → Chaque extension se met à jour visuellement
3. Fin de traitement → Message de succès/erreur, boutons réactivés
4. pendingChanges = true → Indicateur de changements visible

## Complexity Tracking

> Aucune violation de la constitution - pas de justification nécessaire.

| Aspect | Complexité | Justification |
|--------|------------|---------------|
| Fichiers modifiés | 1 | Minimaliste |
| Nouvelles fonctions JS | 3 | Nécessaires pour la fonctionnalité |
| Dépendances ajoutées | 0 | Réutilisation complète |

## Risks

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Timeout sur 142 requêtes | Faible | Moyen | Exécution séquentielle |
| Extension en erreur | Faible | Faible | Continuer et signaler |
| Double clic utilisateur | Moyen | Faible | Désactiver boutons |

## Next Steps

1. Exécuter `/speckit.tasks` pour générer les tâches détaillées
2. Implémenter les modifications dans `index.cgi`
3. Rebuilder le SPK
4. Tester sur NAS
