//
//  ChatViewController.swift
//  Messenger
//
//  Created by Andrew Maher on 28/12/2020.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}

struct Sender: SenderType {
    public var photoUrl: String
    public var senderId: String
    public var displayName: String
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formater = DateFormatter()
        formater.dateStyle = .medium
        formater.timeStyle = .long
        formater.locale = .current
        return formater
    }()
    
    public var isNewConversation = false
    public let otherUserEmail: String
    private var conversationId: String?
    
    private var messages = [Message]()
    private var selfSender:Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.getSafeEmail(from: email)
        return Sender(photoUrl: "",
                      senderId: safeEmail,
                      displayName: "Me")
    }
    
    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blue
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId{
            listenForMessages(id: conversationId)
        }
    }
    
    private func listenForMessages(id: String){
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: {
            [weak self ] result in
            switch result{
            case .success(let messages):
                print("Success getting messages: \(messages)")
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                }
            case .failure(let error):
                print("Failed to get messages: \(error)")
            }
        })
    }
}


// MARK: - Input search Delegate
extension ChatViewController: InputBarAccessoryViewDelegate{
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId() else{
            return
        }
        // Send message
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        if isNewConversation {
            //create new convo
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,name: self.title ?? "User",  firstMessage: message, completion: { [weak self] success, id in
                if success{
                    print("Send message \(text)")
                    self?.isNewConversation = false
                    if let id = id {
                        self?.conversationId = id
                        self?.listenForMessages(id: self?.conversationId ?? "")
                    }
                }else{
                    print("Failed sent")
                }
            })
        }else{
            // append to existing one
            guard let conversationId = conversationId,
                  let name = self.title else{
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId,otherUserEmail: otherUserEmail, name: name, message: message, completion: {success in
                if success{
                    print("Message sent")
                }else{
                    print("Failed sent")
                }
            })
        }
    }
    
    private func createMessageId()->String?{
        guard let email = UserDefaults.standard.value(forKey: "email") as? String
        else {
            return nil
        }
        let safeEmail = DatabaseManager.getSafeEmail(from: email)
        let dateString = Self.dateFormatter.string(from: Date())
        let newId = "\(otherUserEmail)_\(safeEmail)_\(dateString)"
        return newId
    }
}

// MARK:- Message Delegate
extension ChatViewController : MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate{
    func currentSender() -> SenderType {
        if let sender = selfSender{
            return sender
        }
        fatalError("Self Sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
}
