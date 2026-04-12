//
//  Item.swift
//  GitPulse
//
//  Created by Anthony Grimaldi on 4/12/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
