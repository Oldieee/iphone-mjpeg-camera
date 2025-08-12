// ContentView.swift
import SwiftUI
import AVFoundation

class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isServerActive = false
    @Published var serverURL: String = "..."

    private var captureSession: AVCaptureSession?
    private let streamer = MJPEGStreamer()
    private let videoOutput = AVCaptureVideoDataOutput()

    func toggleServer() {
        if isServerActive {
            stopSession()
            streamer.stop()
            serverURL = "Server oprit."
        } else {
            setupSession()
            startSession()
            streamer.start()
            serverURL = "http://\(getIPAddress() ?? "?.?.?.?"):8080"
        }
        isServerActive.toggle()
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480 // Rezoluție mai mică pentru performanță
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Error: Could not create video device input.")
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        self.captureSession = session
    }

    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }

    // Delegate method - Aici se primesc cadrele de la cameră
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let jpegData = jpegData(from: imageBuffer) else { return }
        
        streamer.streamFrame(jpegData)
    }

    // Funcție ajutătoare pentru a converti cadrul în JPEG
    private func jpegData(from imageBuffer: CVImageBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: 0.2) // Calitate redusă pentru viteză
    }
    
    // Funcție ajutătoare pentru a găsi adresa IP locală
    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                let flags = Int32((ptr?.pointee.ifa_flags)!)
                var addr = ptr?.pointee.ifa_addr.pointee
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr?.sa_family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if (getnameinfo(&addr!, socklen_t((addr?.sa_len)!), &hostname, socklen_t(hostname.count),
                                        nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                            if let anAddress = String(cString: hostname, encoding: .utf8) {
                                if anAddress.starts(with: "192.168") || anAddress.starts(with: "10.0") || anAddress.starts(with: "172.16"){
                                    address = anAddress
                                    break
                                }
                            }
                        }
                    }
                }
                ptr = ptr?.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}


struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("iPhone IP Camera")
                .font(.largeTitle)

            Text(viewModel.serverURL)
                .font(.headline)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

            Button(action: {
                viewModel.toggleServer()
            }) {
                Text(viewModel.isServerActive ? "Oprește Server" : "Pornește Server")
                    .font(.title2)
                    .padding()
                    .background(viewModel.isServerActive ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
        }
        .padding()
    }
}