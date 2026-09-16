# OpenClip Changelog

All notable user-facing changes, feature additions, and improvements to OpenClip are documented here.

---

## v1.6.1 - 2026-09-16

### Features & Improvements
- **Apple Intelligence availability**: Preferences › AI now reports whether Apple Intelligence is available, unsupported, switched off, or still downloading, and how to fix it.
- **More reliable Apple Intelligence answers**: guided generation replaces scraping XML tags from free-form output.
- **Inline results in sub-action bars**: group sub-actions show computed text in place of their icon, matching the main bar.
- **Dependency update**: OpenSelection 0.1.2.

### Fixes & Stability
- **Overlay-safe selection reads**: the automatic path no longer posts a synthetic ⌘C while a foreign overlay (e.g. a screenshot tool) owns the key window; the explicit hotkey path still reads.
- **Result card stays on screen**: the popup re-clamps itself as the card resizes.
- **Empty-state hint**: custom actions now point to Actions for placing actions in the popup bar.

---

## v1.6.0 - 2026-09-14

### First signed & notarized release
- **First genuinely signed, hardened, and notarized release.** v1.5.0 announced this, but the work landed after the tag, so every earlier build was ad-hoc signed and could not be notarized.
- **Upgrading from an ad-hoc build needs Accessibility re-granted one last time** (and any Input Monitoring or Screen Recording grant); Developer ID signing makes the permission survive future updates.
- **Fresh installs** open without a Gatekeeper warning or quarantine workaround; the app runs hardened with a single entitlement (Apple events), and both app and disk image are signed, notarized, and stapled.

### Highlights
- **Settings rebuilt like System Settings**: one router, a searchable sidebar, and a page for every extension, built-in action, and custom action.
- **Ask AI from the palette**: a query matching no action offers **Ask AI: “…”** and **Save as AI tool**; ⏎ shows the answer with a diff, ⇧⏎ replaces the selection in place.
- **Refine answers in the result card**: an inline follow-up re-runs AI, keeps the previous answer visible, and diffs against your original selection.
- **AI engines**: local CLIs and universal local models with intelligent model resolution, plus standalone Ask AI and Apply to Selection.
- **Duplication, pinning, and a sortable Store** with real publish dates.

### Features & Improvements
- **Settings**: sidebar filtering and back/forward; a hero page per extension with per-command switches and settings; drag-to-group Customize; one consistent row shape; extension-derived sidebar colours; pages instead of popovers, sheets, or alerts.
- **Store**: sort by Featured / Name / Downloads / Recently Added, publish dates, offline and update states, no-cache Refresh, and **Install from File…**.
- **AI**: Ask AI and Save as AI tool in the palette; inline result-card refinement with session context; CLI tools and universal local models with automatic Ollama migration; standalone Ask AI and Apply to Selection; clearer AI row names.
- **Result card and actions**: duplicate extensions and custom actions; pin button; Copy/Paste hidden while streaming; frozen size during refinement; selection engine extracted into OpenSelection 0.1.1.

### Security & Distribution
- **Inside-out signing and notarization**: packaging no longer runs `codesign --deep`; the app is signed deepest-first, notarized, and stapled, the DMG likewise, and the pipeline verifies both zip and image and fails on a non-distributable artifact.

### Fixes & Stability
- Single-command extension pages render correctly; the hero scrolls with the page; title-bar hairline and overlapping footer buttons removed.
- Sidebar search has its own strip; the page switch no longer stretches; the Store sort control moved into the page.
- Follow-up keeps focus so Esc cancels, refinement never re-opens a dismissed card, and Store offline/refresh/update states are handled.

