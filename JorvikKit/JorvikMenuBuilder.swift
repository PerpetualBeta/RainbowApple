import AppKit

enum JorvikMenuBuilder {

    struct ActionItem {
        let title: String
        let attributedTitle: NSAttributedString?
        let action: Selector
        let target: AnyObject?
        let keyEquivalent: String
        let state: NSControl.StateValue?
        let isEnabled: Bool
        let indentationLevel: Int

        init(
            title: String,
            action: Selector,
            target: AnyObject?,
            keyEquivalent: String = "",
            state: NSControl.StateValue? = nil,
            isEnabled: Bool = true,
            indentationLevel: Int = 0,
            attributedTitle: NSAttributedString? = nil
        ) {
            self.title = title
            self.attributedTitle = attributedTitle
            self.action = action
            self.target = target
            self.keyEquivalent = keyEquivalent
            self.state = state
            self.isEnabled = isEnabled
            self.indentationLevel = indentationLevel
        }
    }

    /// Builds the standardised menu:
    /// About {appName} → [separator] → {actions} → [separator] → Settings… → [separator] → Quit
    static func buildMenu(
        appName: String,
        aboutAction: Selector,
        settingsAction: Selector,
        target: AnyObject,
        actions: [ActionItem] = []
    ) -> NSMenu {
        let menu = NSMenu()

        // About
        let aboutItem = NSMenuItem(title: "About \(appName)", action: aboutAction, keyEquivalent: "")
        aboutItem.target = target
        menu.addItem(aboutItem)

        // App actions (if any)
        if !actions.isEmpty {
            menu.addItem(.separator())
            for action in actions {
                if action.title == "-" {
                    menu.addItem(.separator())
                } else {
                    let item = NSMenuItem(title: action.title, action: action.isEnabled ? action.action : nil, keyEquivalent: action.keyEquivalent)
                    item.target = action.isEnabled ? action.target : nil
                    item.isEnabled = action.isEnabled
                    item.indentationLevel = action.indentationLevel
                    if let state = action.state {
                        item.state = state
                    }
                    if let attr = action.attributedTitle {
                        item.attributedTitle = attr
                    }
                    menu.addItem(item)
                }
            }
        }

        // Settings
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: settingsAction, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)

        // Quit
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

        return menu
    }
}
