//
//  ChatViewController.swift
//  NearTalk
//
//  Created by dong eun shin on 2022/11/23.
//

import RxSwift
import UIKit

final class ChatViewController: UIViewController, UICollectionViewDelegate {
    // MARK: - Proporties
    
    private enum Metric {
        static var keyboardHeight: CGFloat = 0
        static var defaultChatInputAccessoryViewHeight = 50
    }
    
    private let viewModel: ChatViewModel
    private var messageItems: [MessageItem]
    
    private let disposeBag: DisposeBag = DisposeBag()
    private lazy var dataSource: DataSource = makeDataSource()
    private lazy var compositionalLayout: UICollectionViewCompositionalLayout = self.createLayout()
    
    private lazy var collectionView: UICollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: compositionalLayout
    ).then {
        $0.backgroundColor = .primaryBackground
        $0.showsVerticalScrollIndicator = false
        $0.register(ChatCollectionViewCell.self, forCellWithReuseIdentifier: ChatCollectionViewCell.identifier)
        $0.delegate = self
    }
    
    private lazy var chatInputAccessoryView: ChatInputAccessoryView = ChatInputAccessoryView().then {
        $0.backgroundColor = .primaryBackground
    }
        
    // MARK: - Lifecycles
    
    init(viewModel: ChatViewModel) {
        self.messageItems = []
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.viewModel.viewDidDisappear()
        super.viewDidDisappear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .primaryBackground
        self.addSubviews()
        self.configureChatInputAccessoryView()
        self.configureCollectionView()
        self.bind()
        self.chatInputAccessoryView.messageInputTextField.delegate = self
        
        /// 키보드
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardHandler(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardHandler(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        /// 제스처
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard(_:)))
        view.addGestureRecognizer(tapGesture)
    }

    private func scrollToBottom() {
        let indexPath = IndexPath(item: messageItems.count - 1, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
    }
        
    private func bind() {
        self.chatInputAccessoryView.messageInputTextField.rx.text.orEmpty
            .map { !$0.isEmpty }
            .bind(to: chatInputAccessoryView.sendButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        self.chatInputAccessoryView.sendButton.rx.tap
            .withLatestFrom(chatInputAccessoryView.messageInputTextField.rx.text.orEmpty)
            .filter { !$0.isEmpty }
            .bind { [weak self] message in
                self?.viewModel.sendMessage(message)
                self?.chatInputAccessoryView.messageInputTextField.text = nil
                self?.chatInputAccessoryView.sendButton.isEnabled = false
            }
            .disposed(by: disposeBag)
        
        self.viewModel.chatMessages
            .asDriver(onErrorJustReturn: [])
            .drive(onNext: { [weak self] messages in
                guard let self,
                      let myID = self.viewModel.myID,
                      let message: ChatMessage = messages.last else {
                    return
                }
                
                let userProfile: UserProfile? = self.viewModel.getUserProfile(userID: message.senderID ?? "")
                
                let messageItem: MessageItem = .init(
                    chatMessage: message,
                    myID: myID,
                    userProfile: userProfile
                )
                
                self.messageItems.append(messageItem)
                let snapshot = self.appendSnapshot(items: self.messageItems)
                self.dataSource.apply(snapshot, animatingDifferences: false) {
                    self.scrollToBottom()
                }
            })
            .disposed(by: disposeBag)
        
        self.viewModel.chatRoom
            .bind { [weak self] chatRoom in
                guard let self,
                      let chatRoom else {
                    return
                }
                self.navigationItem.title = "\(chatRoom.roomName ?? "Unknown") (\(chatRoom.userList?.count ?? 0))"
            }
            .disposed(by: disposeBag)
        
        self.chatInputAccessoryView.messageInputTextField.rx.text.orEmpty
            .filter({!$0.isEmpty})
            .subscribe(onNext: { _ in
                print("=--------=", self.chatInputAccessoryView.messageInputTextField.frame.height)
                self.reconfigureChatInputAccessoryView()
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UICollectionViewDiffableDataSource

private extension ChatViewController {
    typealias DataSource = UICollectionViewDiffableDataSource<Section, MessageItem>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, MessageItem>
    
    enum Section {
        case main
    }
    
    func makeDataSource() -> DataSource {
        let datasource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self,
                  let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: ChatCollectionViewCell.identifier,
                    for: indexPath) as? ChatCollectionViewCell
            else {
                return UICollectionViewCell()
            }
            cell.configure(messageItem: item) {
                var snapshot = self.dataSource.snapshot()
                snapshot.reloadItems([item])
            }
            return cell
        }
        return datasource
    }
    
    func appendSnapshot(items: [MessageItem]) -> NSDiffableDataSourceSnapshot<Section, MessageItem> {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(messageItems.sorted { $0.createdAt < $1.createdAt })
        return snapshot
    }
}

// MARK: - UITextViewDelegate

extension ChatViewController: UITextViewDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }
}

// MARK: - Keyboard Notification Handler

private extension ChatViewController {
    @objc
    func keyboardHandler(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let keyboardAnimationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
              let keyboardDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let keyboardCurve = UIView.AnimationCurve(rawValue: keyboardAnimationCurve)
        else {
            return
        }
        
        let keyboardSize = keyboardFrame.cgRectValue
        let keyboardHeight = keyboardSize.height
        
        let safeAreaExists = (self.view?.window?.safeAreaInsets.bottom != 0)
        let bottomConstant: CGFloat = 20
        Metric.keyboardHeight = keyboardHeight + (safeAreaExists ? 0 : bottomConstant)

        self.reconfigureChatInputAccessoryView()
        
        self.collectionView.snp.makeConstraints { make in
            make.bottom.equalTo(chatInputAccessoryView.snp.top)
        }
        
        print("키보드--------", self.chatInputAccessoryView.messageInputTextField.frame.height, self.chatInputAccessoryView.frame.height)
        
        let animator = UIViewPropertyAnimator(duration: keyboardDuration, curve: keyboardCurve) { [weak self] in
            self?.view.layoutIfNeeded()
        }
        
        animator.startAnimation()
        self.scrollToBottom()
    }
    
    @objc
    func hideKeyboard(_ sender: Any) {
        view.endEditing(true)
        
        self.chatInputAccessoryView.snp.remakeConstraints { make in
            make.left.right.equalTo(self.view)
            make.height.equalTo(Metric.defaultChatInputAccessoryViewHeight)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide)
        }
        
        self.collectionView.snp.remakeConstraints { make in
            make.left.right.equalTo(self.view)
            make.top.equalTo(self.view.safeAreaLayoutGuide)
            make.bottom.equalTo(chatInputAccessoryView.snp.top)
        }
    }
}

