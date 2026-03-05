// MARK: - Models/DiscoveredElement.swift
import Foundation
import SwiftData

@Model
final class DiscoveredElement {
    @Attribute(.unique) var name: String
    var emoji: String
    var colorHex: String
    var discoveryDate: Date
    var creatorName: String = ""

    init(name: String, emoji: String, colorHex: String, discoveryDate: Date = Date()) {
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.discoveryDate = discoveryDate
    }
}
