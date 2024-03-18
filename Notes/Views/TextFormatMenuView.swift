//
//  textStyleMenuView.swift
//  Notes
//
//  Created by laishere on 2023/8/10.
//

import UIKit

class TextFormatMenuView: UIView {
    
    weak var delegate: TextFormatMenuViewDelegate? = nil
    
    private var textTypesContainer: UIView!
    private var textTypesViews: [UIButton] = []
    private var textTypes: [TextType] = []
    private var textStyles: [TextStyle] = []
    private var textTypesViewWidths: [CGFloat] = []
    private var textTypesViewsSumWidth = 0.0
    private var textTypeHighlightView: UIView!
    private let textTypesHeight = 50.0
    private let paddingHorizontal = 15.0
    private let textTypeHighlightPadding = 10.0
    private var textTypeViewsGap = 0.0
    private var lastSelectedTypeIndex = -1
    private var textStyleViews: [RoundedButton] = []
    private let cornerRadius = 8.0

    init() {
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        textTypesContainer = UIView()
        textTypeHighlightView = UIView()
        textTypeHighlightView.backgroundColor = .systemYellow
        textTypeHighlightView.layer.cornerRadius = cornerRadius
        textTypeHighlightView.isHidden = true
        textTypesContainer.addSubview(textTypeHighlightView)
        setupTextTypes()
        addSubview(textTypesContainer)
        setuptextStyleViews()
    }
    
    func updateText(type: TextType, style: TextStyle) {
        let typeIndex = textTypes.firstIndex(of: type) ?? -1
        updateSelectedType(at: typeIndex)
        for i in textStyleViews.indices {
            textStyleViews[i].isSelected = style.contains(textStyles[i])
        }
    }
    
