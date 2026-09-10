//
//  OffsetScrollView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 10/9/26.
//

import SwiftUI

struct OffsetScrollView<Content: View>: View {
    @State private var offset = CGPoint.zero

    var axes: Axis.Set
    var showsIndicators: Bool
    var content: (CGPoint) -> Content

    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: @escaping (CGPoint) -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            VStack {
                content(offset)
            }
            .background(
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .named("scroll")).origin
                    Color.clear.preference(
                        key: ViewOffsetKey.self,
                        value: .init(x: -frame.x, y: -frame.y)
                    )
                }
            )
            .onPreferenceChange(ViewOffsetKey.self) {
                offset = $0
            }
        }
        .coordinateSpace(name: "scroll")
    }
}

struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGPoint
    static var defaultValue = CGPoint.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        let next = nextValue()
        value.x += next.x
        value.y += next.y
    }
}
