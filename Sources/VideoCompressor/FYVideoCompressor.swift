//
//
//
//
//

import Foundation
import AVFoundation
// sample video https://download.blender.org/demo/movies/BBB/

/// A high-performance, flexible and easy to use Video compressor library written by Swift.
/// Using hardware-accelerator APIs in AVFoundation.
public class FYVideoCompressor: VideoCompressor {
    public enum VideoCompressorError: Error, LocalizedError {
        case noVideo
        case compressedFailed(_ error: Error)
        
        public var errorDescription: String? {
            switch self {
            case .noVideo:
                return "No video"
            case .compressedFailed(let error):
                return error.localizedDescription
            }
        }
    }
    
    /// Quality configuration. VideoCompressor will compress video by decreasing fps and bitrate.
    /// Bitrate has a minimum value: `minimumVideoBitrate`, you can change it if need.
    /// The video will be compressed using H.264, audio will be compressed using AAC.
    public enum VideoQuality: Equatable {
        /// Scale video size proportionally, not large than 224p and
        /// reduce fps and bit rate if need.
        case lowQuality
        
        /// Scale video size proportionally, not large than 480p and
        /// reduce fps and bit rate if need.
        case mediumQuality
        
        /// Scale video size proportionally, not large than 1080p and
        /// reduce fps and bit rate if need.
        case highQuality
        
        /// reduce fps and bit rate if need.
        /// Scale video size with specified `scale`.
        case custom(fps: Float = 24, bitrate: Int = 1000_000, scale: CGSize)
        
        /// fps and bitrate.
        /// This bitrate value is the maximum value. Depending on the video original bitrate, the video bitrate after compressing may be lower than this value.
        /// Considering that the video size taken by mobile phones is reversed, we don't hard code scale value.
        var value: (fps: Float, bitrate: Int) {
            switch self {
            case .lowQuality:
                return (15, 250_000)
            case .mediumQuality:
                return (24, 2500_000)
            case .highQuality:
                return (30, 8000_000)
            case .custom(fps: let fps, bitrate: let bitrate, _):
                return (fps, bitrate)
            }
        }
        
    }
    
    private let group = DispatchGroup()
    private let videoCompressQueue = DispatchQueue.init(label: "com.video.compress_queue")
    private lazy var audioCompressQueue = DispatchQueue.init(label: "com.audio.compress_queue")
    private var reader: AVAssetReader?
    private var writer: AVAssetWriter?
    private var compressVideoPaths: [URL] = []
    
    static public let shared: FYVideoCompressor = FYVideoCompressor()
    
    private init() {
    }
    
    /// youtube suggests 1Mbps for 24 frame rate 360p video, 1Mbps = 1000_000bps.
    /// Custom quality will not be affected by this value.
    static public var minimumVideoBitrate = 1000 * 200
    
    /// Compress Video with config.
    public func compressVideo(inputURL: URL, outputURL: URL, config: VideoCompressionConfig, completion: @escaping (Error?) -> Void) {
        let asset = AVAsset(url: inputURL)
        // setup
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(VideoCompressorError.noVideo)
            return
        }
        
        let targetSize = calculateSizeWithScale(config.scale, originalSize: videoTrack.naturalSize)
        let videoSettings = createVideoSettingsWithBitrate(config.videoBitrate,
                                                           maxKeyFrameInterval: config.videoMaxKeyFrameInterval,
                                                           size: targetSize)
        
        var audioTrack: AVAssetTrack?
        var audioSettings: [String: Any]?
        
        if let adTrack = asset.tracks(withMediaType: .audio).first {
            audioTrack = adTrack
            audioSettings = createAudioSettingsWithAudioTrack(adTrack, bitrate: config.audioBitrate, sampleRate: config.audioSampleRate)
        }
#if DEBUG
        print("Original video size: \(inputURL.sizePerMB())M")
        print("########## Video ##########")
        print("ORIGINAL:")
        print("bitrate: \(videoTrack.estimatedDataRate) b/s")
        
