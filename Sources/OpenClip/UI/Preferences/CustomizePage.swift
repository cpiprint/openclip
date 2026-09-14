// CustomizePage.swift
// OpenClip
//
// The Customize page: the popup bar's layout, action enablement, palette aliases, and hotkeys.
// One reorderable outline of everything the bar shows — drag to change the order, drag onto a group
// to add to it, select several rows and make a group of them. Each row also hosts an enable toggle,
// alias text field, and hotkey recorder.

import SwiftUI
import UniformTypeIdentifiers
import Core
import KeyboardShortcuts

@MainActor
struct CustomizePage: View {
    @Binding var selectedRowIDs: Set<String>
    @Binding var disabledActionIDs: Set<String>
    @Binding var disabledPackages: Set<String>

    @ObservedObject private var coordinator = ActionCoordinator.shared
    @ObservedObject private var customizationManager = ActionCustomizationManager.shared

    @State private var query = ""
    @State private var aliasError: String?
    @State private var isShowingHelp = false

    init(
        selectedRowIDs: Binding<Set<String>>,
        disabledActionIDs: Binding<Set<String>>,
        disabledPackages: Binding<Set<String>>
    ) {
        _selectedRowIDs = selectedRowIDs
        _disabledActionIDs = disabledActionIDs
        _disabledPackages = disabledPackages
    }

    /// Eligible candidate action IDs for custom grouping. Only top-level standalone actions
    /// (not AI presets, not AI launcher, not group parents, not extension sub-actions,
    /// and not existing custom group members) can be selected for a new group.
    static func groupCandidates(selectedRowIDs: Set<String>, coordinator: ActionCoordinator) -> [String] {
        let customGroupMemberIDs = Set(coordinator.actionGroupDefs.flatMap(\.memberActionIDs))

        return coordinator.actions.compactMap { action in
            guard selectedRowIDs.contains(action.id) else { return nil }
            guard coordinator.isEligibleForGrouping(actionID: action.id) else { return nil }
            if customGroupMemberIDs.contains(action.id) { return nil }
            return action.id
        }
    }

