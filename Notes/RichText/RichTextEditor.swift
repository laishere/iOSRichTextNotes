//
//  RichTextEditor.swift
//  Notes
//
//  Created by laishere on 2023/11/14.
//

import UIKit

class RichTextEditor {
    let textStorage: NSTextStorage
    weak var delegate: RichTextEditorDelegate? = nil
    private(set) var selection = NSRange(location: 0, length: 0)
    private(set) var currentFormat: TextFormat = .none
    private var preserveFormatPosition = -1
    private var string: NSString {
        textStorage.string as NSString
    }
    private let logger = Logger(type: RichTextEditor.self)
    private var isReplacing = false
    private var editApplyFormat: TextFormat = .none
    // 需要显式设置格式的范围，注意不包含扩展合并的范围
    private var editApplyRange: NSRange = NSRange(location: 0, length: 0)
    private var editApplyFormat2: TextFormat = .none
    private var editApplyRange2: NSRange = NSRange(location: 0, length: 0)
    private var extraCheckboxUpdateIndex = -1
    private var editDontMergeChecklist = false
    private var postEditSelection: NSRange? = nil
    private let renderer = RichTextRenderer()
    
    init() {
        textStorage = NSTextStorage()
        textStorage.insert(endOfTextMark(), at: 0)
        applyFormat(TextFormat(type: .normal, style: []), in: NSRange(location: 0, length: 1))
    }
    
    /// 结束标志
    /// 不可被删除
    /// 光标不能出现在结束标志之后
    /// 结束标志承担记录最后一行格式的作用（最后一行为空行时也能记录格式）
    private func endOfTextMark() -> NSAttributedString {
        // 零宽空白字符
        let str = NSMutableAttributedString(string: StringLiteralType(UnicodeScalar(unichar(0x200B))!))
        // 调试用可视结束符号
//        let str = NSMutableAttributedString(string: String("$"))
        str.addAttributes([.rtEndOfText: 0], range: NSRange(location: 0, length: str.length))
        return str
    }
    
    func setTextType(_ type: TextType) {
        preserveFormatPosition = -1
        var style: TextStyle = []
        var range = selection
        if type == .title1 || type == .title2 || type == .title3 {
            // 标题默认添加粗体样式
            style = .bold
            range = lineRange(for: selection)
        }
        applyFormat(TextFormat(type: type, style: style), in: range)
    }
    
    func addTextStyle(_ style: TextStyle) {
        updateTextStyles(style)
    }
    
    func removeTextStyle(_ style: TextStyle) {
        updateTextStyles(style.erase)
    }
    
    func insertTable() {
        guard let delegate = delegate else {
            return
        }
        let ins = blockInsertPoint()
        logger.debug("insertTable: block insert point \(ins)")
        let attachment = delegate.editorCreateTable(at: ins)
        insertBlock(attachementString(of: attachment), at: ins)
    }
    
    func insertImage(_ image: UIImage) {
        guard let delegate = delegate else {
            return
        }
        let ins = blockInsertPoint()
        logger.debug("insertImage: block insert point \(ins)")
        let attachment = delegate.editorCreateImage(at: ins, for: image)
        insertBlock(attachementString(of: attachment), at: ins)
    }
    
    /// 预插入一个block，获取插入位置
    /// block格式：<内容><换行>，要求独占一行
    private func blockInsertPoint() -> Int {
        // 先删除选中区域
        replaceText(in: selection, with: "")
        // 可以直接插入block的:
        // 1). ^<首>xxx<尾>
        // 不可以直接插入block的:
        // 2). x^xx<尾> => 插入换行 => 1)
        // 3). xxx^<尾> => 插入换行 => 1)
        // 4). []^xxx<尾> => 移动到checkbox前面 => 1)
        // 5). []x^xx<尾> => 插入换行 => 移动到checkbox前面 => 1)
        // 6). []xxx^<尾> => 插入换行 => 继续插入换行（checklist转换为正文）=> 1)
        // 7). []^<尾> => 插入换行(转换为正文) => 1)
        // block前后插入只可能是1)
        // 注意<尾>可能是结束标志，所以当在<尾>前面插入，不能直接移动到<尾>后面
        var ins = selection.location
        if ins == 0 || isEndOfLine(at: ins - 1) {
            // 1)
        } else if textType(at: ins) == .checklist {
            if checkboxAttachment(at: ins - 1) != nil {
                if isEndOfLine(at: ins) {
                    // 7)
                    replaceText(in: selection, with: "\n")
                    ins = selection.location
                } else {
                    // 4)
                    ins = ins - 1
                }
            } else if isEndOfLine(at: ins) {
                // 6)
                // 插入换行
                replaceText(in: selection, with: "\n")
                // 光标在下一行checkbox后面
                replaceText(in: selection, with: "\n")
                ins = selection.location
            } else {
                // 5)
                replaceText(in: selection, with: "\n")
                // 光标在checkbox后面
                ins = selection.location - 1
            }
        } else {
            // 2), 3)
            replaceText(in: selection, with: "\n")
            ins = selection.location
        }
        return ins
    }
    