        print("size: \(videoTrack.naturalSize)")
#endif
        _compress(asset: asset, outputURL: outputURL, fileType: config.fileType, videoTrack, videoSettings, audioTrack, audioSettings, targetFPS: config.fps, completion: completion)
    }
    
    public func compressVideo(inputURL: URL, outputURL: URL, config: VideoCompressionConfig) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            compressVideo(inputURL: inputURL, outputURL: outputURL, config: config) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
    
    
    /// Remove all cached compressed videos
    public func removeAllCompressedVideo() {
        compressVideoPaths.forEach {
            try? FileManager.default.removeItem(at: $0)
        }
        compressVideoPaths.removeAll()
    }
    
    // MARK: - Private methods
    private func _compress(asset: AVAsset, outputURL: URL, fileType: AVFileType, _ videoTrack: AVAssetTrack, _ videoSettings: [String: Any], _ audioTrack: AVAssetTrack?, _ audioSettings: [String: Any]?, targetFPS: Float, completion: @escaping (Error?) -> Void) {
        // video
        let videoOutput = AVAssetReaderTrackOutput.init(track: videoTrack,
                                                        outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = videoTrack.preferredTransform // fix output video orientation
        do {
            // store urls for deleting
            compressVideoPaths.append(outputURL)
            
            let reader = try AVAssetReader(asset: asset)
            let writer = try AVAssetWriter(url: outputURL, fileType: fileType)
            writer.shouldOptimizeForNetworkUse = true
            self.reader = reader
            self.writer = writer
            
            // video output
            if reader.canAdd(videoOutput) {
                reader.add(videoOutput)
                videoOutput.alwaysCopiesSampleData = false
            }
            if writer.canAdd(videoInput) {
                writer.add(videoInput)
            }
            
            // audio output
            var audioInput: AVAssetWriterInput?
            var audioOutput: AVAssetReaderTrackOutput?
            if let audioTrack = audioTrack, let audioSettings = audioSettings {
                // Specify the number of audio channels we want when decompressing the audio from the asset to avoid error when handling audio data.
                // It really matters when the audio has more than 2 channels, e.g: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
                audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVNumberOfChannelsKey: 2])
                let adInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput = adInput
                if reader.canAdd(audioOutput!) {
                    reader.add(audioOutput!)
                }
                if writer.canAdd(adInput) {
                    writer.add(adInput)
                }
            }
            
#if DEBUG
            let startTime = Date()
#endif
            
            // start compressing
            reader.startReading()
            writer.startWriting()
            writer.startSession(atSourceTime: CMTime.zero)
            
            // output video
            group.enter()
            let reduceFPS = targetFPS < videoTrack.nominalFrameRate
            if reduceFPS {
                outputVideoDataByReducingFPS(originFPS: videoTrack.nominalFrameRate,
                                             targetFPS: targetFPS,
                                             videoInput: videoInput,
                                             videoOutput: videoOutput,
                                             duration: videoTrack.asset!.duration) {
                    self.group.leave()
                }
            } else {
                outputVideoData(videoInput, videoOutput: videoOutput) {
                    self.group.leave()
                }
            }
            
            // output audio
            if let realAudioInput = audioInput, let realAudioOutput = audioOutput {
                group.enter()
                realAudioInput.requestMediaDataWhenReady(on: audioCompressQueue) {
                    while realAudioInput.isReadyForMoreMediaData {
                        if let buffer = realAudioOutput.copyNextSampleBuffer() {
                            realAudioInput.append(buffer)
                        } else {
                            //                            print("finish audio appending")
                            realAudioInput.markAsFinished()
                            self.group.leave()
                            break
                        }
                    }
                }
            }
            
            // completion
            group.notify(queue: .main) {
                switch writer.status {
                case .writing, .completed:
                    writer.finishWriting {
#if DEBUG
                        let endTime = Date()
                        let elapse = endTime.timeIntervalSince(startTime)
                        print("compression time: \(elapse)")
                        print("compressed video size: \(outputURL.sizePerMB())M")
#endif
                        DispatchQueue.main.sync {
                            completion(nil)
                        }
                    }
                default:
                    completion(writer.error!)
                }
            }
            
        } catch {
            completion(error)
        }
    }
    
    private func createVideoSettingsWithBitrate(_ bitrate: Int, maxKeyFrameInterval: Int, size: CGSize) -> [String: Any] {
        return ["AVVideoCodecKey": AVVideoCodecType.hevc,
                "AVVideoHeightKey": size.height,
                "AVVideoCompressionPropertiesKey": [
                    "AllowFrameReordering": 1,
                    "AverageBitRate": bitrate,
                    "ExpectedFrameRate": 30,
                    "Priority": 80,
                    "ProfileLevel": "HEVC_Main_AutoLevel",
                    "RealTime": 1,
                    "SoftMaxQuantizationParameter": 43,
                    "SoftMinQuantizationParameter": 18,
                ], "AVVideoWidthKey": size.width]
    }
    
    private func createAudioSettingsWithAudioTrack(_ audioTrack: AVAssetTrack, bitrate: Int, sampleRate: Int) -> [String: Any] {
#if DEBUG
        if let audioFormatDescs = audioTrack.formatDescriptions as? [CMFormatDescription], let formatDescription = audioFormatDescs.first {
            print("########## Audio ##########")
            print("ORINGIAL:")
            print("bitrate: \(audioTrack.estimatedDataRate)")
            if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                print("sampleRate: \(streamBasicDescription.pointee.mSampleRate)")
                print("channels: \(streamBasicDescription.pointee.mChannelsPerFrame)")
                print("formatID: \(streamBasicDescription.pointee.mFormatID)")
            }
            
            print("TARGET:")
            print("bitrate: \(bitrate)")
            print("sampleRate: \(sampleRate)")
            print("channels: \(2)")
            print("formatID: \(kAudioFormatMPEG4AAC)")
        }
