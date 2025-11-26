#!/bin/bash
# PHP 8.4 Installation Wizard with Conditional Steps
# Based on SynoCommunity/spksrc roundcube pattern

quote_json() {
    sed -e 's|\\|\\\\|g' -e 's|"|\\"|g' | tr '\n' ' ' | tr '\t' ' '
}

# Step titles (must match exactly)
PROFILE_STEP="Profil"
MINIMAL_STEP="Extensions Minimal"
STANDARD_STEP="Extensions Standard"
CONFIRM_STEP="Confirmation"

# Helper JavaScript functions
jsFunction=$(/bin/cat<<EOF
    function findStepByTitle(wizardDialog, title) {
        for (var i = wizardDialog.customuiIds.length - 1; i >= 0; i--) {
            var step = wizardDialog.getStep(wizardDialog.customuiIds[i]);
            if (title === step.headline) {
                return step;
            }
        }
        return null;
    }
    function getSelectedProfile(wizardDialog) {
        var profileStep = findStepByTitle(wizardDialog, "${PROFILE_STEP}");
        if (!profileStep) return "standard";
        if (profileStep.getComponent("profile_minimal").checked) return "minimal";
        if (profileStep.getComponent("profile_complete").checked) return "complete";
        return "standard";
    }
EOF
)

# Deactivate function for Profile step
# Sets up navigation: Minimal step -> Confirm OR Standard step depending on profile
getDeactivateProfile() {
    DEACTIVATE=$(/bin/cat<<EOF
{
    ${jsFunction}
    var currentStep = arguments[0];
    var wizardDialog = currentStep.owner;
    var minimalStep = findStepByTitle(wizardDialog, "${MINIMAL_STEP}");
    var standardStep = findStepByTitle(wizardDialog, "${STANDARD_STEP}");
    var confirmStep = findStepByTitle(wizardDialog, "${CONFIRM_STEP}");
    var profile = getSelectedProfile(wizardDialog);

    if (profile === "minimal") {
        currentStep.nextId = minimalStep.itemId;
        minimalStep.nextId = confirmStep.itemId;
    } else if (profile === "complete") {
        currentStep.nextId = confirmStep.itemId;
    } else {
        currentStep.nextId = standardStep.itemId;
        standardStep.nextId = confirmStep.itemId;
    }
}
EOF
)
    echo "$DEACTIVATE" | quote_json
}

# Activate function for Minimal step - skip if not minimal profile
getActivateMinimal() {
    ACTIVATE=$(/bin/cat<<EOF
{
    ${jsFunction}
    var currentStep = arguments[0];
    var wizardDialog = currentStep.owner;
    var profileStep = findStepByTitle(wizardDialog, "${PROFILE_STEP}");
    var standardStep = findStepByTitle(wizardDialog, "${STANDARD_STEP}");
    var confirmStep = findStepByTitle(wizardDialog, "${CONFIRM_STEP}");
    var profile = getSelectedProfile(wizardDialog);

    if (profile !== "minimal") {
        if (profile === "standard") {
            wizardDialog.goBack(profileStep.itemId);
            wizardDialog.goNext(standardStep.itemId);
        } else {
            wizardDialog.goBack(profileStep.itemId);
            wizardDialog.goNext(confirmStep.itemId);
        }
    }
}
EOF
)
    echo "$ACTIVATE" | quote_json
}

# Activate function for Standard step - skip if not standard profile
getActivateStandard() {
    ACTIVATE=$(/bin/cat<<EOF
{
    ${jsFunction}
    var currentStep = arguments[0];
    var wizardDialog = currentStep.owner;
    var profileStep = findStepByTitle(wizardDialog, "${PROFILE_STEP}");
    var minimalStep = findStepByTitle(wizardDialog, "${MINIMAL_STEP}");
    var confirmStep = findStepByTitle(wizardDialog, "${CONFIRM_STEP}");
    var profile = getSelectedProfile(wizardDialog);

    if (profile !== "standard") {
        if (profile === "minimal") {
            wizardDialog.goBack(profileStep.itemId);
            wizardDialog.goNext(minimalStep.itemId);
        } else {
            wizardDialog.goBack(profileStep.itemId);
            wizardDialog.goNext(confirmStep.itemId);
        }
    }
}
EOF
)
    echo "$ACTIVATE" | quote_json
}

