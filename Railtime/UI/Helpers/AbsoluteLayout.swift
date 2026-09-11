//
//  AbsoluteLayout.swift
//  Railtime
//
//  Created by Kai Quan Tay on 9/9/26.
//

import SwiftUI

nonisolated struct AbsoluteOffset {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Angle = .zero
}

nonisolated struct AbsoluteOffsetKey: LayoutValueKey { static let defaultValue: AbsoluteOffset = .init() }

extension View {
    func fanOffset(x: CGFloat = 0, y: CGFloat = 0, angle: Angle = .zero) -> some View {
        self
            .layoutValue(key: AbsoluteOffsetKey.self, value: .init(x: x, y: y, angle: angle))
            .rotationEffect(angle * -1, anchor: .bottomLeading) // swiftui uses clockwise = positive, math uses anticlockwise = positive
    }
}

struct AbsoluteLayout: Layout {
    func makeCache(subviews: Subviews) -> CGRect {
        var minX: CGFloat = .infinity
        var minY: CGFloat = .infinity
        var maxX: CGFloat = .infinity * -1
        var maxY: CGFloat = .infinity * -1

        for subview in subviews {

            let size = subview.sizeThatFits(.unspecified)
            let offsets = subview[AbsoluteOffsetKey.self]

            let w = size.width
            let h = size.height

            // See https://www.desmos.com/calculator/sh1ebkwpri for the math behind these operations
            // note that these are obtained in a "positive y = up" frame of reference, but iOS uses "positive y = down".
            // we will flip these in `placeSubviews`.
            minX = min(minX, offsets.x - h * cos(offsets.angle.radians))
            maxX = max(maxX, offsets.x + w * cos(offsets.angle.radians))
            minY = min(minY, offsets.y)
            maxY = max(maxY, offsets.y + w * sin(offsets.angle.radians) + h * cos(offsets.angle.radians))
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    typealias Cache = CGRect

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CGRect) -> CGSize {
        return cache.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CGRect) {
        for subview in subviews {

            let size = subview.sizeThatFits(.unspecified)
            let offsets = subview[AbsoluteOffsetKey.self]

            let w = size.width
            let h = size.height

            // See https://www.desmos.com/calculator/sh1ebkwpri for the math behind these operations
            // note that these are obtained in a "positive y = up" frame of reference, but iOS uses "positive y = down".
            // we will flip these in `placeSubviews`.
            let minX = offsets.x - h * cos(offsets.angle.radians)
//            let maxX = offsets.x + w * cos(offsets.angle.radians)
            let minY = offsets.y
//            let maxY = offsets.y + w * sin(offsets.angle.radians) + h * cos(offsets.angle.radians)

            subview.place(
                at: .init(
                    x: minX - cache.minX,
                    y: cache.maxY - minY - h
                ),
                proposal: .init(
                    width: w,
                    height: h
                )
            )
        }
    }
}
