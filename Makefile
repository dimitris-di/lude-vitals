APP_NAME := LudeVitals
CONFIG   := release
BUILD    := .build/arm64-apple-macosx/$(CONFIG)
BUNDLE   := $(APP_NAME).app
DMG_STAGE := .release/dmg

.PHONY: help build app run clean kill install dmg benchmark icon check-release-metadata verify-app provenance
.DEFAULT_GOAL := help
VERSION := $(shell cat VERSION)
DMG     := LudeVitals-$(VERSION).dmg
LEGAL_FILES := LICENSE THIRD_PARTY_NOTICES.md
SIGN_IDENTITY ?= -
ifeq ($(strip $(SIGN_IDENTITY)),)
SIGN_IDENTITY := -
endif
CODESIGN_FLAGS := --force --options=runtime --entitlements LudeVitals.entitlements
ifneq ($(SIGN_IDENTITY),-)
CODESIGN_FLAGS += --timestamp
endif

help:  ## Show this help and the list of available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build:  ## Compile the release binary with swift build for arm64
	swift build -c $(CONFIG) --arch arm64

check-release-metadata:  ## Validate release metadata via scripts/check-release-metadata.sh
	scripts/check-release-metadata.sh

app: check-release-metadata build  ## Build the release binary and assemble LudeVitals.app
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	mkdir -p $(BUNDLE)/Contents/Resources/Legal
	cp $(BUILD)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/
	@for f in $(LEGAL_FILES); do \
		if [ -f "$$f" ]; then cp "$$f" "$(BUNDLE)/Contents/Resources/Legal/"; fi; \
	done
	chmod +x $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	codesign $(CODESIGN_FLAGS) --sign "$(SIGN_IDENTITY)" $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	codesign $(CODESIGN_FLAGS) --sign "$(SIGN_IDENTITY)" $(BUNDLE)
	@echo "Built $(BUNDLE)"

verify-app: app  ## Build the app and verify release artifacts
	scripts/verify-release-artifacts.sh

run: app  ## Build the app, kill any running instance, and launch it
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done
	open $(BUNDLE)

kill:  ## Kill any running LudeVitals instance
	@pkill -x $(APP_NAME) 2>/dev/null && echo "killed" || echo "not running"

install: app  ## Build the app and install it into /Applications
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done
	rm -rf /Applications/$(BUNDLE)
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(BUNDLE)
	@echo "Installed to /Applications/$(BUNDLE)"

dmg: app  ## Build the app and package it into a versioned .dmg installer
	rm -f $(DMG)
	rm -rf $(DMG_STAGE)
	mkdir -p $(DMG_STAGE)
	cp -R $(BUNDLE) $(DMG_STAGE)/
	@for f in $(LEGAL_FILES); do \
		if [ -f "$$f" ]; then cp "$$f" "$(DMG_STAGE)/"; fi; \
	done
	hdiutil create -volname "LudeVitals $(VERSION)" -srcfolder $(DMG_STAGE) -ov -format UDZO $(DMG)
	@echo "Created $(DMG)"

provenance:  ## Write the release provenance JSON for the current DMG
	scripts/write-provenance.sh release-provenance.json $(DMG) SHA256SUMS

icon:  ## Regenerate the AppIcon.icns from source artwork
	@scripts/generate-icon.sh

benchmark: app  ## Launch the app and report binary size, idle RSS, and idle CPU
	@open $(BUNDLE)
	@sleep 5
	@echo "Binary size: $$(stat -f%z $(BUNDLE)/Contents/MacOS/$(APP_NAME)) bytes"
	@ps -o rss,pcpu -p $$(pgrep -x $(APP_NAME)) | tail -1 | awk '{printf "Idle RSS: %.1f MB\nIdle CPU: %s%%\n", $$1/1024, $$2}'
	@pkill -x $(APP_NAME) 2>/dev/null || true

clean:  ## Remove build artifacts, app bundle, dmg, and release outputs
	rm -rf .build $(BUNDLE) $(DMG) .release SHA256SUMS release-provenance.json
