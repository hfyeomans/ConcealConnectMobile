import Foundation
import Network
@_exported import MasqueC

public enum MasqueError: Error { case connectFailed, sendFailed }

public final class MasqueClient {

    var conn: OpaquePointer!
    
    public init() {
        // Initialize MasqueClient
    }                // quiche_conn*

    // MARK: connect / send / poll -------------------------------------------------
    public func connect(host: String, port: UInt16 = 443) throws {
        var scid = [UInt8](repeating: 0, count: 20)
        _ = SecRandomCopyBytes(kSecRandomDefault, scid.count, &scid)
        guard let c = conceal_masque_connect(&scid, scid.count, host, port) else {
            throw MasqueError.connectFailed
        }
        conn = c
        
        // Log that connection is initiated (handshake will complete asynchronously)
        print("MasqueClient: QUIC connection initiated to \(host):\(port)")
    }

    @discardableResult
    public func send(_ data: Data) throws -> UInt64 {
        let sid = conceal_masque_stream_new(conn)
        guard sid != UInt64.max else { throw MasqueError.sendFailed }
        let rc = data.withUnsafeBytes {
            conceal_masque_send(conn, sid,
                                $0.bindMemory(to: UInt8.self).baseAddress,
                                data.count)
        }
        guard rc >= 0 else { throw MasqueError.sendFailed }
        return sid
    }

    public func poll(maxBytes: Int = 4096) -> (UInt64, Data)? {
        var buf = [UInt8](repeating: 0, count: maxBytes)
        let sid = conceal_masque_poll(conn, &buf, buf.count)
        guard sid != UInt64.max else { return nil }
        return (sid, Data(buf))
    }
    
    public func isHandshakeComplete() -> Bool {
        guard conn != nil else { return false }
        return quiche_conn_is_established(conn)
    }

    // MARK: minimal UDP pump (tests only) -----------------------------------------
    // This is a simplified version - the test file will handle the actual UDP pump
}
