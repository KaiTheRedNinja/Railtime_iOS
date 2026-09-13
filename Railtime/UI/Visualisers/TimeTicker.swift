//
//  TimeTicker.swift
//  Railtime
//
//  Created by Kai Quan Tay on 13/9/26.
//

import SwiftUI

// NOTE: currently assumes that "now" is located at (0, 0)
struct TimeTicker: View {
    var verticalScale: CGFloat
    var horizontalScale: CGFloat

    var ttGraphSize: CGSize
    var scrollPosition: CGPoint

    var minutes: Int

    var body: some View {
        let xOffset = min(ttGraphSize.width, CGFloat(minutes) * horizontalScale - scrollPosition.x - scrollPosition.y * horizontalScale / verticalScale)
        let yOffset = max(0, (CGFloat(minutes) - (ttGraphSize.width + scrollPosition.x)/horizontalScale) * verticalScale - scrollPosition.y)

        let isNow = minutes == 0

        ZStack(alignment: .bottomLeading) {
            let strokeColor = isNow ? Color.green : Color.gray

            Path { path in
                path.move(to: .init(x: 0, y: CGFloat(minutes) * verticalScale - scrollPosition.y - scrollPosition.x * verticalScale / horizontalScale))
                path.addLine(to: .init(x: xOffset, y: yOffset))
            }
            .stroke(
                strokeColor,
                style: isNow
                ? .init(lineWidth: 2, lineCap: .round, lineJoin: .round, miterLimit: 0)
                : .init(lineWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 0, dash: [5, 5], dashPhase: 0)
            )
            .frame(width: ttGraphSize.width, height: ttGraphSize.height)
            .mask {
                Rectangle().ignoresSafeArea()
            }

            Path { path in
                path.move(to: .init(x: xOffset, y: yOffset + Sizing.timeTickerLabelsHeight))

                if yOffset > 0 { // if there is a y-offset, draw a horizontal line
                    path.addLine(to: .init(x: ttGraphSize.width + Sizing.timeTickerLabelsWidth/2, y: yOffset + Sizing.timeTickerLabelsHeight))
                } else { // else, draw a vertical line
                    path.addLine(to: .init(x: xOffset, y: Sizing.timeTickerLabelsHeight/2))
                }
            }
            .stroke(strokeColor, lineWidth: 1)
            .frame(
                width: ttGraphSize.width + Sizing.timeTickerLabelsWidth,
                height: ttGraphSize.height + Sizing.timeTickerLabelsHeight
            )
            //            .clipShape(Rectangle())
        }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .bottomLeading) {
                Text(isNow ? "now" : "\(minutes)m")
                    .font(.caption)
                    .offset(x: xOffset, y: yOffset)
            }
            .padding(3)
            .frame(height: Sizing.timeTickerLabelsHeight)
        }
        .opacity(isNow ? 1 : 0.5)
    }
}