    /// 直接在指定位置插入block
    private func insertBlock(_ attrString: NSAttributedString, at index: Int) {
        let block = NSMutableAttributedString(attributedString: attrString)
        // block内容后必定跟随换行
        block.mutableString.append("\n")
        let range = NSRange(location: 0, length: block.length)
        block.addAttribute(.rtTextType, value: TextType.block, range: range)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 10.0
        block.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        textStorage.insert(block, at: index)
        // 更新光标位置
        updateSelection(to: NSRange(location: index + block.length, length: 0))
        checkDebugOptions()
    }
    
    private func updateTextStyles(_ change: TextStyle) {
        var styles = currentFormat.style
        if TextStyle.all.contains(change) {
            // 新增
            styles.insert(change)
        } else {
            styles.remove(change.reverseErase)
        }
        logger.debug("updateTextStyles: change \(change) selection \(selection)")
        preserveFormatPosition = -1
        if selection.length == 0 {
            preserveCurrentFormat(TextFormat(type: currentFormat.type, style: styles))
            return
        }
        // 如果change是删除样式，那么加入styles标志
        styles.insert(change)
        applyFormat(TextFormat(type: currentFormat.type, style: styles), in: selection)
    }
    
    @discardableResult
    func replaceText(in range: NSRange, with text: String) -> Bool {
        postEditSelection = nil
        if shouldReplaceText(in: range, with: text) {
            textStorage.replaceCharacters(in: range, with: text)
            if postEditSelection == nil {
                updateSelectionAfterReplaceText(in: range, with: text)
            }
            textDidChange()
            return true
        }
        return false
    }
    
    private func updateSelectionAfterReplaceText(in range: NSRange, with text: String) {
        // 更新选区
        var newSelection = selection
        if selection == range {
            newSelection = NSRange(location: range.location + text.count, length: 0)
        } else {
            var start = selection.location
            var end = selection.upperBound
            if start >= range.location {
                // 拆分成两步：1. 删除range字符，2. 在range.location处插入新字符
                // 从删除位置开始偏移，偏移量 = 未被删除的长度 + 插入的字符串长度
                start = range.location + max(0, start - range.upperBound) + text.count
            }
            if end >= range.location {
                end = range.location + max(0, end - range.upperBound) + text.count
            }
            assert(start <= end)
            newSelection = NSRange(location: start, length: end - start)
        }
        postEditSelection = newSelection
    }
    
    func shouldReplaceText(in range: NSRange, with text: String) -> Bool {
        if range.length == 0 && text.count == 0 {
            return false
        }
        isReplacing = _shouldReplaceText(in: range, with: text as NSString)
        extraCheckboxUpdateIndex = -1
        if isReplacing {
            handleAttachmentRemove(in: range)
            // 检查需要额外更新checkbox的区域
            if !text.isEmpty {
                if range.upperBound < string.length && textType(at: range.upperBound) == .checklist {
                    // 注意是修改后的index
                    extraCheckboxUpdateIndex = range.location + text.count
                }
            }
        }
        return isReplacing
    }
    
