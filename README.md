# Face Liveness

On-device face liveness (anti-spoofing) detection for iOS. It checks whether the face in front of the camera is real or a presentation attack (printed photo, screen replay, mask) from a single camera frame. The user doesn't have to blink or turn their head, and nothing leaves the device.

The package is based on [Silent-Face-Anti-Spoofing](https://github.com/minivision-ai/Silent-Face-Anti-Spoofing) by MiniVision (see [Credits](#credits)) and runs on [ncnn](https://github.com/Tencent/ncnn).

- iOS 13+, Swift and Objective-C
- `FASLivenessCameraView`: a ready-made front-camera view that scores every frame
- `FASEngine`: runs on a `UIImage`, a `CVPixelBuffer` (BGRA / NV12) or raw RGBA/BGRA/RGB/BGR/NV21/NV12 bytes
- Models are included (about 5.5 MB)

## Installation

In Xcode, choose **File → Add Package Dependencies…** and enter:

```
https://github.com/vishalsgithub/face-liveness
```

Or add it in `Package.swift`:

```swift
.package(url: "https://github.com/vishalsgithub/face-liveness", from: "1.0.0")
```

Then add `.product(name: "FaceLiveness", package: "face-liveness")` to your target's dependencies.

If you use the camera view, add a camera usage description to your app's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>The camera is used to check that a real person is in front of the device.</string>
```

## Usage

### Camera view

```swift
import FaceLiveness

let cameraView = FASLivenessCameraView(frame: view.bounds)
cameraView.resultHandler = { result in
    guard let face = result.face else { return }    // no face in frame
    print(face.livenessScore, face.isLive)            // 0...1, score >= threshold
    print(result.faceFrameInView)                     // box in view coordinates
}
view.addSubview(cameraView)
cameraView.start()   // asks for camera permission if needed
```

Errors such as a denied camera permission are reported through `FASLivenessCameraViewDelegate.livenessCameraView(_:didFailWithError:)`.

A single frame is noisy. For a verification flow, only accept a face after it has been live for several consecutive frames, for example 8.

### SwiftUI

```swift
struct LivenessCamera: UIViewRepresentable {
    var onResult: (FASLivenessResult) -> Void

    func makeUIView(context: Context) -> FASLivenessCameraView {
        let view = FASLivenessCameraView()
        view.resultHandler = onResult
        view.start()
        return view
    }

    func updateUIView(_ view: FASLivenessCameraView, context: Context) {
        view.resultHandler = onResult
    }

    static func dismantleUIView(_ view: FASLivenessCameraView, coordinator: ()) {
        view.stop()
    }
}
```

### Still images and camera frames

```swift
let engine = try FASEngine.bundled()                 // loads the bundled models
engine.livenessThreshold = 0.915             // default

let faces = try engine.detectFaces(in: uiImage)                       // honours imageOrientation
let faces = try engine.detectFaces(in: pixelBuffer, orientation: .right)

if let face = faces.first {
    print(face.bounds, face.livenessScore, face.isLive)
}
```

Face `bounds` are in pixels of the upright image. By default only the largest face is evaluated. Set `evaluatesAllFaces = true` to evaluate every face.

| Property | Default | Meaning |
| --- | --- | --- |
| `livenessThreshold` | `0.915` | Minimum score for a face to count as live |
| `minFaceSize` | `64` | Smallest face to detect, in pixels |
| `faceDetectionThreshold` | `0.6` | Minimum face detector confidence |
| `numThreads` | `2` | Number of CPU inference threads |

`FASEngine` is thread-safe; concurrent calls are serialized. Create it once and reuse it, because loading the models takes a moment.

## How it works

1. **Face detection**: an SSD-style detector finds faces in a 192 px version of the frame, and each box is squared.
2. **Liveness**: two MiniFASNet models look at the face at different context scales (2.7× and 4.0× the face box, resized to 80×80). Each outputs a "real face" probability, and the two are averaged.

Inference takes a few milliseconds per frame on recent iPhones.

## Credits

The liveness algorithm, the trained models and the original Android deployment code that this package is ported from are the work of **[MiniVision (小视科技)](https://www.minivision.cn/)**:

- **[minivision-ai/Silent-Face-Anti-Spoofing](https://github.com/minivision-ai/Silent-Face-Anti-Spoofing)**, Silent Face Anti-Spoofing (MiniFASNet), Apache-2.0

All credit for the anti-spoofing research and models goes to them. This package repackages their work for iOS and Swift Package Manager.

Inference is powered by **[Tencent/ncnn](https://github.com/Tencent/ncnn)** (BSD-3-Clause).

## License

Apache-2.0, the same license as the original [Silent-Face-Anti-Spoofing](https://github.com/minivision-ai/Silent-Face-Anti-Spoofing) project. ncnn is distributed under BSD-3-Clause.
