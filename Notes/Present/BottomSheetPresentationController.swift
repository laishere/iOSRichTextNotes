//
//  BottomSheetPresentationController.swift
//  Notes
//
//  Created by laishere on 2023/8/7.
//

import UIKit

/// 仿官方的BottomSheet效果，因为官方的需要16.0+版本才支持自定义高度
class BottomSheetPresentationController: UIPresentationController, CAAnimationDelegate {
    
    var cornerRadius = 10.0
    
    private var wrapper: UIView!
    private var contentWrapper: UIView!
    private var dropShadowView: UIView!
    private var idle = true
    private var isClosing = false
    
    override var presentedView: UIView? {
        return wrapper
    }
    
    private var prefferedHeight: CGFloat {
        return presentedViewController.preferredContentSize.height
    }
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        wrapper = UIView()
        wrapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wrapper.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDragging)))
        contentWrapper = UIView()
        contentWrapper.backgroundColor = .systemBackground
        contentWrapper.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentWrapper.clipsToBounds = true
        dropShadowView = UIView()
        dropShadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wrapper.addSubview(dropShadowView)
        wrapper.addSubview(contentWrapper)
        let view = presentedViewController.view!
        view.frame = .zero // 重要
        view.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        contentWrapper.addSubview(view)
        configShadow()
        updateAppearence()
    }

    private func updateAppearence() {
        contentWrapper.layer.cornerRadius = cornerRadius
        dropShadowView.layer.cornerRadius = cornerRadius
    }
    
    private func configShadow() {
        dropShadowView.backgroundColor = .systemGray4
        dropShadowView.layer.shadowColor = UIColor.black.cgColor
        dropShadowView.layer.shadowRadius = 4.0
        dropShadowView.layer.shadowOffset = CGSize(width: 2, height: 2)
        dropShadowView.layer.shadowOpacity = 0.2
    }
    
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        if (!idle) {
            return
        }
        updateHeight(heightOffset: 0.0)
    }
    
    private func updateHeight(heightOffset: CGFloat) {
        guard let containerView = containerView, let window = containerView.window else {
            return
        }
        let contentHeight = prefferedHeight
        let marginBottom = containerView.safeAreaInsets.bottom
        let height = contentHeight + marginBottom + max(heightOffset, 0.0)
        let y = window.frame.height - height + max(-heightOffset, 0.0)
        containerView.frame.size.height = height
        containerView.frame.origin.y = y
        presentedViewController.view.frame.size.height = height - marginBottom
    }
    
    /// 拖动结束
    private func settle(velocity: CGPoint) {
        guard let containerView = containerView, let window = containerView.window else {
            idle = true
            return
        }
        let visibleHeight = window.frame.height - containerView.frame.minY - containerView.safeAreaInsets.bottom
        let visibleRatio = visibleHeight / prefferedHeight
        let shouldClose = (visibleRatio < 1.0 / 3.0 && velocity.y > -10.0) || (visibleRatio < 1.0 && velocity.y > 500.0)
        if (shouldClose) {
//            print("closing")
            isClosing = true
            presentedViewController.dismiss(animated: true)
        } else {
            let contentHeight = prefferedHeight
            let marginBottom = containerView.safeAreaInsets.bottom
            let height = contentHeight + marginBottom
            let y = window.frame.height - height
            let newFrame = CGRect(x: 0, y: y, width: containerView.frame.width, height: height)
            let oldPos = containerView.layer.position
            let newPos = CGPoint(x: newFrame.midX, y: newFrame.midY)
            let newSize = newFrame.size
            let spd = max(0, visibleHeight < prefferedHeight ? -velocity.y : velocity.y)
            let posAnim = CASpringAnimation(keyPath: "position")
            posAnim.damping = 30
            posAnim.stiffness = 333
            let dy = newPos.y - oldPos.y
            posAnim.initialVelocity = min(50.0, spd * 0.1 / abs(dy))
            let expectedDuration = 0.5
            posAnim.damping *= posAnim.settlingDuration / expectedDuration
            posAnim.duration = posAnim.settlingDuration
            posAnim.fillMode = .both
            posAnim.isRemovedOnCompletion = false
            let sizeAnim = posAnim.copy() as! CASpringAnimation
            sizeAnim.keyPath = "bounds.size"
            posAnim.fromValue = oldPos
            posAnim.toValue = newPos
            sizeAnim.fromValue = containerView.layer.bounds.size
            sizeAnim.toValue = newSize
            sizeAnim.delegate = self
            CATransaction.begin()
            // 提前让它到达目标位置，这样才可以正常处理事件，如果中途停止那么再更新为最新值
            containerView.layer.position = newPos
            containerView.layer.bounds.size = newSize
            containerView.layer.add(posAnim, forKey: "pos")
            containerView.layer.add(sizeAnim, forKey: "size")
            CATransaction.commit()
//            dump(posAnim)
        }
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//        print("anim stop ", flag)
        removeAnim()
        idle = false
        if (isClosing) {
            presentedViewController.dismiss(animated: false)
        }
    }
    
    private func removeAnim() {
        saveAnimState()
        containerView?.layer.removeAllAnimations()
    }
    
    /// 同步动画展现层的属性到实际层
    private func saveAnimState() {
        guard let containerView = containerView else {
            return
        }
        let layer = containerView.layer
        let presentation = layer.presentation() ?? layer
        layer.position = presentation.position
        layer.bounds = presentation.bounds
    }
    
    private var downPoint: CGPoint = .zero
    @objc func handleDragging(_ recoginzer: UIPanGestureRecognizer) {
        if (isClosing) {
            return
        }
        let point = recoginzer.location(in: wrapper.window)
        if (recoginzer.state == .began) {
            downPoint = point
            removeAnim()
            idle = false
        } else if (recoginzer.state == .changed) {
            let t = point.y - downPoint.y
            let offsetScale = 100.0
            let offset = t < 0 ? (1 - exp(t / offsetScale * 0.5)) * offsetScale : -t
//            print("move: ", offset)
            updateHeight(heightOffset: offset)
        } else {
            let v = recoginzer.velocity(in: wrapper.window)
//            print("v: \(v)", recoginzer.state.rawValue)
            settle(velocity: v)
        }
    }
}
