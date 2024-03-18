//
//  NotesBottomMenuView.swift
//  Notes
//
//  Created by laishere on 2023/8/6.
//

import UIKit

class NotesBottomMenuView: UIView {
    weak var delegate: NotesBottomMenuViewDelegate? = nil
    private var items: [UIButton] = []
    private let padding = 40.0
    private let iconSize = 20.0
    private var _disabled = false
    
    var disabled: Bool {
        get {
            _disabled
        }
        
        set(value) {
            _disabled = value
            updateDisabled()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .systemGray6
        clipsToBounds = true
        let iconNames = [
            "table",
            "textformat.alt",
            "checklist",
            "camera"
        ]
        for i in iconNames.indices {
            let name = iconNames[i]
            let img = name.first!.isUppercase ? UIImage(named: name)! : UIImage(systemName: name)!
            let btn = UIButton()
            btn.setImage(img, for: .normal)
            btn.configuration = .borderless()
            btn.tintColor = .black
            btn.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
            btn.tag = i
            addSubview(btn)
            items.append(btn)
        }
    }
    
    private func updateDisabled() {
        for v in self.items {
            v.isEnabled = !_disabled
        }
    }
    
    @objc func menuTapped(_ sender: UIButton) {
        delegate?.menuTapped(at: sender.tag)
    }
    
    override func layoutSubviews() {
        var x = 0.0
        let cnt = CGFloat(items.count)
        let gap = (frame.width - padding * 2 - iconSize * cnt) / (cnt - 1)
        let height = frame.height
        for i in 0..<items.count {
            let btn = items[i]
            let nextX = i == 0 ? padding + iconSize + gap * 0.5 : (i + 1 < items.count ? x + iconSize + gap : frame.width)
            let iconLeft = i + 1 < items.count ? nextX - gap * 0.5 - iconSize : x + gap * 0.5
            btn.configuration?.contentInsets = .init(top: 0, leading: iconLeft - x, bottom: 0, trailing: nextX - iconLeft - iconSize)
            btn.frame = CGRect(x: x, y: 0.0, width: nextX - x, height: height)
            x = nextX
        }
    }
}

protocol NotesBottomMenuViewDelegate: NSObject {
    func menuTapped(at index: Int)
}
