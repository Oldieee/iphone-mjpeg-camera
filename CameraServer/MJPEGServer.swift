import Foundation
import Network

class MJPEGServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    var latestJPEG: Data?

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: 8080)
            listener?.newConnectionHandler = { connection in
                self.connections.append(connection)
                connection.start(queue: .main)
                self.sendStream(to: connection)
            }
            listener?.start(queue: .main)
            print("Server started on port 8080")
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    private func sendStream(to connection: NWConnection) {
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: multipart/x-mixed-replace; boundary=frame\r
        \r
        """
        connection.send(content: header.data(using: .utf8), completion: .contentProcessed { _ in })

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if let jpeg = self.latestJPEG {
                var frame = "--frame\r\n"
                frame += "Content-Type: image/jpeg\r\n"
                frame += "Content-Length: \(jpeg.count)\r\n\r\n"
                var data = Data(frame.utf8)
                data.append(jpeg)
                data.append("\r\n".data(using: .utf8)!)
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
        }
    }
}
