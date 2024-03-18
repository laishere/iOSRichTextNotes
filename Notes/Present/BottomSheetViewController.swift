//
//  BottomSheetViewController.swift
//  Notes
//
//  Created by laishere on 2023/8/8.
//

import UIKit

class BottomSheetViewController: UIViewController, UIViewControllerTransitioningDelegate {
    
    weak var delegate: BottomSheetViewControllerDelegate? = nil
    
    init() {
        super.init(nibName: nil, bundle: nil)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }
    
    func setContentView(_ view: UIView, height: CGFloat) {
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        preferredContentSize.height = height
        self.view.addSubview(view)
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return BottomSheetPresentationController(presentedViewController: presented, presenting: presenting)
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        delegate?.bottomSheetWillDismiss?()
        super.dismiss(animated: flag, completion: completion)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if (isBeingDismissed) {
            delegate?.bottomSheetDidDismiss?()
        }
    }
}

@objc protocol BottomSheetViewControllerDelegate {
    @objc optional func bottomSheetWillDismiss()
    @objc optional func bottomSheetDidDismiss()
}
