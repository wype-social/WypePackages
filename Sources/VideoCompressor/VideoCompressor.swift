//
//  VideoCompressor.swift
//  Wype
//
//  Created by Tadreik Campbell on 2/24/22.
//

import UIKit

public protocol VideoCompressor {
    func compressVideo(inputURL: URL, outputURL: URL, config: VideoCompressionConfig) async throws
}
