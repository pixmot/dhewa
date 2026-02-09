//
//  ViewExtension.swift
//  xpenz
//
//  Created by Rafael Soh on 16/5/22.
//

import Foundation
import SwiftUI
import UIKit
#if canImport(ObjectiveC)
    import ObjectiveC
#endif

#if canImport(UIKit)
    extension View {
        func hideKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
#endif

extension View {
    @ViewBuilder func scrollEnabled(_ enabled: Bool) -> some View {
        if enabled {
            self
        } else {
            simultaneousGesture(DragGesture(minimumDistance: 0),
                                including: .all)
        }
    }
}

extension HorizontalAlignment {
    struct MoneySubtitle: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            d[.top]
        }
    }

    static let moneySubtitle = HorizontalAlignment(MoneySubtitle.self)
}

private var popGestureDelegateKey: UInt8 = 0

private final class InteractivePopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        let delegate = InteractivePopGestureDelegate(navigationController: self)
        interactivePopGestureRecognizer?.delegate = delegate
        objc_setAssociatedObject(self, &popGestureDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

class Utilities {
    @AppStorage("colourScheme") var selectedAppearance = 0
    var userInterfaceStyle: ColorScheme? = .dark

    func overrideDisplayMode() {
        var userInterfaceStyle: UIUserInterfaceStyle

        if selectedAppearance == 2 {
            userInterfaceStyle = .dark
        } else if selectedAppearance == 1 {
            userInterfaceStyle = .light
        } else {
            userInterfaceStyle = .unspecified
        }

        (UIApplication.shared.connectedScenes.first as?
            UIWindowScene)?.windows.first!.overrideUserInterfaceStyle = userInterfaceStyle
    }
}
