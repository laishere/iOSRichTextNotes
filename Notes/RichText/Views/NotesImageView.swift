//
//  NotesImageView.swift
//  Notes
//
//  Created by laishere on 2023/11/13.
//

import UIKit

class NotesImageView: UIImageView {
    private weak var attachment: RichTextAttachment? = nil
    
    override init(image: UIImage?) {
        super.init(image: image)
        layer.cornerRadius = 15.0
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
}

extension NotesImageView : RichTextAttachmentView {
    func attachmentBind(_ attachment: RichTextAttachment) {
        self.attachment = attachment
    }
    
    func attachmentBounds(for lineFrag: CGRect, padding: UIEdgeInsets) -> CGRect {
        guard let image = image else {
            return .zero
        }
        let size = image.size
        if size.height == 0.0 {
            return .zero
        }
        let ratio = size.width / size.height
        let width = lineFrag.width - padding.left - padding.right
        let height = width / ratio
        return CGRect(x: padding.left, y: 0, width: width, height: height)
    }
    
    func attachmentLayout(bounds: CGRect, lineFragment: UnsafeMutablePointer<CGRect>, lineFragmentUsed: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>) {
        frame = CGRect(x: bounds.minX, y: lineFragment.pointee.minY, width: bounds.width, height: bounds.height)
    }
    
    override func setNeedsLayout() {
        attachment?.invalidateLayout()
    }
}