    private func _shouldReplaceText(in range: NSRange, with text: NSString) -> Bool {
        if range.upperBound >= textStorage.length {
            logger.warn("cannot replace end-mark, range \(range), length \(textStorage.length)")
            return false
        }
        if range.lowerBound < 0 {
            logger.warn("invalid range, range \(range), length \(textStorage.length)")
            return false
        }
        // 设置默认的格式
        editApplyFormat = computeFormat(in: range)
        editApplyRange = NSRange(location: -1, length: 0)
        editApplyFormat2 = editApplyFormat
        editApplyRange2 = editApplyRange
        if text.length == 0 {
            if range.length == 1 && selection.length == 0 {
                return delete(at: range.location)
            }
            return deleteRange(in: range)
        }
        if range.length == 0 {
            return insert(at: range.location, with: text)
        }
        return replaceRange(in: range, with: text)
    }
    
    func textDidChange() {
        if !isReplacing {
            logger.error("textDidChange called without calling shouldReplaceText")
            return
        }
        postEdit()
        isReplacing = false
    }
    
    /// 更新选区
    /// 1. 禁止选中结束标志
    /// 2. checkbox: 光标不可以落在checkbox字符位置（因为checkbox字符设置为零宽字符）
    /// 3. 禁止选中部分block的情况
    func updateSelection(to range: NSRange) {
        var start = range.lowerBound
        var end = range.upperBound
        var maxMove = 5
        while maxMove > 0 {
            let oldStart = start
            let oldEnd = end
            maxMove -= 1
            if end >= string.length {
                logger.debug("updateSelection: range overlapping end-mark")
                start = min(start, string.length - 1)
                end = min(end, string.length - 1)
            }
            // checkbox
            if checkboxAttachment(at: start) != nil {
                // 按照当前移动方向移动到合法位置
                logger.debug("updateSelection: start at checkbox")
                var newStart = start + (selection.lowerBound < start ? 1 : -1)
                if newStart < 0 {
                    newStart = 1
                }
                if start == end {
                    end = newStart
                }
                start = newStart
            }
            if start != end && checkboxAttachment(at: end) != nil {
                logger.debug("updateSelection: end at checkbox")
                end += selection.upperBound < end ? 1 : -1
            }
            // block
            if textType(at: start) == .block {
                logger.debug("updateSelection: start at block")
                let blockRange = lineRange(at: start)
                var newStart = start
                // 允许在block换行前面
                if newStart < blockRange.upperBound - 1 {
                    newStart = selection.lowerBound < start ? blockRange.upperBound - 1 : blockRange.lowerBound
                }
                if start == end {
                    end = newStart
                }
                start = newStart
            }
            if end != start && textType(at: end) == .block {
                logger.debug("updateSelection: end at block")
                let blockRange = lineRange(at: end)
                // 允许在block换行前面
                if end < blockRange.upperBound - 1 {
                    end = selection.upperBound < end ? blockRange.upperBound - 1 : blockRange.lowerBound
                }
            }
            if oldStart == start && oldEnd == end {
                break
            }
        }
        if maxMove == 0 {
            logger.warn("updateSelection: too many moves")
        }
        let newSelection = NSRange(location: start, length: end - start)
        if range != newSelection || selection != newSelection {
            logger.debug("adjust selection from \(range) to \(newSelection)")
            selection = newSelection
            preserveFormatPosition = -1
            updateCurrentFormat()
            delegate?.editorDidUpdateSelection(range: selection)
        }
    }
    
    private func updateCurrentFormat() {
        currentFormat = computeFormat(in: selection)
        delegate?.editorDidUpdateTextFormat(currentFormat)
    }
    
    private func preserveCurrentFormat(_ format: TextFormat) {
        currentFormat = format
        preserveFormatPosition = selection.location
        delegate?.editorDidUpdateTextFormat(currentFormat)
    }
    
    private func computeFormat(in range: NSRange) -> TextFormat {
        var cur = range.location
        if range.length == 0 {
            if cur == preserveFormatPosition {
                return currentFormat
            }
            if cur > 0 && !isEndOfLine(at: cur - 1) {
                // 光标模式且不是行首，取光标前一位的格式
                cur -= 1
            }
        }
        return textFormat(at: cur)
    }
    
    private func handleAttachmentRemove(in range: NSRange) {
        if !textStorage.containsAttachments(in: range) {
            return
        }
        var attachments: [RichTextAttachment] = []
        for i in range.lowerBound..<range.upperBound {
            if let attachment = attachment(at: i) {
                attachments.append(attachment)
            }
        }
        logger.debug("removing attachments, count \(attachments.count)")
        for attachment in attachments {
            removeAttachment(attachment)
        }
    }
    
