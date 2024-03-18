//
//  NotesTableView.swift
//  Notes
//
//  Created by laishere on 2023/7/16.
//
import UIKit

class NotesTableView: UIView {
    
    private var numberOfRows: Int = 0
    private var numberOfColumns: Int = 0
    // 行高前缀和，0位置留空
    private var rowHeightSums: [CGFloat] = []
    // 列宽前缀和，0位置留空
    private var columnWidthSums: [CGFloat] = []
    private var cells: [[CellTextView]] = []
    private let borderWidth = 0.5
    private let highlightStrokeWidth = 2.0
    private let highlightColor = UIColor.systemYellow
    private var editingCell: [Int]? = nil
    private let rowDotsBtn = DotsButton()
    private let colDotsBtn = DotsButton()
    private let contentView = ContentView()
    private let colDotsBtnContainer = UIView()
    private let rowDotsBtnContainer = UIView()
    private let dragContainer = UIView()
    private let highlightLayer = HightlightLayer()
    private var padding: Double = 20.0
    private var marginTop: Double = 0.0
    private var highlightRowRect = CGRect.zero
    private var highlightColRect = CGRect.zero
    private var highlightState = HighlightState.none
    private let settlingRatio = 0.2
    private var lastDraggingPoint = CGPoint.zero
    private let dragOffset = 5.0
    private let moveCellDuration = 0.25
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var ignoreNextLayout = false
    private weak var attachment: RichTextAttachment? = nil
    private var btnAreaSize: Double {
        padding * 0.8
    }
    private var editBegan = false
    
    weak var viewController: UIViewController? = nil
    
