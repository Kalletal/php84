# Quickstart: Boutons d'activation/désactivation globale

## Résumé

Ajouter deux boutons "Tout activer" et "Tout désactiver" dans l'Extension Manager pour permettre l'activation/désactivation de toutes les extensions PHP en un clic.

## Fichier à modifier

```
spk/php84/src/ui/index.cgi
```

## Modifications requises

### 1. Ajouter les boutons HTML (dans la filter-bar)

Localiser la section `filter-bar` et ajouter les boutons :

```html
<div class="filter-bar">
    <button class="filter-btn active" onclick="setFilter('all', this)">Toutes</button>
    <button class="filter-btn" onclick="setFilter('enabled', this)">Activées</button>
    <button class="filter-btn" onclick="setFilter('disabled', this)">Désactivées</button>
    <span style="flex:1"></span>
    <button class="btn btn-success" id="enable-all-btn" onclick="enableAllExtensions()">Tout activer</button>
    <button class="btn btn-danger" id="disable-all-btn" onclick="disableAllExtensions()">Tout désactiver</button>
</div>
```

### 2. Ajouter le style CSS pour btn-danger

```css
.btn-danger { background: #f44336; color: #fff; }
.btn-danger:hover { background: #d32f2f; }
.btn-danger:disabled, .btn-success:disabled { background: #ccc; cursor: not-allowed; }
```

### 3. Ajouter les fonctions JavaScript

```javascript
// Promise wrapper pour toggleExt
function toggleExtAsync(el, targetState) {
    return new Promise(function(resolve) {
        var ext = el.getAttribute('data-ext');
        var isEnabled = el.classList.contains('enabled');

        // Skip si déjà dans l'état cible
        if ((targetState === 'enabled' && isEnabled) ||
            (targetState === 'disabled' && !isEnabled)) {
            resolve({skipped: true});
            return;
        }

        el.classList.add('pending');
        var xhr = new XMLHttpRequest();
        xhr.open('POST', 'index.cgi', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                el.classList.remove('pending');
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (resp.success) {
                            if (resp.enabled) {
                                el.classList.remove('disabled');
                                el.classList.add('enabled');
                            } else {
                                el.classList.remove('enabled');
                                el.classList.add('disabled');
                            }
                            updateEnabledCount();
                        }
                        resolve(resp);
                    } catch(e) {
                        resolve({success: false, error: 'Parse error'});
                    }
                } else {
                    resolve({success: false, error: 'Server error'});
                }
            }
        };
        xhr.send('action=toggle&ext=' + encodeURIComponent(ext));
    });
}

// Activer toutes les extensions
async function enableAllExtensions() {
    var btn = document.getElementById('enable-all-btn');
    var btnDisable = document.getElementById('disable-all-btn');
    btn.disabled = true;
    btnDisable.disabled = true;
    btn.textContent = 'En cours...';

    var exts = document.querySelectorAll('.ext.disabled');
    var errors = [];

    for (var i = 0; i < exts.length; i++) {
        var result = await toggleExtAsync(exts[i], 'enabled');
        if (result && !result.success && !result.skipped) {
            errors.push(exts[i].getAttribute('data-ext'));
        }
    }

    pendingChanges = true;
    updateChangesIndicator();

    btn.disabled = false;
    btnDisable.disabled = false;
    btn.textContent = 'Tout activer';

    if (errors.length > 0) {
        showMessage('Terminé avec ' + errors.length + ' erreur(s)', 'error');
    } else {
        showMessage('Toutes les extensions activées', 'success');
    }
}

// Désactiver toutes les extensions
async function disableAllExtensions() {
    var btn = document.getElementById('disable-all-btn');
    var btnEnable = document.getElementById('enable-all-btn');
    btn.disabled = true;
    btnEnable.disabled = true;
    btn.textContent = 'En cours...';

    var exts = document.querySelectorAll('.ext.enabled');
    var errors = [];

    for (var i = 0; i < exts.length; i++) {
        var result = await toggleExtAsync(exts[i], 'disabled');
        if (result && !result.success && !result.skipped) {
            errors.push(exts[i].getAttribute('data-ext'));
        }
    }

    pendingChanges = true;
    updateChangesIndicator();

    btn.disabled = false;
    btnEnable.disabled = false;
    btn.textContent = 'Tout désactiver';

    if (errors.length > 0) {
        showMessage('Terminé avec ' + errors.length + ' erreur(s)', 'error');
    } else {
        showMessage('Toutes les extensions désactivées', 'success');
    }
}
```

## Test rapide

1. Rebuilder le SPK : `./scripts/build-spk.sh`
2. Installer sur NAS
3. Ouvrir l'Extension Manager
4. Cliquer sur "Tout désactiver" → toutes les extensions passent en gris
5. Cliquer sur "Tout activer" → toutes les extensions passent en vert
6. Vérifier le compteur "142 / 142"
7. Cliquer sur "Appliquer & Recharger"

## Critères de succès

- [ ] Les deux boutons sont visibles dans la filter-bar
- [ ] "Tout activer" active toutes les extensions en ~30 secondes
- [ ] "Tout désactiver" désactive toutes les extensions en ~30 secondes
- [ ] Les boutons sont désactivés pendant l'opération
- [ ] Le compteur se met à jour en temps réel
- [ ] Un message de confirmation s'affiche à la fin
