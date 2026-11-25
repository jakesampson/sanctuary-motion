import AVFoundation
import CoreVideo
import Foundation

struct EncoderError: LocalizedError {
    var errorDescription: String?
    init(_ text: String) { errorDescription = text }
}

func readFrame(_ handle: FileHandle, bytes: Int) throws -> Data {
    var frame = Data()
    frame.reserveCapacity(bytes)
    while frame.count < bytes {
        guard let piece = try handle.read(upToCount: bytes - frame.count), !piece.isEmpty else {
            throw EncoderError("The frame stream ended early.")
        }
        frame.append(piece)
    }
    return frame
}

func encode() throws {
    let args = CommandLine.arguments
    guard args.count == 6, let width = Int(args[1]), let height = Int(args[2]),
          let fps = Int32(args[3]), let count = Int(args[4]),
          (2...8192).contains(width), (2...8192).contains(height),
          width % 2 == 0, height % 2 == 0, width * height <= 16_777_216,
          [24, 25, 30, 50, 60].contains(fps), (1...3600).contains(count) else {
        throw EncoderError("Invalid encoder arguments.")
    }
    let file = URL(fileURLWithPath: args[5])
    let writer = try AVAssetWriter(outputURL: file, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let output: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: max(1_500_000, Int(Double(width * height) * Double(fps) * 0.18)),
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoAllowFrameReorderingKey: false,
        ],
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
    ]
    guard writer.canApply(outputSettings: output, forMediaType: .video) else {
        throw EncoderError("This Mac cannot encode H.264 at the requested size.")
    }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: output)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
    guard writer.canAdd(input) else { throw EncoderError("Could not create a video track.") }
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? EncoderError("Could not start writing.") }
    writer.startSession(atSourceTime: .zero)
    guard let pool = adaptor.pixelBufferPool else { throw EncoderError("Could not allocate video buffers.") }
    let stdin = FileHandle.standardInput
    for frame in 0..<count {
        try autoreleasepool {
            let rgba = try readFrame(stdin, bytes: width * height * 4)
            let timeout = ProcessInfo.processInfo.systemUptime + 30
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing, ProcessInfo.processInfo.systemUptime < timeout else {
                    throw writer.error ?? EncoderError("The video encoder did not accept another frame.")
                }
                Thread.sleep(forTimeInterval: 0.002)
            }
            var pixelBuffer: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard result == kCVReturnSuccess, let buffer = pixelBuffer else {
                throw EncoderError("Could not allocate a video frame.")
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            rgba.withUnsafeBytes { bytes in
                let source = bytes.bindMemory(to: UInt8.self)
                let destination = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
                let stride = CVPixelBufferGetBytesPerRow(buffer)
                for y in 0..<height {
                    let row = destination + y * stride
                    for x in 0..<width {
                        let offset = (y * width + x) * 4
                        row[x * 4] = source[offset + 2]
                        row[x * 4 + 1] = source[offset + 1]
                        row[x * 4 + 2] = source[offset]
                        row[x * 4 + 3] = 255
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) else {
                throw writer.error ?? EncoderError("Could not append video frame \(frame).")
            }
        }
    }
    writer.endSession(atSourceTime: CMTime(value: Int64(count), timescale: fps))
    input.markAsFinished()
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    guard finished.wait(timeout: .now() + 60) == .success, writer.status == .completed else {
        throw writer.error ?? EncoderError("Could not finalize the video.")
    }
}

do {
    try encode()
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(EXIT_FAILURE)
}
