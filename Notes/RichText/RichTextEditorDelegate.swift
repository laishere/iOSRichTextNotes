//
//  RichTextEditorDelegate.swift
//  Notes
//
//  Created by lai on 2023/12/11.
//

import UIKit

protocol RichTextEditorDelegate : AnyObject {
    func editorDidUpdateSelection(range: NSRange)
    func editorDidRemoveAttachment(_ attachment: RichTextAttachment)
    func editorDidUpdateTextFormat(_ format: TextFormat)
    func editorCreateCheckbox(at index: Int) -> RichTextAttachment
    func editorCreateTable(at index: Int) -> RichTextAttachment
    func editorCreateImage(at index: Int, for image: UIImage) -> RichTextAttachment
}