### Contributors
- **Matej Bačo ([@Meldiron](https://github.com/Meldiron))** — Developer ID signing, hardened runtime, and notarization; palette Ask AI; in-place result-card refinement; and the unified Settings window.
- **Ganesh M ([@ganeshmshetty](https://github.com/ganeshmshetty))** — AI CLI tools, universal local models, and model resolution; inline extension results.
- **JTOBIN ([@binjto-boop](https://github.com/binjto-boop))** — rebuilding the preferences window on stock AppKit controls.

### Fixes & Stability
- **Log File Timestamps**: The rotating log file sink now formats timestamps on its own serial queue instead of on the thread that emitted the log, so its `DateFormatter` is never shared across threads ([#45](https://github.com/ganeshmshetty/openclip/issues/45)).

---

## v1.5.0 - 2026-09-10

### Highlights
- **Resizable Result Cards & Search Palette**: Action output cards, AI streaming responses, and the action search palette can now be resized by dragging edges or corner handles, remembering your preferred maximum size without blowing up short responses ([#78](https://github.com/ganeshmshetty/openclip/pull/78)).
- **Per-Action Global Hotkeys & Search Aliases**: Trigger favorite actions instantly with dedicated global keyboard shortcuts, or assign custom search aliases for rapid invocation in the palette.
- **Extension Group & Sub-Action Reordering**: Fully customize your action workflow by reordering extension groups and individual member actions via drag-and-drop in Preferences, complete with custom member icon overrides ([#68](https://github.com/ganeshmshetty/openclip/issues/68)).
- **Universal Binaries (Apple Silicon & Intel Macs)**: Universal binary distribution restored with multi-stage verification across release archives and DMGs, ensuring OpenClip runs natively on both Intel and Apple Silicon Macs ([#72](https://github.com/ganeshmshetty/openclip/pull/72)).
- **In-App Updater Release Notes Delivery**: Fixed an issue where update changelogs failed to appear during updates by upgrading the release pipeline to Sparkle 2.9, providing native markdown release notes directly in the update window.
- **Redesigned DMG Installer**: Beautiful new branded installer window with Retina-sharp HTML-rendered backgrounds, guided drop indicators, and scroll-free layout built via `dmgbuild` ([#67](https://github.com/ganeshmshetty/openclip/pull/67)).

### Features & Improvements
- **Resizable Result Card and Search Palette**: The result card that shows an action's output (including before/after diffs and AI responses) and the action-search palette can now be resized by dragging their right edge, bottom edge, or the bottom-right corner grip. Resized dimensions are remembered as an intelligent maximum constraint: short answers stay compact, while longer text expands up to your preferred dimensions ([#78](https://github.com/ganeshmshetty/openclip/pull/78) by [@Meldiron](https://github.com/Meldiron)).
- **Per-Action Global Hotkeys and Search Aliases**: Assign direct system-wide keyboard shortcuts and custom keyword aliases to any individual action, allowing you to trigger actions anywhere without opening the floating menu.
- **Extension Group & Member Reordering**: Multi-action extension groups and member actions can now be rearranged via drag-and-drop within Preferences › Actions. Sub-action ordering is persisted cleanly in `extensionGroupMemberOrder`, and individual member actions can be customized with custom icons in the group editor sheet ([#68](https://github.com/ganeshmshetty/openclip/issues/68)).
- **Custom Icon Importing**: Import custom icon assets (SF Symbols, custom SVG/PNG images) to personalize action buttons and extension groups in Preferences.
- **Per-Command Extension Settings**: Commands inside a multi-command extension now display the settings cog in Preferences › Actions whenever options are declared, enabling inline configuration of API keys, endpoints, and parameters ([#79](https://github.com/ganeshmshetty/openclip/pull/79) by [@Meldiron](https://github.com/Meldiron)).
- **Redesigned DMG Installer**: The disk image now opens with a styled installation window aligned with `getopenclip.app` design tokens, featuring a Retina 1×/2× TIFF background, branded icon placements, and clean zero-scroll geometry ([#67](https://github.com/ganeshmshetty/openclip/pull/67) by [@Meldiron](https://github.com/Meldiron)).
- **Synchronous Palette Resolution & Prewarming**: Hotkey invocation now resolves the search palette synchronously while prewarming selection context in the background, eliminating trigger latency.
- **Extension Store Catalog Refresh**: Added a dedicated Refresh button to Preferences › Store header to bypass cached catalog entries and fetch updates immediately, paired with single-line description formatting.
- **Visual Palette & Toast Polish**: Styled search palette with neutral selection highlights and capped floating toast notifications to 40 characters for compact readability.

### Security & Distribution
- **Signed, Hardened & Notarized Builds**: OpenClip is now signed with an Apple Developer ID certificate, built with the hardened runtime genuinely enabled, and notarized and stapled by Apple — the app and the disk image both. macOS opens it without a Gatekeeper warning, and nothing has to strip a quarantine attribute to make it launch. Every previous release was ad-hoc signed: the packaging step finished with `codesign --deep`, which replaced Xcode's hardened signature with an unhardened ad-hoc one, so the app could not be notarized and Gatekeeper refused it on every Mac but the one that built it.
- **Accessibility Permission Survives Updates**: An ad-hoc signature identifies an app by a hash that changes with every build, so macOS treated each update as a brand-new application and dropped the Accessibility grant. A Developer ID signature identifies it by bundle ID and team instead, so the permission now persists across updates. Upgrading to this version needs the Accessibility toggle re-granted one last time.
- **Minimal Entitlements**: The hardened runtime is granted exactly one exception, for the Apple events that AppleScript actions send. JIT, library-validation, and dynamic-linker exceptions are all withheld, and the release scripts fail if a build's entitlements ever differ from the file that declares them. Building from source still needs no Apple Developer account: local builds are ad-hoc signed with the same hardening and entitlements.

### Fixes & Stability
- **Log File Timestamps**: The rotating log file sink now formats timestamps on its own serial queue instead of on the thread that emitted the log, so its `DateFormatter` is never shared across threads ([#45](https://github.com/ganeshmshetty/openclip/issues/45)).

---

## v1.5.0 - 2026-09-10

### Highlights
- **Resizable result cards and search palette**, remembered as an intelligent maximum size.
- **Per-action global hotkeys and search aliases.**
- **Extension group and member reordering** with custom member icons.
- **Universal binaries** for Apple Silicon and Intel Macs.
- **Redesigned DMG installer** and in-app updater release notes via Sparkle 2.9.

### Features & Improvements
- **Result card and palette resizing** from any edge or corner grip.
- **Per-action hotkeys and aliases** to run actions without the floating bar.
- **Extension reordering** (persisted in `extensionGroupMemberOrder`) and custom icons.
- **Per-command extension settings** for API keys, endpoints, and parameters.
- **Faster palette**: synchronous resolution with background prewarming.
- **Store refresh** and palette/toast polish.

### Security & Distribution
- **Signed, hardened, and notarized builds**; Accessibility survives updates; minimal entitlements (Apple events only); Sigstore build provenance.

### Fixes & Stability
- Updater release notes render; universal binaries restored and verified.
- Script output buffer draining and JavaScript fetch lifetime fixes.
- Extension module containment hardened against symlink traversal.
- Focus race and empty-selection toast; hold gestures and wide I-beam detection.

### Contributors
- **Matej Bačo ([@Meldiron](https://github.com/Meldiron))** — resizable cards and palette, per-command extension settings, DMG installer, universal binaries, build provenance.
- **Md ([@md786-dotcom](https://github.com/md786-dotcom))** — pipe buffer draining, fetch lifetime safety, extension containment.
- **Ganesh M ([@ganeshmshetty](https://github.com/ganeshmshetty))** — per-action hotkeys and aliases, extension reordering, custom icons, palette prewarming, selection fixes, store refresh.

---

## v1.4.0 - 2026-09-07

### Highlights
- **Visual before-and-after text diffs** in result cards.
- **Screen-space floating tooltips** that never clip.
- **Palette row keyboard shortcuts** (⌘1–⌘9 and alphanumeric).
- **Preferences and action-configuration fixes**, including editor persistence and Dock restore.
- **Process lifecycle cleanup** that kills descendant process trees.
- **Hardened AI presets** against prompt injection.

### Features & Improvements
- **Diff engine** (`TextDiff.swift`): word- and line-level deltas, with inline and side-by-side views in the result card.
- **Tooltips**: independent overlay panel and boundary-aware placement.
- **Preferences**: action editor stays open during navigation; minimized Settings windows reuse correctly; extension and custom groups separated; glyph icon state fixed.
- **Runtime**: watchdog terminates descendant process trees; subtree traversal optimized; `dev_run.sh` launches the fresh binary.
- **AI**: prompt-injection boundary, polished default presets, updated localizations.

### Fixes & Stability
- Paste probe starvation recovery with aggregate deadlines.
- Zero idle CPU during toast dismissals.
- Selection permit released when `Edit ▸ Copy` is blocked.
- Hermetic, fully isolated test suite.

### Contributors
- **Matej Bačo ([@Meldiron](https://github.com/Meldiron))** — action editor persistence; `dev_run.sh` improvements.
- **Jtobin ([@binjto-boop](https://github.com/binjto-boop))** — Settings window Dock restore.
- **Md ([@md786-dotcom](https://github.com/md786-dotcom))** — descendant process termination; paste probe recovery.
- **Ganesh M ([@ganeshmshetty](https://github.com/ganeshmshetty))** — diff engine, tooltips, AI hardening, test refactor.

---

## v1.3.1 - 2026-09-05

### Features & Improvements
- **Direct action search** via shortcut, centered and focused, dismissed with `Escape`.
- **Search alignment clamping** within the bar and screen.
- **Layered glass contrast** with an adaptive backing scrim and specular borders.
- **Preferences label updates**: "Horizontal Position" and "Popup Width".

### Fixes & Stability
- **Extension Store resilience**: network retries, loading states, and offline diagnostics.

---

## v1.3.0 - 2026-09-04

### Highlights
- **`openclip.pasteboard` JavaScript API** for reading, inspecting, and writing clipboard content.
- **Customizable popup alignment and vertical position**, with synchronized sub-action bars.
- **Full multilingual localization**: Traditional Chinese, French, and Japanese, plus multilingual search keywords.
- **Storefront and Actions overhaul**: category tabs, pagination, and a zebra-striped outline with drag-and-drop.
- **Snooze and per-app pause** from the status bar menu.

### Fixes & Stability
- Extension security: blocked path traversal and unauthorized script execution.
- Clipboard preservation for lazy pasteboard items.
- App-switch paste races; secret-staging permission race.
- Release notes in update prompts; settings preserved across updates.

### Community
- Join our [Discord community](https://discord.gg/sy4MeFxf8).

---

## v1.2.1 - 2026-09-02

### Features & Improvements
- **Context-aware web search** opens in the active browser.
- **Bar width slider** and dynamic page packing.
- **CLI flags** `--version`/`-v` and `--help`/`-h`.
- **Extension icon validation** in `validate_extension.sh`.

### Fixes & Stability
- Action group persistence across extension updates.
- Toast centered over the closed popup frame.
- Extension update failures logged and surfaced.
- Calendar `.ics` cleanup; safe `SettingsStore.get`; docs synced with Swift 6.

### Contributors
- **[@ayangweb](https://github.com/ayangweb)** — [#26](https://github.com/ganeshmshetty/openclip/pull/26), [#27](https://github.com/ganeshmshetty/openclip/pull/27), [#28](https://github.com/ganeshmshetty/openclip/pull/28), [#29](https://github.com/ganeshmshetty/openclip/pull/29), [#30](https://github.com/ganeshmshetty/openclip/pull/30), [#31](https://github.com/ganeshmshetty/openclip/pull/31), [#32](https://github.com/ganeshmshetty/openclip/pull/32)

---

## v1.2.0 - 2026-09-01

### Features & Improvements
- **Custom action groups and sub-action bar** with hovering sub-bar and scoped search.
- **Simplified Chinese localization.**
- **Search engine presets** (Google, DuckDuckGo, Kagi, Brave, Bing, Ecosia, Custom).
- **Sparkle 2 in-app updates** with background checks and release notes.
- **AI loading toast**, scaled toasts, and a menu bar icon toggle.

### Fixes & Stability
- Popup edge cursor stickiness and sub-bar hit-testing.
- AI session state across loading-toast transitions.
- Empty action groups can be created and configured.

### Contributors
- **[@ayangweb](https://github.com/ayangweb)** — [#5](https://github.com/ganeshmshetty/openclip/pull/5), [#12](https://github.com/ganeshmshetty/openclip/pull/12), [#13](https://github.com/ganeshmshetty/openclip/pull/13)
- **[@cauton2020](https://github.com/cauton2020)** — [#3](https://github.com/ganeshmshetty/openclip/pull/3)

---

## v1.1.1 - 2026-08-28

### Features & Improvements
- **Launch classification and permission recovery** for fresh installs, updates, and missing Accessibility.
- **Onboarding redesign**: 4-step wizard with recommended extensions and a live sandbox preview.
- **Reactive extension store** with instant install and remove.

### Fixes & Stability
- Reliable action reordering; correct "Copied" toast; simplified Homebrew install docs.

---

## v1.1.0 - 2026-08-26

### Features & Improvements
- **Anchored action configuration** popover with hero icon headers.
- **Unified result cards and live previews** across actions and AI tools.
- **Curated onboarding** with store recommendations.
- **Shared extension-store cache**, refined App Rules, and post-onboarding coach marks.

### Fixes & Stability
- Reliable cursor and selection detection via `NSCursor.currentSystem`.
- Clipboard fallback gated on I-beam cursors and paste probes.
- Popup shadow clicks fall through; toasts anchor cleanly.
- Catalog fixes across 25 extensions; validator accepts payload-free service actions.

---

## v1.0.1 - 2026-08-22

### Features & Improvements
- **Rich text**: capture and paste HTML/RTF with styles, headings, and links.
- **Mouse-hold trigger** with a configurable hold timer.
- **Expanded calendar providers**; normalized popup sizing across all 5 scale levels.

### Fixes & Stability
- No unexpected trust warnings while editing local extensions.
- Instant selection capture in Safari and Chromium browsers.

---

## v1.0.0 - 2026-08-21

The initial major release — a native floating action bar that turns selected text into instant actions.

### Highlights
- **Floating action bar**: contextual trigger, adaptive positioning, three themes (Glass, Dark, Light), hover feedback, and clipboard fallback.
- **Built-in actions**: web search, inline calculator, dictionary, word completion, text transformations, and macOS Services/Share.
- **Search palette**: global **Option+Command+C** shortcut with recent-action ranking.
- **AI assistants**: Apple Intelligence, Ollama, OpenAI, or Anthropic, with streaming result cards and one-click insert/replace.
- **Extensions**: in-app store, no-code custom actions, a 9,000+ icon library, and JavaScript / AppleScript / Shell / URL / Shortcuts runtimes.
- **Customization and privacy**: per-app rules, action reordering, 100% local operation, Keychain storage, subprocess isolation, and start at login.
