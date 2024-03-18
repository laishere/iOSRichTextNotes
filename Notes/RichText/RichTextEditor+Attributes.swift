//
//  RichTextEditor+TextStorage.swift
//  Notes
//
//  Created by lai on 2023/12/10.
//

import Foundation

extension RichTextEditor {
    private func isValidIndex(at index: Int) -> Bool {
        let valid = index >= 0 && index < textStorage.length
        if !valid {
            return false
        }
        return valid
    }
    
    func textType(at index: Int) -> TextType {
        if !isValidIndex(at: index) {
            return .none
        }
        return (textStorage.attribute(.rtTextType, at: index, effectiveRange: nil) as? TextType) ?? .none
    }
    
    func textStyle(at index: Int) -> TextStyle {
        if !isValidIndex(at: index) {
            return []
        }
        var styles = TextStyle(rawValue: 0)
        let keys: [NSAttributedString.Key] = [.rtTextStyleBold, .rtTextStyleItalic, .rtTextStyleItalic, .rtTextStyleUnderline, .rtTextStyleStrikethrough]
        for key in keys {
            if let style = textStorage.attribute(key, at: index, effectiveRange: nil) as? TextStyle {
                styles.insert(style)
            }
        }
        return styles
    }
    
    func textFormat(at index: Int) -> TextFormat {
        return TextFormat(type: textType(at: index), style: textStyle(at: index))
    }
    
    func isEndOfText(at index: Int) -> Bool {
        if !isValidIndex(at: index) {
            return false
        }
        return textStorage.attribute(.rtEndOfText, at: index, effectiveRange: nil) != nil
    }
    
    func attachment(at index: Int) -> RichTextAttachment? {
        if !isValidIndex(at: index) {
            return nil
        }
        return textStorage.attribute(.rtAttachment, at: index, effectiveRange: nil) as? RichTextAttachment
    }
    
    func checkboxAttachment(at index: Int) -> RichTextAttachment? {
        if let attachment = attachment(at: index) {
            if attachment.type == .checkbox {
                return attachment
            }
        }
        return nil
    }
}
