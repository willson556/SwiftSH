//
// The MIT License (MIT)
//
// Copyright (c) 2017 Tommaso Madonia
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

// MARK: - SSH Library

/// A library that implements the SSH2 protocol.
public protocol SSHLibrary {

    /// The name of the library.
    static var name: String { get }
    
    /// The version of the library.
    static var version: String { get }

    /// Initialize a new SSH session.
    ///
    /// - Returns: The SSH session.
    static func makeSession() throws -> SSHLibrarySession
    
}

// MARK: - Session

public protocol SSHLibrarySession {
    
    var authenticated: Bool { get }
    var blocking: Bool { get set }
    var banner: String? { get }
    var timeout: Int { get set }
    
    func makeChannel() -> SSHLibraryChannel
    func makeSFTPChannel() -> SSHLibrarySFTPChannel
    func setBanner(_ banner: String) throws
    func handshake(_ socket: CFSocket) throws
    func fingerprint(_ hashType: FingerprintHashType) -> String?
    func authenticationList(_ username: String) throws -> [String]
    func authenticateByPassword(_ username: String, password: String) throws
    func authenticateByKeyboardInteractive(_ username: String, callback: @escaping ((String) -> String)) throws
    func authenticateByPublicKeyFromFile(_ username: String, password: String, publicKey: String?, privateKey: String) throws
    func authenticateByPublicKeyFromMemory(_ username: String, password: String, publicKey: Data?, privateKey: Data) throws
    func disconnect() throws
    
}

// MARK: - Channel

public protocol SSHLibraryChannel {
    
    var opened: Bool { get }
    var receivedEOF: Bool { get }
    
    func openChannel() throws
    func closeChannel() throws
    func setEnvironment(_ environment: Environment) throws
    func requestPseudoTerminal(_ terminal: Terminal) throws
    func setPseudoTerminalSize(_ terminal: Terminal) throws
    func exec(_ command: String) throws
    func shell() throws
    func read() throws -> Data
    func readError() throws -> Data
    func write(_ data: Data) -> (error: Error?, bytesSent: Int)
    func exitStatus() -> Int?
    func sendEOF() throws
    
}

// MARK: - SFTP

public struct FileOpenOptions: OptionSet {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let Read = FileOpenOptions(rawValue: 1 << 0)
    public static let Write = FileOpenOptions(rawValue: 1 << 1)
    public static let Append = FileOpenOptions(rawValue: 1 << 2)
    public static let Create = FileOpenOptions(rawValue: 1 << 3)
    public static let Truncate = FileOpenOptions(rawValue: 1 << 4)
    public static let Exclude = FileOpenOptions(rawValue: 1 << 5)
}

public struct RenameOptions: OptionSet {
    public let rawValue : UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let Overwrite = FileOpenOptions(rawValue: 1 << 0)
    public static let Atomic = FileOpenOptions(rawValue: 1 << 1)
    public static let Native = FileOpenOptions(rawValue: 1 << 2)
}

public protocol SSHLibrarySFTPFile {
    func getCurrentPosition() throws -> UInt64
    func seek(offset: UInt64) throws
    func read() throws -> Data
    func write(_ data: Data) -> (error: Error?, bytesSent: ssize_t)
    
    func close() throws
}

public protocol SSHLibrarySFTPChannel {
    var opened: Bool { get }
    
    func openChannel() throws
    func closeChannel() throws
    
    func openFile(_ path: String, flags: FileOpenOptions, mode: Int) throws -> SSHLibrarySFTPFile
    func removeFile(_ path: String) throws
    func rename(source: String, destination: String, flags: RenameOptions) throws
    
    func makeDirectory(_ path: String, mode: Int) throws
    func removeDirectory(_ path: String) throws
    func listDirectory(_ path: String) throws -> [String]
}

// MARK: - SCP

public protocol SSHLibrarySCP {
    
}

// MARK: - Fingerprint

public enum FingerprintHashType: CustomStringConvertible {
    
    case md5, sha1
    
    public var description: String {
        switch self {
        case .md5:  return "MD5"
        case .sha1: return "SHA1"
        }
    }
    
}

// MARK: - Authentication

public enum AuthenticationMethod: CustomStringConvertible, Equatable {

    case password, keyboardInteractive, publicKey
    case unknown(String)

    public init(_ rawValue: String) {
        switch rawValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            case "password": self = .password
            case "keyboard-interactive": self = .keyboardInteractive
            case "publickey": self = .publicKey
            default: self = .unknown(rawValue)
        }
    }

    public var description: String {
        switch self {
            case .password: return "Password"
            case .keyboardInteractive: return "Keyboard Interactive"
            case .publicKey: return "Public Key"
            case .unknown(let method): return method
        }
    }

}

public enum AuthenticationChallenge {

    case byPassword(username: String, password: String)
    case byKeyboardInteractive(username: String, callback: ((String) -> String))
    case byPublicKeyFromFile(username: String, password: String, publicKey: String?, privateKey: String)
    case byPublicKeyFromMemory(username: String, password: String, publicKey: Data?, privateKey: Data)

    var username: String {
        switch self {
            case .byPassword(let username, _), .byKeyboardInteractive(let username, _), .byPublicKeyFromFile(let username, _, _, _), .byPublicKeyFromMemory(let username, _, _, _):
                return username
        }
    }

    var requiredAuthenticationMethod: AuthenticationMethod {
        switch self {
            case .byPassword: return .password
            case .byKeyboardInteractive: return .keyboardInteractive
            case .byPublicKeyFromFile, .byPublicKeyFromMemory: return .publicKey
        }
    }

}

// MARK: - Environment

public struct Environment {

    public let name: String
    public let variable: String

}

// MARK: - Terminal

public struct Terminal: ExpressibleByStringLiteral, CustomStringConvertible {
    
    public let name: String
    public var width: UInt
    public var height: UInt
    
    public var description: String {
        return "\(self.name) [\(self.width)x\(self.height)]"
    }

    public init(_ name: String, width: UInt = 80, height: UInt = 24) {
        self.name = name
        self.width = width
        self.height = height
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.name = value
        self.width = 80
        self.height = 24
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.name = value
        self.width = 80
        self.height = 24
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self.name = value
        self.width = 80
        self.height = 24
    }
    
}