    init(rows: Int, cols: Int, padding: Double = 20.0, marginTop: Double = 0.0) {
        super.init(frame: CGRectZero)
        self.padding = padding
        self.marginTop = marginTop
        setup()
        numberOfRows = rows
        numberOfColumns = cols
        for row in 0..<numberOfRows {
            var rowCells: [CellTextView] = []
            for col in 0..<numberOfColumns {
                rowCells.append(createCell(row: row, col: col))
            }
            cells.append(rowCells)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        clipsToBounds = false
        
        rowDotsBtn.highlightColor = highlightColor
        colDotsBtn.highlightColor = highlightColor
        colDotsBtn.isOnRow = false
        updateEditingCell(cell: nil)
        
        colDotsBtnContainer.addSubview(colDotsBtn)
        colDotsBtnContainer.clipsToBounds = true
        rowDotsBtnContainer.addSubview(rowDotsBtn)
        rowDotsBtnContainer.clipsToBounds = true
        
        contentView.clipsToBounds = true
        contentView.delegate = self
        
        highlightLayer.strokeWidth = highlightStrokeWidth
        highlightLayer.highlightColor = highlightColor
        highlightLayer.contentsScale = 3.0
        
        colDotsBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleColBtnTap)))
        let colPanGR = UIPanGestureRecognizer(target: self, action: #selector(handleColDragging))
        colDotsBtn.addGestureRecognizer(colPanGR)
        colDotsBtn.panGestureRecoginzer = colPanGR
        
        rowDotsBtn.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleRowBtnTap)))
        let rowPanGR = UIPanGestureRecognizer(target: self, action: #selector(handleRowDragging))
        rowDotsBtn.addGestureRecognizer(rowPanGR)
        rowDotsBtn.panGestureRecoginzer = rowPanGR
        
        addSubview(contentView)
        addSubview(colDotsBtnContainer)
        addSubview(rowDotsBtnContainer)
    }
    
    private func createCell(row: Int, col: Int) -> CellTextView {
        let cell = CellTextView()
        cell.isScrollEnabled = false
        cell.layer.borderWidth = borderWidth
        cell.layer.borderColor = UIColor.systemGray3.cgColor
        cell.delegate = self
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        cell.row = row
        cell.col = col
        cell.returnKeyType = .next
        cell.font = .systemFont(ofSize: 15)
        contentView.addSubview(cell)
        return cell
    }
    
    @objc func handleRowBtnTap(_ sender: Any) {
        if (!rowDotsBtn.isHightlight) {
            setHighlightState(.row)
        }
    }

    @objc func handleColBtnTap(_ sender: Any) {
        if (!colDotsBtn.isHightlight) {
            setHighlightState(.col)
        }
    }
    
    private func updateHighlightFrame() {
        if (highlightState == .row) {
            highlightLayer.frame = highlightRowRect
        } else if (highlightState == .col) {
            highlightLayer.frame = highlightColRect
        }
    }
    
    private func setHighlightState(_ state: HighlightState) {
        if state != .none {
            didBeginEditing()
        }
        highlightState = state
        rowDotsBtn.setHighlight(state == .row)
        colDotsBtn.setHighlight(state == .col)
        if (rowDotsBtn.isHightlight) {
            rowDotsBtn.setMenu(getMenu(true, btn: rowDotsBtn))
        } else if (colDotsBtn.isHightlight) {
            colDotsBtn.setMenu(getMenu(false, btn: colDotsBtn))
        }
        highlightLayer.isHidden = state == .none
        updateHighlightFrame()
        if (state != .none) {
            contentView.layer.addSublayer(highlightLayer)
        } else {
            highlightLayer.removeFromSuperlayer()
        }
        highlightLayer.setNeedsDisplay()
    }
    
    private func addRow(after row: Int) {
        if (!(0..<numberOfRows).contains(row)) {
            return
        }
        cells.append(cells[numberOfRows - 1])
        for i in (row+1..<max(row+1, numberOfRows-1)).reversed() {
            cells[i + 1] = cells[i]
        }
        for col in 0..<numberOfColumns {
            cells[row + 1][col] = createCell(row: row + 1, col: col)
        }
        setHighlightState(.none)
        numberOfRows += 1
        editingCell = [row + 1, 0]
        setNeedsLayout()
    }
    
    private func addCol(after col: Int) {
        if (!(0..<numberOfColumns).contains(col)) {
            return
        }
        for row in 0..<numberOfRows {
            cells[row].insert(createCell(row: row, col: col + 1), at: col + 1)
            // 不需要更新每个被移动cell的col属性，layout时会更新
        }
        setHighlightState(.none)
        numberOfColumns += 1
        editingCell = [0, col + 1]
        setNeedsLayout()
    }
    
    private func deleteRow(at row: Int) {
        if (numberOfRows < 2 || !(0..<numberOfRows).contains(row)) {
            return
        }
        for col in 0..<numberOfColumns {
            cells[row][col].removeFromSuperview()
        }
        cells.remove(at: row)
        setHighlightState(.none)
        numberOfRows -= 1
        editingCell = [min(numberOfRows - 1, row), editingCell?[1] ?? 0]
        setNeedsLayout()
    }
    
    private func deleteCol(at col: Int) {
        if (numberOfColumns < 2 || !(0..<numberOfColumns).contains(col)) {
            return
        }
        for row in 0..<numberOfRows {
            cells[row][col].removeFromSuperview()
            cells[row].remove(at: col)
        }
        setHighlightState(.none)
        numberOfColumns -= 1
        editingCell = [editingCell?[0] ?? 0, min(numberOfColumns - 1, col)]
        setNeedsLayout()
    }
    
    private func getMenu(_ isRow: Bool, btn: DotsButton) -> UIMenu {
        var menuItems: [UIAction] = []
        let addAction = UIAction(title: isRow ? "添加行" : "添加列", image: UIImage(systemName: "plus.square")) {_ in
            if (isRow) {
                self.addRow(after: btn.rowIndex)
            } else {
                self.addCol(after: btn.colIndex)
            }
        }
        menuItems.append(addAction)
        if ((isRow && numberOfRows > 1) || (!isRow && numberOfColumns > 1)) {
            let deleteAction = UIAction(title: isRow ? "删除行" : "删除列", image: UIImage(systemName: "trash")) {_ in
                if (isRow) {
                    self.deleteRow(at: btn.rowIndex)
                } else {
                    self.deleteCol(at: btn.colIndex)
                }
            }
            menuItems.append(deleteAction)
        }
        let copyAction = UIAction(title: "拷贝", image: UIImage(systemName: "doc.on.doc")) {_ in
            
        }
        let cutAction = UIAction(title: "剪切", image: UIImage(systemName: "scissors")) {_ in
            
        }
        let pasteAction = UIAction(title: "粘贴", image: UIImage(systemName: "doc.on.clipboard")) {_ in
            
        }
        menuItems.append(copyAction)
        menuItems.append(cutAction)
        menuItems.append(pasteAction)
        return UIMenu(children: menuItems)
    }
    
    private func updateScroll() {
        if (rowDotsBtn.isHidden && colDotsBtn.isHidden) { return }
        let x = contentView.bounds.minX
        ignoreNextLayout = true // 禁止因修改bounds而触发的layoutSubviews
        colDotsBtnContainer.bounds.origin.x = x
        rowDotsBtnContainer.frame.origin.x = padding - btnAreaSize + max(0, -x)
        setNeedsLayout() // 确保消费掉ignoreNextLayout
    }
    
    private func updateEditingCell(cell: [Int]?) {
        if (isDragging()) {
            return
        }
        editingCell = cell
        if (cell == nil) {
            rowDotsBtn.isHidden = true
            colDotsBtn.isHidden = true
        } else {
            let rowRect = getRowRect(at: cell![0])
            rowDotsBtn.frame = CGRect(x: 0, y: rowRect.minY, width: btnAreaSize, height: rowRect.height)
            rowDotsBtn.rowIndex = cell![0]
            highlightRowRect = rowRect
            
            let colRect = getColRect(at: cell![1])
            colDotsBtn.frame = CGRect(x: colRect.minX, y: 0, width: colRect.width, height: btnAreaSize)
            colDotsBtn.colIndex = cell![1]
            highlightColRect = colRect
            rowDotsBtn.isHidden = false
            colDotsBtn.isHidden = false
            updateScroll()
            updateHighlightFrame()
            rowDotsBtn.setNeedsDisplay()
            colDotsBtn.setNeedsDisplay()
            let cellView = cells[cell![0]][cell![1]]
            if (!cellView.isFirstResponder) {
                cellView.becomeFirstResponder()
            }
        }
    }
    
    func getAreaRect(rowRange: Range<Int>, colRange: Range<Int>) -> CGRect {
        var x = columnWidthSums[colRange.lowerBound]
        var y = rowHeightSums[rowRange.lowerBound]
        var w = columnWidthSums[colRange.upperBound] - x
        var h = rowHeightSums[rowRange.upperBound] - y
        // 除去重叠的border
        x -= CGFloat(colRange.lowerBound) * borderWidth
        y -= CGFloat(rowRange.lowerBound) * borderWidth
        w -= CGFloat(colRange.count - 1) * borderWidth
        h -= CGFloat(rowRange.count - 1) * borderWidth
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    func getRowRect(at: Int) -> CGRect {
        return getAreaRect(rowRange: at..<at + 1, colRange: 0..<numberOfColumns)
    }
    
    func getColRect(at: Int) -> CGRect {
        return getAreaRect(rowRange: 0..<numberOfRows, colRange: at..<at + 1)
    }
    
    private func findRowToSettle(for row: Int) -> Int {
        if (row > 0) {
            let r = getAreaRect(rowRange: row-1..<row, colRange: 0..<1)
            let y = dragContainer.frame.minY - padding
            if (r.minY + r.height * settlingRatio > y) {
                return row - 1
            }
        }
        if (row + 1 < numberOfRows) {
            let r = getAreaRect(rowRange: row+1..<row+2, colRange: 0..<1)
            let y = dragContainer.frame.maxY - padding
            if (r.maxY - r.height * settlingRatio < y) {
                return row + 1
            }
        }
        return row
    }
    
    private func swapRow(a: Int, b: Int) {
        let i = min(a, b)
        let j = max(a, b)
        assert(i + 1 == j)
        rowHeightSums[i + 1] += (rowHeightSums[j + 1] - rowHeightSums[j]) - (rowHeightSums[i + 1] - rowHeightSums[i])
        for col in 0..<numberOfColumns {
            let a = cells[i][col]
            let b = cells[j][col]
            a.row = j
            b.row = i
            cells[i][col] = b
            cells[j][col] = a
        }
    }
    
    private func moveCellFeedback() {
        feedbackGenerator.impactOccurred()
    }
    
    private func moveRow(at row: Int, by dy: CGFloat) {
        dragContainer.frame.origin.y += dy
        let r = findRowToSettle(for: row)
        if (r != row) {
            swapRow(a: r, b: row)
            UIView.animate(withDuration: moveCellDuration, animations: {
                self.updateCellsPosition(rowRange: row..<row+1, colRange: 0..<self.numberOfColumns)
            })
            rowDotsBtn.rowIndex = r
            moveCellFeedback()
        }
    }
    
    private func findColToSettle(for col: Int) -> Int {
        if (col > 0) {
            let r = getAreaRect(rowRange: 0..<1, colRange: col-1..<col)
            let x = dragContainer.frame.minX - padding + contentView.bounds.minX
            if (r.minX + r.width * settlingRatio > x) {
                return col - 1
            }
        }
        if (col + 1 < numberOfColumns) {
            let r = getAreaRect(rowRange: 0..<1, colRange: col+1..<col+2)
            let x = dragContainer.frame.maxX - padding + contentView.bounds.minX
            if (r.maxX - r.width * settlingRatio < x) {
                return col + 1
            }
        }
        return col
    }
    
    private func swapCol(a: Int, b: Int) {
        let i = min(a, b)
        let j = max(a, b)
        assert(i + 1 == j)
        columnWidthSums[i + 1] += (columnWidthSums[j + 1] - columnWidthSums[j]) - (columnWidthSums[i + 1] - columnWidthSums[i])
        for row in 0..<numberOfRows {
            cells[row].swapAt(i, j)
            cells[row][i].col = i
            cells[row][j].col = j
        }
    }
    
    private var isScrollInSchedule = false
    private func scrollTableIfNeededForMovingCol() {
        if (isScrollInSchedule) {
            return
        }
        let left = contentView.frame.minX - dragContainer.frame.minX
        let right = dragContainer.frame.maxX - contentView.frame.maxX
        if (left < 0 && right < 0) {
            return
        }
        var dx = 0.0
        let minScroll = 2.0
        let scrollFactor = 0.1
        let boundMaxX = contentView.contentSize.width - contentView.frame.width
        if (left > 0 && contentView.bounds.minX > 0) {
            dx = -minScroll - left * scrollFactor
        } else if (right > 0 && contentView.bounds.minX < boundMaxX) {
            dx = minScroll + right * scrollFactor
        } else {
            return
        }
        let scrollX = contentView.bounds.minX + dx
        contentView.bounds.origin.x = max(0, min(boundMaxX, scrollX))
        isScrollInSchedule = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
            // 延迟确认是否仍在边界
            self.isScrollInSchedule = false
            if (self.isDragging()) {
                self.moveCol(at: self.colDotsBtn.colIndex, by: 0.0)
            }
        }
    }
    
    private func moveCol(at col: Int, by dx: CGFloat) {
        dragContainer.frame.origin.x += dx
        scrollTableIfNeededForMovingCol()
        let c = findColToSettle(for: col)
        if (c != col) {
            swapCol(a: c, b: col)
            UIView.animate(withDuration: moveCellDuration, animations: {
                self.updateCellsPosition(rowRange: 0..<self.numberOfRows, colRange: col..<col+1)
            })
            colDotsBtn.colIndex = c
            moveCellFeedback()
        }
    }
    
    private func changeSupview(supview: UIView, rowRange: Range<Int>, colRange: Range<Int>) {
        for row in rowRange {
            for col in colRange {
                let cell = cells[row][col]
                supview.addSubview(cell)
            }
        }
    }
    
    private func isDragging() -> Bool {
        return dragContainer.superview != nil
    }
    
    private func initRowDragging() {
        print("init row dragging")
        addSubview(dragContainer)
        
        if (highlightState != .row) {
            setHighlightState(.row)
        }
        
        let rowContent = UIView()
        dragContainer.addSubview(rowContent)
        
        let row = rowDotsBtn.rowIndex
        let rowCell = cells[row][0]
        changeSupview(supview: rowContent, rowRange: row..<row+1, colRange: 0..<numberOfColumns)
        rowContent.layer.addSublayer(highlightLayer)
        rowContent.frame = CGRect(x: btnAreaSize, y: 0, width: contentView.frame.width, height: rowCell.frame.height)
        rowContent.bounds.origin = CGPoint(x: contentView.bounds.minX, y: rowCell.frame.minY)
        rowContent.clipsToBounds = true
        
        dragContainer.frame = CGRect(x: padding - btnAreaSize - dragOffset, y: rowCell.frame.minY + padding, width: btnAreaSize + rowContent.frame.width, height: rowContent.frame.height)
        
        dragContainer.addSubview(rowDotsBtn)
        rowDotsBtn.frame.origin.y = 0
    }
    
    private func completeRowDragging() {
        let settleRow = rowDotsBtn.rowIndex
        let rect = getAreaRect(rowRange: settleRow..<settleRow+1, colRange: 0..<1)
        let origin = CGPoint(x: padding - btnAreaSize, y: rect.minY + padding)
        UIView.animate(withDuration: 0.2, animations: {
            self.dragContainer.frame.origin = origin
        }, completion: {_ in
            self.rowDraggingDidEnd()
        })
    }
    
    private func rowDraggingDidEnd() {
        print("rowDraggingDidEnd")
        rowDotsBtnContainer.addSubview(rowDotsBtn)
        let row = rowDotsBtn.rowIndex
        changeSupview(supview: contentView, rowRange: row..<row+1, colRange: 0..<numberOfColumns)
        contentView.layer.addSublayer(highlightLayer)
        dragContainer.removeFromSuperview()
        editingCell = [row, editingCell?[1] ?? 0]
        setNeedsLayout()
    }
    
    private func initColDragging() {
        print("initColDragging")
        addSubview(dragContainer)
        
        if (highlightState != .col) {
            setHighlightState(.col)
        }
        
        let colContent = UIView()
        dragContainer.addSubview(colContent)
        
        let col = colDotsBtn.colIndex
        let colCell = cells[0][col]
        changeSupview(supview: colContent, rowRange: 0..<numberOfRows, colRange: col..<col+1)
        colContent.layer.addSublayer(highlightLayer)
        colContent.frame = CGRect(x: 0, y: btnAreaSize, width: colCell.frame.width, height: contentView.frame.height)
        colContent.bounds.origin = CGPoint(x: colCell.frame.minX, y: 0)
        colContent.clipsToBounds = true
        
        dragContainer.frame = CGRect(x: padding + colCell.frame.minX - contentView.bounds.minX, y: padding - btnAreaSize - dragOffset, width: colContent.frame.width, height: colContent.frame.height + btnAreaSize)
        
        dragContainer.addSubview(colDotsBtn)
        colDotsBtn.frame.origin.x = 0
    }
    
    private func completeColDragging() {
        print("completeColDragging")
        let settleCol = colDotsBtn.colIndex
        let rect = getAreaRect(rowRange: 0..<1, colRange: settleCol..<settleCol+1)
        let origin = CGPoint(x: padding + rect.minX - contentView.bounds.minX, y: padding - btnAreaSize)
        UIView.animate(withDuration: 0.2, animations: {
            self.dragContainer.frame.origin = origin
        }, completion: {_ in
            self.colDraggingDidEnd()
        })
    }
    
    private func colDraggingDidEnd() {
        print("colDraggingDidEnd")
        colDotsBtnContainer.addSubview(colDotsBtn)
        let col = colDotsBtn.colIndex
        changeSupview(supview: contentView, rowRange: 0..<numberOfRows, colRange: col..<col+1)
        contentView.layer.addSublayer(highlightLayer)
        dragContainer.removeFromSuperview()
        editingCell = [editingCell?[0] ?? 0, col]
        setNeedsLayout()
    }
    
    
    @objc func handleRowDragging(_ gestureRecognizer: UIPanGestureRecognizer) {
        let p = gestureRecognizer.translation(in: self)
        let state = gestureRecognizer.state
        if (state == .began) {
            initRowDragging()
        }
        else if (state == .changed) {
            let dy = p.y - lastDraggingPoint.y
            moveRow(at: rowDotsBtn.rowIndex, by: dy)
        } else if (state == .ended || state == .cancelled) {
            completeRowDragging()
        }
        lastDraggingPoint = p
    }
    
    @objc func handleColDragging(_ gestureRecognizer: UIPanGestureRecognizer) {
        let p = gestureRecognizer.translation(in: self)
        let state = gestureRecognizer.state
        if (state == .began) {
            initColDragging()
        }
        else if (state == .changed) {
            let dx = p.x - lastDraggingPoint.x
            moveCol(at: colDotsBtn.colIndex, by: dx)
        } else if (state == .ended || state == .cancelled) {
            completeColDragging()
        }
        lastDraggingPoint = p
    }
    
    private func updateCellsPosition(rowRange: Range<Int>, colRange: Range<Int>) {
        for row in rowRange {
            for col in colRange {
                let tv = cells[row][col]
                tv.frame = getAreaRect(rowRange: row..<row + 1, colRange: col..<col+1)
                tv.row = row
                tv.col = col
            }
        }
    }

    override func layoutSubviews() {
        if (isDragging()) {
            // dragging
            return
        }
        if (ignoreNextLayout) {
            ignoreNextLayout = false
            return
        }
        if (numberOfRows * numberOfColumns == 0) {
            return
        }
        print("layoutSubviews")
        let t1 = Date().timeIntervalSince1970
        calculateTableSize(with: frame.width)
        let t2 = Date().timeIntervalSince1970
        print("calculateTableSize: \(String(format: "%.1f", (t2 - t1) * 1000.0))ms")
        updateCellsPosition(rowRange: 0..<numberOfRows, colRange: 0..<numberOfColumns)
        let tableRect = getAreaRect(rowRange: 0..<numberOfRows, colRange: 0..<numberOfColumns)
        contentView.contentSize = tableRect.size
        let w = frame.width - 2 * padding
        let h = tableRect.height
        contentView.frame = CGRect(x: padding, y: padding, width: w, height: h)
        colDotsBtnContainer.frame = CGRect(x: padding, y: padding - btnAreaSize, width: w, height: btnAreaSize)
        rowDotsBtnContainer.frame = CGRect(x: padding - btnAreaSize, y: padding, width: btnAreaSize, height: h)
        if (editingCell != nil) {
            updateEditingCell(cell: editingCell)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view == self ||
            view == colDotsBtnContainer ||
            view == rowDotsBtnContainer {
            // 对事件透明的view
            return nil
        }
        return view
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width
        calculateTableSize(with: width)
        let tableRect = getAreaRect(rowRange: 0..<numberOfRows, colRange: 0..<numberOfColumns)
        let height = tableRect.height + padding * 2
        return CGSize(width: width, height: height)
    }

    private func clearAllCells() {
        for subview in contentView.subviews {
            if (subview is CellTextView) {
                subview.removeFromSuperview()
            }
        }
        cells.removeAll()
    }

    private func calculateTableSize(with width: Double) {
        rowHeightSums = Array(repeating: 0, count: numberOfRows + 1)
        columnWidthSums = Array(repeating: 0, count: numberOfColumns + 1)
        
        for col in 0..<numberOfColumns {
            var w = 0.0
            for row in 0..<numberOfRows {
                let tv = cells[row][col]
                w = max(w, calculateCellWidth(textView: tv, width: width))
            }
            columnWidthSums[col + 1] = columnWidthSums[col] + w
        }
        
        // 不足宽度则平均增加到每列
        let extraWidths = width - columnWidthSums.last! - padding * 2
        if (extraWidths > 0)
        {
            let w = extraWidths / CGFloat(numberOfColumns)
            var sum = 0.0
            for col in 1...numberOfColumns {
                sum += w
                columnWidthSums[col] += sum
            }
        }
        
        for row in 0..<numberOfRows {
            var h = 0.0
            for col in 0..<numberOfColumns {
                let tv = cells[row][col]
                let w = columnWidthSums[col + 1] - columnWidthSums[col]
                h = max(h, calculateCellHeight(textView: tv, width: w))
                tv.isCacheSizeInvalid = false
            }
            rowHeightSums[row + 1] = rowHeightSums[row] + h
        }
    }

    private func calculateCellWidth(textView: CellTextView, width: Double) -> CGFloat {
        if (textView.isCacheSizeInvalid) {
            // 格子宽度策略：
            // n行内容，宽度x: 如果宽度设置为上限设置为x，行数<=n，那么宽度设置不大于x
            let lines = [2, 4, 6]
            let widthTable = [0.4, 0.6, 0.8]
            let minWidth = 50.0
            let maxWidth = max(minWidth, width * 0.8)
            let lineHeight = textView.font?.lineHeight ?? 15.0
            var finalWidth = maxWidth
            for i in lines.indices {
                let line = lines[i]
                let r = widthTable[i]
                let width = minWidth + (maxWidth - minWidth) * r
                let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
                let n = Int(size.height / lineHeight)
                if n <= line {
                    finalWidth = width
                    break
                }
            }
            textView.cacheWidth = max(minWidth, min(maxWidth, finalWidth))
        }
        return textView.cacheWidth
    }

    private func calculateCellHeight(textView: CellTextView, width: CGFloat) -> CGFloat {
        if (textView.isCacheSizeInvalid) {
            let size = textView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            textView.cacheHeight = max(size.height, 30.0)
        }
        return textView.cacheHeight
    }
    
    private class ContentView: UIScrollView {
    }
    
    private class CellTextView: UITextView {
        var row = 0
        var col = 0
        var isCacheSizeInvalid = true
        var cacheWidth = 0.0
        var cacheHeight = 0.0
    }
    
    enum HighlightState {
    case row, col, none
    }
    
    private class DotsButton: UIButton {
        
        var isHightlight = false
        var highlightColor = UIColor.systemYellow
        var isOnRow = true
        var rowIndex = 0
        var colIndex = 0
        var panGestureRecoginzer: UIGestureRecognizer? = nil
        
        private let dotsRadius = 2.0
        private let dotsGap = 8.0
        private let dotsNormalColor = UIColor.lightGray
        private let dotsHighlightColor = UIColor.white
        private let highlightRadius = 6.0
        
        init() {
            super.init(frame: .zero)
            backgroundColor = .white.withAlphaComponent(0.0)
        }
        
        override func menuAttachmentPoint(for configuration: UIContextMenuConfiguration) -> CGPoint {
            return CGPoint(x: bounds.midX, y: bounds.maxY + 10)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setHighlight(_ highlight: Bool) {
            isHightlight = highlight
            setNeedsDisplay()
            if (!isHightlight) {
                self.menu = nil
                showsMenuAsPrimaryAction = false
            }
        }
        
        func setMenu(_ menu: UIMenu) {
            self.menu = menu
            showsMenuAsPrimaryAction = true
            if (panGestureRecoginzer != nil) {
                for i in 0..<gestureRecognizers!.count {
                    if (gestureRecognizers![i] != panGestureRecoginzer) {
                        gestureRecognizers![i].require(toFail: panGestureRecoginzer!)
                    }
                }
            }
        }
        
        /// 高亮时，可点击区域是整个按钮，否则，缩短为三个点的图标大小
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if (isHightlight) {
                return super.point(inside: point, with: event)
            }
            let size = dotsGap * 2 + dotsRadius * 2 + 10
            let offset = size * 0.5
            let rect: CGRect
            if (isOnRow) {
                rect = CGRect(x: 0, y: bounds.midY - offset , width: bounds.width, height: size)
            } else {
                rect = CGRect(x: bounds.midX - offset, y: 0, width: size, height: bounds.height)
            }
            return rect.contains(point)
        }
        
        override func draw(_ rect: CGRect) {
            let ctx = UIGraphicsGetCurrentContext()!
            if (isHightlight) {
                drawHighlight(ctx)
            }
            drawDots(ctx)
        }
        
        private func drawHighlight(_ ctx: CGContext) {
            let radii = CGSize(width: highlightRadius, height: highlightRadius)
            var path: CGPath
            if (isOnRow) {
                path = UIBezierPath(roundedRect: bounds, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: radii).cgPath
            } else {
                path = UIBezierPath(roundedRect: bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: radii).cgPath
            }
            ctx.setFillColor(highlightColor.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }
        
        private func drawDots(_ ctx: CGContext) {
            ctx.setFillColor((isHightlight ? dotsHighlightColor : dotsNormalColor).cgColor)
            var x = bounds.midX
            var y = bounds.midY
            var dx = 0.0
            var dy = 0.0
            if (isOnRow) {
                y -= dotsGap
                dy = dotsGap
            } else {
                x -= dotsGap
                dx = dotsGap
            }
            for _ in 0..<3 {
                ctx.addArc(center: CGPoint(x: x, y: y), radius: dotsRadius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
                ctx.fillPath()
                x += dx
                y += dy
            }
        }
    }
    
    private class HightlightLayer : CALayer {
        var strokeWidth = 0.0
        var highlightColor = UIColor.systemYellow
        
        override func draw(in ctx: CGContext) {
            let padding = strokeWidth * 0.5
            let rect = bounds.insetBy(dx: padding, dy: padding)
            ctx.setStrokeColor(highlightColor.cgColor)
            ctx.stroke(rect, width: strokeWidth)
        }
        
        override func action(forKey event: String) -> CAAction? {
            if (event == "hidden") {
                return super.action(forKey: event)
            }
            return nil
        }
    }
    
    func requireBeginEditing() {
        if editBegan {
            return
        }
        editBegan = true
        if cells.isEmpty || cells[0].isEmpty {
            return
        }
        let firstCell = cells[0][0]
        let _ = firstCell.becomeFirstResponder()
        attachment?.didBeginEditing()
    }
    
    func requireEndEditing() {
        if !editBegan {
            return
        }
        setHighlightState(.none)
        editBegan = false
        attachment?.didEndEditing()
    }
    
    func didBeginEditing() {
        if editBegan {
            return
        }
        editBegan = true
        attachment?.didBeginEditing()
    }
}

extension NotesTableView : RichTextAttachmentView {
    func attachmentBind(_ attachment: RichTextAttachment) {
        self.attachment = attachment
    }
    
    func attachmentBounds(for lineFrag: CGRect, padding: UIEdgeInsets) -> CGRect {
        let size = sizeThatFits(CGSize(width: lineFrag.width, height: .greatestFiniteMagnitude))
        let contentHeight = size.height - 2 * self.padding
        return CGRect(x: 0, y: 0, width: size.width, height: contentHeight)
    }
    
    func attachmentLayout(bounds: CGRect, lineFragment: UnsafeMutablePointer<CGRect>, lineFragmentUsed: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>) {
        var lineRect = lineFragment.pointee
//        lineRect.origin.y += btnAreaSize * 0.8 修改origin会导致下方的附件位置出现问题
        lineRect.size.height += 10
        lineFragment.initialize(to: lineRect)
        lineFragmentUsed.initialize(to: lineRect)
        frame = CGRect(x: 0, y: lineRect.minY - self.padding + btnAreaSize * 0.8, width: bounds.width, height: bounds.height + 2 * self.padding)
    }
    
    func attachmentRequireEndEditing() {
        requireEndEditing()
    }
    
    func attachmentRequireBeginEditing() {
        requireBeginEditing()
    }
    
    override func setNeedsLayout() {
        attachment?.invalidateLayout()
        super.setNeedsLayout()
    }
}

extension NotesTableView : UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScroll()
    }
}

extension NotesTableView : UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let cell = textView as! CellTextView
        cell.isCacheSizeInvalid = true
        setNeedsLayout()
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        let tv = textView as! CellTextView
        setHighlightState(.none)
        updateEditingCell(cell: [tv.row, tv.col])
        didBeginEditing()
        print("editing \(tv.row) \(tv.col)")
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if highlightState == .none {
            updateEditingCell(cell: nil)
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            let cell = textView as! CellTextView
            let nextIndex = cell.row * numberOfColumns + cell.col + 1
            let nextRow = nextIndex / numberOfColumns
            let nextCol = nextIndex % numberOfColumns
            if nextRow < numberOfRows && nextCol < numberOfColumns {
                cells[nextRow][nextCol].becomeFirstResponder()
            } else {
                addRow(after: cell.row)
            }
            return false
        }
        return true
    }
}

extension CALayer {
    func setFrameWithoutAnim(_ frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = frame
        CATransaction.commit()
    }
}

extension UIView {
    func setFrameWithoutAnim(_ frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.frame = frame
        CATransaction.commit()
    }
}
