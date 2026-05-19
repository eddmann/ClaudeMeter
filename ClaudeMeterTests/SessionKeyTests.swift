import XCTest
@testable import ClaudeMeter

final class SessionKeyTests: XCTestCase {
    func test_sessionKey_acceptsRawSessionKey() throws {
        let sessionKey = try SessionKey("  \(TestConstants.sessionKeyValue)  ")

        XCTAssertEqual(sessionKey.value, TestConstants.sessionKeyValue)
    }

    func test_sessionKey_extractsValueFromCookieHeader() throws {
        let sessionKey = try SessionKey("Cookie: foo=bar; sessionKey=\(TestConstants.sessionKeyValue); other=value")

        XCTAssertEqual(sessionKey.value, TestConstants.sessionKeyValue)
    }

    func test_sessionKey_rejectsCookieHeaderWithoutSessionKey() {
        XCTAssertThrowsError(try SessionKey("Cookie: foo=bar"))
    }
}
