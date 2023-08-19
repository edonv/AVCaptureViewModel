//
//  AVCaptureDeviceDiscoverySession+Extension.swift
//  
//
//  Created by Edon Valdman on 8/17/23.
//

import Foundation
import AVFoundation

extension AVCaptureDevice.DiscoverySession {
    internal var uniqueDevicePositionsCount: Int {
        var uniqueDevicePositions = [AVCaptureDevice.Position]()
        
        for device in devices where !uniqueDevicePositions.contains(device.position) {
            uniqueDevicePositions.append(device.position)
        }
        
        return uniqueDevicePositions.count
    }
}
