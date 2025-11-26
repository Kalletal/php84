/**
 * PHP 8.4 Extension Manager for Synology DSM 7
 * Native DSM Application using ExtJS
 */

Ext.ns('SYNO.SDS.PHP84Manager');

/**
 * Application Instance
 */
SYNO.SDS.PHP84Manager.Instance = Ext.extend(SYNO.SDS.AppInstance, {
    appWindowName: 'SYNO.SDS.PHP84Manager.MainWindow',

    constructor: function(config) {
        SYNO.SDS.PHP84Manager.Instance.superclass.constructor.call(this, config);
    }
});

/**
 * Main Application Window
 */
SYNO.SDS.PHP84Manager.MainWindow = Ext.extend(SYNO.SDS.AppWindow, {
    appInstance: null,
    extensionStore: null,
    categoryStore: null,
    extensionGrid: null,
    categoryTree: null,
    currentCategory: null,
    dirty: false,

    constructor: function(config) {
        this.appInstance = config.appInstance;
        this.callParent([this.fillConfig(config)]);
    },

    fillConfig: function(config) {
        // Create stores
        this.createStores();

        var panelConfig = {
            title: 'PHP 8.4 Extension Manager',
            width: 900,
            height: 600,
            minWidth: 800,
            minHeight: 500,
            layout: 'border',
            border: false,
            cls: 'php84-manager',
            items: [
                this.createCategoryPanel(),
                this.createMainPanel()
            ],
            tbar: this.createToolbar(),
            bbar: this.createStatusBar()
        };

        Ext.apply(panelConfig, config);
        return panelConfig;
    },

    /**
     * Create data stores for extensions and categories
     */
    createStores: function() {
        // Extension store
        this.extensionStore = new Ext.data.JsonStore({
            url: 'webman/3rdparty/php84/cgi/extensions.cgi',
            root: 'extensions',
            idProperty: 'id',
            fields: [
                {name: 'id', type: 'string'},
                {name: 'name', type: 'string'},
                {name: 'description', type: 'string'},
                {name: 'category', type: 'string'},
                {name: 'categoryName', type: 'string'},
                {name: 'enabled', type: 'boolean'},
                {name: 'available', type: 'boolean'},
                {name: 'filename', type: 'string'},
                {name: 'dependencies', type: 'auto'},
                {name: 'priority', type: 'int'}
            ],
            listeners: {
                scope: this,
                load: this.onExtensionsLoaded,
                exception: this.onStoreException
            }
        });

        // Category store
        this.categoryStore = new Ext.data.JsonStore({
            url: 'webman/3rdparty/php84/cgi/extensions.cgi',
            baseParams: {action: 'categories'},
            root: 'categories',
            idProperty: 'id',
            fields: [
                {name: 'id', type: 'string'},
                {name: 'name', type: 'string'},
                {name: 'description', type: 'string'},
                {name: 'order', type: 'int'},
                {name: 'count', type: 'int'}
            ]
        });
    },

    /**
     * Create category navigation panel
     */
    createCategoryPanel: function() {
        this.categoryTree = new Ext.tree.TreePanel({
            region: 'west',
            title: 'Catégories',
            width: 200,
            split: true,
            collapsible: true,
            autoScroll: true,
            rootVisible: false,
            cls: 'php84-category-tree',
            root: new Ext.tree.AsyncTreeNode({
                text: 'Categories',
                expanded: true,
                children: []
            }),
            listeners: {
                scope: this,
                click: this.onCategoryClick
            }
        });

        return this.categoryTree;
    },

    /**
     * Create main panel with extension grid
     */
    createMainPanel: function() {
        // CheckboxSelectionModel for enabling/disabling extensions
        var sm = new Ext.grid.CheckboxSelectionModel({
            singleSelect: false,
            checkOnly: true,
            listeners: {
                scope: this,
                selectionchange: this.onSelectionChange
            }
        });

        this.extensionGrid = new Ext.grid.GridPanel({
            region: 'center',
            title: 'Extensions',
            store: this.extensionStore,
            border: false,
            loadMask: true,
            stripeRows: true,
            cls: 'php84-extension-grid',
            sm: sm,
            columns: [
                sm,
                {
                    header: 'Extension',
                    dataIndex: 'name',
                    width: 150,
                    sortable: true,
                    renderer: this.renderExtensionName
                },
                {
                    header: 'Description',
                    dataIndex: 'description',
                    flex: 1,
                    sortable: false
                },
                {
                    header: 'Catégorie',
                    dataIndex: 'categoryName',
                    width: 120,
                    sortable: true,
                    hidden: false
                },
                {
                    header: 'Statut',
                    dataIndex: 'enabled',
                    width: 80,
                    sortable: true,
                    renderer: this.renderStatus
                },
                {
                    header: 'Disponible',
                    dataIndex: 'available',
                    width: 80,
                    sortable: true,
                    renderer: this.renderAvailable
                }
            ],
            viewConfig: {
                forceFit: true,
                emptyText: 'Aucune extension disponible',
                getRowClass: function(record) {
                    if (!record.get('available')) {
                        return 'php84-row-unavailable';
                    }
                    if (record.get('enabled')) {
                        return 'php84-row-enabled';
                    }
                    return '';
                }
            },
            listeners: {
                scope: this,
                cellclick: this.onCellClick
            }
        });

        return this.extensionGrid;
    },

    /**
     * Create toolbar
     */
    createToolbar: function() {
        return new Ext.Toolbar({
            items: [
                {
                    text: 'Rafraîchir',
                    iconCls: 'syno-icon-refresh',
                    handler: this.onRefresh,
                    scope: this
                },
                '-',
                {
                    text: 'Tout activer',
                    iconCls: 'syno-icon-check',
                    handler: this.onEnableAll,
                    scope: this
                },
                {
                    text: 'Tout désactiver',
                    iconCls: 'syno-icon-uncheck',
                    handler: this.onDisableAll,
                    scope: this
                },
                '->',
                {
                    xtype: 'textfield',
                    id: 'php84-search-field',
                    emptyText: 'Rechercher...',
                    width: 200,
                    enableKeyEvents: true,
                    listeners: {
                        scope: this,
                        keyup: this.onSearchKeyUp
                    }
                },
                '-',
                {
                    text: 'Appliquer',
                    iconCls: 'syno-icon-apply',
                    cls: 'php84-apply-btn',
                    handler: this.onApply,
                    scope: this
                }
            ]
        });
    },

    /**
     * Create status bar
     */
    createStatusBar: function() {
        return new Ext.ux.StatusBar({
            id: 'php84-statusbar',
            defaultText: 'Prêt',
            defaultIconCls: 'x-status-valid',
            items: [
                {
                    xtype: 'tbtext',
                    id: 'php84-ext-count',
                    text: ''
                }
            ]
        });
    },

    /**
     * Initialize component
     */
    initComponent: function() {
        SYNO.SDS.PHP84Manager.MainWindow.superclass.initComponent.call(this);
        this.on('afterrender', this.onAfterRender, this);
    },

    /**
     * After render - load data
     */
    onAfterRender: function() {
        this.loadData();
    },

    /**
     * Load all data
     */
    loadData: function() {
        this.setStatusBusy('Chargement des extensions...');
        this.extensionStore.load();
        this.loadCategories();
    },

    /**
     * Load categories into tree
     */
    loadCategories: function() {
        var me = this;
        Ext.Ajax.request({
            url: 'webman/3rdparty/php84/cgi/extensions.cgi',
            params: {action: 'categories'},
            success: function(response) {
                var data = Ext.decode(response.responseText);
                if (data.success && data.categories) {
                    me.buildCategoryTree(data.categories);
                }
            },
            failure: function() {
                me.showError('Erreur lors du chargement des catégories');
            }
        });
    },

    /**
     * Build category tree from data
     */
    buildCategoryTree: function(categories) {
        var root = this.categoryTree.getRootNode();
        root.removeAll(true);

        // Add "All" node
        root.appendChild({
            id: 'all',
            text: 'Toutes les extensions',
            leaf: true,
            iconCls: 'php84-icon-all'
        });

        // Sort categories by order
        categories.sort(function(a, b) {
            return a.order - b.order;
        });

        // Add category nodes
        Ext.each(categories, function(cat) {
            root.appendChild({
                id: cat.id,
                text: cat.name + ' (' + cat.count + ')',
                leaf: true,
                iconCls: 'php84-icon-category'
            });
        });

        root.expand();
    },

    /**
     * Extensions loaded handler
     */
    onExtensionsLoaded: function(store, records) {
        var enabled = 0, total = records.length;
        Ext.each(records, function(rec) {
            if (rec.get('enabled')) enabled++;
        });

        Ext.getCmp('php84-ext-count').setText(
            enabled + ' / ' + total + ' extensions activées'
        );

        this.setStatusReady();
        this.syncSelections();
    },

    /**
     * Sync grid selections with enabled state
     */
    syncSelections: function() {
        var sm = this.extensionGrid.getSelectionModel();
        sm.suspendEvents();
        sm.clearSelections();

        this.extensionStore.each(function(record) {
            if (record.get('enabled') && record.get('available')) {
                sm.selectRow(this.extensionStore.indexOf(record), true);
            }
        }, this);

        sm.resumeEvents();
    },

    /**
     * Store exception handler
     */
    onStoreException: function(proxy, type, action, options, response) {
        this.showError('Erreur de communication avec le serveur');
        this.setStatusError('Erreur de chargement');
    },

    /**
     * Category click handler
     */
    onCategoryClick: function(node) {
        this.currentCategory = node.id;
        this.filterByCategory(node.id);
    },

    /**
     * Filter extensions by category
     */
    filterByCategory: function(categoryId) {
        if (categoryId === 'all') {
            this.extensionStore.clearFilter();
        } else {
            this.extensionStore.filter('category', categoryId);
        }
    },

    /**
     * Cell click handler
     */
    onCellClick: function(grid, rowIndex, colIndex, e) {
        // Toggle enabled state when clicking on status column
        if (colIndex === 4) { // Status column
            var record = grid.getStore().getAt(rowIndex);
            if (record.get('available')) {
                this.toggleExtension(record);
            }
        }
    },

    /**
     * Selection change handler
     */
    onSelectionChange: function(sm) {
        this.dirty = true;
        this.updateExtensionsFromSelection();
    },

    /**
     * Update extension enabled state from selection
     */
    updateExtensionsFromSelection: function() {
        var selections = this.extensionGrid.getSelectionModel().getSelections();
        var selectedIds = {};

        Ext.each(selections, function(rec) {
            selectedIds[rec.get('id')] = true;
        });

        this.extensionStore.each(function(record) {
            var shouldBeEnabled = selectedIds[record.get('id')] === true;
            if (record.get('enabled') !== shouldBeEnabled && record.get('available')) {
                record.set('enabled', shouldBeEnabled);
            }
        });
    },

    /**
     * Toggle extension enabled state
     */
    toggleExtension: function(record) {
        if (!record.get('available')) return;

        var newState = !record.get('enabled');
        record.set('enabled', newState);

        // Handle dependencies
        if (newState) {
            this.enableDependencies(record);
        } else {
            this.checkDependents(record);
        }

        this.dirty = true;
        this.syncSelections();
    },

    /**
     * Enable dependencies of an extension
     */
    enableDependencies: function(record) {
        var deps = record.get('dependencies') || [];
        Ext.each(deps, function(depId) {
            var depRecord = this.extensionStore.getById(depId);
            if (depRecord && !depRecord.get('enabled') && depRecord.get('available')) {
                depRecord.set('enabled', true);
            }
        }, this);
    },

    /**
     * Check if other extensions depend on this one
     */
    checkDependents: function(record) {
        var extId = record.get('id');
        var dependents = [];

        this.extensionStore.each(function(rec) {
            if (rec.get('enabled')) {
                var deps = rec.get('dependencies') || [];
                if (deps.indexOf(extId) !== -1) {
                    dependents.push(rec.get('name'));
                }
            }
        });

        if (dependents.length > 0) {
            Ext.Msg.alert(
                'Dépendances',
                'Les extensions suivantes dépendent de ' + record.get('name') + ':\n' +
                dependents.join(', ') + '\n\nElles seront également désactivées.'
            );
        }
    },

    /**
     * Refresh button handler
     */
    onRefresh: function() {
        if (this.dirty) {
            Ext.Msg.confirm(
                'Modifications non sauvegardées',
                'Vous avez des modifications non sauvegardées. Voulez-vous les abandonner?',
                function(btn) {
                    if (btn === 'yes') {
                        this.dirty = false;
                        this.loadData();
                    }
                },
                this
            );
        } else {
            this.loadData();
        }
    },

    /**
     * Enable all extensions
     */
    onEnableAll: function() {
        this.extensionStore.each(function(record) {
            if (record.get('available')) {
                record.set('enabled', true);
            }
        });
        this.dirty = true;
        this.syncSelections();
    },

    /**
     * Disable all extensions
     */
    onDisableAll: function() {
        this.extensionStore.each(function(record) {
            record.set('enabled', false);
        });
        this.dirty = true;
        this.syncSelections();
    },

    /**
     * Search keyup handler
     */
    onSearchKeyUp: function(field) {
        var value = field.getValue().toLowerCase();
        if (value === '') {
            this.extensionStore.clearFilter();
            if (this.currentCategory && this.currentCategory !== 'all') {
                this.filterByCategory(this.currentCategory);
            }
        } else {
            this.extensionStore.filterBy(function(record) {
                var name = record.get('name').toLowerCase();
                var desc = record.get('description').toLowerCase();
                return name.indexOf(value) !== -1 || desc.indexOf(value) !== -1;
            });
        }
    },

    /**
     * Apply changes
     */
    onApply: function() {
        if (!this.dirty) {
            this.showInfo('Aucune modification à appliquer');
            return;
        }

        var me = this;
        var extensions = {};

        this.extensionStore.each(function(record) {
            extensions[record.get('id')] = record.get('enabled');
        });

        this.setStatusBusy('Application des modifications...');

        Ext.Ajax.request({
            url: 'webman/3rdparty/php84/cgi/extensions.cgi',
            method: 'POST',
            jsonData: {
                action: 'update',
                extensions: extensions
            },
            success: function(response) {
                var data = Ext.decode(response.responseText);
                if (data.success) {
                    me.dirty = false;
                    me.showInfo('Modifications enregistrées');
                    me.restartService();
                } else {
                    me.showError(data.error || 'Erreur lors de la sauvegarde');
                    me.setStatusError('Erreur');
                }
            },
            failure: function() {
                me.showError('Erreur de communication');
                me.setStatusError('Erreur');
            }
        });
    },

    /**
     * Restart PHP-FPM service
     */
    restartService: function() {
        var me = this;
        this.setStatusBusy('Redémarrage du service PHP-FPM...');

        Ext.Ajax.request({
            url: 'webman/3rdparty/php84/cgi/service.cgi',
            method: 'POST',
            jsonData: {action: 'restart'},
            success: function(response) {
                var data = Ext.decode(response.responseText);
                if (data.success) {
                    me.showInfo('Service redémarré avec succès');
                    me.setStatusReady();
                    me.loadData();
                } else {
                    me.showError(data.error || 'Erreur lors du redémarrage');
                    me.setStatusError('Erreur de redémarrage');
                }
            },
            failure: function() {
                me.showError('Erreur de communication lors du redémarrage');
                me.setStatusError('Erreur');
            }
        });
    },

    /**
     * Render extension name with icon
     */
    renderExtensionName: function(value, meta, record) {
        var cls = record.get('available') ? 'php84-ext-name' : 'php84-ext-name-disabled';
        return '<span class="' + cls + '">' + Ext.util.Format.htmlEncode(value) + '</span>';
    },

    /**
     * Render status column
     */
    renderStatus: function(value, meta, record) {
        if (!record.get('available')) {
            return '<span class="php84-status-unavailable">N/A</span>';
        }
        if (value) {
            return '<span class="php84-status-enabled">Activé</span>';
        }
        return '<span class="php84-status-disabled">Désactivé</span>';
    },

    /**
     * Render available column
     */
    renderAvailable: function(value) {
        if (value) {
            return '<span class="php84-available-yes">Oui</span>';
        }
        return '<span class="php84-available-no">Non</span>';
    },

    /**
     * Set status bar to busy state
     */
    setStatusBusy: function(text) {
        var sb = Ext.getCmp('php84-statusbar');
        if (sb) {
            sb.showBusy(text);
        }
    },

    /**
     * Set status bar to ready state
     */
    setStatusReady: function() {
        var sb = Ext.getCmp('php84-statusbar');
        if (sb) {
            sb.clearStatus({useDefaults: true});
        }
    },

    /**
     * Set status bar to error state
     */
    setStatusError: function(text) {
        var sb = Ext.getCmp('php84-statusbar');
        if (sb) {
            sb.setStatus({
                text: text,
                iconCls: 'x-status-error'
            });
        }
    },

    /**
     * Show info message
     */
    showInfo: function(msg) {
        SYNO.SDS.MessageBox.alert('Information', msg);
    },

    /**
     * Show error message
     */
    showError: function(msg) {
        SYNO.SDS.MessageBox.alert('Erreur', msg);
    },

    /**
     * Before close - check for unsaved changes
     */
    onBeforeClose: function() {
        if (this.dirty) {
            Ext.Msg.confirm(
                'Modifications non sauvegardées',
                'Vous avez des modifications non sauvegardées. Voulez-vous quitter sans sauvegarder?',
                function(btn) {
                    if (btn === 'yes') {
                        this.dirty = false;
                        this.close();
                    }
                },
                this
            );
            return false;
        }
        return true;
    }
});
