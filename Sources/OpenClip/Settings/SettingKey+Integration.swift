// SettingKey+Integration.swift
// OpenClip
//
// Settings that govern the inbound URL-scheme integration (control panels such as Droppy). Both
// default off: enabling the scheme is an explicit opt-in, and the first request after enabling
// asks for approval before any setting is read or written.
import Core

extension SettingKey where Value == Bool {
    /// Whether `openclip://settings`, `openclip://set`, and `openclip://command` are honoured.
    static var integrationSettingsURISchemeEnabled: SettingKey<Bool> {
        SettingKey<Bool>("integration.settingsURISchemeEnabled", defaultValue: false)
    }

    /// Set once the user has approved the first request after enabling the scheme; avoids a prompt
    /// on every run. Cleared when the scheme is switched off so re-enabling asks again.
    static var integrationSettingsURISchemeApproved: SettingKey<Bool> {
        SettingKey<Bool>("integration.settingsURISchemeApproved", defaultValue: false)
    }
}
