//
//  SFTPTests.swift
//  SwiftSH Integration Tests
//
//  Created by Thomas Willson on 12/22/19.
//  Copyright © 2019 Tommaso Madonia. All rights reserved.
//

import XCTest
@testable import SwiftSH

class SFTPTests: XCTestCase {

    private let config = Config.load()
    private var session: SSHSession!

    override func setUp() {
        super.setUp()

        self.session = try! SSHSession(host: self.config.session.host, port: self.config.session.port)
    }

    override func tearDown() {
        self.session = nil
        super.tearDown()
    }

    func testFileCreateAndDelete() {
        let filename = "sample2.txt"
        let channel = connect()

        var file: SSHLibrarySFTPFile! = nil
        XCTAssertNoThrow(file = try channel.openFile(filename, flags: [.Create], mode: 0o777))
        XCTAssertNoThrow(try file.close())

        XCTAssertNoThrow(try channel.removeFile(filename))
    }

    func testFileReadWrite() {
        let filename = "sample.txt"
        let channel = connect()

        var file: SSHLibrarySFTPFile! = nil
        XCTAssertNoThrow(file = try channel.openFile(filename,
                                                     flags: [.Create, .Write],
                                                     mode: 0o777))
        let stringToWrite = "Some file content..."
        let dataToWrite = stringToWrite.data(using: .utf8)!
        let writeResult = file.write(dataToWrite)
        XCTAssertNil(writeResult.error)
        XCTAssert(writeResult.bytesSent == dataToWrite.count)
        XCTAssertNoThrow(try file.close())

        XCTAssertNoThrow(file = try channel.openFile(filename,
                                                     flags: [.Read],
                                                     mode: 0o777))
        var readData: Data!
        XCTAssertNoThrow(readData = try file.read())
        let readString = String(data: readData, encoding: .utf8)
        XCTAssertEqual(stringToWrite, readString, "Data roundtrip occurs correctly.")

        try! channel.removeFile(filename)
    }

    func testFolderCreateAndDelete() {
        let folderName = "AFolder"
        let channel = connect()

        XCTAssertNoThrow(try channel.makeDirectory(folderName, mode: 0o666))

        var folderContents = [String]()
        XCTAssertNoThrow(folderContents = try channel.listDirectory("."))
        XCTAssert(folderContents.contains(folderName))

        XCTAssertNoThrow(try channel.removeDirectory(folderName))

        XCTAssertNoThrow(folderContents = try channel.listDirectory("."))
        XCTAssert(!folderContents.contains(folderName))
    }

    func testFileRename() {
        let originalName = "AFile"
        let newName = "BFile"

        let channel = connect()
        XCTAssertNoThrow(try channel.openFile(originalName, flags: [.Create], mode: 0o777))

        var folderContents = [String]()
        XCTAssertNoThrow(folderContents = try channel.listDirectory("."))
        XCTAssert(folderContents.contains(originalName))

        XCTAssertNoThrow(try channel.rename(source: originalName, destination: newName, flags: []))

        XCTAssertNoThrow(folderContents = try channel.listDirectory("."))
        XCTAssert(!folderContents.contains(originalName))
        XCTAssert(folderContents.contains(newName))

        XCTAssertNoThrow(try channel.removeFile(newName))
    }

    private func connect() -> SSHLibrarySFTPChannel
    {
        let expectation = XCTestExpectation(description: "Authenticate")

        self.session
            .connect()
            .authenticate(.byPassword(username: self.config.authentication.password.username, password: self.config.authentication.password.password)) { [unowned self] error in
                XCTAssertNil(error)
                XCTAssertTrue(self.session.authenticated)

                expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        let channel = self.session.session.makeSFTPChannel()
        XCTAssertNoThrow(try channel.openChannel())
        return channel
    }
}