// MARK: - Layout

private extension ChatViewController {
    func addSubviews() {
        [collectionView, chatInputAccessoryView].forEach {
            self.view.addSubview($0)
        }
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .estimated(40.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(40))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                         subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8.0

        let layout = UICollectionViewCompositionalLayout(section: section)
        
        return layout
    }
    
    func reconfigureChatInputAccessoryView() {
        let contentHeight = self.chatInputAccessoryView.messageInputTextField.contentSize.height
        
        if (41...(40*3)).contains(contentHeight) {
            self.chatInputAccessoryView.snp.remakeConstraints { make in
                make.left.right.equalTo(self.view)
                make.height.equalTo(self.chatInputAccessoryView.messageInputTextField.contentSize.height)
                make.bottom.equalToSuperview().inset(Metric.keyboardHeight)
            }
        } else if ((40*3) + 1) < contentHeight {
            self.chatInputAccessoryView.snp.remakeConstraints { make in
                make.left.right.equalTo(self.view)
                make.height.equalTo((40*3) + (5*2))
                make.bottom.equalToSuperview().inset(Metric.keyboardHeight)
            }
        } else {
            self.chatInputAccessoryView.snp.remakeConstraints { make in
                make.left.right.equalTo(self.view)
                make.height.equalTo(Metric.defaultChatInputAccessoryViewHeight)
                make.bottom.equalToSuperview().inset(Metric.keyboardHeight)
            }
        }
    }
    
    func configureChatInputAccessoryView() {
        self.chatInputAccessoryView.snp.makeConstraints { make in
            make.left.right.equalTo(self.view)
            make.height.equalTo(Metric.defaultChatInputAccessoryViewHeight)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide)
        }
    }
    
    func configureCollectionView() {
        self.collectionView.snp.makeConstraints { make in
            make.left.right.equalTo(self.view)
            make.top.equalTo(self.view.safeAreaLayoutGuide)
            make.bottom.equalTo(chatInputAccessoryView.snp.top)
        }
    }
}
