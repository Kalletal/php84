# Research: Boutons d'activation/désactivation globale des extensions

**Feature**: 004-bulk-toggle-extensions
**Date**: 2025-11-28

## Architecture existante

### Extension Manager (index.cgi)

L'Extension Manager actuel est implémenté comme un script CGI Bash (`spk/php84/src/ui/index.cgi`) qui :

1. **Backend (Bash CGI)** :
   - Gère les requêtes GET (affichage HTML) et POST (actions)
   - Actions existantes : `toggle` (activer/désactiver une extension), `reload` (recharger PHP-FPM)
   - Authentification DSM via cookies de session
   - Manipulation des fichiers `.ini` dans `/var/packages/php84/var/etc/conf.d/`

2. **Frontend (HTML/JavaScript vanilla)** :
   - Interface responsive avec grille CSS
   - Fonction `toggleExt(el)` pour toggle individuel via XHR POST
   - Fonction `updateEnabledCount()` pour mettre à jour le compteur
   - Variables globales : `pendingChanges`, `currentFilter`

### Mécanisme de toggle actuel

```javascript
function toggleExt(el) {
    var ext = el.getAttribute('data-ext');
    el.classList.add('pending');
    // XHR POST vers index.cgi avec action=toggle&ext=...
    // Met à jour l'UI et pendingChanges après réponse
}
```

Le serveur répond avec JSON : `{"success":true,"enabled":true/false,"ext":"..."}`

## Décisions techniques

### Decision 1: Approche côté client vs serveur

**Decision**: Approche côté **client** (JavaScript)

**Rationale**:
- Réutilise le mécanisme de toggle existant sans modifier le backend
- Permet un feedback visuel en temps réel (chaque extension se met à jour individuellement)
- Évite de créer de nouvelles actions serveur complexes
- Plus simple à maintenir

**Alternatives considérées**:
- Action serveur `enable_all`/`disable_all` : Plus rapide mais pas de feedback granulaire, nécessite modification du CGI
- WebSocket pour temps réel : Overkill pour ce cas d'usage

### Decision 2: Exécution séquentielle vs parallèle

**Decision**: Exécution **séquentielle** avec délai minimal

**Rationale**:
- Évite de surcharger le serveur avec ~142 requêtes simultanées
- Permet de voir la progression extension par extension
- Plus fiable en cas d'erreur (on sait quelle extension a échoué)
- Le script CGI Bash n'est pas conçu pour la haute concurrence

**Implementation**:
```javascript
async function enableAllExtensions() {
    var exts = document.querySelectorAll('.ext.disabled');
    for (var i = 0; i < exts.length; i++) {
        await toggleExtAsync(exts[i]);
    }
}
```

### Decision 3: Placement des boutons

**Decision**: Dans la barre de filtres existante, à droite

**Rationale**:
- Cohérent avec l'UI existante
- Visible sans défiler
- Séparé du bouton "Appliquer & Recharger" pour éviter confusion

**Layout**:
```
[Toutes] [Activées] [Désactivées]    [Tout activer] [Tout désactiver]
```

### Decision 4: Gestion des erreurs

**Decision**: Continuer l'opération et signaler les erreurs à la fin

**Rationale**:
- Une extension en erreur ne doit pas bloquer les autres
- L'utilisateur voit le résultat global
- Les extensions en erreur restent visibles pour action manuelle

## Contraintes techniques identifiées

1. **Performance** : ~142 requêtes séquentielles = ~30 secondes max (acceptable)
2. **Feedback** : Mise à jour visuelle de chaque extension au fur et à mesure
3. **État des boutons** : Désactivés pendant l'opération pour éviter conflits
4. **Compteur** : Mis à jour après chaque toggle pour refléter la progression

## Fichiers à modifier

| Fichier | Modifications |
|---------|---------------|
| `spk/php84/src/ui/index.cgi` | Ajouter boutons HTML + fonctions JavaScript |

## Risques et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Timeout serveur | Faible | Moyen | Requêtes séquentielles avec délai |
| Extension en erreur | Faible | Faible | Continuer et signaler à la fin |
| Double clic | Moyen | Faible | Désactiver boutons pendant opération |

## Références

- Code source actuel : `spk/php84/src/ui/index.cgi:332-369` (fonction toggleExt)
- Documentation DSM CGI : Non applicable (script custom)
