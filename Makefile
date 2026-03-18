SWIFT ?= swift
CONFIG ?= debug
APP_NAME ?= PixelClaw
BUNDLE_ID ?= com.ronmasas.$(APP_NAME)
APP_VERSION ?= 1.0.0
APP_BUILD ?= 1
DIST_DIR ?= Dist
BINARY = .build/$(CONFIG)/$(APP_NAME)
RELEASE_BINARY = .build/release/$(APP_NAME)
APP_BUNDLE = $(DIST_DIR)/$(APP_NAME).app
APP_CONTENTS = $(APP_BUNDLE)/Contents
APP_MACOS_DIR = $(APP_CONTENTS)/MacOS
APP_RESOURCES_DIR = $(APP_CONTENTS)/Resources
APP_PLIST = $(APP_CONTENTS)/Info.plist
RESOURCE_BUNDLE = .build/$(CONFIG)/$(APP_NAME)_$(APP_NAME).bundle
RELEASE_RESOURCE_BUNDLE = .build/release/$(APP_NAME)_$(APP_NAME).bundle
ICON_SOURCE = Assets/AppIcon/appicon.png
ICONSET_DIR = $(DIST_DIR)/AppIcon.iconset
ICON_FILE = $(APP_RESOURCES_DIR)/AppIcon.icns
DMG_PATH = $(DIST_DIR)/$(APP_NAME).dmg
ZIP_NAME = $(APP_NAME)-$(APP_VERSION).zip
ZIP_PATH = $(DIST_DIR)/$(ZIP_NAME)

all:
	$(SWIFT) build -c $(CONFIG)

run: all
	@pkill -x PixelClaw 2>/dev/null || true
	@sleep 0.3
	$(BINARY) &

debug: all
	@pkill -x PixelClaw 2>/dev/null || true
	@sleep 0.3
	$(BINARY) --debug

release:
	$(SWIFT) build -c release

app: release
	rm -rf $(APP_BUNDLE)
	rm -rf $(ICONSET_DIR)
	mkdir -p $(APP_MACOS_DIR) $(APP_RESOURCES_DIR) $(ICONSET_DIR)
	install -m 755 $(RELEASE_BINARY) $(APP_MACOS_DIR)/$(APP_NAME)
	ditto $(RELEASE_RESOURCE_BUNDLE) $(APP_RESOURCES_DIR)/$(notdir $(RELEASE_RESOURCE_BUNDLE))
	sips -z 16 16 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_16x16.png
	sips -z 32 32 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_16x16@2x.png
	sips -z 32 32 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_32x32.png
	sips -z 64 64 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_32x32@2x.png
	sips -z 128 128 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_128x128.png
	sips -z 256 256 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_128x128@2x.png
	sips -z 256 256 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_256x256.png
	sips -z 512 512 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_256x256@2x.png
	sips -z 512 512 $(ICON_SOURCE) --out $(ICONSET_DIR)/icon_512x512.png
	cp $(ICON_SOURCE) $(ICONSET_DIR)/icon_512x512@2x.png
	iconutil -c icns $(ICONSET_DIR) -o $(ICON_FILE)
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'	<key>CFBundleDevelopmentRegion</key>' \
		'	<string>en</string>' \
		'	<key>CFBundleExecutable</key>' \
		'	<string>$(APP_NAME)</string>' \
		'	<key>CFBundleIconFile</key>' \
		'	<string>AppIcon</string>' \
		'	<key>CFBundleIdentifier</key>' \
		'	<string>$(BUNDLE_ID)</string>' \
		'	<key>CFBundleInfoDictionaryVersion</key>' \
		'	<string>6.0</string>' \
		'	<key>CFBundleName</key>' \
		'	<string>$(APP_NAME)</string>' \
		'	<key>CFBundlePackageType</key>' \
		'	<string>APPL</string>' \
		'	<key>CFBundleShortVersionString</key>' \
		'	<string>$(APP_VERSION)</string>' \
		'	<key>CFBundleVersion</key>' \
		'	<string>$(APP_BUILD)</string>' \
		'	<key>LSMinimumSystemVersion</key>' \
		'	<string>12.0</string>' \
		'	<key>LSUIElement</key>' \
		'	<true/>' \
		'</dict>' \
		'</plist>' > $(APP_PLIST)
	rm -rf $(ICONSET_DIR)
	@echo "Created $(APP_BUNDLE)"

clean:
	rm -rf .build $(DIST_DIR)

dmg: app
	chmod +x Scripts/create_dmg.sh
	DIST_DIR='$(DIST_DIR)' \
	APP_BUNDLE='$(APP_BUNDLE)' \
	DMG_PATH='$(DMG_PATH)' \
	Scripts/create_dmg.sh

zip: app
	rm -f $(ZIP_PATH)
	COPYFILE_DISABLE=1 ditto -c -k --keepParent $(APP_BUNDLE) $(ZIP_PATH)
	@echo "Created $(ZIP_PATH)"

.PHONY: all run debug release app dmg zip clean