    private func setupTextTypes() {
        let typesTextArray = [
            NSAttributedString(string: "标题", attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .heavy)
            ]),
            NSAttributedString(string: "小标题", attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold)
            ]),
            NSAttributedString(string: "副标题", attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold)
            ]),
            NSAttributedString(string: "正文", attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]),
            NSAttributedString(string: "等宽", attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            ])
        ]
        textTypes = [.title1, .title2, .title3, .normal, .monospace]
        textTypesViewsSumWidth = 0.0
        for i in typesTextArray.indices {
            let text = typesTextArray[i]
            let range = NSRange(location: 0, length: text.length)
            let highlightedText = NSMutableAttributedString(attributedString: text)
            highlightedText.addAttributes([.foregroundColor: UIColor.systemGray], range: range)
            let selectedText = NSMutableAttributedString(attributedString: text)
            selectedText.addAttributes([.foregroundColor: UIColor.white], range: range)
            let button = UIButton()
            button.setAttributedTitle(text, for: .normal)
            button.setAttributedTitle(highlightedText, for: .highlighted)
            button.setAttributedTitle(selectedText, for: .selected)
            button.tag = i
            button.addTarget(self, action: #selector(typeButtonTapped), for: .touchUpInside)
            let size = button.sizeThatFits(CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
            textTypesViewsSumWidth += size.width
            textTypesViewWidths.append(size.width)
            textTypesContainer.addSubview(button)
            textTypesViews.append(button)
        }
    }
    
    private func setuptextStyleViews() {
        let icons = [
            "bold",
            "italic",
            "underline",
            "strikethrough"
        ]
        textStyles = [.bold, .italic, .underline, .strikethrough]
        for i in icons.indices {
            let image = UIImage(systemName: icons[i])!
            let button = RoundedButton()
            if (i == 0) {
                button.corners = [.topLeft, .bottomLeft]
            } else if (i == icons.count - 1) {
                button.corners = [.topRight, .bottomRight]
            }
            button.cornerRadius = cornerRadius
            button.setImage(image.withTintColor(.black, renderingMode: .alwaysOriginal), for: .normal)
            button.setImage(image.withTintColor(.white, renderingMode: .alwaysOriginal), for: .selected)
            button.tag = i
            button.addTarget(self, action: #selector(styleButtonTapped), for: .touchUpInside)
            addSubview(button)
            textStyleViews.append(button)
        }
    }
    
    @objc func typeButtonTapped(_ sender : Any?) {
        let button = sender as! UIButton
        let index = button.tag
        if (textTypes.indices.contains(index)) {
            delegate?.textFormatSwitchTextType(to: textTypes[index])
        }
    }
    
    @objc func styleButtonTapped(_ sender : Any?) {
        let button = sender as! UIButton
        let index = button.tag
        if (textStyles.indices.contains(index)) {
            delegate?.textFormatToggleTextStyle(textStyles[index], on: !button.isSelected)
        }
    }
    
    private func updateSelectedType(at index: Int) {
        if (lastSelectedTypeIndex == index) {
            return
        }
        if (textTypesViews.indices.contains(lastSelectedTypeIndex)) {
            textTypesViews[lastSelectedTypeIndex].isSelected = false
        }
        lastSelectedTypeIndex = index
        if (!textTypesViews.indices.contains(index)) {
            textTypeHighlightView.isHidden = true
            return
        }
        let boundsOffset = index == 0 ? 0.0 : (index == textTypesViews.count - 1 ? textTypeViewsGap * 0.5 : textTypesContainer.bounds.origin.x)
        let lastVisible = textTypeHighlightView.isHidden == false
        if (!lastVisible) {
            textTypeHighlightView.frame = textTypesViews[index].frame
            textTypeHighlightView.isHidden = false
            textTypeHighlightView.setNeedsDisplay()
        }
        self.textTypesViews[index].isSelected = true
        UIView.animate(withDuration: 0.2, animations: {
            if (lastVisible) {
                self.textTypeHighlightView.frame = self.textTypesViews[index].frame
            }
            self.textTypesContainer.bounds.origin.x = boundsOffset
        })
    }
    
    override func layoutSubviews() {
        let width = frame.width
        textTypesContainer.frame = CGRect(x: 0, y: 0, width: width, height: textTypesHeight)
        let typeViewGap = 2 * (width - paddingHorizontal * 2 - textTypesViewsSumWidth) / (2 * CGFloat(textTypesViews.count) - 1)
        textTypeViewsGap = typeViewGap
        var xOffset = paddingHorizontal
        for i in textTypesViews.indices {
            let view = textTypesViews[i]
            let textWidth = textTypesViewWidths[i]
            let viewWidth = textWidth + typeViewGap
            view.frame = CGRect(x: xOffset, y: 0, width: viewWidth, height: textTypesHeight)
            xOffset += viewWidth
            if (i == lastSelectedTypeIndex) {
                textTypeHighlightView.frame = view.frame
            }
//            label.backgroundColor = i % 2 == 0 ? .systemGray2 : .systemGray4
        }
        let yOffset = textTypesContainer.frame.maxY + 8.0
        xOffset = paddingHorizontal
        let styleViewGap = 2.0
        let styleViewWidth = (width - paddingHorizontal * 2 - styleViewGap * CGFloat(textStyleViews.count - 1)) / CGFloat(textStyleViews.count)
        for view in textStyleViews {
            view.frame = CGRect(x: xOffset, y: yOffset, width: styleViewWidth, height: textTypesHeight)
            xOffset += styleViewWidth + styleViewGap
        }
    }
    
    private class RoundedButton: UIButton {
        var corners: UIRectCorner = []
        var cornerRadius = 0.0
        
        init() {
            super.init(frame: .zero)
            addObserver(self, forKeyPath: #keyPath(UIButton.frame), options: [.new], context: nil)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if (keyPath == "frame") {
                updateBackground()
            }
        }
        
        private func updateBackground() {
            setBackgroundImage(getImage(.systemGray6), for: .normal)
            setBackgroundImage(getImage(.systemGray5), for: .highlighted)
            setBackgroundImage(getImage(.systemYellow), for: .selected)
        }
        
        private func getImage(_ color: UIColor) -> UIImage {
            return UIGraphicsImageRenderer(bounds: bounds).image {ctx in
                let path = UIBezierPath(
                    roundedRect: bounds,
                    byRoundingCorners: corners,
                    cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
                )
                color.setFill()
                path.fill()
            }
        }
    }
}

protocol TextFormatMenuViewDelegate: NSObject {
    func textFormatSwitchTextType(to type: TextType)
    func textFormatToggleTextStyle(_ style: TextStyle, on: Bool)
}
