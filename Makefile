APP_NAME := LudeVitals
CONFIG   := release
BUILD    := .build/arm64-apple-macosx/$(CONFIG)
BUNDLE   := $(APP_NAME).app

.PHONY: build app run clean kill install

build:
	swift build -c $(CONFIG) --arch arm64

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	chmod +x $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	codesign --force --deep --sign - $(BUNDLE) 2>/dev/null || true
	@echo "Built $(BUNDLE)"

run: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	open $(BUNDLE)

kill:
	@pkill -x $(APP_NAME) 2>/dev/null && echo "killed" || echo "not running"

install: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf /Applications/$(BUNDLE)
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(BUNDLE)
	@echo "Installed to /Applications/$(BUNDLE)"

clean:
	rm -rf .build $(BUNDLE)
