import Cocoa
import ApplicationServices

extension AppController {
    func makeAccessibilityWarningIcon() -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        NSColor.systemOrange.setFill()
        path.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let textRect = NSRect(x: 0, y: -0.5, width: size.width, height: size.height)
        "!".draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    func updateAccessibilityMenuState() {
        accessibilityMenuItem?.isHidden = isAccessibilityGranted
        feedMenuItem?.isEnabled = true
        updateStatusBarIcon()
    }

    func setupStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusBarIcon()

        let menu = NSMenu()
        let accessibilityItem = NSMenuItem(
            title: "Enable Accessibility Access",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.image = makeAccessibilityWarningIcon()
        menu.addItem(accessibilityItem)

        let feedItem = NSMenuItem(title: "Drop Apple", action: #selector(feedApple), keyEquivalent: "f")
        feedItem.keyEquivalentModifierMask = [.option]
        feedItem.isEnabled = false
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates",
            action: #selector(handleUpdatesMenuAction),
            keyEquivalent: ""
        )
        let aboutItem = NSMenuItem(
            title: "About",
            action: #selector(showAboutWindow),
            keyEquivalent: ""
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(feedItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(checkForUpdatesItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(exitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        accessibilityMenuItem = accessibilityItem
        feedMenuItem = feedItem
        checkForUpdatesMenuItem = checkForUpdatesItem
        aboutMenuItem = aboutItem
        refreshUpdateMenuItem()
    }

    func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }

        if let image = makeStatusBarIcon(named: isAccessibilityGranted ? "crabicon" : "crabicon_warn") {
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
            return
        }

        button.image = nil
        button.title = "🦀"
        button.imagePosition = .noImage
    }

    func makeStatusBarIcon(named name: String) -> NSImage? {
        guard let url = AppResources.bundle.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = false
        return image
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItemIfNeeded()
        setupAutomaticUpdateChecks()
        beginLaunchFlow()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        beginLaunchFlow()
    }

    func beginLaunchFlow() {
        if isAccessibilityGranted {
            accessibilityPrePromptShownThisLaunch = false
            accessibilityPromptRequestedThisLaunch = false
            updateAccessibilityMenuState()
            completeLaunch()
            activateAccessibilityFeaturesIfNeeded()
            startAccessibilityPolling()
            return
        }

        deactivateAccessibilityFeatures()
        updateAccessibilityMenuState()
        startAccessibilityPolling()
        completeLaunch()
        presentAccessibilityPrePromptIfNeeded()
    }

    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func presentAccessibilityPrePromptIfNeeded() {
        guard !isAccessibilityGranted else { return }
        guard !accessibilityPrePromptShownThisLaunch else { return }
        guard !accessibilityPromptRequestedThisLaunch else { return }

        accessibilityPrePromptShownThisLaunch = true
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "PixelClaw needs Accessibility access"
        alert.informativeText = "PixelClaw uses Accessibility access to read your Dock position and respond to clicks. Without it, your pet cannot line up with the Dock or react when you interact with it.\n\nClick Continue to let macOS show the permission prompt."
        alert.addButton(withTitle: "Continue")

        if alert.runModal() == .alertFirstButtonReturn {
            DispatchQueue.main.async { [weak self] in
                self?.requestAccessibilityPromptIfNeeded()
            }
        }
    }

    func requestAccessibilityPromptIfNeeded() {
        guard !accessibilityPromptRequestedThisLaunch else { return }
        accessibilityPromptRequestedThisLaunch = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc func openAccessibilitySettings() {
        startAccessibilityPolling()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func startAccessibilityPolling() {
        if accessibilityPollTimer != nil {
            return
        }
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let hasAccessibility = self.isAccessibilityGranted
            self.accessibilityMenuItem?.isHidden = hasAccessibility
            self.updateStatusBarIcon()

            if hasAccessibility {
                self.accessibilityPromptRequestedThisLaunch = false
                self.updateAccessibilityMenuState()
                self.completeLaunch()
                self.activateAccessibilityFeaturesIfNeeded()
            } else {
                self.deactivateAccessibilityFeatures()
            }
        }
    }

    func activateAccessibilityFeaturesIfNeeded() {
        guard isAccessibilityGranted else { return }
        guard window != nil else { return }
        guard !accessibilityFeaturesActive else { return }

        accessibilityFeaturesActive = true
        refreshDockBounds()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleMouseClick(at: NSEvent.mouseLocation)
        }
    }

    func deactivateAccessibilityFeatures() {
        accessibilityFeaturesActive = false
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    func completeLaunch() {
        guard window == nil else { return }

        let screen = NSScreen.main!
        let screenFrame = screen.frame
        let dock = DockInfo.get(screen: screen)

        let halfBody: CGFloat = 5 * SCALE
        dockLeft = dock.x + halfBody
        dockRight = dock.x + dock.width - halfBody
        screenLeft = screenFrame.origin.x + halfBody + 10
        screenRight = screenFrame.origin.x + screenFrame.width - halfBody - 10

        let windowHeight = screenFrame.height
        let windowY = screenFrame.origin.y

        let crabFeetInSprite: CGFloat = 4 * SCALE
        groundFloorY = -5
        dockFloorY = dock.height - crabFeetInSprite + 21

        let windowRect = NSRect(
            x: screenFrame.origin.x,
            y: windowY,
            width: screenFrame.width,
            height: windowHeight
        )

        window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false

        crabView = CrabView(frame: NSRect(x: 0, y: 0, width: spriteW, height: spriteH))
        crabView.wantsLayer = true
        crabView.layer?.backgroundColor = NSColor.clear.cgColor

        shadowView = ShadowView(frame: NSRect(x: 0, y: 0, width: spriteW, height: SHADOW_VIEW_HEIGHT))
        shadowView.wantsLayer = true
        shadowView.layer?.backgroundColor = NSColor.clear.cgColor

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: Int(screenFrame.width), height: Int(windowHeight)))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.addSubview(shadowView)
        contentView.addSubview(crabView)

        window.contentView = contentView

        let startFromLeft = Bool.random()
        let dockCoversScreen = dock.width >= screenFrame.width * 0.99
        crabX = startFromLeft ? -spriteW : screenFrame.width + spriteW
        crabY = dockCoversScreen ? dockFloorY : groundFloorY
        level = dockCoversScreen ? .dock : .ground
        crabView.facingRight = startFromLeft
        positionSprite()

        lastTime = CACurrentMediaTime()
        lastActivityTime = lastTime

        setupStatusItemIfNeeded()
        updateAccessibilityMenuState()

        registerFeedHotKey()
        window.orderFrontRegardless()

        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                if let window = self?.window {
                    let point = window.convertPoint(toScreen: event.locationInWindow)
                    self?.handleMouseClick(at: point)
                }
                return event
            }
        }

        updateTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        if let updateTimer {
            RunLoop.main.add(updateTimer, forMode: .common)
        }
    }
}
