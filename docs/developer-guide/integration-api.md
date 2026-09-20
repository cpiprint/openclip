# Integration & Automation API

OpenClip exposes an inbound `openclip://` URL scheme so other apps and scripts can drive a small,
curated part of its configuration. This document is the **current-state contract**: what exists
today, exactly as implemented. It is intentionally not a roadmap — anything not listed under
"Available now" does not exist.

> **Status:** first iteration. The surface is deliberately small (power, appearance, AI on/off).
> There is no discovery endpoint and no CLI yet; see [Not available yet](#not-available-yet).

---

## Availability

The settings, command, and write routes are always available.

The `install` route is the existing extension-store flow and keeps its own source allow-list and
confirmation dialog.

---

## Routes

| URL | Purpose |
|-----|---------|
| `openclip://install?id=<id>&url=<https-url>[&name=<name>]` | Install a store extension (allow-listed + dialog) |
| `openclip://settings[?callback=<url>]` | Read the curated settings |
| `openclip://set?<key>=<value>[&…][&callback=<url>]` | Write curated settings |
| `openclip://command/<name>[?callback=<url>]` | Run an app-level command |

The scheme is `openclip` (registered in `Info.plist`). The host selects the route; matching is
case-insensitive. Routing and parsing live in `Sources/Core/Integration/OpenClipDeepLink.swift`;
the app performs the effects in `Sources/OpenClip/Platform/DeepLinkRouter.swift`.

### `openclip://install`

```
openclip://install?id=com.example.myext&name=My%20Extension&url=https%3A%2F%2Fopenclip.app%2Fmyext.zip
```

Downloads and installs a signed extension package. The download host must be on the allow-list:

```
github.com, release-assets.githubusercontent.com, objects.githubusercontent.com,
raw.githubusercontent.com, getopenclip.vercel.app, getopenclip.app,
www.getopenclip.app, openclip.app
```

A confirmation dialog is shown before installation. Malformed URLs (missing `id`/`url`) are ignored.

### `openclip://settings` (read)

Returns the current value of every curated key.

```
openclip://settings?callback=myapp%3A%2F%2Fopenclip%2Freply
```

The reply is delivered by opening the `callback` URL with an added `result` query item carrying a
JSON object keyed by setting name:

```
myapp://openclip/reply?result={"isAppEnabled":true,"popupTheme":"glass","popupScale":3,...}
```

If no callback is supplied the route still runs but has no reply target; there is currently no
other read channel.

### `openclip://set` (write)

Sets one or more curated keys in a single request.

```
openclip://set?popupTheme=glass&popupScale=3&isAppEnabled=false
```

Every query item other than `callback`/`x-success` is treated as `name=value`. The reply:

```
myapp://openclip/reply?result={"ok":true,"applied":3,"skipped":[]}
```

- `ok` — true when nothing was skipped.
- `applied` — how many writes succeeded.
- `skipped` — names that are unknown to OpenClip or whose value did not decode to the key's type.
  A skipped name is left untouched (a rejected write never clobbers the existing value).

### `openclip://command/<name>` (commands)

App-level verbs that are not a single settings write.

```
openclip://command/open-settings
openclip://command/pause
openclip://command/resume
openclip://command/reset-appearance
```

| Command | Effect |
|---------|--------|
| `open-settings` | Bring OpenClip's Settings window to the front |
| `pause` | Pause the popup for one hour (same as the menu bar's Pause) |
| `resume` | Clear a temporary pause |
| `reset-appearance` | Restore the popup appearance keys to their defaults |

Reply: `{"ok":true,"command":"<name>"}`.

---

## Value encoding

Query values may be either a JSON fragment or a bare token:

- `isAppEnabled=false` → JSON boolean `false`
- `popupScale=3` → JSON number `3`
- `popupTheme=glass` → JSON string `"glass"` (bare token, JSON-encoded for you)
- `popupTheme="glass"` → JSON string `"glass"` (already-encoded fragment, used as-is)

Rule: if the value parses as JSON (including `true`, `3`, `"x"`, arrays, objects, `null`), it is used
as-is; otherwise it is JSON-encoded as a string. On read, values come back as plain JSON, so
`popupTheme` reads as `"glass"` and `popupScale` as `3` — never wrapped.

---

## Callbacks

Reads and command/write results are returned by opening a caller-supplied URL (the
x-callback-url pattern).

- Parameter: `callback` — `x-success` is accepted as an alias.
- Reply query item: `result` (JSON).
- **Only non-web custom schemes are accepted.** `http`, `https`, `file`, `javascript`, `data`,
  `about`, `blob`, `ws`, `wss`, and `ftp` callbacks are dropped, so a web page cannot use the read
  route to collect settings. The reply is delivered with `NSWorkspace.open`.

---

## Curated settings

The allow-list is defined in `Sources/OpenClip/Settings/IntegrationSettings.swift`. Only these keys
are readable or writable; anything else is reported in `skipped`.

| Key | Type | Default | Values |
|-----|------|---------|--------|
| `isAppEnabled` | Bool | `true` | "Appear Automatically" |
| `isMouseHoldEnabled` | Bool | `true` | |
| `showMenuBarIcon` | Bool | `true` | |
| `startAtLogin` | Bool | `false` | |
| `isAIEnabled` | Bool | `true` | AI on/off only — see below |
| `popupTheme` | String | `"classic"` | `classic` \| `glass` |
| `popupThemeColor` | String | `"system"` | `system` \| `light` \| `dark` |
| `popupAlignment` | String | `"left"` | `left` \| `center` \| `right` |
| `popupVerticalPosition` | String | `"auto"` | `auto` \| `above` \| `below` |
| `popupScale` | Int | `3` | 1–5 |
| `popupBarWidth` | Int | `3` | 1–5 |

### Deliberately never exposed

- **AI provider configuration** — service, endpoint, model, and especially the API key (stored in
  `~/.openclip/secrets.json` via `SecretStore`, never UserDefaults). Only the `isAIEnabled`
  on/off switch is reachable.
- **Extension store / arbitrary installs** — only the allow-listed `install` route exists.
- **Update channel, hotkeys, Action Results, per-action enable toggles.**

---

## Change broadcast

After every successful write or command, OpenClip posts a **distributed** notification so a client
can refresh its mirror without polling:

- Name: `com.openclip.integration.settingsDidChange`
- `userInfo["keys"]`: sorted array of setting names that changed (empty for commands that changed
  none)

```swift
DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.openclip.integration.settingsDidChange"),
    object: nil, queue: .main
) { note in
    let names = note.userInfo?["keys"] as? [String] ?? []
}
```

---

## Not available yet

So this is a **settings surface**, not a general automation API. The following do **not** exist and
are candidates for a later iteration:

- **Discovery / capabilities endpoint** (`openclip://capabilities`) — a self-describing JSON schema
  of settable keys, types, and available commands, so a client can render the surface without
  hardcoding this table.
- **CLI** (`openclip get|set|capabilities`, or extending the existing `--dump-settings` /
  `--dump-logs` modes) — synchronous reads on stdout with exit codes.
- **Running actions** (`openclip://run?action=<id>&text=…`) — headless invocation of any action with
  a returned result. This is the largest missing piece and the basis for real text automation.
- **App Intents / Shortcuts integration.**
- **Per-action enable toggles and Action Results keys** (a set-membership write, not a single key).

---

## Implementation map

| Concern | Location |
|---------|----------|
| URL grammar + reply construction | `Sources/Core/Integration/OpenClipDeepLink.swift` |
| Curated read/write + value normalization | `Sources/Core/Integration/SettingsBridge.swift` |
| Dispatch, broadcast, install | `Sources/OpenClip/Platform/DeepLinkRouter.swift` |
| Allow-list + side effects | `Sources/OpenClip/Settings/IntegrationSettings.swift` |
| Entry point | `AppDelegate.application(_:open:)` → `DeepLinkRouter.shared.handle(_:)` |
| Tests | `Tests/OpenClipTests/DeepLinkTests.swift`, `IntegrationSettingsBridgeTests.swift` |