    private func removeAttachment(_ attachment: RichTextAttachment) {
        attachment.remove()
        delegate?.editorDidRemoveAttachment(attachment)
    }
    
    /// 编辑后更新文本格式
    private func postEdit() {
        // textview可能会让新文本继承文本类型熟悉，
        // 先删除替换部分的文本类型以免影响后面的逻辑
        if editApplyRange.length > 0 {
            textStorage.removeAttribute(.rtTextType, range: editApplyRange)
        }
        if let range = postEditSelection {
            updateSelection(to: range)
            postEditSelection = nil
        }
        if editApplyRange.location != -1 {
            logger.debug("postEdit applying format \(editApplyFormat) in range \(editApplyRange)")
            applyFormat(editApplyFormat, in: editApplyRange)
        }
        if editApplyRange2.location != -1 {
            logger.debug("postEdit applying format2 \(editApplyFormat2) in range \(editApplyRange2)")
            applyFormat(editApplyFormat2, in: editApplyRange2)
        }
    }
    
    /// 给指定范围设置格式
    /// 1. 对于指定范围的内容，同时更新文本类型和样式
    /// 2. 对于指定范围外的内容，但和范围内存存在段落交集的，按需更新文本类型，不更新样式
    /// 3. 如果不是正在编辑，不更新block的类型和样式
    private func applyFormat(_ format: TextFormat, in range: NSRange) {
        if format.type == .none && format.style.isEmpty {
            logger.debug("applyFormat: has nothing to do")
            return
        }
        logger.debug("applyFormat: range \(range), format \(format)")
        var lineStart = range.location
        let applyType = format.type
        let applyStyle = format.style
        while lineStart < range.upperBound {
            let lineEnd = min(range.upperBound, lineRange(at: lineStart).upperBound)
            let lineRange = NSRange(location: lineStart, length: lineEnd - lineStart)
            // 不更新原来为block的类型
            if textType(at: lineStart) != .block {
                if applyType != .none {
                    // 不指定类型表示不更新类型
                    textStorage.addAttribute(.rtTextType, value: applyType, range: lineRange)
                }
                self.applyStyle(applyStyle, in: lineRange)
            }
            lineStart = lineEnd
        }
        var affectedStart = range.lowerBound
        var affectedEnd = range.upperBound
        if affectedEnd > 0 && affectedEnd < string.length && !isEndOfLine(at: affectedEnd - 1) && isEndOfText(at: affectedEnd) {
            // 结束标志的样式总是继承前一个字符，但不能跨行
            self.cloneStyle(textStyle(at: affectedEnd - 1), in: NSRange(location: affectedEnd, length: 1))
            affectedEnd += 1
        }
        let extendStart = lineRange(at: range.lowerBound).lowerBound
        let extendEnd = lineRange(at: max(range.lowerBound, range.upperBound - 1)).upperBound
        // 检查首尾是否存在段落交集
        if applyType != .none {
            if extendStart < range.lowerBound {
                // 首部存在交集
                if textType(at: extendStart) != applyType {
                    // 需要更新类型
                    logger.debug("applyFormat: extend affected start from \(affectedStart) to \(extendStart)")
                    affectedStart = extendStart
                    let lineRange = NSRange(location: extendStart, length: range.lowerBound - extendStart)
                    textStorage.addAttribute(.rtTextType, value: applyType, range: lineRange)
                }
            }
            if extendEnd > range.upperBound {
                // 尾部存在交集
                if textType(at: range.upperBound) != applyType {
                    logger.debug("applyFormat: extend affected end from \(affectedEnd) to \(extendEnd)")
                    affectedEnd = extendEnd
                    let lineRange = NSRange(location: range.upperBound, length: extendEnd - range.upperBound)
                    textStorage.addAttribute(.rtTextType, value: applyType, range: lineRange)
                }
            }
        }
        var affectedRange = NSRange(location: affectedStart, length: affectedEnd - affectedStart)
        affectedRange.length += updateCheckbox(in: affectedRange)
        if extraCheckboxUpdateIndex != -1 && affectedRange.upperBound <= extraCheckboxUpdateIndex {
            // 额外更新checkbox
            logger.debug("applyFormat: extra checkbox update at \(extraCheckboxUpdateIndex)")
            let delta = updateCheckbox(in: NSRange(location: extraCheckboxUpdateIndex, length: 1))
            affectedRange.length = extraCheckboxUpdateIndex + 1 + delta - affectedStart
        }
        extraCheckboxUpdateIndex = -1
        logger.debug("applyFormat: affected range \(affectedRange)")
        renderer.renderAttributes(textStorage, in: affectedRange)
        updateCurrentFormat()
        checkDebugOptions()
    }
    
