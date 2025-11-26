# PHP 8.4.15 SPK Package Makefile for Synology DS920+ (geminilake)
# DSM 7.2.2 compatible

SPK_NAME = php84
SPK_VERS = 8.4.15
SPK_REV = 1
SPK_ICON = src/PACKAGE_ICON.png

# Package display information
DISPLAY_NAME = PHP 8.4
DESCRIPTION = PHP 8.4.15 Hypertext Preprocessor with Extension Manager. Includes ~100 extensions organized by theme with a graphical management interface.
DESCRIPTION_FRE = PHP 8.4.15 avec gestionnaire d'extensions. Inclut environ 100 extensions organisées par thème avec une interface de gestion graphique.

HOMEPAGE = https://www.php.net
LICENSE = PHP-3.01
MAINTAINER = PHP84 SPK Project
CHANGELOG = "Initial release with Extension Manager"

# Architecture and DSM version
ARCH = geminilake
FIRMWARE = 7.0-40000
OS_MIN_VER = 7.0-40000

# Dependencies on other SPK packages (none for self-contained build)
# INSTALL_DEP_SERVICES =
# START_DEP_SERVICES =

# Build dependencies
DEPENDS = cross/php84

# ============================================================================
# Service Configuration
# ============================================================================
STARTABLE = yes
SERVICE_USER = auto
SERVICE_SETUP = src/service-setup.sh
SERVICE_PORT = 9000
SERVICE_PORT_TITLE = PHP-FPM

# ============================================================================
# DSM Integration
# ============================================================================
# UI directory for DSM application (enables "Open" button in Package Center)
DSM_UI_DIR = ui

# Admin interface
ADMIN_PORT = $(SERVICE_PORT)
ADMIN_PROTOCOL = http

# Wizard for installation configuration
WIZARDS_DIR = src/wizard

# ============================================================================
# Package Contents
# ============================================================================
# Source directory containing package files
SRC_DIR = src

# Files to include in package
CONF_DIR = $(SRC_DIR)/conf
SCRIPTS_DIR = $(SRC_DIR)/scripts
WIZARD_DIR = $(SRC_DIR)/wizard
UI_DIR = $(SRC_DIR)/ui

# ============================================================================
# Build Targets
# ============================================================================
WORK_DIR = $(CURDIR)/work
STAGING_DIR = $(WORK_DIR)/staging
PKG_DIR = $(WORK_DIR)/package
DIST_DIR = $(CURDIR)/../../dist

.PHONY: all clean package install-files create-spk

all: package

