//
//  BottomSheetViewController.swift
//  NearTalk
//
//  Created by lymchgmk on 2022/11/17.
//
//

import RxCocoa
import SnapKit
import UIKit

final class BottomSheetViewController: UIViewController {
    
    static let roomTypeItems: [String] = ["전체 채팅방 목록", "입장 가능한 목록"]
    private let roomTypeSegmentedControl = UISegmentedControl(items: BottomSheetViewController.roomTypeItems).then {
        $0.backgroundColor = .red
    }
    
    lazy var chatRoomsTableView = UITableView(frame: CGRect.zero, style: .plain).then {
        $0.register(BottomSheetTableViewCell.self,
                    forCellReuseIdentifier: BottomSheetTableViewCell.reuseIdentifier)
        $0.delegate = self
    }
    
    private var dataSource: [ChatRoom] = []
    
    static func create(with datasource: [ChatRoom]) -> BottomSheetViewController {
        let bottomSheetVC = BottomSheetViewController()
        bottomSheetVC.dataSource = datasource
        
        return bottomSheetVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addSubViews()
        self.configureConstraints()
        self.configureLayout()
    }
    
    private func addSubViews() {
        self.view.addSubview(roomTypeSegmentedControl)
        self.view.addSubview(chatRoomsTableView)
    }
    
    private func configureConstraints() {
        self.roomTypeSegmentedControl.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(40)
        }
        
        self.chatRoomsTableView.snp.makeConstraints {
            $0.top.equalTo(self.roomTypeSegmentedControl.snp.bottom).offset(20)
            $0.leading.equalToSuperview()
            $0.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func configureLayout() {
        self.view.backgroundColor = .systemOrange
        
        self.modalPresentationStyle = .pageSheet
        
        if let sheet = self.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .medium
            sheet.preferredCornerRadius = 20
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
    }
}

extension BottomSheetViewController: UITableViewDelegate {
    
}

extension BottomSheetViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BottomSheetTableViewCell.reuseIdentifier, for: indexPath)
        
        return cell
    }
}