    private var hasNoMatches: Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return false }
        let matchingActions = coordinator.actions.contains { action in
            if customizationManager.presented(action, surface: .table).title.lowercased().contains(needle) { return true }
            if (ActionBindingStore.shared.alias(for: action.id) ?? "").lowercased().contains(needle) { return true }
            return action.keywords.contains { $0.lowercased().contains(needle) }
        }
        if matchingActions { return false }
        let matchingGroups = coordinator.actionGroupDefs.contains { $0.title.lowercased().contains(needle) }
        return !matchingGroups
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            ZStack {
                ActionsOutlineView(
                    coordinator: coordinator,
                    customizationManager: customizationManager,
                    searchQuery: query,
                    disabledActionIDs: $disabledActionIDs,
                    disabledPackages: $disabledPackages,
                    selectedRowIDs: $selectedRowIDs,
                    onAliasMessage: { message in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            aliasError = message
                        }
                    },
                    onEditGroup: { groupID in
                        SettingsRouter.shared.push(.action(id: groupID))
                    },
                    onCreateGroupFromSelection: {
                        SettingsRouter.shared.push(.newGroup(
                            memberIDs: Self.groupCandidates(selectedRowIDs: selectedRowIDs, coordinator: coordinator)
                        ))
                    },
                    onOpenNode: { node in
                        switch node.kind {
                        case .packageHeader(let packageID, _, _):
                            SettingsRouter.shared.show(path: SettingsDestination.path(forPackage: packageID))
                        default:
                            if let action = node.action {
                                SettingsDestination.open(action)
                            }
                        }
                    }
                )

                if hasNoMatches {
                    ContentUnavailableView.search(text: query)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            helpButton
        }
    }

    /// The page's instructions, behind the floating help button the pane keeps in its corner —
    /// the same affordance System Settings uses, so the list itself stays uncluttered.
    private var helpButton: some View {
        Button {
            isShowingHelp.toggle()
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.quaternary))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "About the Actions list"))
        .accessibilityLabel(String(localized: "About the Actions list"))
        .padding(16)
        .popover(isPresented: $isShowingHelp, arrowEdge: .bottom) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Text("Drag to reorder the popup bar or group actions. Turn off an action to hide it. An alias or hotkey triggers an action anywhere.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 300, alignment: .leading)
            .padding(16)
        }
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            NativeSearchField(
                text: $query,
                placeholder: String(localized: "Search actions, shortcuts, or aliases"),
                controlSize: .regular
            )
            .frame(height: 24)

            if let aliasError {
                SettingsInlineError(message: aliasError)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

// MARK: - Rows

/// One action in the Customize list: icon, title, alias, hotkey recorder, enable toggle, and delete.
@MainActor
struct ActionRowView: View {
    let action: any Action
    let presentationModel: ActionPresentationModel
    @Binding var disabledActionIDs: Set<String>
    @Binding var disabledPackages: Set<String>
    var onAliasMessage: (String?) -> Void

    @ObservedObject private var coordinator = ActionCoordinator.shared
    @ObservedObject private var customizationManager = ActionCustomizationManager.shared
    @ObservedObject private var bindingStore = ActionBindingStore.shared
    @State private var aliasDraft: String?

    private static let aliasWidth: CGFloat = 88

    private var isDeletable: Bool {
        // Custom group
        if coordinator.actionGroupDefs.contains(where: { $0.id == action.id }) {
            return true
        }
        // Custom AI Preset
        if ActionIdentity.isAIPreset(action) {
            if let preset = AIServiceManager.shared.preset(forActionID: action.id) {
                return preset.id.hasPrefix("custom_")
            }
            return false
        }
        // Custom action
        if SettingsDestination.isCustomAction(action) {
            return true
        }
        // Everything else — built-ins and extensions alike — is managed from its own page's
        // toolbar menu rather than by a trash on the row.
        return false
    }

    var body: some View {
        let isEnabled = ActionEnablement.binding(
            for: action,
            disabledActionIDs: $disabledActionIDs,
            disabledPackages: $disabledPackages
        )

        HStack(alignment: .center, spacing: 10) {
            ActionIconView(icon: presentationModel.icon, size: 16)
                .frame(width: 22, height: 22, alignment: .center)
                .foregroundStyle(.secondary)

            Text(presentationModel.title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(isEnabled.wrappedValue ? .primary : .secondary)
                .lineLimit(1)

            if let gated = action as? GatedExtensionAction, let tooltip = extensionGateDescription(for: gated.reason) {
                GateInfoIcon(tooltip: tooltip)
            }

            Spacer(minLength: 8)

            if ActionIdentity.isBindable(action) {
                TextField("alias", text: aliasBinding, prompt: Text("alias"))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .labelsHidden()
                    .frame(width: Self.aliasWidth)
                    .accessibilityLabel(String(localized: "Alias for \(presentationModel.title)"))

                KeyboardShortcuts.Recorder(for: .actionHotkey(action.id))
                    .controlSize(.small)
            }

            Toggle("", isOn: isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Enable \(presentationModel.title)"))

            if isDeletable {
                Button {
                    confirmDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "Delete / Uninstall"))
            }

            Button {
                SettingsDestination.open(action)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Configure \(presentationModel.title)"))
        }
        .padding(.trailing, 10)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .id(action.id)
    }

    private func confirmDelete() {
        // 1. Custom Group
        if coordinator.actionGroupDefs.contains(where: { $0.id == action.id }) {
            SettingsRouter.shared.confirmDestructive(
                title: String(localized: "Delete?"),
                message: "",
                confirmTitle: String(localized: "Delete")
            ) {
                coordinator.ungroup(groupID: action.id)
            }
            return
        }

        // 2. Custom AI Preset
        if ActionIdentity.isAIPreset(action),
           let preset = AIServiceManager.shared.preset(forActionID: action.id) {
            SettingsRouter.shared.confirmDestructive(
                title: String(localized: "Delete?"),
                message: "",
                confirmTitle: String(localized: "Delete")
            ) {
                var list = AIServiceManager.shared.presets
                list.removeAll(where: { $0.id == preset.id })
                AIServiceManager.shared.presets = list
            }
            return
        }

        // 3. Custom Action
        if case .custom = action.chrome.source {
            SettingsRouter.shared.confirmDestructive(
                title: String(localized: "Delete?"),
                message: "",
                confirmTitle: String(localized: "Delete")
            ) {
                coordinator.deleteCustomAction(actionID: action.id)
                customizationManager.resetOverride(for: action.id)
            }
            return
        }
    }

    private var aliasBinding: Binding<String> {
        Binding(
            get: { aliasDraft ?? bindingStore.alias(for: action.id) ?? "" },
            set: { newValue in
                aliasDraft = newValue
                switch bindingStore.setAlias(newValue, for: action.id) {
                case .accepted, .cleared:
                    onAliasMessage(nil)
                case .invalid:
                    onAliasMessage(String(localized: "Aliases can only contain letters and numbers."))
                case .collision:
                    onAliasMessage(String(localized: "That alias is already used."))
                }
            }
        )
    }
}

/// The header row of a multi-action package that is not a group: label and package enable toggle.
@MainActor
struct PackageHeaderRowView: View {
    let title: String
    let packageID: String
    let gatedReason: ExtensionGateReason?
    @Binding var disabledPackages: Set<String>

    var body: some View {
        let isEnabled = ActionEnablement.packageBinding(
            packageID: packageID,
            gatedReason: gatedReason,
            disabledPackages: $disabledPackages
        )

        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22, alignment: .center)

            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.secondary)

            if let gatedReason, let tooltip = extensionGateDescription(for: gatedReason) {
                GateInfoIcon(tooltip: tooltip)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Enable \(title)"))

            Button {
                confirmUninstall()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "Uninstall Extension"))

            Color.clear
                .frame(width: 16, height: 16)
        }
        .padding(.trailing, 10)
        .padding(.vertical, 2)
    }

    private func confirmUninstall() {
        SettingsRouter.shared.confirmDestructive(
            title: String(localized: "Uninstall?"),
            message: "",
            confirmTitle: String(localized: "Uninstall")
        ) {
            Task {
                do {
                    let actionID = InstalledExtensionInfo.info(for: packageID, in: ActionCoordinator.shared.actions)?.uninstallActionID ?? packageID
                    try await ExtensionManager.shared.uninstallExtension(actionID: actionID)
                    NotificationCenter.default.post(name: .openClipExtensionsDidChange, object: nil)
                } catch {
                    SettingsRouter.shared.notifyError(
                        title: String(localized: "Remove Failed"),
                        message: String(localized: "OpenClip could not remove extension: \(error.localizedDescription)")
                    )
                }
            }
        }
    }
}

/// Why a package is gated, as a tooltip on a red dot.
private struct GateInfoIcon: View {
    let tooltip: String

    var body: some View {
        Image(systemName: "info.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.red)
            .help(tooltip)
            .accessibilityLabel(tooltip)
    }
}
