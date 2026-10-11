//
//  HostingAnnotationView.swift
//  Railtime
//
//  Created by Kai Quan Tay on 11/10/26.
//

import MapKit
import SwiftUI

@MainActor
final class HostingAnnotationView: MKAnnotationView {

    private var hostingController: UIHostingController<AnyView>?

    private var lastSize: CGSize = .zero
    private var isUpdatingSize = false

    override init(
        annotation: MKAnnotation?,
        reuseIdentifier: String?
    ) {
        super.init(
            annotation: annotation,
            reuseIdentifier: reuseIdentifier
        )

        backgroundColor = .clear
        canShowCallout = true
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure<Content: View>(
        annotation: MKAnnotation,
        @ViewBuilder content: () -> Content
    ) {
        self.annotation = annotation

        let rootView = AnyView(content())

        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let controller = UIHostingController(rootView: rootView)
            controller.view.backgroundColor = .clear
            controller.view.isOpaque = false
            controller.view.translatesAutoresizingMaskIntoConstraints = true
            controller.sizingOptions = [.intrinsicContentSize]

            self.hostingController = controller
            addSubview(controller.view)
        }

        // Do not measure using the previous annotation's bounds.
        lastSize = .zero
        bounds = .zero

        setNeedsLayout()
        layoutIfNeeded()
        updateSize()
    }

    private func updateSize() {
        guard !isUpdatingSize,
              let hostingController else {
            return
        }

        isUpdatingSize = true
        defer { isUpdatingSize = false }

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let size = hostingController.sizeThatFits(
            in: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )

        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0 else {
            return
        }

        guard size != lastSize else {
            return
        }

        lastSize = size

        // The annotation's size is independent of its previous frame.
        bounds = CGRect(origin: .zero, size: size)
        hostingController.view.frame = bounds

        // Anchor the bottom center at the geographic coordinate.
        centerOffset = CGPoint(x: 0, y: -size.height / 2)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        hostingController?.view.frame = bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        annotation = nil
        lastSize = .zero
        bounds = .zero
        centerOffset = .zero
        hostingController?.view.frame = .zero
        canShowCallout = true
    }
}
