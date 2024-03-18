//
//  RichTextRenderer.swift
//  Notes
//
//  Created by laishere on 2023/11/20.
//

import UIKit

class RichTextRenderer {
    private let logger = Logger(type: RichTextRenderer.self)
    private let baseParagraphStyle = NSParagraphStyle()
    private var textColor = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
    }
    
    func renderAttributes(_ textStorage: NSTextStorage, in range: NSRange) {
        if range.length == 0 {
            return
        }
        // 字体相关
        var textType: TextType = .none
        var bold = false
        var italic = false
        var fontStart = range.lowerBound
        // 底部划线
        var underline = false
        var underlineStart = range.lowerBound
        // 中部划线
        var strikethrough = false
        var strikethroughStart = range.lowerBound
        
        func setFontAttrs(_ end: Int) {
            if textType == .block {
                return
            }
            let range = NSRange(location: fontStart, length: end - fontStart)
            fontStart = end
            logger.debug("renderAttributes: set font attributes, type \(textType) bold \(bold) italic \(italic) range \(range)")
            textStorage.addAttributes([.paragraphStyle: paragraphStyle(for: textType), .foregroundColor: textColor], range: range)
            if var font = getFont(forType: textType) {
                font = applyStyleToFont(font, bold: bold, italic: italic)
                textStorage.addAttribute(.font, value: font, range: range)
            }
        }
        
        func setUnderlineAttrs(_ end: Int) {
            let range = NSRange(location: underlineStart, length: end - underlineStart)
            if underline {
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                textStorage.removeAttribute(.underlineStyle, range: range)
            }
            underlineStart = end
        }
        
        func setStrikethroughAttrs(_ end: Int) {
            let range = NSRange(location: strikethroughStart, length: end - strikethroughStart)
            if strikethrough {
                textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                textStorage.removeAttribute(.strikethroughStyle, range: range)
            }
            strikethroughStart = end
        }
        
        for i in range.lowerBound..<range.upperBound {
            // 逐字检查样式
            let nextTextType = (textStorage.attribute(.rtTextType, at: i, effectiveRange: nil) as? TextType) ?? .none // 可以通过指定影响范围指针进行优化，不用每个i都获取
            let nextBold = textStorage.attribute(.rtTextStyleBold, at: i, effectiveRange: nil) != nil
            let nextItalic = textStorage.attribute(.rtTextStyleItalic, at: i, effectiveRange: nil) != nil
            let nextUnderline = textStorage.attribute(.rtTextStyleUnderline, at: i, effectiveRange: nil) != nil
            let nextStrikethrough = textStorage.attribute(.rtTextStyleStrikethrough, at: i, effectiveRange: nil) != nil
            
            if i == range.lowerBound {
                textType = nextTextType
                bold = nextBold
                italic = nextItalic
                underline = nextUnderline
                strikethrough = nextStrikethrough
                continue
            }
            
            // 字体相关的属性
            if textType != nextTextType || bold != nextBold || italic != nextItalic {
                setFontAttrs(i)
                textType = nextTextType
                bold = nextBold
                italic = nextItalic
            }
            
            // underline
            if underline != nextUnderline {
                setUnderlineAttrs(i)
                underline = nextUnderline
            }
            
            // strikethrough
            if strikethrough != nextStrikethrough {
                setStrikethroughAttrs(i)
                strikethrough = nextStrikethrough
            }
        }
        setFontAttrs(range.upperBound)
        setUnderlineAttrs(range.upperBound)
        setStrikethroughAttrs(range.upperBound)
    }
    
    func debugTextType(_ textStorage: NSTextStorage, in range: NSRange) {
        for i in range.lowerBound..<range.upperBound {
            let type = textStorage.attribute(.rtTextType, at: i, effectiveRange: nil) as? TextType
            textStorage.addAttribute(.backgroundColor, value: getBgColorForType(type), range: NSRange(location: i, length: 1))
        }
    }
    
    private func getBgColorForType(_ type: TextType?) -> UIColor {
        switch type {
        case .title1:
            return .systemRed
        case .title2:
            return .systemYellow
        case .title3:
            return .systemBrown
        case .block:
            return .systemCyan
        case .checklist:
            return .systemGreen
        case .normal:
            return .systemBlue
        case .monospace:
            return .systemPurple
        default:
            return .systemGray3
        }
    }
    
    private func getFont(forType type: TextType) -> UIFont? {
        switch type {
        case .title1:
            return .systemFont(ofSize: 28)
        case .title2:
            return .systemFont(ofSize: 24)
        case .title3:
            return .systemFont(ofSize: 20)
        case .normal:
            return .systemFont(ofSize: 18)
        case .monospace:
            return .monospacedSystemFont(ofSize: 18, weight: .regular)
        case .checklist:
            return .systemFont(ofSize: 18)
        default:
            return nil
        }
    }
    
    private func applyStyleToFont(_ font: UIFont, bold: Bool, italic: Bool) -> UIFont {
        if !bold && !italic {
            return font
        }
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold {
            traits.insert(.traitBold)
        }
        if italic {
            traits.insert(.traitItalic)
        }
        return UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor, size: font.pointSize)
    }
    
    private func paragraphStyle(for type: TextType) -> NSParagraphStyle {
        let style = baseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle
        guard let font = getFont(forType: type) else {
            return style
        }
        switch type {
        case .title1, .title2, .title3:
            style.lineSpacing = font.pointSize * 0.3
        default:
            style.lineSpacing = 4.0
        }
        style.minimumLineHeight = 1.5 * font.pointSize
        return style
    }
}
