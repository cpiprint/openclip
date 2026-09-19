import XCTest
@testable import Core
@testable import OpenClip

final class IntegrationSettingsBridgeTests: XCTestCase {
    private var store: MemorySettingsStore!

    override func setUp() {
        super.setUp()
        store = MemorySettingsStore()
    }

    private var keys: [AnySettingKey] {
        [
            SettingKey.popupTheme.erased,
            SettingKey.popupScale.erased,
            SettingKey.isAppEnabled.erased
        ]
    }

    func testWriteNormalizesBareTokensAndJSONFragments() {
        let result = IntegrationSettingsBridge.write(
            values: ["popupTheme": "glass", "popupScale": "3", "isAppEnabled": "false"],
            keys: keys,
            store: store
        )
        XCTAssertEqual(result.applied, 3)
        XCTAssertTrue(result.skipped.isEmpty)

        XCTAssertEqual(store.get(.popupTheme), "glass")
        XCTAssertEqual(store.get(.popupScale), 3)
        XCTAssertEqual(store.get(.isAppEnabled), false)
    }

    func testQuotedJSONStringIsAccepted() {
        let result = IntegrationSettingsBridge.write(
            values: ["popupTheme": "\"glass\""],
            keys: keys,
            store: store
        )
        XCTAssertEqual(result.applied, 1)
        XCTAssertEqual(store.get(.popupTheme), "glass")
    }

    func testReadUnwrapsBoxIntoPlainValues() {
        store.set(.popupTheme, value: "glass")
        store.set(.popupScale, value: 4)
        store.set(.isAppEnabled, value: true)

        let read = IntegrationSettingsBridge.read(keys: keys, store: store)
        XCTAssertEqual(read["popupTheme"] as? String, "glass")
        XCTAssertEqual(read["popupScale"] as? Int, 4)
        XCTAssertEqual(read["isAppEnabled"] as? Bool, true)
    }

    func testUnknownKeyIsSkipped() {
        let result = IntegrationSettingsBridge.write(
            values: ["notASetting": "1", "popupTheme": "glass"],
            keys: keys,
            store: store
        )
        XCTAssertEqual(result.applied, 1)
        XCTAssertEqual(result.skipped, ["notASetting"])
        XCTAssertEqual(store.get(.popupTheme), "glass")
    }

    func testTypeMismatchIsSkipped() {
        let result = IntegrationSettingsBridge.write(
            values: ["isAppEnabled": "notabool"],
            keys: keys,
            store: store
        )
        XCTAssertEqual(result.applied, 0)
        XCTAssertEqual(result.skipped, ["isAppEnabled"])
        // Untouched: the default survives a rejected write.
        XCTAssertEqual(store.get(.isAppEnabled), true)
    }

    func testRoundTripReadAfterWrite() {
        _ = IntegrationSettingsBridge.write(
            values: ["popupTheme": "classic", "popupScale": "5"],
            keys: keys,
            store: store
        )
        let read = IntegrationSettingsBridge.read(keys: keys, store: store)
        XCTAssertEqual(read["popupTheme"] as? String, "classic")
        XCTAssertEqual(read["popupScale"] as? Int, 5)
    }
}
