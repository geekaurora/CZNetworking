import XCTest
@testable import CZNetworking

final class CZNetworkingTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(CZNetworking().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
