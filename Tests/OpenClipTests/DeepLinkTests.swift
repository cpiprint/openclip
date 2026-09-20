import XCTest
@testable import Core
@testable import OpenClip

final class DeepLinkTests: XCTestCase {

    // MARK: - Parsing

    func testParsesInstall() {
        let url = URL(string: "openclip://install?id=com.test.app&name=Test&url=https%3A%2F%2Fopenclip.app%2Ftest.zip")!
        guard case .install(let id, let name, let downloadURL)? = OpenClipDeepLink.parse(url) else {
            return XCTFail("expected an install deep link")
        }
        XCTAssertEqual(id, "com.test.app")
        XCTAssertEqual(name, "Test")
        XCTAssertEqual(downloadURL.absoluteString, "https://openclip.app/test.zip")
    }

    func testParsesReadSettingsWithCallback() {
        let url = URL(string: "openclip://settings?callback=panel%3A%2F%2Freply")!
        guard case .readSettings(let callback)? = OpenClipDeepLink.parse(url) else {
            return XCTFail("expected a read deep link")
        }
        XCTAssertEqual(callback, URL(string: "panel://reply"))
    }

    func testParsesWriteSettingsExcludingCallback() {
        let url = URL(string: "openclip://set?popupTheme=glass&popupScale=3&callback=panel%3A%2F%2Fdone")!
        guard case .writeSettings(let values, let callback)? = OpenClipDeepLink.parse(url) else {
            return XCTFail("expected a write deep link")
        }
        XCTAssertEqual(values, ["popupTheme": "glass", "popupScale": "3"])
        XCTAssertEqual(callback, URL(string: "panel://done"))
    }

    func testParsesCommand() {
        let url = URL(string: "openclip://command/open-settings")!
        guard case .command(let command, _)? = OpenClipDeepLink.parse(url) else {
            return XCTFail("expected a command deep link")
        }
        XCTAssertEqual(command, .openSettings)
    }

    func testAcceptsXSuccessCallbackAlias() {
        let url = URL(string: "openclip://settings?x-success=panel%3A%2F%2Freply")!
        guard case .readSettings(let callback)? = OpenClipDeepLink.parse(url) else {
            return XCTFail("expected a read deep link")
        }
        XCTAssertEqual(callback, URL(string: "panel://reply"))
    }

    // MARK: - Rejections

    func testRejectsUnknownHostAndScheme() {
        XCTAssertNil(OpenClipDeepLink.parse(URL(string: "openclip://frobnicate")!))
        XCTAssertNil(OpenClipDeepLink.parse(URL(string: "https://openclip.app/settings")!))
    }

    func testRejectsUnknownCommand() {
        XCTAssertNil(OpenClipDeepLink.parse(URL(string: "openclip://command/self-destruct")!))
    }

    func testRejectsWriteWithNoValues() {
        XCTAssertNil(OpenClipDeepLink.parse(URL(string: "openclip://set?callback=panel%3A%2F%2Fdone")!))
    }

    /// A web callback would let any page receive the settings, so it is dropped (the route still
    /// parses; it simply has no reply target).
    func testDropsWebCallback() {
        let url = URL(string: "openclip://settings?callback=https%3A%2F%2Fevil.example%2Fcollect")!
        guard case .readSettings(let callback)? = OpenClipDeepLink.parse(url) else {
            return XCTFail("expected a read deep link")
        }
        XCTAssertNil(callback)
    }

    // MARK: - Reply

    func testSuccessReplyCarriesResultJSON() {
        let callback = URL(string: "panel://reply")!
        guard let reply = OpenClipDeepLinkReply.success(callback: callback, payload: ["ok": true, "applied": 2]) else {
            return XCTFail("expected a reply URL")
        }
        let components = URLComponents(url: reply, resolvingAgainstBaseURL: false)
        let result = components?.queryItems?.first { $0.name == OpenClipDeepLink.resultQueryItem }?.value
        let data = Data((result ?? "{}").utf8)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["ok"] as? Bool, true)
        XCTAssertEqual(json?["applied"] as? Int, 2)
    }

    func testFailureReplyCarriesMessage() {
        let callback = URL(string: "panel://reply")!
        guard let reply = OpenClipDeepLinkReply.failure(callback: callback, message: "nope") else {
            return XCTFail("expected a reply URL")
        }
        let components = URLComponents(url: reply, resolvingAgainstBaseURL: false)
        let result = components?.queryItems?.first { $0.name == OpenClipDeepLink.errorQueryItem }?.value
        XCTAssertTrue((result ?? "").contains("nope"))
    }
}
