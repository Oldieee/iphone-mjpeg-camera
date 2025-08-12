import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    let server = MJPEGServer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        startCamera()
        server.start()
    }

    func startCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        session.addOutput(output)

        session.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()

        if let jpegData = context.jpegRepresentation(of: ciImage,
                                                     colorSpace: CGColorSpaceCreateDeviceRGB(),
                                                     options: [:]) {
            server.latestJPEG = jpegData
        }
    }
}
