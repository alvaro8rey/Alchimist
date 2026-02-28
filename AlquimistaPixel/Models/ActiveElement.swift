// MARK: - Chromancy/Models/ActiveElement.swift
import Foundation

struct ActiveElement: Identifiable, Codable {
    let id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var position: CGPoint
}