# Step 1: Profile Selection
STEP_PROFILE=$(/bin/cat<<EOF
{
    "step_title": "${PROFILE_STEP}",
    "deactivate_v2": "$(getDeactivateProfile)",
    "items": [
        {
            "type": "singleselect",
            "desc": "Choisissez le profil qui correspond a vos besoins :",
            "subitems": [
                {
                    "key": "profile_minimal",
                    "desc": "<b>Minimal</b> - 7 extensions essentielles<br/><small>OPcache, Session, Filter, Ctype, PDO, cURL, OpenSSL</small>",
                    "defaultValue": false
                },
                {
                    "key": "profile_standard",
                    "desc": "<b>Standard</b> - 23 extensions web (recommande)<br/><small>+ MySQL, SQLite, Mbstring, Intl, XML, DOM, Zip, GD...</small>",
                    "defaultValue": true
                },
                {
                    "key": "profile_complete",
                    "desc": "<b>Complet</b> - Toutes les extensions<br/><small>Tout est active. Gerez dans PHP Manager.</small>",
                    "defaultValue": false
                }
            ]
        }
    ]
}
EOF
)

# Step 2: Minimal Profile Extensions
STEP_MINIMAL=$(/bin/cat<<EOF
{
    "step_title": "${MINIMAL_STEP}",
    "activate_v2": "$(getActivateMinimal)",
    "items": [
        {
            "type": "textfield",
            "desc": "<div style='padding:8px;background:#e8f5e9;border-left:3px solid #4caf50'><b>Profil Minimal</b> - Extensions de base incluses : OPcache, Session, Filter, Ctype, PDO, cURL, OpenSSL</div>",
            "subitems": [{"key": "info_minimal", "desc": "", "hidden": true}]
        },
        {
            "type": "multiselect",
            "desc": "Ajouter des extensions optionnelles :",
            "subitems": [
                {"key": "min_apcu", "desc": "APCu (cache memoire)", "defaultValue": false},
                {"key": "min_redis", "desc": "Redis", "defaultValue": false},
                {"key": "min_mbstring", "desc": "Mbstring (encodage)", "defaultValue": false},
                {"key": "min_xml", "desc": "XML", "defaultValue": false},
                {"key": "min_zip", "desc": "Zip", "defaultValue": false},
                {"key": "min_gd", "desc": "GD (images)", "defaultValue": false}
            ]
        }
    ]
}
EOF
)

# Step 3: Standard Profile Extensions
STEP_STANDARD=$(/bin/cat<<EOF
{
    "step_title": "${STANDARD_STEP}",
    "activate_v2": "$(getActivateStandard)",
    "items": [
        {
            "type": "textfield",
            "desc": "<div style='padding:8px;background:#e3f2fd;border-left:3px solid #2196f3'><b>Profil Standard</b> - Extensions web incluses : MySQL, SQLite, Mbstring, Intl, XML, DOM, Zip, GD...</div>",
            "subitems": [{"key": "info_standard", "desc": "", "hidden": true}]
        },
        {
            "type": "multiselect",
            "desc": "Cache et NoSQL :",
            "subitems": [
                {"key": "std_apcu", "desc": "APCu (cache memoire)", "defaultValue": false},
                {"key": "std_redis", "desc": "Redis", "defaultValue": false},
                {"key": "std_memcached", "desc": "Memcached", "defaultValue": false},
                {"key": "std_mongodb", "desc": "MongoDB", "defaultValue": false}
            ]
        },
        {
            "type": "multiselect",
            "desc": "Reseau :",
            "subitems": [
                {"key": "std_sockets", "desc": "Sockets", "defaultValue": false},
                {"key": "std_soap", "desc": "SOAP", "defaultValue": false},
                {"key": "std_ssh2", "desc": "SSH2", "defaultValue": false},
                {"key": "std_ldap", "desc": "LDAP", "defaultValue": false}
            ]
        },
        {
            "type": "multiselect",
            "desc": "Developpement :",
            "subitems": [
                {"key": "std_xdebug", "desc": "Xdebug", "defaultValue": false},
                {"key": "std_yaml", "desc": "YAML", "defaultValue": false},
                {"key": "std_pcntl", "desc": "PCNTL (CLI)", "defaultValue": false}
            ]
        }
    ]
}
EOF
)

# Step 4: Confirmation
STEP_CONFIRM=$(/bin/cat<<EOF
{
    "step_title": "${CONFIRM_STEP}",
    "items": [
        {
            "type": "textfield",
            "desc": "<div style='padding:12px;background:#f5f5f5;border-radius:4px'><b>Installation prete</b><br/><br/>Les extensions seront activees selon votre profil.<br/><br/>Apres installation, utilisez <b>PHP 8.4 Manager</b> pour gerer les extensions.<br/><br/><small>Socket PHP-FPM : /var/packages/php84/var/run/php-fpm.sock</small></div>",
            "subitems": [{"key": "info_final", "desc": "", "hidden": true}]
        }
    ]
}
EOF
)

# Output complete wizard JSON
echo "[$STEP_PROFILE,$STEP_MINIMAL,$STEP_STANDARD,$STEP_CONFIRM]" > "${SYNOPKG_TEMP_LOGFILE}"
