PROJECT := Composer.xcodeproj
SCHEME := Composer
APP_NAME := Composer
BUILD_DIR := build
INSTALL_DIR := /Applications

# Dev builds are signed ad hoc so they don't need a developer certificate
# (the sandbox entitlements are still embedded).
DEV_SIGNING := CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=

APP_PATH_DEV := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app
APP_PATH_RELEASE := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app

# Mac App Store. The team that owns org.perfectink.composer on the App Store.
TEAM_ID ?= XS9W9A8FWM
APPSTORE_DIR := $(BUILD_DIR)/appstore
APPSTORE_ARCHIVE := $(APPSTORE_DIR)/$(APP_NAME).xcarchive
APPSTORE_PKG := $(APPSTORE_DIR)/$(APP_NAME).pkg
# Optional App Store Connect API key (CI sets these). Without it, Xcode signs
# with the Apple ID signed in under Xcode > Settings > Accounts.
ASC_AUTH := $(if $(ASC_KEY_PATH),-authenticationKeyPath "$(ASC_KEY_PATH)" -authenticationKeyID "$(ASC_KEY_ID)" -authenticationKeyIssuerID "$(ASC_ISSUER_ID)",)

.DEFAULT_GOAL := all
.PHONY: all help setup dev build open close clean install uninstall reinstall install-open appstore metadata submit

## Default: same as `make setup` then `make dev`.
all: setup dev

## Help for all commands, grouped by category.
help:
	@echo "Composer"
	@echo ""
	@echo "Building:"
	@echo "  make dev        Close the app, delete the old build, build Debug and open it"
	@echo "  make build      Build for production (Release)"
	@echo "  make open       Open the dev build"
	@echo "  make close      Quit the app"
	@echo "  make clean      Remove build/ and the generated Xcode project"
	@echo "  make setup      Install XcodeGen if missing and generate the Xcode project"
	@echo ""
	@echo "Production:"
	@echo "  make install    Build for production and install to $(INSTALL_DIR)"
	@echo "  make uninstall  Quit the app and remove it from $(INSTALL_DIR)"
	@echo "  make reinstall  make uninstall, then make install"
	@echo "  make install-open  Install, then open the installed app"
	@echo ""
	@echo "Mac App Store (see docs/app-store/README.md):"
	@echo "  make appstore   Archive and export the signed App Store package to $(APPSTORE_PKG)"
	@echo "  make metadata VERSION=x.y.z  Push docs/app-store/ to App Store Connect"
	@echo "  make submit VERSION=x.y.z    Submit the newest processed build for review"

## Install XcodeGen if missing and (re)generate the Xcode project.
setup:
	@command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
	@xcodegen generate --quiet

## Close the app, delete the old build, build Debug and open it.
dev: setup close
	@rm -rf "$(APP_PATH_DEV)"
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(BUILD_DIR) $(DEV_SIGNING) build
	@$(MAKE) --no-print-directory open

## Build for production.
build: setup
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(BUILD_DIR) build

## Open the dev build.
open:
	@[ -d "$(APP_PATH_DEV)" ] || { echo "No dev build at $(APP_PATH_DEV). Run 'make dev' first."; exit 1; }
	open "$(APP_PATH_DEV)"

## Quit the app.
close:
	@pkill -x "$(APP_NAME)" >/dev/null 2>&1 || true

## Remove build output and the generated project.
clean: close
	rm -rf "$(BUILD_DIR)" "$(PROJECT)"

## Build for production and install to /Applications.
install: build
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_PATH_RELEASE)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

uninstall: close
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

reinstall: uninstall install

install-open: close install
	open "$(INSTALL_DIR)/$(APP_NAME).app"

## Archive and export the signed Mac App Store package.
## VERSION and BUILD_NUMBER override the ones in project.yml.
appstore: setup
	@rm -rf "$(APPSTORE_DIR)"
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-archivePath "$(APPSTORE_ARCHIVE)" -allowProvisioningUpdates $(ASC_AUTH) \
		DEVELOPMENT_TEAM=$(TEAM_ID) CODE_SIGN_STYLE=Automatic \
		$(if $(VERSION),MARKETING_VERSION=$(VERSION),) $(if $(BUILD_NUMBER),CURRENT_PROJECT_VERSION=$(BUILD_NUMBER),) archive
	xcodebuild -exportArchive -archivePath "$(APPSTORE_ARCHIVE)" \
		-exportOptionsPlist Scripts/ExportOptions-AppStore.plist -exportPath "$(APPSTORE_DIR)" \
		-allowProvisioningUpdates $(ASC_AUTH)
	@pkgutil --check-signature "$(APPSTORE_PKG)"
	@echo "Built $(APPSTORE_PKG)"

## Push the App Store listing (docs/app-store/) to App Store Connect, and submit
## a processed build for review. Need fastlane and the APP_STORE_CONNECT_API_KEY_*
## variables described at the top of fastlane/Fastfile.
metadata:
	@[ -n "$(VERSION)" ] || { echo "Set VERSION (e.g. 1.0.0)"; exit 1; }
	fastlane mac metadata version:$(VERSION)

submit:
	@[ -n "$(VERSION)" ] || { echo "Set VERSION (e.g. 1.0.0)"; exit 1; }
	fastlane mac submit version:$(VERSION) $(if $(BUILD_NUMBER),build:$(BUILD_NUMBER),)
