//
//  RichTextAttributeKeys.swift
//  Notes
//
//  Created by laishere on 2023/11/20.
//

import Foundation

extension NSAttributedString.Key {
    static let rtTextType = NSAttributedString.Key("richtext.text.type")
    static let rtTextStyleBold = NSAttributedString.Key("richtext.text.style.bold")
    static let rtTextStyleItalic = NSAttributedString.Key("richtext.text.style.italic")
    static let rtTextStyleUnderline = NSAttributedString.Key("richtext.text.style.underline")
    static let rtTextStyleStrikethrough = NSAttributedString.Key("richtext.text.style.strikethrough")
    static let rtAttachment = NSAttributedString.Key("richtext.view.attachment")
    static let rtEndOfText = NSAttributedString.Key("richtext.endOfText")
}
