//
//  NotesCheckbox.swift
//  Notes
//
//  Created by laishere on 2023/8/15.
//

import UIKit

class NotesCheckbox: UIButton {
    
    var boundsSize: CGSize = .zero
    private let iconSize = 20.0
    private let iconPadding = 10.0

    init() {
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        setImage(UIImage(systemName: "circle")?.withTintColor(.systemGray3, renderingMode: .alwaysOriginal), for: .normal)
        setImage(UIImage(systemName: "checkmark.circle.fill")?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal), for: .selected)
        addTarget(self, action: #selector(toggleSelect), for: .touchUpInside)
//        configuration = .plain()
        contentHorizontalAlignment = .fill
        contentVerticalAlignment = .fill
//        backgroundColor = .systemGray6
    }
    
    @objc func toggleSelect(_ sender: Any?) {
        isSelected = !isSelected
    }
}


extension NotesCheckbox : RichTextAttachmentView {
    func attachmentBind(_ attachment: RichTextAttachment) {
    }
    
    func attachmentBounds(for lineFrag: CGRect, padding: UIEdgeInsets) -> CGRect {
        let width = padding.left + iconSize + iconPadding
        let height = iconSize
        imageEdgeInsets = .init(top: 0, left: padding.left, bottom: 0, right: iconPadding)
        boundsSize = CGSize(width: width, height: height)
        return .zero// 此处返回0，不占用文本大小，由TextContainer预留实际空间
    }
    
    func attachmentLayout(bounds: CGRect, lineFragment: UnsafeMutablePointer<CGRect>, lineFragmentUsed: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>) {
        let lineRect = lineFragmentUsed.pointee
        // y值最好通过字体大小确定
        frame = CGRect(x: 0, y: lineRect.minY + boundsSize.height * 0.3, width: boundsSize.width, height: boundsSize.height)
        superview?.setNeedsDisplay(frame)
    }
}
