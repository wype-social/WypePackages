//
//  CompressionConfig.swift
//  Wype
//
//  Created by Tadreik Campbell on 2/24/22.
//

import AVFoundation


public protocol VideoCompressionConfig {
    var videoBitrate: Int { get set }
    var videoMaxKeyFrameInterval: Int { get set }
    var fps: Float { get set }
    var audioSampleRate: Int { get set }
    var audioBitrate: Int { get set }
    var fileType: AVFileType { get set }
    var scale: CGSize? { get set }
}

// Compression Encode Parameters
public struct FYVideoCompressionConfig: VideoCompressionConfig {
    // video
    public var videoBitrate: Int // bitrate use 1000 for 1kbps.https://en.wikipedia.org/wiki/Bit_rate
    
    public var videoMaxKeyFrameInterval: Int // A key to access the maximum interval between keyframes. 1 means key frames only, H.264 only
    
    public var fps: Float // If video's fps less than this value, this value will be ignored.
    
    // audio
    public var audioSampleRate: Int
    
    public var audioBitrate: Int
    
    public var fileType: AVFileType
    
    /// Scale (resize) the input video
    /// 1. If you need to simply resize your video to a specific size (e.g 320×240), you can use the scale: CGSize(width: 320, height: 240)
    /// 2. If you want to keep the aspect ratio, you need to specify only one component, either width or height, and set the other component to -1
    ///    e.g CGSize(width: 320, height: -1)
    public var scale: CGSize?
    
    /// size: nil
    /// videoBitrate: 1Mbps
    /// videomaxKeyFrameInterval: 10
    /// audioSampleRate: 44100
    /// audioBitrate: 128_000
    /// fileType: mp4
    public static let `default` = FYVideoCompressionConfig(
        videoBitrate: 1000_000,
        videoMaxKeyFrameInterval: 10,
        fps: 24,
        audioSampleRate: 44100,
        audioBitrate: 128_000,
        fileType: .mp4,
        scale: nil
    )
    
    public init(videoBitrate: Int, videoMaxKeyFrameInterval: Int, fps: Float, audioSampleRate: Int, audioBitrate: Int, fileType: AVFileType, scale: CGSize? = nil) {
        self.videoBitrate = videoBitrate
        self.videoMaxKeyFrameInterval = videoMaxKeyFrameInterval
        self.fps = fps
        self.audioSampleRate = audioSampleRate
        self.audioBitrate = audioBitrate
        self.fileType = fileType
        self.scale = scale
    }
}