# Copy all package files to staging
install-files:
	@echo "Installing package files..."
	@mkdir -p $(STAGING_DIR)/var/packages/$(SPK_NAME)/target
	@mkdir -p $(STAGING_DIR)/var/packages/$(SPK_NAME)/scripts
	@mkdir -p $(STAGING_DIR)/var/packages/$(SPK_NAME)/conf
	@mkdir -p $(STAGING_DIR)/var/packages/$(SPK_NAME)/ui

	@# Copy PHP binaries from cross-compilation
	@if [ -d "../../../cross/php84/work/staging" ]; then \
		cp -r ../../../cross/php84/work/staging/* $(STAGING_DIR)/var/packages/$(SPK_NAME)/target/; \
	fi

	@# Copy configuration files
	@cp -r $(CONF_DIR)/* $(STAGING_DIR)/var/packages/$(SPK_NAME)/conf/ 2>/dev/null || true

	@# Copy scripts
	@cp -r $(SCRIPTS_DIR)/* $(STAGING_DIR)/var/packages/$(SPK_NAME)/scripts/ 2>/dev/null || true

	@# Copy UI files
	@cp -r $(UI_DIR)/* $(STAGING_DIR)/var/packages/$(SPK_NAME)/ui/ 2>/dev/null || true

# Create INFO file
create-info:
	@echo "Creating INFO file..."
	@mkdir -p $(PKG_DIR)
	@echo 'package="$(SPK_NAME)"' > $(PKG_DIR)/INFO
	@echo 'version="$(SPK_VERS)-$(SPK_REV)"' >> $(PKG_DIR)/INFO
	@echo 'os_min_ver="$(OS_MIN_VER)"' >> $(PKG_DIR)/INFO
	@echo 'arch="$(ARCH)"' >> $(PKG_DIR)/INFO
	@echo 'displayname="$(DISPLAY_NAME)"' >> $(PKG_DIR)/INFO
	@echo 'description="$(DESCRIPTION)"' >> $(PKG_DIR)/INFO
	@echo 'maintainer="$(MAINTAINER)"' >> $(PKG_DIR)/INFO
	@echo 'startable="$(STARTABLE)"' >> $(PKG_DIR)/INFO
	@echo 'dsmuidir="$(DSM_UI_DIR)"' >> $(PKG_DIR)/INFO
	@echo 'dsmappname="SYNO.SDS.PHP84Manager.Instance"' >> $(PKG_DIR)/INFO
	@echo 'adminport="$(ADMIN_PORT)"' >> $(PKG_DIR)/INFO
	@echo 'adminprotocol="$(ADMIN_PROTOCOL)"' >> $(PKG_DIR)/INFO

# Create package.tgz
create-package-tgz: install-files
	@echo "Creating package.tgz..."
	@mkdir -p $(PKG_DIR)
	cd $(STAGING_DIR) && tar czf $(PKG_DIR)/package.tgz .

# Copy wizard files
copy-wizard:
	@echo "Copying wizard files..."
	@mkdir -p $(PKG_DIR)/WIZARD_UIFILES
	@cp $(WIZARD_DIR)/* $(PKG_DIR)/WIZARD_UIFILES/ 2>/dev/null || true

# Copy scripts
copy-scripts:
	@echo "Copying scripts..."
	@cp $(SCRIPTS_DIR)/postinst $(PKG_DIR)/ 2>/dev/null || true
	@cp $(SCRIPTS_DIR)/preuninst $(PKG_DIR)/ 2>/dev/null || true
	@cp $(SCRIPTS_DIR)/start-stop-status $(PKG_DIR)/ 2>/dev/null || true
	@chmod +x $(PKG_DIR)/*.sh 2>/dev/null || true
	@chmod +x $(PKG_DIR)/postinst 2>/dev/null || true
	@chmod +x $(PKG_DIR)/preuninst 2>/dev/null || true
	@chmod +x $(PKG_DIR)/start-stop-status 2>/dev/null || true

# Copy conf directory
copy-conf:
	@echo "Copying conf files..."
	@mkdir -p $(PKG_DIR)/conf
	@cp $(CONF_DIR)/* $(PKG_DIR)/conf/ 2>/dev/null || true

# Copy icons
copy-icons:
	@echo "Copying icons..."
	@cp $(SRC_DIR)/PACKAGE_ICON.png $(PKG_DIR)/ 2>/dev/null || true
	@cp $(SRC_DIR)/PACKAGE_ICON_256.png $(PKG_DIR)/ 2>/dev/null || true

# Create final SPK
create-spk: create-info create-package-tgz copy-wizard copy-scripts copy-conf copy-icons
	@echo "Creating SPK package..."
	@mkdir -p $(DIST_DIR)
	cd $(PKG_DIR) && tar cf $(DIST_DIR)/$(SPK_NAME)-$(SPK_VERS)-$(SPK_REV)-$(ARCH).spk *
	@echo "Package created: $(DIST_DIR)/$(SPK_NAME)-$(SPK_VERS)-$(SPK_REV)-$(ARCH).spk"

package: create-spk

clean:
	rm -rf $(WORK_DIR)

# Cross-compilation target
arch-geminilake-7.2: package
	@echo "SPK build complete for geminilake-7.2"
