// IntegrationsTab.swift
// OpenClip
//
// The Integrations preferences tab: the opt-in switch that lets a control panel (Droppy) drive
// OpenClip over the `openclip://` scheme, and the approval state for its first request. Off by
// default — the scheme is refused entirely until this switch is on.
import SwiftUI
import Core

@MainActor
struct IntegrationsTab: View {
    @State private var isEnabled: Bool
    @State private var isApproved: Bool

    init() {
        _isEnabled = State(initialValue: DefaultSettingsStore.shared.get(.integrationSettingsURISchemeEnabled))
        _isApproved = State(initialValue: DefaultSettingsStore.shared.get(.integrationSettingsURISchemeApproved))
    }

    var body: some View {
        Form {
            Section("Automation") {
                SettingsToggleRow(
                    title: "Allow Settings Control",
                    subtitle: "Let control panels such as Droppy read and change OpenClip's settings. Turn this off to refuse every request.",
                    systemImage: "link",
                    isOn: $isEnabled
                )
                .onChange(of: isEnabled) { _, newValue in
                    DefaultSettingsStore.shared.set(.integrationSettingsURISchemeEnabled, value: newValue)
                    if newValue {
                        isApproved = DefaultSettingsStore.shared.get(.integrationSettingsURISchemeApproved)
                    } else {
                        DefaultSettingsStore.shared.set(.integrationSettingsURISchemeApproved, value: false)
                        isApproved = false
                    }
                }
            }

            Section("Approval") {
                SettingsRow(
                    title: "Last Request",
                    subtitle: approvalSubtitle,
                    systemImage: isApproved ? "checkmark.shield" : "questionmark.circle"
                ) {
                    Text(isApproved ? String(localized: "Approved") : String(localized: "Not Yet Asked"))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("This integration can read and change power and appearance settings only. AI API keys, the extension store, and hotkeys are never shared.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private var approvalSubtitle: LocalizedStringKey {
        isApproved
            ? "A control panel has been approved to read and change settings."
            : "The first request from a control panel asks for approval."
    }
}