#endif
        
        var audioChannelLayout = AudioChannelLayout()
        memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: bitrate,
            AVNumberOfChannelsKey: 2,
            AVChannelLayoutKey: Data(bytes: &audioChannelLayout, count: MemoryLayout<AudioChannelLayout>.size)
        ]
    }
    
    private func outputVideoDataByReducingFPS(originFPS: Float,
                                              targetFPS: Float,
                                              videoInput: AVAssetWriterInput,
                                              videoOutput: AVAssetReaderTrackOutput,
                                              duration: CMTime,
                                              completion: @escaping(() -> Void)) {
        let randomFrames = getFrameIndexesWith(originalFPS: originFPS, targetFPS: targetFPS, duration: Float(duration.seconds))
        var counter = 0
        var index = 0
        
        videoInput.requestMediaDataWhenReady(on: videoCompressQueue) {
            while videoInput.isReadyForMoreMediaData {
                if let buffer = videoOutput.copyNextSampleBuffer() {
                    // append first frame
                    if index < randomFrames.count {
                        let frameIndex = randomFrames[index]
                        if counter == frameIndex {
                            index += 1
                            let timingInfo = UnsafeMutablePointer<CMSampleTimingInfo>.allocate(capacity: 1)
                            let newSample = UnsafeMutablePointer<CMSampleBuffer?>.allocate(capacity: 1)
                            
                            // Should check call succeeded
                            CMSampleBufferGetSampleTimingInfo(buffer, at: 0, timingInfoOut: timingInfo)
                            
                            // timingInfo.pointee.duration is 0
                            timingInfo.pointee.duration = CMTimeMultiplyByFloat64(timingInfo.pointee.duration, multiplier: Float64(originFPS/targetFPS))
                            
                            // Again, should check call succeeded
                            CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: buffer, sampleTimingEntryCount: 1, sampleTimingArray: timingInfo, sampleBufferOut: newSample)
                            videoInput.append(newSample.pointee!)
                            // deinit
                            newSample.deinitialize(count: 1)
                            newSample.deallocate()
                            timingInfo.deinitialize(count: 1)
                            timingInfo.deallocate()
                        }
                        counter += 1
                    } else {
                        break
                    }
                } else {
                    //                    print("counter: \(counter)")
                    videoInput.markAsFinished()
                    completion()
                    break
                }
            }
        }
    }
    
    func outputVideoData(_ videoInput: AVAssetWriterInput,
                         videoOutput: AVAssetReaderTrackOutput,
                         completion: @escaping(() -> Void)) {
        // Loop Video Frames
        videoInput.requestMediaDataWhenReady(on: videoCompressQueue) {
            while videoInput.isReadyForMoreMediaData {
                if let vBuffer = videoOutput.copyNextSampleBuffer(), CMSampleBufferDataIsReady(vBuffer) {
                    videoInput.append(vBuffer)
                } else {
                    videoInput.markAsFinished()
                    completion()
                    break
                }
            }
        }
    }
    
    // MARK: - Calculation
    func getVideoBitrateWithQuality(_ quality: VideoQuality, originalBitrate: Int) -> Int {
        var targetBitrate = quality.value.bitrate
        if originalBitrate < targetBitrate {
            switch quality {
            case .lowQuality:
                targetBitrate = originalBitrate/8
                targetBitrate = max(targetBitrate, Self.minimumVideoBitrate)
            case .mediumQuality:
                targetBitrate = originalBitrate/4
                targetBitrate = max(targetBitrate, Self.minimumVideoBitrate)
            case .highQuality:
                targetBitrate = originalBitrate/2
                targetBitrate = max(targetBitrate, Self.minimumVideoBitrate)
            case .custom(_, _, _):
                break
            }
        }
        return targetBitrate
    }
    
    func calculateSizeWithQuality(_ quality: VideoQuality, originalSize: CGSize) -> CGSize {
        let originalWidth = originalSize.width
        let originalHeight = originalSize.height
        let isRotated = originalHeight > originalWidth // videos captured by mobile phone have rotated size.
        
        var threshold: CGFloat = -1
        
        switch quality {
        case .lowQuality:
            threshold = 224
        case .mediumQuality:
            threshold = 480
        case .highQuality:
            threshold = 1080
        case .custom(_, _, let scale):
            return scale
        }
        
        var targetWidth: CGFloat = originalWidth
        var targetHeight: CGFloat = originalHeight
        if !isRotated {
            if originalHeight > threshold {
                targetHeight = threshold
                targetWidth = threshold * originalWidth / originalHeight
            }
        } else {
            if originalWidth > threshold {
                targetWidth = threshold
                targetHeight = threshold * originalHeight / originalWidth
            }
        }
        return CGSize(width: Int(targetWidth), height: Int(targetHeight))
    }
    
    func calculateSizeWithScale(_ scale: CGSize?, originalSize: CGSize) -> CGSize {
        guard let scale = scale else {
            return originalSize
        }
        if scale.width == -1 && scale.height == -1 {
            return originalSize
        } else if scale.width != -1 && scale.height != -1 {
            return scale
        } else {
            var targetWidth: Int = Int(scale.width)
            var targetHeight: Int = Int(scale.height)
            if scale.width == -1 {
                targetWidth = Int(scale.height * originalSize.width / originalSize.height)
            } else {
                targetHeight = Int(scale.width * originalSize.height / originalSize.width)
            }
            return CGSize(width: targetWidth, height: targetHeight)
        }
    }
    
    /// Randomly drop some indexes to get final frames indexes
    ///
    /// 1. Calculate original frames and target frames
    /// 2. Divide the range (0, `originalFrames`) into `targetFrames` parts equaly, eg., divide range 0..<9 into 3 parts: 0..<3, 3..<6. 6..<9
    /// 3.
    ///
    /// - Parameters:
    ///   - originFPS: original video fps
    ///   - targetFPS: target video fps
    /// - Returns: frame indexes
    func getFrameIndexesWith(originalFPS: Float, targetFPS: Float, duration: Float) -> [Int] {
        assert(originalFPS > 0)
        assert(targetFPS > 0)
        let originalFrames = Int(originalFPS * duration)
        let targetFrames = Int(ceil(Float(originalFrames) * targetFPS / originalFPS))
        
        //
        var rangeArr = Array(repeating: 0, count: targetFrames)
        for i in 0..<targetFrames {
            rangeArr[i] = Int(ceil(Double(originalFrames) * Double(i+1) / Double(targetFrames)))
        }
        
        var randomFrames = Array(repeating: 0, count: rangeArr.count)
        
#if DEBUG
        //        defer {
        //            print("originFrames: \(originalFrames)")
        //            print("targetFrames: \(targetFrames)")
        //
        //            print("range arr: \(rangeArr)")
        //            print("range arr count: \(rangeArr.count)")
        //
        //            print("randomFrames: \(randomFrames)")
        //            print("randomFrames count: \(randomFrames.count)")
        //        }
#endif
        guard !randomFrames.isEmpty else {
            return []
        }
        
        // first frame
        // avoid droping the first frame
        guard randomFrames.count > 1 else {
            return randomFrames
        }
        
        for index in 1..<rangeArr.count {
            let pre = rangeArr[index-1]
            let res = Int.random(in: pre..<rangeArr[index])
            randomFrames[index] = res
        }
        return randomFrames
    }
}
