//
//  RichTextAttachment.swift
//  Notes
//
//  Created by laishere on 2023/11/20.
//

import UIKit

@objc
protocol RichTextAttachmentView {
    @objc optional func attachmentBind(_ attachment: RichTextAttachment)
    func attachmentBounds(for lineFrag: CGRect, padding: UIEdgeInsets) -> CGRect
    func attachmentLayout(bounds: CGRect, lineFragment: UnsafeMutablePointer<CGRect>, lineFragmentUsed: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>)
    @objc optional func attachmentRequireBeginEditing()
    @objc optional func attachmentRequireEndEditing()
}

protocol RichTextAttachmentDelegate: AnyObject {
    func attachmentDidBeginEditing(_ attachment: RichTextAttachment)
    func attachmentDidEndEditing(_ attachment: RichTextAttachment)
}

class RichTextAttachment: NSTextAttachment {
    
    static let string = String(UnicodeScalar(character)!)
    
    let view: RichTextAttachmentView
    let type: RichTextAttachmentType
    weak var deleagte: RichTextAttachmentDelegate? = nil
    private var charIndex: Int? = nil
    private weak var layoutManager: NSLayoutManager? = nil
    
    init(view: RichTextAttachmentView, type: RichTextAttachmentType) {
        self.view = view
        self.type = type
        super.init(data: nil, ofType: nil)
        view.attachmentBind?(self)
    }
    
    func remove() {
        (view as? UIView)?.removeFromSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        return nil
    }
    
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        self.charIndex = charIndex
        self.layoutManager = textContainer?.layoutManager
        let horizontalPadding = textContainer?.lineFragmentPadding ?? 0.0
        let verticalPadding = 0.0
        let padding = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
        bounds = view.attachmentBounds(for: lineFrag, padding: padding)
        return bounds
    }
    
    func invalidateLayout() {
        if let index = charIndex, let layoutManager = layoutManager {
            layoutManager.invalidateLayout(forCharacterRange: NSRange(location: index, length: 1), actualCharacterRange: nil)
        }
    }
    
    func updateLayout(lineFragment: UnsafeMutablePointer<CGRect>, lineFragmentUsed: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>) {
        view.attachmentLayout(bounds: bounds, lineFragment: lineFragment, lineFragmentUsed: lineFragmentUsed, baselineOffset: baselineOffset)
    }
    
    func requireBeginEditing() {
        view.attachmentRequireBeginEditing?()
    }
    
    func requireEndEditing() {
        view.attachmentRequireEndEditing?()
    }
    
    func didBeginEditing() {
        deleagte?.attachmentDidBeginEditing(self)
    }
    
    func didEndEditing() {
        deleagte?.attachmentDidEndEditing(self)
    }
}
