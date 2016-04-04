// TCPClientSocket.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
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

import CLibvenice

public final class TCPClientSocket: TCPSocket, C7.Connection {

    public var uri: URI?

    override public init(socket: tcpsock) throws {
        try super.init(socket: socket)
    }

    public init(ip: IP, deadline: Deadline = never) throws {
        try super.init(socket: tcpconnect(ip.address, deadline))
    }

    public init(fileDescriptor: FileDescriptor) throws {
        try super.init(socket: tcpattach(fileDescriptor, 0))
    }

    public var ip: IP {
        return try! IP(address: tcpaddr(socket))
    }

    public func send(data: Data, flush: Bool = true, deadline: Deadline = never) throws {
        try assertNotClosed()

        let bytesProcessed = data.withUnsafeBufferPointer {
            tcpsend(socket, $0.baseAddress, $0.count, deadline)
        }

        try TCPError.assertNoSendErrorWithData(data, bytesProcessed: bytesProcessed)

        if flush {
            try self.flush()
        }
    }

    public func send(data: Data) throws {
      try self.send(data, flush:true, deadline: never)
    }

    public func flush(deadline: Deadline) throws {
        try assertNotClosed()
        tcpflush(socket, deadline)
        try TCPError.assertNoError()
    }

    public func flush() throws {
      try self.flush(never)
    }

    public func receive(length length: Int, deadline: Deadline = never) throws -> Data {
        try assertNotClosed()

        var data = Data.bufferWithSize(length)
        let bytesProcessed = data.withUnsafeMutableBufferPointer {
            tcprecv(socket, $0.baseAddress, $0.count, deadline)
        }

        try TCPError.assertNoReceiveErrorWithData(data, bytesProcessed: bytesProcessed)
        return Data(data.prefix(bytesProcessed))
    }

    public func receive() throws -> Data {
      return try receive(length: Int.max)
    }

    public func receive(lowWaterMark lowWaterMark: Int, highWaterMark: Int, deadline: Deadline = never) throws -> Data {
        try assertNotClosed()

        if lowWaterMark <= 0 || highWaterMark <= 0 {
            throw TCPError.unknown(description: "Marks should be > 0")
        }

        if lowWaterMark > highWaterMark {
            throw TCPError.unknown(description: "loweWaterMark should be less than highWaterMark")
        }

        var data = Data.bufferWithSize(highWaterMark)
        let bytesProcessed = data.withUnsafeMutableBufferPointer {
            tcprecvlh(socket, $0.baseAddress, lowWaterMark, highWaterMark, deadline)
        }

        try TCPError.assertNoReceiveErrorWithData(data, bytesProcessed: bytesProcessed)
        return Data(data.prefix(bytesProcessed))
    }

    public func receive(length length: Int, untilDelimiter delimiter: String, deadline: Deadline = never) throws -> Data {
        try assertNotClosed()

        var data = Data.bufferWithSize(length)
        let bytesProcessed = data.withUnsafeMutableBufferPointer {
            tcprecvuntil(socket, $0.baseAddress, $0.count, delimiter, delimiter.utf8.count, deadline)
        }

        try TCPError.assertNoReceiveErrorWithData(data, bytesProcessed: bytesProcessed)
        return Data(data.prefix(bytesProcessed))
    }

    public func attach(fileDescriptor: FileDescriptor) throws {
        try super.attach(fileDescriptor, isServer: false)
    }
}

extension TCPClientSocket {
    public func send(convertible: DataConvertible, deadline: Deadline = never) throws {
        try send(convertible.data, deadline: deadline)
    }

    public func receiveString(length length: Int, deadline: Deadline = never) throws -> String {
        let result = try receive(length: length, deadline: deadline)
        return try String(data: result)
    }

    public func receiveString(length length: Int, untilDelimiter delimiter: String, deadline: Deadline = never) throws -> String {
        let result = try receive(length: length, untilDelimiter: delimiter, deadline: deadline)
        return try String(data: result)
    }
}