    /// 增量修改样式，不明确指定添加或删除则忽略
    private func applyStyle(_ style: TextStyle, in range: NSRange) {
        if style.isEmpty || range.length == 0 {
            return
        }
        logger.debug("applyStyle: style \(style) range \(range)")
        let styles: [TextStyle] = [.bold, .italic, .strikethrough, .underline]
        for s in styles {
            if style.contains(s) {
                textStorage.addAttribute(keyForStyle(s), value: s, range: range)
            } else if style.contains(s.erase) {
                textStorage.removeAttribute(keyForStyle(s), range: range)
            }
        }
    }
    
    /// 完全复制样式
    private func cloneStyle(_ style: TextStyle, in range: NSRange) {
        if range.length == 0 {
            return
        }
        logger.debug("cloneStyle: style \(style) range \(range)")
        let styles: [TextStyle] = [.bold, .italic, .strikethrough, .underline]
        for s in styles {
            if style.contains(s) {
                textStorage.addAttribute(keyForStyle(s), value: s, range: range)
            } else {
                textStorage.removeAttribute(keyForStyle(s), range: range)
            }
        }
    }
    
    private func keyForStyle(_ style: TextStyle) -> NSAttributedString.Key {
        switch style {
        case .bold:
            return .rtTextStyleBold
        case .italic:
            return .rtTextStyleItalic
        case .underline:
            return .rtTextStyleUnderline
        case .strikethrough:
            return .rtTextStyleStrikethrough
        default:
            fatalError()
        }
    }
    
    /// 检查给定段的checklist，添加或删除checkbox
    /// 返回变化长度
    private func updateCheckbox(in range: NSRange) -> Int {
        guard let delegate = delegate else {
            return 0
        }
        var lineStart = lineRange(at: range.lowerBound).lowerBound
        var change: [Int] = [] // 维护插入和删除位置，正值为插入，负值为删除，下标从1开始
        while lineStart < range.upperBound {
            let isChecklist = textType(at: lineStart) == .checklist
            let checkbox = checkboxAttachment(at: lineStart)
            if isChecklist {
                if checkbox == nil {
                    change.append(lineStart + 1)
                }
            } else if checkbox != nil {
                change.append(-(lineStart + 1))
                removeAttachment(checkbox!)
            }
            lineStart = lineRange(at: lineStart).upperBound
        }
        if change.count == 0 {
            logger.debug("updateCheckbox: no checkbox changed")
            return 0
        }
        logger.debug("updateCheckbox: total affected count \(change.count)")
        let selectedRange = selection
        var startOffset = 0
        var endOffset = 0
        var deltaLength = 0
        for i in change.reversed() {
            let cur = abs(i) - 1
            let checkbox = attachementString(of: delegate.editorCreateCheckbox(at: cur))
            checkbox.addAttribute(.rtTextType, value: TextType.checklist, range: NSRange(location: 0, length: 1))
            if i > 0 {
                textStorage.insert(checkbox, at: cur)
            } else {
                textStorage.replaceCharacters(in: NSRange(location: cur, length: checkbox.length), with: "")
            }
            let delta = i > 0 ? checkbox.length : -checkbox.length
            deltaLength += delta
            if cur == selectedRange.lowerBound {
                // 如果在选区开始的位置插入checkbox，选区左边界应该移动到checkbox后面
                // 如果是删除则保持不变
                startOffset += max(0, delta)
            } else if cur < selectedRange.lowerBound {
                startOffset += delta
            }
            if selectedRange.length > 0 && cur < selectedRange.upperBound {
                // 仅在左右边界不一样的时候更新endOffset
                endOffset += delta
            }
        }
        if selectedRange.length == 0 {
            endOffset = startOffset
        }
        let newStart = selectedRange.lowerBound + startOffset
        let newEnd = selectedRange.upperBound + endOffset
        // 更新选区
        updateSelection(to: NSRange(location: newStart, length: newEnd - newStart))
        return deltaLength
    }
    
