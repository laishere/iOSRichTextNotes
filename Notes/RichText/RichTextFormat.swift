//
//  RichTextFormat.swift
//  Notes
//
//  Created by laishere on 2023/11/20.
//

import Foundation

/// 文本类型，以行为单位
enum TextType {
    case title1
    case title2
    case title3
    case normal
    case monospace
    case checklist
    case block
    case none
}

/// 文本样式，最小单位是字符
struct TextStyle: OptionSet {
    let rawValue: Int
    
    static let bold = TextStyle(rawValue: 1 << 0)
    static let italic = TextStyle(rawValue: 1 << 1)
    static let underline = TextStyle(rawValue: 1 << 2)
    static let strikethrough = TextStyle(rawValue: 1 << 3)
    
    static let all: TextStyle = [.bold, .italic, .underline, .strikethrough]
    
    private static let eraseOffset = 4
    var erase: TextStyle {
        TextStyle(rawValue: rawValue << TextStyle.eraseOffset)
    }
    var reverseErase: TextStyle {
        TextStyle(rawValue: rawValue >> TextStyle.eraseOffset)
    }
}

/// 文本格式，包含文本类型、样式
struct TextFormat: Equatable {
    let type: TextType
    let style: TextStyle
    
    static let none = TextFormat(type: .none, style: [])
}
