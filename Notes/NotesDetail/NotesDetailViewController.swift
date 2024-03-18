//
//  NotesDetailViewController.swift
//  Notes
//
//  Created by laishere on 2023/4/2.
//

import UIKit

class NotesDetailViewController: UIViewController, BottomSheetViewControllerDelegate, NotesBottomMenuViewDelegate, TextFormatMenuViewDelegate {
    
    @IBOutlet weak var notesView: NotesView!
    
    @IBOutlet weak var menuView: NotesBottomMenuView!
    
    private var textFormatSheetController: BottomSheetViewController? = nil
    private var textFormatMenuView: TextFormatMenuView? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    private func setupViews() {
        menuView.delegate = self
        notesView.notesViewDelegate = self
    }
    
    func menuTapped(at index: Int) {
        switch index {
        case 0:
            notesView.insertTable()
        case 1:
            showTextFormatBottomSheet()
        case 2:
            toggleChecklist()
        case 3:
            notesView.insertImage(UIImage(named: "Image")!)
        default:
            break
        }
    }
    
    func bottomSheetWillDismiss() {
        notesView.enableInput()
    }
    
    private func toggleChecklist() {
        notesView.setTextType(notesView.textFormat.type == .checklist ? .normal : .checklist)
    }
    
    private func initTextFormatSheet() {
        let sheetController = BottomSheetViewController()
        let titleView = UIView()
        let label = UILabel()
        label.text = "格式"
        label.font = .systemFont(ofSize: 18.0, weight: .bold)
        let closeBtn = UIButton()
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .systemGray
        closeBtn.contentVerticalAlignment = .fill
        closeBtn.contentHorizontalAlignment = .fill
        closeBtn.configuration = .plain()
        let btnPadding = 10.0
        closeBtn.configuration?.contentInsets = NSDirectionalEdgeInsets(top: btnPadding, leading: btnPadding, bottom: btnPadding, trailing: btnPadding)
        titleView.addSubview(label)
        titleView.addSubview(closeBtn)
        
        let container = UIStackView()
        container.axis = .vertical
        let menuView = TextFormatMenuView()
        container.addArrangedSubview(titleView)
        container.addArrangedSubview(menuView)
        
        titleView.layoutMargins = UIEdgeInsets(top: 0, left: 15.0, bottom: 0, right: 15.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        titleView.translatesAutoresizingMaskIntoConstraints = false
        menuView.translatesAutoresizingMaskIntoConstraints = false
        let titleViewHeightCon = titleView.heightAnchor.constraint(equalToConstant: 50)
        titleViewHeightCon.priority = .defaultLow
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: titleView.layoutMarginsGuide.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: titleView.layoutMarginsGuide.trailingAnchor, constant: btnPadding),
            closeBtn.widthAnchor.constraint(equalToConstant: 50),
            closeBtn.heightAnchor.constraint(equalToConstant: 50),
            closeBtn.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
            titleViewHeightCon
        ])
        sheetController.setContentView(container, height: 200)
        sheetController.delegate = self
        textFormatSheetController = sheetController
        closeBtn.addTarget(self, action: #selector(closeSheet), for: .touchUpInside)
        menuView.delegate = self
        textFormatMenuView = menuView
    }
    
    @objc func closeSheet(_ : Any?) {
        textFormatSheetController?.dismiss(animated: true)
    }
    
    private func showTextFormatBottomSheet() {
        if (textFormatSheetController == nil) {
            initTextFormatSheet()
        }
        notesView.disableInput()
        notesView.forceUpdateSelectedRange()
        textFormatMenuView?.updateText(type: notesView.textFormat.type, style: notesView.textFormat.style)
        present(textFormatSheetController!, animated: true)
    }

    
    func textFormatSwitchTextType(to type: TextType) {
        notesView.setTextType(type)
    }
    
    func textFormatToggleTextStyle(_ style: TextStyle, on: Bool) {
        if on {
            notesView.addTextStyle(style)
        } else {
            notesView.removeTextStyle(style)
        }
    }
}

extension NotesDetailViewController: NotesViewDelegate {
    func notesViewDidUpdateTextFormat(_ format: TextFormat) {
        textFormatMenuView?.updateText(type: format.type, style: format.style)
    }
    
    func notesViewEditingMainContentChanged(_ editing: Bool) {
        menuView?.disabled = !editing
    }
}