    private func attachementString(of attachement: RichTextAttachment) -> NSMutableAttributedString {
        let str = NSMutableAttributedString(attachment: attachement)
        str.addAttribute(.rtAttachment, value: attachement, range: NSRange(location: 0, length: str.length))
        return str
    }
    
    private func checkDebugOptions() {
//        renderer.debugTextType(textStorage, in: NSRange(location: 0, length: textStorage.length))
    }
}


/// 编辑行为
extension RichTextEditor {
    /// 光标删除模式
    /// 1. 删除block，需要先选中整个block内容，舍弃本次删除操作
    /// 2. 删除checkbox
    ///  1). 如果前面那行是checklist，合并两行
    ///  2). 否则，只删除checkbox
    /// 3. 其他，转换为选区删除
    private func delete(at index: Int) -> Bool {
        logger.debug("delete at \(index)")
        if textType(at: index) == .block {
            // 先完整选中block内容，不包括换行
            // 不选中换行的效果更好看一点，删除的时候我们依然会删除block的换行
            var blockRange = lineRange(at: index)
            blockRange.length -= 1
            logger.debug("won't delete block, select first")
            updateSelection(to: blockRange)
            return false
        }
        if checkboxAttachment(at: index) != nil {
            // 删除checkbox
            logger.debug("deleting checkbox")
            // 如果明确指定不合并，那么跳过
            if !editDontMergeChecklist && index > 0 && textType(at: index - 1) == .checklist {
                // 连带删除前面的换行
                logger.debug("merging two checklist")
                replaceText(in: NSRange(location: index - 1, length: 2), with: "")
                return false
            }
            logger.debug("delete just checkbox, update checklist format to normal")
            // 只删除checkbox，把该行设置为正文
            editApplyFormat = TextFormat(type: .normal, style: [])
            editApplyRange = lineRange(at: index)
            // 注意删除了一个字符
            editApplyRange.length -= 1
            return true
        }
        return deleteRange(in: NSRange(location: index, length: 1))
    }
    
    /// 选区删除模式，等价于用空字符串替换选区
    private func deleteRange(in range: NSRange) -> Bool {
        logger.debug("delete range \(range)")
        return replaceRange(in: range, with: "")
    }
    
    /// 替换选区内容
    /// 1. 如果选区以block结尾，那么需要检查是否完整选中，没有完整的直接转换为完全选中后的替换
    /// 2. 替换block前面的内容
    ///  1). 如果替换后，前面整行删除，不需要额外操作
    ///  2). text以换行结尾，不需要额外操作
    ///  3). 否则，更换替换内容为<text><换行>
    /// 3. 如果替换以block开头，那么需要更改样式更新逻辑
    private func replaceRange(in range: NSRange, with text: NSString) -> Bool {
        logger.debug("replace range \(range) with text count \(text.length)")
        if textType(at: range.upperBound - 1) == .block {
            let blockRange = lineRange(at: range.upperBound - 1)
            if blockRange.upperBound > range.upperBound {
                // 未完全选中，转换为选中后替换
                let extendRange = NSRange(location: range.location, length: blockRange.upperBound - range.location)
                logger.debug("replacing block with complete range \(extendRange)")
                replaceText(in: extendRange, with: text as String)
                return false
            }
        }
        if editApplyFormat.type == .block {
            // 替换的开头是block
            // 如果text为空，那么取消格式更新
            // 否则，设置格式为normal
            if text.length == 0 {
                return true
            }
            editApplyFormat = TextFormat(type: .normal, style: [])
        }
        if textType(at: range.upperBound) == .block {
            // 替换block前面的内容
            if text.length > 0 && text.isNewLine(at: text.length - 1) {
                // 2). text以换行结尾
            } else if text.length == 0 && lineRange(for: range) == range {
                // 1). 替换后整行删除
            } else {
                // text不以\n结尾，加上\n再替换
                replaceText(in: range, with: "\(text)\n")
                updateSelection(to: NSRange(location: range.location + text.length, length: 0))
                return false
            }
        }
        if text.length == 0 && lineRange(for: range) == range {
            // 整行删除，类型不需要更新，避免合并空段落而更改类型
        } else {
            editApplyRange.location = range.location
            editApplyRange.length = text.length
        }
        return true
    }
    
