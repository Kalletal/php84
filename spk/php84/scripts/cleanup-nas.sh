#!/bin/sh
# PHP 8.4 NAS Cleanup Script
# Fixes duplicate .ini files and www.conf issues
# Run on Synology NAS with: sudo sh cleanup-nas.sh

echo "=========================================="
echo "PHP 8.4 NAS Cleanup Script"
echo "=========================================="

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Paths
CONF_D_DIR="/var/packages/php84/var/etc/conf.d"
FPM_CONF_DIR="/var/packages/php84/var/etc/php-fpm.d"
VAR_DIR="/var/packages/php84/var"

# Check if package is installed
if [ ! -d "$VAR_DIR" ]; then
    echo "ERROR: PHP 8.4 package not found at $VAR_DIR"
    exit 1
fi

echo ""
echo "Step 1: Analyzing duplicate .ini files..."
echo "-------------------------------------------"

# List of extensions that have duplicates (without prefix and with prefix)
DUPLICATES=""
DUPLICATE_COUNT=0

for ini in "$CONF_D_DIR"/*.ini; do
    [ -f "$ini" ] || continue
    filename=$(basename "$ini")

    # Check if this is a non-prefixed file (doesn't start with number)
    case "$filename" in
        [0-9][0-9]-*)
            # This is a prefixed file, skip
            ;;
        *)
            # This is a non-prefixed file, check if prefixed version exists
            ext_name="${filename%.ini}"
            if ls "$CONF_D_DIR"/[0-9][0-9]-"$ext_name".ini 1>/dev/null 2>&1; then
                DUPLICATES="$DUPLICATES $filename"
                DUPLICATE_COUNT=$((DUPLICATE_COUNT + 1))
                echo "  DUPLICATE: $filename (prefixed version exists)"
            fi
            ;;
    esac
done

echo ""
echo "Found $DUPLICATE_COUNT duplicate .ini files"

echo ""
echo "Step 2: Removing duplicate .ini files..."
echo "-----------------------------------------"

for ini in "$CONF_D_DIR"/*.ini; do
    [ -f "$ini" ] || continue
    filename=$(basename "$ini")

    case "$filename" in
        [0-9][0-9]-*)
            # Keep prefixed files
            ;;
        *)
            # Remove non-prefixed files that have prefixed versions
            ext_name="${filename%.ini}"
            if ls "$CONF_D_DIR"/[0-9][0-9]-"$ext_name".ini 1>/dev/null 2>&1; then
                echo "  Removing: $filename"
                rm -f "$ini"
            else
                echo "  Keeping (no prefixed version): $filename"
            fi
            ;;
    esac
done

echo ""
echo "Step 3: Fixing www.conf (removing user/group directives)..."
echo "------------------------------------------------------------"

WWW_CONF="$FPM_CONF_DIR/www.conf"
if [ -f "$WWW_CONF" ]; then
    # Check if www.conf has user/group directives
    if grep -q "^user = " "$WWW_CONF" 2>/dev/null || grep -q "^group = " "$WWW_CONF" 2>/dev/null; then
        echo "  Found user/group directives, creating fixed version..."

        # Backup original
        cp "$WWW_CONF" "$WWW_CONF.backup"

        # Create fixed www.conf
        cat > "$WWW_CONF" << 'EOF'
[www]
; Non-root mode: omit user/group (runs as service user)
; user and group directives removed - requires root privileges

; Socket in package var directory (accessible without root)
listen = /var/packages/php84/var/run/php-fpm.sock
listen.mode = 0666

; Process manager settings
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500

; Logging
slowlog = /var/packages/php84/var/log/php-fpm.slow.log
request_slowlog_timeout = 30s
catch_workers_output = yes
decorate_workers_output = no
EOF
        echo "  www.conf fixed (backup saved as www.conf.backup)"
    else
        echo "  www.conf OK (no user/group directives found)"
    fi
else
    echo "  WARNING: www.conf not found"
fi

echo ""
echo "Step 4: Fixing php-fpm.conf paths..."
echo "-------------------------------------"

FPM_CONF="/var/packages/php84/var/etc/php-fpm.conf"
if [ -f "$FPM_CONF" ]; then
    # Check if paths use @appdata (should use var)
    if grep -q "@appdata" "$FPM_CONF" 2>/dev/null; then
        echo "  Found @appdata paths, fixing..."
        cp "$FPM_CONF" "$FPM_CONF.backup"

        cat > "$FPM_CONF" << 'EOF'
[global]
pid = /var/packages/php84/var/run/php-fpm.pid
error_log = /var/packages/php84/var/log/php-fpm.log
log_level = notice
daemonize = yes

include=/var/packages/php84/var/etc/php-fpm.d/*.conf
EOF
        echo "  php-fpm.conf fixed"
    else
        echo "  php-fpm.conf paths OK"
    fi
else
    echo "  WARNING: php-fpm.conf not found"
fi

echo ""
echo "Step 5: Setting correct permissions..."
echo "---------------------------------------"

# Fix log file permissions
if [ -f "$VAR_DIR/log/php-fpm.log" ]; then
    chmod 664 "$VAR_DIR/log/php-fpm.log"
    chown php84:php84 "$VAR_DIR/log/php-fpm.log" 2>/dev/null || true
    echo "  Fixed php-fpm.log permissions"
fi

# Ensure run directory exists
mkdir -p "$VAR_DIR/run"
chown php84:php84 "$VAR_DIR/run" 2>/dev/null || true
echo "  Ensured run directory exists"

echo ""
echo "Step 6: Listing current .ini files..."
echo "--------------------------------------"
ls -la "$CONF_D_DIR"/*.ini 2>/dev/null | head -30
INI_COUNT=$(ls "$CONF_D_DIR"/*.ini 2>/dev/null | wc -l)
echo "  Total: $INI_COUNT .ini files"

echo ""
echo "Step 7: Testing PHP-FPM configuration..."
echo "-----------------------------------------"

export LD_LIBRARY_PATH="/var/packages/php84/target/lib:$LD_LIBRARY_PATH"
if /var/packages/php84/target/sbin/php-fpm -t -c /var/packages/php84/var/etc/php.ini -y /var/packages/php84/var/etc/php-fpm.conf 2>&1; then
    echo "  PHP-FPM configuration test: OK"
else
    echo "  PHP-FPM configuration test: FAILED (see errors above)"
fi

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Restart the package: synopkg restart php84"
echo "  2. Or reinstall with the new SPK version"
echo ""
