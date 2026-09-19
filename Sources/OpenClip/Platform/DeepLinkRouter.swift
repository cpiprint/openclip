// DeepLinkRouter.swift
// OpenClip
//
// The one place that acts on an inbound `openclip://` URL. It owns the trust boundary the URL
// scheme needs — the scheme is off until the user enables it in Preferences → Integrations, and
// the first request after enabling asks for approval — then dispatches to the settings bridge, the
// app-level commands, or the extension installer.
//
// The grammar itself lives in Core (`OpenClipDeepLink`), so the app target only decides *whether*
// and *how* to act. `AppDelegate.application(_:open:)` is a one-line delegate to `handle(_:)`.
import AppKit
import Core
import Foundation

extension Notification.Name {
    /// Posted on `DistributedNotificationCenter` after an integration write or command, so a
    /// control panel can refresh its mirror without polling. `userInfo["keys"]` carries the names
    /// that changed (empty for a command that changed none).
    static let openClipIntegrationSettingsDidChange = Notification.Name("com.openclip.integration.settingsDidChange")
}

@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    private var store: SettingsStore = DefaultSettingsStore.shared
    /// Brings OpenClip's Settings window forward. Injected by `AppDelegate`, which owns the status
    /// bar controller that shows it.
    private var openPreferences: () -> Void = {}
    /// Confirms the first request after the user enables the scheme. Injectable so tests can bypass
    /// the modal.
    private var confirmFirstUse: @MainActor (String) -> Bool = DeepLinkRouter.presentConsentPrompt

    private init() {}

    func configure(
        store: SettingsStore = DefaultSettingsStore.shared,
        openPreferences: @escaping () -> Void
    ) {
        self.store = store
        self.openPreferences = openPreferences
    }

    /// Parses and performs `url`. Unknown or malformed URLs are logged and ignored.
    func handle(_ url: URL) {
        guard let link = OpenClipDeepLink.parse(url) else {
            Log.settings.notice("Ignoring unrecognised deep link")
            return
        }

        switch link {
        case .install(let id, let name, let downloadURL):
            install(id: id, name: name, downloadURL: downloadURL)

        case .readSettings(let callback):
            guard authorize(callback: callback) else { return }
            let payload = IntegrationSettingsBridge.read(keys: IntegrationSettings.curatedKeys, store: store)
            reply(callback: callback, payload: payload)

        case .writeSettings(let values, let callback):
            guard authorize(callback: callback) else { return }
            write(values: values, callback: callback)

        case .command(let command, let callback):
            guard authorize(callback: callback) else { return }
            run(command, callback: callback)
        }
    }

    // MARK: - Trust gate

    /// Refuses integration routes while the scheme is off, and asks once after it is enabled. A
    /// declined prompt turns the scheme back off, so a caller cannot keep re-asking.
    private func authorize(callback: URL?) -> Bool {
        guard store.get(.integrationSettingsURISchemeEnabled) else {
            Log.settings.notice("Refused integration request: settings control is off")
            reply(callback: callback, error: String(localized: "OpenClip's settings control is turned off."))
            return false
        }
        guard store.get(.integrationSettingsURISchemeApproved) else {
            let approved = confirmFirstUse(
                String(localized: "An app is asking to read and change OpenClip's settings. Allow it?")
            )
            guard approved else {
                store.set(.integrationSettingsURISchemeEnabled, value: false)
                Log.settings.notice("Integration request declined; settings control disabled")
                reply(callback: callback, error: String(localized: "The request was not approved."))
                return false
            }
            store.set(.integrationSettingsURISchemeApproved, value: true)
            return true
        }
        return true
    }

    // MARK: - Settings

    private func write(values: [String: String], callback: URL?) {
        let result = IntegrationSettingsBridge.write(
            values: values,
            keys: IntegrationSettings.curatedKeys,
            store: store
        )
        let writtenNames = Set(values.keys).subtracting(result.skipped)
        IntegrationSettings.postSideEffects(forWrittenNames: writtenNames, store: store)
        broadcast(names: writtenNames)
        reply(callback: callback, payload: [
            "ok": result.skipped.isEmpty,
            "applied": result.applied,
            "skipped": result.skipped
        ])
    }

    private func run(_ command: IntegrationCommand, callback: URL?) {
        switch command {
        case .openSettings:
            openPreferences()
        case .pause:
            IntegrationSettings.pause(store: store)
        case .resume:
            IntegrationSettings.resume(store: store)
        case .resetAppearance:
            IntegrationSettings.resetAppearance(store: store)
        }
        broadcast(names: [])
        reply(callback: callback, payload: ["ok": true, "command": command.rawValue])
    }

    // MARK: - Replies and broadcast

    private func reply(callback: URL?, payload: [String: Any]) {
        guard let callback, let url = OpenClipDeepLinkReply.success(callback: callback, payload: payload) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func reply(callback: URL?, error: String) {
        guard let callback, let url = OpenClipDeepLinkReply.failure(callback: callback, message: error) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func broadcast(names: Set<String>) {
        DistributedNotificationCenter.default().postNotificationName(
            .openClipIntegrationSettingsDidChange,
            object: nil,
            userInfo: ["keys": Array(names).sorted()],
            deliverImmediately: true
        )
    }

    // MARK: - Extension install (existing store deep link)

    private func install(id: String, name: String?, downloadURL: URL) {
        guard let host = downloadURL.host?.lowercased(),
              RemoteExtensionInstaller.allowedDownloadHosts.contains(host) else {
            Log.extensions.error("Refused deep-link install from a host outside the allowlist")
            return
        }

        let alert = NSAlert()
        alert.messageText = String(localized: "Install Extension?")
        alert.informativeText = String(localized: "OpenClip wants to install the extension \"\(id)\" from \(host). Extensions can run scripts when you select text. Only proceed if you trust this source.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Install"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task { @MainActor in
            do {
                ExtensionManager.shared.prepareInstall(source: "store", packageID: id)
                _ = try await RemoteExtensionInstaller.shared.installFromRemoteURL(downloadURL, extensionID: id)
                await ExtensionUpdateManager.shared.checkForUpdates()
            } catch {
                Log.extensions.error("Failed to install extension '\(id, privacy: .public)' from host \(host, privacy: .public): \(error.localizedDescription, privacy: .private)")
                let failure = NSAlert()
                failure.messageText = String(localized: "Extension Install Failed")
                failure.informativeText = String(localized: "OpenClip could not install \"\(id)\": \(error.localizedDescription)")
                failure.alertStyle = .warning
                failure.runModal()
            }
        }
    }

    /// The approval prompt for the first integration request after the scheme is enabled.
    private static func presentConsentPrompt(_ message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Allow Settings Control?")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Allow"))
        alert.addButton(withTitle: String(localized: "Don't Allow"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
