// SettingsBridge.swift
// OpenClip
//
// The curated read/write surface behind the integration URL scheme. It rides the same erased
// catalog keys the settings snapshot uses (`AnySettingKey`), so the allowed keys are explicit and
// the value format is the one backup/restore already round-trips.
//
// Two conversions happen here:
//   * Erased keys read and write a `{"value": <json>}` box (`AnySettingKey`), but the wire format
//     the integration exchanges is the bare value (`{"popupTheme": "glass"}`). `read` unwraps and
//     `write` wraps.
//   * A query item value may be a JSON fragment (`true`, `3`, `"glass"`) or a bare token
//     (`glass`). `normalizedJSONValue` keeps the fragment and JSON-encodes the bare token.
//
// Only the keys handed in are touched, so adding a setting to the integration is a one-line
// change to the caller's list, never a change here.
import Foundation

public enum IntegrationSettingsBridge {
    /// The current value of every readable key, as plain JSON values keyed by setting name.
    public static func read(keys: [AnySettingKey], store: SettingsStore) -> [String: Any] {
        var result: [String: Any] = [:]
        for key in keys {
            guard let boxJSON = key.readJSON(from: store) else { continue }
            result[key.name] = plainValue(fromBoxJSON: boxJSON) ?? NSNull()
        }
        return result
    }

    /// Writes the given `name -> raw value` pairs, ignoring any name not in `keys`. Returns how
    /// many were applied and which were skipped (unknown name, or a value that did not decode to
    /// the key's type).
    @discardableResult
    public static func write(
        values: [String: String],
        keys: [AnySettingKey],
        store: SettingsStore
    ) -> SettingsApplyResult {
        var keysByName: [String: AnySettingKey] = [:]
        for key in keys { keysByName[key.name] = key }

        var applied = 0
        var skipped: [String] = []
        for (name, raw) in values.sorted(by: { $0.key < $1.key }) {
            guard let key = keysByName[name] else {
                skipped.append(name)
                continue
            }
            let boxJSON = boxJSON(fromPlainJSON: normalizedJSONValue(raw))
            if key.writeJSON(boxJSON, to: store) {
                applied += 1
            } else {
                skipped.append(name)
            }
        }
        return SettingsApplyResult(applied: applied, skipped: skipped)
    }

    /// A raw query value kept as-is when it is a JSON fragment, otherwise JSON-encoded as a string.
    public static func normalizedJSONValue(_ raw: String) -> String {
        if let data = raw.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
            return raw
        }
        guard let data = try? JSONEncoder().encode(raw),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return encoded
    }

    /// Unwraps `{"value": <json>}` into the bare value. `nil` only when the box itself is unreadable.
    public static func plainValue(fromBoxJSON json: String) -> Any? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let box = object as? [String: Any] else {
            return nil
        }
        return box["value"] ?? NSNull()
    }

    /// Wraps a bare JSON value so the erased key can decode it.
    public static func boxJSON(fromPlainJSON json: String) -> String {
        "{\"value\":\(json)}"
    }
}
