// MARK: - Models/DiscoveredElement.swift
import Foundation
import SwiftData

@Model
final class DiscoveredElement {
    @Attribute(.unique) var name: String
    var emoji: String
    var colorHex: String
    var discoveryDate: Date
    
    init(name: String, emoji: String, colorHex: String) {
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.discoveryDate = Date()
    }
}
