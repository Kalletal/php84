#!/bin/sh
# SPK Version Bump Script
# POSIX-compliant - Automatically increments the build number in INFO file
#
# Usage:
#   ./bump-version.sh          # Increment build number (0001 -> 0002)
#   ./bump-version.sh patch    # Increment patch version (8.4.15 -> 8.4.16)
#   ./bump-version.sh minor    # Increment minor version (8.4.15 -> 8.5.0)
#   ./bump-version.sh major    # Increment major version (8.4.15 -> 9.0.0)
#   ./bump-version.sh set 8.4.16-0001  # Set specific version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SPK_DIR="$(dirname "$SCRIPT_DIR")"
INFO_FILE="${SPK_DIR}/src/INFO"

# Colors for output (if terminal supports it)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    color="$1"
    msg="$2"
    if [ -t 1 ]; then
        printf "${color}%s${NC}\n" "$msg"
    else
        echo "$msg"
    fi
}

# Check INFO file exists
if [ ! -f "$INFO_FILE" ]; then
    print_msg "$RED" "ERROR: INFO file not found: $INFO_FILE"
    exit 1
fi

# Read current version
CURRENT_VERSION=$(grep '^version=' "$INFO_FILE" | cut -d'=' -f2 | tr -d '"')

if [ -z "$CURRENT_VERSION" ]; then
    print_msg "$RED" "ERROR: Could not read version from INFO file"
    exit 1
fi

# Parse version components (format: X.Y.Z-BBBB)
PHP_VERSION=$(echo "$CURRENT_VERSION" | cut -d'-' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'-' -f2)

MAJOR=$(echo "$PHP_VERSION" | cut -d'.' -f1)
MINOR=$(echo "$PHP_VERSION" | cut -d'.' -f2)
PATCH=$(echo "$PHP_VERSION" | cut -d'.' -f3)

print_msg "$YELLOW" "Current version: $CURRENT_VERSION"
print_msg "$YELLOW" "  PHP: $MAJOR.$MINOR.$PATCH"
print_msg "$YELLOW" "  Build: $BUILD_NUMBER"

# Determine action
ACTION="${1:-build}"

case "$ACTION" in
    build|b)
        # Increment build number
        # Remove leading zeros, increment, then pad back to 4 digits
        BUILD_NUM=$(echo "$BUILD_NUMBER" | sed 's/^0*//')
        [ -z "$BUILD_NUM" ] && BUILD_NUM=0
        NEW_BUILD=$((BUILD_NUM + 1))
        NEW_BUILD_PADDED=$(printf "%04d" "$NEW_BUILD")
        NEW_VERSION="${PHP_VERSION}-${NEW_BUILD_PADDED}"
        ;;
    patch|p)
        # Increment patch version, reset build
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}-0001"
        ;;
    minor|m)
        # Increment minor version, reset patch and build
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="${MAJOR}.${NEW_MINOR}.0-0001"
        ;;
    major|M)
        # Increment major version, reset minor, patch and build
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION="${NEW_MAJOR}.0.0-0001"
        ;;
    set|s)
        # Set specific version
        if [ -z "$2" ]; then
            print_msg "$RED" "ERROR: Please provide version (e.g., ./bump-version.sh set 8.4.16-0001)"
            exit 1
        fi
        NEW_VERSION="$2"
        # Validate format
        if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+-[0-9]{4}$'; then
            print_msg "$RED" "ERROR: Invalid version format. Expected: X.Y.Z-BBBB (e.g., 8.4.16-0001)"
            exit 1
        fi
        ;;
    show|status)
        # Just show current version
        echo "$CURRENT_VERSION"
        exit 0
        ;;
    help|h|-h|--help)
        echo "SPK Version Bump Script"
        echo ""
        echo "Usage: $0 [action] [version]"
        echo ""
        echo "Actions:"
        echo "  build, b     Increment build number (default)"
        echo "  patch, p     Increment patch version (X.Y.Z+1)"
        echo "  minor, m     Increment minor version (X.Y+1.0)"
        echo "  major, M     Increment major version (X+1.0.0)"
        echo "  set, s VER   Set specific version"
        echo "  show         Show current version"
        echo "  help, h      Show this help"
        echo ""
        echo "Examples:"
        echo "  $0           # 8.4.15-0001 -> 8.4.15-0002"
        echo "  $0 build     # 8.4.15-0001 -> 8.4.15-0002"
        echo "  $0 patch     # 8.4.15-0001 -> 8.4.16-0001"
        echo "  $0 minor     # 8.4.15-0001 -> 8.5.0-0001"
        echo "  $0 major     # 8.4.15-0001 -> 9.0.0-0001"
        echo "  $0 set 8.4.16-0002"
        exit 0
        ;;
    *)
        print_msg "$RED" "ERROR: Unknown action: $ACTION"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac

# Update INFO file
# Create temp file and update version line
TMP_FILE="${INFO_FILE}.tmp"
while IFS= read -r line; do
    case "$line" in
        version=*)
            echo "version=\"${NEW_VERSION}\""
            ;;
        *)
            echo "$line"
            ;;
    esac
done < "$INFO_FILE" > "$TMP_FILE"

# Replace original file
mv "$TMP_FILE" "$INFO_FILE"

print_msg "$GREEN" "Version updated: $CURRENT_VERSION -> $NEW_VERSION"

# Show updated INFO
echo ""
echo "Updated INFO file:"
grep -E '^(package|version|displayname)=' "$INFO_FILE"

# Remind about SPK filename
NEW_PHP_VER=$(echo "$NEW_VERSION" | cut -d'-' -f1)
NEW_BUILD=$(echo "$NEW_VERSION" | cut -d'-' -f2)
echo ""
echo "Expected SPK filename: php84-${NEW_VERSION}-geminilake-7.2.spk"
