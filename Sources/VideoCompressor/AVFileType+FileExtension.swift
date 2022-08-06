//
//  AVFileType.swift
//  
//
//  Created by xiaoyang on 2021/11/11.
//

import Foundation
import AVFoundation

extension AVFileType {
    /// Fetch and extension for a file from UTI string
    var fileExtension: String {
        if let utType = UTType(self.rawValue) {
            print("utType.preferredMIMEType: \(String(describing: utType.preferredMIMEType))")
            return utType.preferredFilenameExtension ?? "None"
        }
        return "None"
    }
}
