import Foundation
import XCTest
import MasqueC
@testable import TunnelCore      // TunnelCore is the framework that ships MasqueClient

final class MasqueClientTests: XCTestCase {

    /// Basic connectivity test
    func testBasicConnection() throws {
        let client = MasqueClient()
        // Just test that we can create a connection
        try client.connect(host: "127.0.0.1", port: 6121)
        
        // Test that we can create a stream and send data
        let payload = "GET /\r\n".data(using: .utf8)!
        let streamId = try client.send(payload)
        
        XCTAssertNotEqual(streamId, UInt64.max, "Stream creation should succeed")
    }
}
