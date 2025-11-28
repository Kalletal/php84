#!/bin/bash
# PHP 8.4 Service Setup Script
# Called by spksrc framework during package installation

# Package variables (set by spksrc)
# SYNOPKG_PKGDEST - Package installation directory
# SYNOPKG_PKGVAR - Package variable directory
# SYNOPKG_PKGNAME - Package name

# Service configuration
SERVICE_COMMAND="${SYNOPKG_PKGDEST}/sbin/php-fpm"
SERVICE_COMMAND_ARGS="-c ${SYNOPKG_PKGVAR}/etc/php.ini -y ${SYNOPKG_PKGVAR}/etc/php-fpm.conf"
SVC_BACKGROUND=no
SVC_WAIT=5

# PID file location
PID_FILE="${SYNOPKG_PKGVAR}/run/php-fpm.pid"

# PHP-FPM writes its own PID file
SVC_WRITE_PID=no

# Note: SERVICE_USER/GROUP not used - DSM 7 non-root packages
# run as the package service user automatically

# Pre-start actions
service_prestart() {
    # Ensure directories exist
    # DSM 7 manages permissions automatically for non-root packages
    mkdir -p "${SYNOPKG_PKGVAR}/run"
    mkdir -p "${SYNOPKG_PKGVAR}/log"
    mkdir -p "${SYNOPKG_PKGVAR}/tmp"
    mkdir -p "${SYNOPKG_PKGVAR}/etc/conf.d"

    # CRITICAL: Allow 'http' user (CGI executor) to write extension configs
    # CGI scripts in DSM 7 run as 'http' user, not the package user (sc-php84)
    # Without this, the Extension Manager UI cannot enable/disable extensions
    chmod 777 "${SYNOPKG_PKGVAR}/etc/conf.d"

    # Note: chown removed - requires root privileges
    # DSM 7 handles permissions automatically for SYNOPKG_PKGVAR

    # Set LD_LIBRARY_PATH for bundled libraries
    export LD_LIBRARY_PATH="${SYNOPKG_PKGDEST}/lib:${LD_LIBRARY_PATH}"

    # Verify configuration exists
    if [ ! -f "${SYNOPKG_PKGVAR}/etc/php-fpm.conf" ]; then
        echo "ERROR: PHP-FPM configuration not found"
        return 1
    fi

    # Test configuration
    "${SERVICE_COMMAND}" -c "${SYNOPKG_PKGVAR}/etc/php.ini" \
                         -y "${SYNOPKG_PKGVAR}/etc/php-fpm.conf" \
                         -t > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "ERROR: PHP-FPM configuration test failed"
        return 1
    fi

    return 0
}

# Post-start actions
service_poststart() {
    # Wait for PID file
    local count=0
    while [ $count -lt 10 ]; do
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "PHP-FPM started (PID: $pid)"
                return 0
            fi
        fi
        sleep 1
        ((count++))
    done

    echo "WARNING: PHP-FPM may not have started correctly"
    return 0
}

# Pre-stop actions
service_prestop() {
    return 0
}

# Post-stop actions
service_poststop() {
    # Clean up PID file
    rm -f "$PID_FILE"

    # Clean up socket if using Unix socket
    rm -f "${SYNOPKG_PKGVAR}/run/php-fpm.sock" 2>/dev/null

    return 0
}

# Service status
service_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}
