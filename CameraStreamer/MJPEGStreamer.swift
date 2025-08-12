// MJPEGStreamer.swift
import Foundation
import Network
import AVFoundation

class MJPEGStreamer: NSObject {
    private var listener: NWListener?
    private var connections = [NWConnection]()
    private let port: NWEndpoint.Port

    init(port: UInt16 = 8080) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: self.port)
            listener?.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    print("Server ready on port \(self.port)")
                case .failed(let error):
                    print("Server failed with error: \(error)")
                default:
                    break
                }
            }
            listener?.newConnectionHandler = { newConnection in
                self.handleNewConnection(newConnection)
            }
            listener?.start(queue: .main)
        } catch {
            print("Failed to create listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                self.sendInitialResponse(on: connection)
                self.connections.append(connection)
            case .failed, .cancelled:
                self.connections.removeAll { $0 === connection }
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    private func sendInitialResponse(on connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK
        Content-Type: multipart/x-mixed-replace; boundary=--boundary
        
        
        """.data(using: .utf8)!
        connection.send(content: response, completion: .contentProcessed({ _ in }))
    }

    func streamFrame(_ jpegData: Data) {
        let frameData = """
        --boundary
        Content-Type: image/jpeg
        Content-Length: \(jpegData.count)
        
        
        """.data(using: .utf8)! + jpegData + "\r\n".data(using: .utf8)!
        
        connections.forEach { connection in
            connection.send(content: frameData, completion: .contentProcessed({ _ in }))
        }
    }
}