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

// MARK: - SFTPSession

public class SFTPSession: SSHSession {
    var sftp: SSHLibrarySFTPChannel?

    public init(host: String, port: UInt16 = 22) throws {
        try super.init(sshLibrary: Libssh2.self, host: host, port: port)
    }

    // MARK: - Open/Close
    public func open(_ completion: SSHCompletionBlock? = nil) -> Self {
        self.queue.async(completion: completion) {
            guard self.authenticated else {
                throw SSHError.authenticationFailed
            }

            guard self.sftp == nil else {
                throw SSHError.Channel.alreadyOpen
            }

            self.log.debug("Opening the SFTP channel...")

            self.session.blocking = true
            defer {
                self.session.blocking = false
            }

            self.sftp = self.session.makeSFTPChannel()
            try self.sftp?.openChannel()
        }

        return self
    }

    public func close(_ completion: SSHCompletionBlock? = nil) -> Self {
        self.queue.async(completion: completion) {
            if let sftp = self.sftp {
                try sftp.closeChannel()
            }
        }

        return self
    }

    // MARK: - File

    public func openFile(_ path: String, flags: FileOpenOptions, mode: Int, completion: ((Error?, SFTPFile?) -> Void)?) {
        self.queue.async(completion: { error in
            if let error = error,
               let completion = completion {
                completion(error, nil)
            }
        }, block: {
            guard let sftp = self.sftp else {
                throw SSHError.Channel.closed
            }

            let file = try sftp.openFile(path, flags: flags, mode: mode)

            if let completion = completion {
                self.queue.callbackQueue.async {
                    completion(nil, SFTPFile(file: file, queue: self.queue))
                }
            }
        })
    }

    public func removeFile(_ path: String, completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion){
            guard let sftp = self.sftp else {
                throw SSHError.Channel.closed
            }

            try sftp.removeFile(path)
        }
    }

    public func rename(source: String, destination: String, flags: RenameOptions, completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion) {
            guard let sftp = self.sftp else {
                throw SSHError.Channel.closed
            }

            try sftp.rename(source: source, destination: destination, flags: flags)
        }
    }

    // MARK: - Directory

    public func makeDirectory(_ path: String, mode: Int, completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion) {
            guard let sftp = self.sftp else {
                throw SSHError.Channel.closed
            }

            try sftp.makeDirectory(path, mode: mode)
        }
    }

    public func removeDirectory(_ path: String, completion: SSHCompletionBlock?) {
        self.queue.async(completion: completion) {
            guard let sftp = self.sftp else {
                throw SSHError.Channel.closed
            }

            try sftp.removeDirectory(path)
        }
    }

    public func listDirectory(_ path: String, completion: ((Error?, [String]) -> Void)?) {
        self.queue.async(completion: { error in
            if let error = error,
               let completion = completion {
                completion(error, [String]())
            }
        }, block: {
            guard let sftp = self.sftp else {
                throw SSHError.Channel.closed
            }

            let listResult = try sftp.listDirectory(path)

            if let completion = completion {
                completion(nil, listResult)
            }
        })
    }
}

// MARK: - SFTPFile

public class SFTPFile {
    var queue: Queue
    var file: SSHLibrarySFTPFile

    internal init(file: SSHLibrarySFTPFile, queue: Queue) {
        self.queue = queue
        self.file = file
    }

    public func seek(_ offset: UInt64, completion: ((Error?) -> Void)?) {
        self.queue.async(completion: { error in
            if let error = error {
                do { try self.file.close() }
                catch {}

                if let completion = completion {
                    completion(error)
                }
            }
        }, block: {
            try self.file.seek(offset: offset)

            if let completion = completion {
                self.queue.callbackQueue.async { completion(nil) }
            }
        })
    }

    public func write(_ data: Data, completion: ((Error?, Int) -> Void)?) {
        self.queue.async {
            let writeResult = self.file.write(data)

            if let completion = completion {
                self.queue.callbackQueue.async { completion(writeResult.error, writeResult.bytesSent)
                }
            }
        }
    }

    public func read(_ completion: ((Error?, Data?) -> Void)?) {
        self.queue.async(completion: { error in
            if let error = error {
                do { try self.file.close() }
                catch {}

                if let completion = completion {
                    completion(error, nil)
                }
            }
        }, block: {
            let readResult = try self.file.read()

            if let completion = completion {
                self.queue.callbackQueue.async {
                    completion(nil, readResult)
                }
            }
        })
    }

    public func getCurrentPosition() throws -> UInt64 {
        return try self.file.getCurrentPosition()
    }
}