    /// 插入模式，不涉及替换
    /// 1. 行后插入空行的行为
    /// 2. block前面插入内容，格式需要更新为normal
    ///  1). text以换行结尾，不需要额外操作
    ///  2). 否则，转换为插入<text><换行>
    /// 3. 其它，更改插入后的格式
    private func insert(at index: Int, with text: NSString) -> Bool {
        logger.debug("insert at \(index) with text count \(text.length)")
        // 默认给新内容设置格式
        editApplyRange.location = index
        editApplyRange.length = text.length
        if isEndOfLine(at: index) && text.length == 1 && text.isNewLine(at: 0) {
            return insertBlankLine(at: index)
        }
        if textType(at: index) == .block {
            // block前面插入内容
            if text.isNewLine(at: text.length - 1) {
                // 1). text以换行结尾
                // 格式换成normal
                editApplyFormat = TextFormat(type: .normal, style: [])
                // 光标移至行尾
                postEditSelection = NSRange(location: index + text.length - 1, length: 0)
            } else {
                // 2). 插入<text><换行>
                logger.debug("insert before block, append \\n")
                replaceText(in: NSRange(location: index, length: 0), with: "\(text)\n")
                return false
            }
        }
        return true
    }
    
    /// 插入空行
    /// 1. checklist行尾插入空行：
    ///  1). 如果当前行没有内容，取消插入空行，并把当前行改为正文
    ///  2). 如果当前行不为空，插入的空行格式依然是checklist
    /// 2. 标题、block后插入空行，空行需要清除所有样式，类型改为正文
    /// 3. 正文和等宽中间和尾部插入换行保持格式
    private func insertBlankLine(at index: Int) -> Bool {
        logger.debug("insert blank line at \(index)")
        let type = textType(at: index)
        if type == .checklist {
            if checkboxAttachment(at: index - 1) != nil {
                // 空内容checklist，转换为删除checkbox
                logger.debug("empty checklist, removing checkbox")
                // 仅删除checkbox，不希望合并checklist
                editDontMergeChecklist = true
                replaceText(in: NSRange(location: index - 1, length: 1), with: "")
                editDontMergeChecklist = false
                return false
            }
            // 新插入的换行符格式checklist，因为上面设置了默认范围，此处无需设置
            return true
        }
        if type == .title1 || type == .title2 || type == .title3 || type == .block {
            // 新插入的换行符格式保持和当前行的一致，需要把下一个换行符设置为正文
            logger.debug("new line following title, update format to normal")
            editApplyFormat2 = TextFormat(type: .normal, style: .all.erase)
            editApplyRange2 = NSRange(location: index + 1, length: 1)
            return true
        }
        // 上面设置了默认范围，此处无需设置即可保持格式不变
        logger.debug("new line following normal/monospace, keep the format")
        return true
    }
}

/// 字符串相关
private extension RichTextEditor {
    func lineRange(for range: NSRange) -> NSRange {
        var validRange = range
        if validRange.location < 0 {
            validRange.location = 0
        }
        if validRange.length > string.length {
            validRange.length = string.length
        }
        if validRange != range {
            logger.warn("lineRange: range is invalid \(range), length \(textStorage.length)")
        }
        return string.lineRange(for: range)
    }
    
    func lineRange(at index: Int) -> NSRange {
        return lineRange(for: NSRange(location: index, length: 0))
    }
    
    /// 检查是否是行尾，考虑文本末尾的情况
    func isEndOfLine(at index: Int) -> Bool {
        return string.isNewLine(at: index) || isEndOfText(at: index)
    }
}

private extension NSString {
    func isNewLine(at index: Int) -> Bool {
        if index < 0 || index >= length {
            return false
        }
        return character(at: index) == Character("\n").asciiValue!
    }
}
