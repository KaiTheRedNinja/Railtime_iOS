//
//  Utils.swift
//  Railtime
//
//  Created by Kai Quan Tay on 11/10/26.
//

import SwiftUI

extension Color {
    init(rgb hexString: String, fallback: Color = .clear) {
        let hex = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard hex.count == 6,
              let value = UInt64(hex, radix: 16) else {
            self = fallback
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }
}

extension UIColor {
    convenience init(rgb hexString: String, fallback: UIColor = .clear) {
        let hex = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard hex.count == 6,
              let value = UInt64(hex, radix: 16) else {
            self.init(cgColor: fallback.cgColor)
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
