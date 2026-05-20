APP_NAME := LudeVitals
CONFIG   := release
BUILD    := .build/arm64-apple-macosx/$(CONFIG)
BUNDLE   := $(APP_NAME).app

.PHONY: build app run clean kill install dmg benchmark icon
VERSION := 0.1.0
DMG     := LudeVitals-$(VERSION).dmg

build:
	swift build -c $(CONFIG) --arch arm64

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/
	chmod +x $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	codesign --force --sign - --options=runtime --entitlements LudeVitals.entitlements $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	codesign --force --sign - --options=runtime --entitlements LudeVitals.entitlements $(BUNDLE)
	@echo "Built $(BUNDLE)"

run: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done
	open $(BUNDLE)

kill:
	@pkill -x $(APP_NAME) 2>/dev/null && echo "killed" || echo "not running"

install: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done
	rm -rf /Applications/$(BUNDLE)
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(BUNDLE)
	@echo "Installed to /Applications/$(BUNDLE)"

dmg: app
	rm -f $(DMG)
	hdiutil create -volname "LudeVitals" -srcfolder $(BUNDLE) -ov -format UDZO $(DMG)
	@echo "Created $(DMG)"

icon:
	@scripts/generate-icon.sh

benchmark: app
	@open $(BUNDLE)
	@sleep 5
	@echo "Binary size: $$(stat -f%z $(BUNDLE)/Contents/MacOS/$(APP_NAME)) bytes"
	@ps -o rss,pcpu -p $$(pgrep -x $(APP_NAME)) | tail -1 | awk '{printf "Idle RSS: %.1f MB\nIdle CPU: %s%%\n", $$1/1024, $$2}'
	@pkill -x $(APP_NAME) 2>/dev/null || true

clean:
	rm -rf .build $(BUNDLE) $(DMG)
