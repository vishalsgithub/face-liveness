import CoreVideo
import FaceLiveness
import UIKit
import XCTest

final class FASEngineTests: XCTestCase {
    private var engine: FASEngine!
    private var image: UIImage!

    override func setUpWithError() throws {
        engine = try FASEngine.bundled()
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: Self.self)
        #endif
        let url = try XCTUnwrap(bundle.url(forResource: "face", withExtension: "jpeg"))
        image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
    }

    func testDetectsLiveFaceInSampleImage() throws {
        let faces = try engine.detectFaces(in: image)
        XCTAssertEqual(faces.count, 1)
        let face = try XCTUnwrap(faces.first)
        XCTAssertGreaterThan(face.detectionConfidence, 0.9)
        XCTAssertGreaterThan(face.livenessScore, 0.9)
        XCTAssertGreaterThan(face.bounds.width, 300)
    }

    func testOrientedImageMatchesUprightImage() throws {
        let upright = try XCTUnwrap(engine.detectFaces(in: image).first)
        let cgImage = try XCTUnwrap(image.cgImage)
        // Store the pixels rotated 90° counter-clockwise and tag them `.right`, like a
        // portrait camera photo: the engine must render the face upright again.
        let width = cgImage.width, height = cgImage.height
        let context = try XCTUnwrap(CGContext(
            data: nil, width: height, height: width, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.translateBy(x: CGFloat(height), y: 0)
        context.rotate(by: .pi / 2)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let rotatedPixels = try XCTUnwrap(context.makeImage())
        let rotated = UIImage(cgImage: rotatedPixels, scale: 1, orientation: .right)
        XCTAssertEqual(rotated.size, image.size)
        let face = try XCTUnwrap(engine.detectFaces(in: rotated).first)
        XCTAssertEqual(face.bounds.minX, upright.bounds.minX, accuracy: 4)
        XCTAssertEqual(face.bounds.minY, upright.bounds.minY, accuracy: 4)
        XCTAssertEqual(face.bounds.width, upright.bounds.width, accuracy: 4)
        XCTAssertEqual(face.livenessScore, upright.livenessScore, accuracy: 0.05)
    }

    func testBGRAPixelBufferMatchesImage() throws {
        let upright = try XCTUnwrap(engine.detectFaces(in: image).first)
        let buffer = try makeBGRAPixelBuffer(from: image)
        let face = try XCTUnwrap(engine.detectFaces(in: buffer, orientation: .up).first)
        XCTAssertEqual(face.bounds.minX, upright.bounds.minX, accuracy: 2)
        XCTAssertEqual(face.bounds.minY, upright.bounds.minY, accuracy: 2)
        XCTAssertEqual(face.livenessScore, upright.livenessScore, accuracy: 0.01)
    }

    func testReturnsNoFaceForBlankImage() throws {
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 240)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
        }
        XCTAssertEqual(try engine.detectFaces(in: blank).count, 0)
    }

    func testThresholdControlsVerdict() throws {
        engine.livenessThreshold = 0.999
        XCTAssertFalse(try XCTUnwrap(engine.detectFaces(in: image).first).isLive)
        engine.livenessThreshold = 0.5
        XCTAssertTrue(try XCTUnwrap(engine.detectFaces(in: image).first).isLive)
    }

    func testRejectsUnsupportedPixelBuffer() throws {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_OneComponent8, nil, &buffer)
        XCTAssertThrowsError(try engine.detectFaces(in: try XCTUnwrap(buffer), orientation: .up))
    }

    func testDetectionPerformance() throws {
        let buffer = try makeBGRAPixelBuffer(from: image)
        measure {
            _ = try? engine.detectFaces(in: buffer, orientation: .up)
        }
    }

    private func makeBGRAPixelBuffer(from image: UIImage) throws -> CVPixelBuffer {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixelBuffer = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}
