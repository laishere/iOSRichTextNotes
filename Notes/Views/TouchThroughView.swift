//
//  TouchThroughView.swift
//  Notes
//
//  Created by laishere on 2023/8/15.
//

import UIKit

class TouchThroughView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}
