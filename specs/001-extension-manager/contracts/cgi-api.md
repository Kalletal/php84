# API Contracts: Extension Manager CGI Backend

**Feature**: 001-extension-manager
**Date**: 2025-11-26
**Protocol**: HTTP CGI (via /webman/3rdparty/php84/)

## Overview

L'interface de gestion communique avec le backend via des scripts CGI. Ces scripts sont accessibles via le chemin `/webman/3rdparty/php84/cgi/`.

## Authentication

Toutes les requêtes doivent être authentifiées via la session DSM. Le token CSRF (`SynoToken`) doit être inclus dans les requêtes POST.

```
Header: X-SYNO-TOKEN: <token>
Cookie: id=<session_id>
```

---

## Endpoints

### GET /cgi/extensions.cgi

Récupère la liste des extensions avec leur état.

**Request**:
```
GET /webman/3rdparty/php84/cgi/extensions.cgi
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "categories": [
      {
        "id": "database",
        "name": "Base de données",
        "order": 1,
        "extensions": [
          {
            "id": "mysqli",
            "name": "MySQLi",
            "description": "MySQL Improved Extension",
            "enabled": true,
            "default": true,
            "dependencies": [],
            "conflicts": []
          },
          {
            "id": "pdo_mysql",
            "name": "PDO MySQL",
            "description": "PDO MySQL Driver",
            "enabled": true,
            "default": true,
            "dependencies": ["pdo"],
            "conflicts": []
          }
        ]
      }
    ],
    "total_extensions": 100,
    "enabled_count": 25
  }
}
```

**Response** (401 Unauthorized):
```json
{
  "success": false,
  "error": {
    "code": 401,
    "message": "Authentication required"
  }
}
```

---

### POST /cgi/extensions.cgi

Met à jour l'état des extensions.

**Request**:
```
POST /webman/3rdparty/php84/cgi/extensions.cgi
Content-Type: application/x-www-form-urlencoded
X-SYNO-TOKEN: <token>

action=update&extensions={"mysqli":true,"pdo_pgsql":false}
```

**Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| action | string | yes | "update" |
| extensions | JSON string | yes | Map extension_id -> enabled |

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "changed": ["pdo_pgsql"],
    "auto_enabled": [],
    "auto_disabled": [],
    "restart_required": true
  }
}
```

**Response** (400 Bad Request - Dependency Error):
```json
{
  "success": false,
  "error": {
    "code": 400,
    "message": "Cannot disable pdo: required by pdo_mysql, pdo_pgsql",
    "details": {
      "extension": "pdo",
      "dependents": ["pdo_mysql", "pdo_pgsql"]
    }
  }
}
```

**Response** (400 Bad Request - Missing Dependency):
```json
{
  "success": false,
  "error": {
    "code": 400,
    "message": "Cannot enable pdo_mysql: requires pdo",
    "details": {
      "extension": "pdo_mysql",
      "missing_dependencies": ["pdo"]
    },
    "suggestion": {
      "auto_enable": ["pdo"]
    }
  }
}
```

---

### GET /cgi/config.cgi

Récupère la configuration PHP actuelle.

**Request**:
```
GET /webman/3rdparty/php84/cgi/config.cgi
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "php_version": "8.4.15",
    "package_version": "8.4.15-1",
    "settings": {
      "memory_limit": "256M",
      "max_execution_time": 60,
      "upload_max_filesize": "64M",
      "post_max_size": "64M",
      "timezone": "Europe/Paris"
    },
    "paths": {
      "php_binary": "/var/packages/php84/target/bin/php",
      "php_ini": "/var/packages/php84/var/etc/php.ini",
      "extensions_dir": "/var/packages/php84/target/lib/php/modules"
    }
  }
}
```

---

### POST /cgi/config.cgi

Met à jour les paramètres PHP.

**Request**:
```
POST /webman/3rdparty/php84/cgi/config.cgi
Content-Type: application/x-www-form-urlencoded
X-SYNO-TOKEN: <token>

action=update&settings={"memory_limit":"512M","max_execution_time":120}
```

**Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| action | string | yes | "update" |
| settings | JSON string | yes | Paramètres à modifier |

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "changed": ["memory_limit", "max_execution_time"],
    "restart_required": true
  }
}
```

---

### GET /cgi/service.cgi

Récupère l'état du service PHP-FPM.

**Request**:
```
GET /webman/3rdparty/php84/cgi/service.cgi
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "status": "running",
    "pid": 12345,
    "uptime": 3600,
    "last_restart": "2025-11-26T09:30:00Z",
    "workers": {
      "active": 2,
      "idle": 3,
      "total": 5
    }
  }
}
```

---

### POST /cgi/service.cgi

Contrôle le service PHP-FPM.

**Request**:
```
POST /webman/3rdparty/php84/cgi/service.cgi
Content-Type: application/x-www-form-urlencoded
X-SYNO-TOKEN: <token>

action=restart
```

**Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| action | string | yes | "start", "stop", "restart" |

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "action": "restart",
    "previous_status": "running",
    "current_status": "running",
    "message": "Service restarted successfully"
  }
}
```

**Response** (500 Internal Server Error):
```json
{
  "success": false,
  "error": {
    "code": 500,
    "message": "Failed to restart service",
    "details": {
      "stderr": "php-fpm: error while loading shared libraries..."
    }
  }
}
```

---

### GET /cgi/validate.cgi

Valide une configuration avant application.

**Request**:
```
GET /webman/3rdparty/php84/cgi/validate.cgi?extensions={"mysqli":true,"pdo":false}
```

**Response** (200 OK - Valid):
```json
{
  "success": true,
  "data": {
    "valid": true,
    "warnings": [],
    "info": {
      "extensions_to_enable": ["mysqli"],
      "extensions_to_disable": ["pdo", "pdo_mysql", "pdo_pgsql"],
      "cascade_disable": ["pdo_mysql", "pdo_pgsql"]
    }
  }
}
```

**Response** (200 OK - Invalid):
```json
{
  "success": true,
  "data": {
    "valid": false,
    "errors": [
      {
        "type": "dependency",
        "extension": "pdo_mysql",
        "message": "Cannot enable pdo_mysql without pdo",
        "fix": {"enable": ["pdo"]}
      }
    ],
    "warnings": [
      {
        "type": "performance",
        "message": "opcache is disabled. This may impact performance."
      }
    ]
  }
}
```

---

## Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request (validation error) |
| 401 | Unauthorized (not authenticated) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found (extension not found) |
| 500 | Internal Server Error |

## Common Error Response Format

```json
{
  "success": false,
  "error": {
    "code": <http_status_code>,
    "message": "<human_readable_message>",
    "details": { ... }
  }
}
```
