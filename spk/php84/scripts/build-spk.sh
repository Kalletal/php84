#!/bin/sh
# SPK Build Script
# POSIX-compliant - Builds the SPK package with optional version bump
#
# Usage:
#   ./build-spk.sh              # Build SPK without version change
#   ./build-spk.sh --bump       # Increment build number and build SPK
#   ./build-spk.sh --bump patch # Increment patch version and build SPK

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPK_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="${SPK_DIR}/src"
DIST_DIR="${SPK_DIR}/dist"
INFO_FILE="${SRC_DIR}/INFO"
BUMP_SCRIPT="${SCRIPT_DIR}/bump-version.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_msg() {
    color="$1"
    msg="$2"
    if [ -t 1 ]; then
        printf "${color}%s${NC}\n" "$msg"
    else
        echo "$msg"
    fi
}

print_step() {
    print_msg "$BLUE" "==> $1"
}

# Parse arguments
# Default: always bump build number
BUMP_VERSION="build"
while [ $# -gt 0 ]; do
    case "$1" in
        --no-bump|-n)
            BUMP_VERSION=""
            ;;
        --bump|-b)
            BUMP_VERSION="${2:-build}"
            if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
                shift
            fi
            ;;
        --help|-h)
            echo "SPK Build Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --bump, -b [type]  Bump version before building (default: build)"
            echo "                     Types: build (default), patch, minor, major"
            echo "  --no-bump, -n      Build without incrementing version"
            echo "  --help, -h         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                 # Bump build number and build (default)"
            echo "  $0 --bump patch    # Bump patch version and build"
            echo "  $0 --no-bump       # Build without version change"
            exit 0
            ;;
        *)
            print_msg "$RED" "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# Check required files
if [ ! -f "$INFO_FILE" ]; then
    print_msg "$RED" "ERROR: INFO file not found: $INFO_FILE"
    exit 1
fi

if [ ! -d "${SRC_DIR}/target" ]; then
    print_msg "$RED" "ERROR: target directory not found. PHP must be compiled first."
    exit 1
fi

# Bump version if requested
if [ -n "$BUMP_VERSION" ]; then
    print_step "Bumping version ($BUMP_VERSION)..."
    if [ -x "$BUMP_SCRIPT" ]; then
        "$BUMP_SCRIPT" "$BUMP_VERSION"
    else
        print_msg "$RED" "ERROR: bump-version.sh not found or not executable"
        exit 1
    fi
    echo ""
fi

# Read version from INFO
VERSION=$(grep '^version=' "$INFO_FILE" | cut -d'=' -f2 | tr -d '"')
PACKAGE=$(grep '^package=' "$INFO_FILE" | cut -d'=' -f2 | tr -d '"')
ARCH=$(grep '^arch=' "$INFO_FILE" | cut -d'=' -f2 | tr -d '"')
OS_MIN=$(grep '^os_min_ver=' "$INFO_FILE" | cut -d'=' -f2 | tr -d '"' | cut -d'-' -f1)

# Build SPK name with DSM version
SPK_ARCH="${ARCH}-${OS_MIN}"
print_step "Building SPK: ${PACKAGE}-${VERSION}-${SPK_ARCH}.spk"

# Create dist directory
mkdir -p "$DIST_DIR"

# Remove previous SPK versions
print_step "Cleaning previous versions..."
rm -f "${DIST_DIR}/${PACKAGE}"-*.spk 2>/dev/null && echo "  Previous versions removed" || echo "  No previous versions found"

# Set permissions on scripts
print_step "Setting script permissions..."
chmod 755 "${SRC_DIR}/scripts/"* 2>/dev/null || true
chmod 755 "${SRC_DIR}/target/scripts/"* 2>/dev/null || true
chmod 755 "${SRC_DIR}/ui/"*.cgi 2>/dev/null || true
chmod 755 "${SRC_DIR}/ui/cgi/"*.cgi 2>/dev/null || true

# Create package.tgz
# Note: package.tgz contains files installed to /var/packages/xxx/target/
# The CONTENT of src/target/ goes to the ROOT of package.tgz (not target/ folder itself)
# conf/ and scripts/ must be at SPK root level, NOT in package.tgz
print_step "Creating package.tgz..."
cd "$SRC_DIR" || exit 1

if [ ! -d "target" ]; then
    print_msg "$RED" "ERROR: target directory not found"
    exit 1
fi

# Build package.tgz with content of target/ at root level
# Use -C to change directory so target contents are at root
cd "$SRC_DIR/target" || exit 1
PACKAGE_CONTENTS=$(ls -1)

# Add ui directory if it exists (from parent)
if [ -d "$SRC_DIR/ui" ]; then
    tar czf "${SPK_DIR}/package.tgz" $PACKAGE_CONTENTS -C "$SRC_DIR" ui
else
    tar czf "${SPK_DIR}/package.tgz" $PACKAGE_CONTENTS
fi
if [ $? -ne 0 ]; then
    print_msg "$RED" "ERROR: Failed to create package.tgz"
    exit 1
fi

PACKAGE_SIZE=$(du -h "${SPK_DIR}/package.tgz" | cut -f1)
echo "  package.tgz: $PACKAGE_SIZE"

# Create SPK
print_step "Creating SPK archive..."
cd "$SPK_DIR" || exit 1

SPK_NAME="${PACKAGE}-${VERSION}-${SPK_ARCH}.spk"

# Build list of files to include
SPK_FILES="package.tgz"

# Add INFO (removing src/ prefix)
if [ -f "src/INFO" ]; then
    SPK_FILES="$SPK_FILES src/INFO"
fi

# Add icons
for icon in src/PACKAGE_ICON*.PNG; do
    if [ -f "$icon" ]; then
        SPK_FILES="$SPK_FILES $icon"
    fi
done

# Add conf directory (must be at SPK root for DSM 7 privilege system)
if [ -d "src/conf" ]; then
    SPK_FILES="$SPK_FILES src/conf"
fi

# Add scripts directory (postinst, preuninst, start-stop-status)
if [ -d "src/scripts" ]; then
    SPK_FILES="$SPK_FILES src/scripts"
fi

# Add WIZARD_UIFILES (wizard files must be at SPK root level)
# Synology expects WIZARD_UIFILES/install_uifile for installation wizard
if [ -d "src/wizard" ]; then
    # Create WIZARD_UIFILES directory with proper structure
    rm -rf "WIZARD_UIFILES"
    mkdir -p "WIZARD_UIFILES"
    cp src/wizard/* "WIZARD_UIFILES/" 2>/dev/null || true
    SPK_FILES="$SPK_FILES WIZARD_UIFILES"
fi

# Create SPK with transform to remove src/ prefix
rm -f "dist/${SPK_NAME}"
tar cf "dist/${SPK_NAME}" --transform='s|^src/||' $SPK_FILES

# Cleanup temporary WIZARD_UIFILES
rm -rf "WIZARD_UIFILES"

if [ $? -ne 0 ]; then
    print_msg "$RED" "ERROR: Failed to create SPK"
    exit 1
fi

# Show result
SPK_SIZE=$(du -h "dist/${SPK_NAME}" | cut -f1)

echo ""
print_msg "$GREEN" "SPK built successfully!"
echo ""
echo "Package: dist/${SPK_NAME}"
echo "Size: $SPK_SIZE"
echo "Version: $VERSION"
echo ""

# Show SPK contents
print_step "SPK contents:"
tar tf "dist/${SPK_NAME}"

# Count extensions
EXT_COUNT=$(tar tzf package.tgz 2>/dev/null | grep -c '\.so$' || echo "?")
echo ""
echo "Extensions included: $EXT_COUNT"
