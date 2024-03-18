//
//  NotesView.swift
//  Notes
//
//  Created by laishere on 2023/8/6.
//

import UIKit

class NotesView: UIView {
    
    weak var notesViewDelegate: NotesViewDelegate? = nil
    var ignoreSelectionChange = false
    private var editingMainContent = true
    private(set) var textView: UITextView!
    private let editor = RichTextEditor()
    var textFormat: TextFormat {
        editor.currentFormat
    }
    private let logger = Logger(type: NotesView.self)
    private weak var editingAttachment: RichTextAttachment? = nil
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        let layoutManager = NSLayoutManager()
        let textContainer = NotesViewTextContainer()
        layoutManager.addTextContainer(textContainer)
        editor.textStorage.addLayoutManager(layoutManager)
        textView = UITextView(frame: bounds, textContainer: textContainer)
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(textView)
        textView.tintColor = .systemBrown
        textView.textContainer.lineFragmentPadding = 20.0
        textView.delegate = self
        textView.layoutManager.delegate = self
        textView.textContainerInset = .zero
        textView.clipsToBounds = false
        editor.delegate = self
    }
    
    func forceUpdateSelectedRange() {
        // 强制更新光标
        ignoreSelectionChange = true
        let oldRange = textView.selectedRange
        textView.selectedRange = NSRange(location: (oldRange.location + 1) % max(1, textView.text.count), length: 0)
        textView.selectedRange = NSRange(location: (oldRange.location + 1) % max(1, textView.text.count), length: 0)
        textView.selectedRange = oldRange
        ignoreSelectionChange = false
    }
    
    func disableInput() {
        textView.inputView = UIView()
    }
    
    func enableInput() {
        textView.inputView = nil
    }
    
    func insertTable() {
        editor.insertTable()
    }
    
    func insertImage(_ image: UIImage) {
        editor.insertImage(image)
    }
    
    func setTextType(_ type: TextType) {
        editor.setTextType(type)
    }
    
    func addTextStyle(_ style: TextStyle) {
        editor.addTextStyle(style)
    }
    
    func removeTextStyle(_ style: TextStyle) {
        editor.removeTextStyle(style)
    }
    
    private func updateEditingMainContent(_ editing: Bool) {
        if (editingMainContent == editing) {
            return
        }
        editingMainContent = editing
        notesViewDelegate?.notesViewEditingMainContentChanged(editing)
    }
}

extension NotesView : NSLayoutManagerDelegate {
    
    /// - Parameters:
    ///  - lineFragmentRect: 设置这个值可以告诉NSLayoutMananger实际设置的整行的rect
    ///  - lineFragmentUsedRect: 这个值是当前行已经占用的rect
    func layoutManager(_ layoutManager: NSLayoutManager, shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>, lineFragmentUsedRect: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>, in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange) -> Bool {
        guard let ts = layoutManager.textStorage else {
            return true
        }
        // 更新attachment的layout
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        if ts.containsAttachments(in: charRange) {
            for i in charRange.lowerBound..<charRange.upperBound {
                if let attachment = ts.attribute(.rtAttachment, at: i, effectiveRange: nil) as? RichTextAttachment {
                    attachment.updateLayout(lineFragment: lineFragmentRect, lineFragmentUsed: lineFragmentUsedRect, baselineOffset: baselineOffset)
                }
            }
        }
        return true
    }
}

extension NotesView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if textView.selectedRange.length != 0 && range != textView.selectedRange {
            logger.warn("range not equal \(range) \(textView.selectedRange)")
            if text.isEmpty {
                // 直接改为选区
                return editor.shouldReplaceText(in: textView.selectedRange, with: "")
            }
        }
        return editor.shouldReplaceText(in: range, with: text)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        editingAttachment?.requireEndEditing()
        updateEditingMainContent(true)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        editor.textDidChange()
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        if ignoreSelectionChange {
            return
        }
        editor.updateSelection(to: textView.selectedRange)
    }
}

extension NotesView: RichTextEditorDelegate {
    func editorDidUpdateSelection(range: NSRange) {
        logger.debug("update range \(textView.selectedRange) to \(range)")
        textView.selectedRange = range
    }
    
    func editorDidRemoveAttachment(_ attachment: RichTextAttachment) {
    }
    
    func editorDidUpdateTextFormat(_ format: TextFormat) {
        notesViewDelegate?.notesViewDidUpdateTextFormat(format)
    }
    
    func editorCreateCheckbox(at index: Int) -> RichTextAttachment {
        let checkbox = NotesCheckbox()
        textView.addSubview(checkbox)
        DispatchQueue.main.async {
            // 需要主动更新布局
//            self.textView.layoutManager.invalidateLayout(forCharacterRange: NSRange(location: index, length: self.textView.textStorage.length - index), actualCharacterRange: nil)
        }
        return RichTextAttachment(view: checkbox, type: .checkbox)
    }
    
    func editorCreateTable(at index: Int) -> RichTextAttachment {
        let tableView = NotesTableView(rows: 2, cols: 2, padding: textView.textContainer.lineFragmentPadding)
        textView.addSubview(tableView)
        DispatchQueue.main.async {
            tableView.requireBeginEditing()
        }
        let attachment = RichTextAttachment(view: tableView, type: .table)
        attachment.deleagte = self
        return attachment
    }
    
    func editorCreateImage(at index: Int, for image: UIImage) -> RichTextAttachment {
        let imageView = NotesImageView(image: image)
        textView.addSubview(imageView)
        return RichTextAttachment(view: imageView, type: .image)
    }
}

class NotesViewTextContainer: NSTextContainer {
    override func lineFragmentRect(forProposedRect proposedRect: CGRect, at characterIndex: Int, writingDirection baseWritingDirection: NSWritingDirection, remaining remainingRect: UnsafeMutablePointer<CGRect>?) -> CGRect {
        let rect = CGRect(x: 0, y: proposedRect.minY, width: size.width, height: proposedRect.height)
        guard let textStorage = layoutManager?.textStorage else {
            return rect
        }
        let str = textStorage.string as NSString
        if characterIndex < str.length && str.character(at: characterIndex) == NSTextAttachment.character {
            if let attachment = textStorage.attribute(.rtAttachment, at: characterIndex, effectiveRange: nil) as? RichTextAttachment, let checkbox = attachment.view as? NotesCheckbox {
                let checkboxWidth = checkbox.boundsSize.width - lineFragmentPadding
                return CGRect(x: checkboxWidth, y: rect.minY, width: rect.width - checkboxWidth, height: rect.height)
            }
        }
        return rect
    }
}

protocol NotesViewDelegate: NSObject {
    func notesViewDidUpdateTextFormat(_ format: TextFormat)
    func notesViewEditingMainContentChanged(_ editing: Bool)
}

extension NotesView : RichTextAttachmentDelegate {
    func attachmentDidBeginEditing(_ attachment: RichTextAttachment) {
        editingAttachment = attachment
        updateEditingMainContent(false)
    }
    
    func attachmentDidEndEditing(_ attachment: RichTextAttachment) {
        if (editingAttachment == attachment) {
            editingAttachment = nil
        }
    }
}
