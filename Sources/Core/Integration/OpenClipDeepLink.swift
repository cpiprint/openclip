// OpenClipDeepLink.swift
// OpenClip
//
// The inbound `openclip://` URL grammar, parsed into a typed value. This is the write/read side of
// the droplet contract third-party control panels (Droppy) use to mirror and drive OpenClip.
//
// The parser is pure and lives in Core so the grammar is testable without the app: the router that
// gates, asks for consent, and performs the side effects stays in the app target.
//
// Routes (host-based, matching the existing `openclip://install`):
//
//   openclip://install?id=<id>&url=<https-url>[&name=<name>]   install a store extension
//   openclip://settings[?callback=<url>]                       read the integration settings
//   openclip://set?<key>=<value>[&<key>=<value>...][&callback=<url>]  write settings
//   openclip://command/<name>[?callback=<url>]                 run an app-level command
//
// `<value>` may be any JSON fragment (`true`, `3`, `"glass"`); a bare token that is not valid JSON
// (`glass`) is treated as a JSON string. Reads and write replies are delivered by opening
// `callback` with a `result=<urlencoded json>` query item (the x-callback-url pattern), so the
// grammar does not assume any one transport beyond a URL the caller controls.
import Foundation

/// An app-level verb the integration can invoke. These are the things that are not expressible as a
/// single settings write; enabling/disabling and pausing are settings writes and do not need one.
public enum IntegrationCommand: String, CaseIterable, Sendable, Equatable {
    /// Bring OpenClip's Settings window to the front.
    case openSettings = "open-settings"
    /// Temporarily pause the popup (the same pause the menu bar offers).
    case pause
    /// Clear a temporary pause.
    case resume
    /// Restore the popup appearance settings to their defaults.
    case resetAppearance = "reset-appearance"
}

/// A parsed `openclip://` URL.
public enum OpenClipDeepLink: Equatable, Sendable {
    case install(id: String, name: String?, downloadURL: URL)
    case readSettings(callback: URL?)
    case writeSettings(values: [String: String], callback: URL?)
    case command(IntegrationCommand, callback: URL?)

    public static let scheme = "openclip"
    /// Canonical reply query item. `x-success` is accepted as an alias so callers using the
    /// x-callback-url spelling work without changes.
    public static let callbackQueryItem = "callback"
    public static let callbackAliasQueryItem = "x-success"

    /// Query item carrying the JSON reply on the callback URL.
    public static let resultQueryItem = "result"
    /// Query item carrying a failure message on the callback URL.
    public static let errorQueryItem = "error"

    /// Parses `url`, or returns `nil` when the scheme, host, or required parameters are missing.
    public static func parse(_ url: URL) -> OpenClipDeepLink? {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = components.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        let callback = sanitizedCallback(value(callbackQueryItem) ?? value(callbackAliasQueryItem))

        switch components.host?.lowercased() {
        case "install":
            guard let id = value("id"), !id.isEmpty,
                  let rawURL = value("url"), let downloadURL = URL(string: rawURL) else {
                return nil
            }
            return .install(id: id, name: value("name"), downloadURL: downloadURL)

        case "settings":
            return .readSettings(callback: callback)

        case "set":
            var values: [String: String] = [:]
            for item in items {
                guard let itemValue = item.value,
                      !item.name.isEmpty,
                      item.name.caseInsensitiveCompare(callbackQueryItem) != .orderedSame,
                      item.name.caseInsensitiveCompare(callbackAliasQueryItem) != .orderedSame else {
                    continue
                }
                values[item.name] = itemValue
            }
            guard !values.isEmpty else { return nil }
            return .writeSettings(values: values, callback: callback)

        case "command":
            let raw = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let command = IntegrationCommand(rawValue: raw.lowercased()) else { return nil }
            return .command(command, callback: callback)

        default:
            return nil
        }
    }

    /// Accepts a caller-supplied callback only when it is a non-web custom scheme. A `callback`
    /// that points at `http(s)` would turn the read route into a way for any page to exfiltrate the
    /// settings, and `file`/`javascript` are never a legitimate reply target.
    public static func sanitizedCallback(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty,
              let url = URL(string: raw),
              let callbackScheme = url.scheme?.lowercased(), !callbackScheme.isEmpty else {
            return nil
        }
        let denied: Set<String> = [
            "http", "https", "file", "javascript", "data", "about", "blob", "ws", "wss", "ftp"
        ]
        guard !denied.contains(callbackScheme) else { return nil }
        return url
    }
}

/// Builds the URL the router opens to answer a caller that supplied a callback.
public enum OpenClipDeepLinkReply {
    /// `callback?result=<json>`.
    public static func success(callback: URL, payload: [String: Any]) -> URL? {
        reply(callback: callback, key: OpenClipDeepLink.resultQueryItem, valueJSON: json(payload))
    }

    /// `callback?error=<message>`.
    public static func failure(callback: URL, message: String) -> URL? {
        reply(callback: callback, key: OpenClipDeepLink.errorQueryItem, valueJSON: json(["message": message]))
    }

    private static func reply(callback: URL, key: String, valueJSON: String) -> URL? {
        guard var components = URLComponents(url: callback, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: key, value: valueJSON))
        components.queryItems = items
        return components.url
    }

    private static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
