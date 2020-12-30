//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Andrew Maher on 28/12/2020.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager{
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func getSafeEmail(from emailAddress: String) -> String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager{
    public func getData(for path: String, completion: @escaping (Result<Any, Error>)->Void){
        self.database.child(path).observeSingleEvent(of: .value){
            snapshot in
            guard let value = snapshot.value else{
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
}


// MARK: - Account Managment
extension DatabaseManager{
    
    /// Check if the email is already exist
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)){
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            
            completion(true)
        })
    }
    
    /// Insert new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void){
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: {
            [weak self] error, _ in
            guard error == nil else{
                print("Failed to add user to database")
                completion(false)
                return
            }
            self?.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var userCollection = snapshot.value as? [[String: String]] {
                    // Add to user dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    userCollection.append(newElement)
                    self?.database.child("users").setValue(userCollection, withCompletionBlock: {error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }else{
                    // create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self?.database.child("users").setValue(newCollection, withCompletionBlock: {error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]] ,Error>) -> Void){
        database.child("users").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as? [[String: String]] else{
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            
            completion(.success(value))
        })
    }
}

extension DatabaseManager{
    public enum DatabaseErrors: Error{
        case failedToFetch
    }
}

// MARK: - Conversation Managment
extension DatabaseManager{
    /// Create a new conversation with the new user and the first message sent
    public func createNewConversation(with otherUserEmail: String, name: String,firstMessage: Message, completion: @escaping (Bool, String?)->Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
            return
        }
        let safeEmail = DatabaseManager.getSafeEmail(from: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: {[weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else{
                completion(false, nil)
                print("User not found")
                return
            }
            var message = ""
            switch firstMessage.kind{
            case .text(let text):
                message = text
            default:
                break
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            let conversationId = "conversation_\(firstMessage.messageId)"
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "is_read": false,
                    "message": message,
                ]
            ]
            let recepient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "is_read": false,
                    "message": message,
                ]
            ]
            // Update recepient user conversation
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {[weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]]{
                    // append
                    conversations.append(recepient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }else{
                    // create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recepient_newConversationData])
                }
            })
            
            // Update current user conversation
            if var conversations = userNode["conversations"] as? [[String: Any]]{
                //append conv already exist
                conversations.append(newConversationData)
                userNode["conversations"] = conversations 
                ref.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else{
                        completion(false, nil)
                        return
                    }
                    self?.finishCreatingConversation(name:name,conversationId: conversationId, firstMessage: firstMessage, completion: completion)
                })
            }else{
                // Create new conversation
                userNode["conversations"] = [newConversationData]
                ref.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else{
                        completion(false, nil)
                        return
                    }
                    self?.finishCreatingConversation(name: name,conversationId: conversationId, firstMessage: firstMessage, completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(name: String, conversationId: String, firstMessage: Message,completion: @escaping (Bool, String?)->Void ){
        var messageContent = ""
        switch firstMessage.kind{
        case .text(let text):
            messageContent = text
        default:
            break
        }
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            completion(false, nil)
            return
        }
        let safeEmail = DatabaseManager.getSafeEmail(from: currentEmail)
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        let message: [String: Any] = [
            "id": firstMessage.messageId ,
            "type": "text",
            "content": messageContent,
            "sender_email": safeEmail,
            "date": dateString ,
            "is_read": false,
            "name": name
        ]
        let value: [String: Any] = [
            "messages": [
                message
            ]
        ]
        database.child("\(conversationId)").setValue(value, withCompletionBlock: {error, _ in
            guard error == nil else{
                completion(false, nil)
                return
            }
            completion(true, conversationId)
        })
    }
    
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversation(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void){
        database.child("\(email)/conversations").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseErrors.failedToFetch ))
                return
            }
            let conversations:[Conversation] = value.compactMap({dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else{
                    return nil
                    
                }
                let latestMessageObject = LatestMessage(date: date, message: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    /// Gets all messages for a given conversation
    public func  getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void){
        database.child("\(id)/messages").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseErrors.failedToFetch ))
                return
            }
            let messages:[Message] = value.compactMap({dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageId = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString),
                      let type = dictionary["type"] as? String else{
                    return nil
                }
                let sender = Sender(photoUrl: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: id, sentDate: date, kind: .text(content))
            })
            completion(.success(messages))
        })
    }
    
    /// Sends a message to a target conversation and a message
    public func sendMessage(to conversation: String,otherUserEmail: String ,name:String, message: Message, completion: @escaping (Bool)->Void){
        // add new message to message
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: {
            [weak self] snapshot in
            guard let strongRef = self else{return}
            
            guard var currentMessages = snapshot.value as? [[String: Any]],
                  let currentEmail = UserDefaults.standard.value(forKey: "email") as? String
            else{
                completion(false)
                return
            }
            
            var messageContent = ""
            switch message.kind{
            case .text(let text):
                messageContent = text
            default:
                break
            }
            
            let safeEmail = DatabaseManager.getSafeEmail(from: currentEmail)
            let messageDate = message.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            let newMessageEntry: [String: Any] = [
                "id": message.messageId ,
                "type": "text",
                "content": messageContent,
                "sender_email": safeEmail,
                "date": dateString ,
                "is_read": false,
                "name": name
            ]
            currentMessages.append(newMessageEntry)
            strongRef.database.child("\(conversation)/messages").setValue(currentMessages, withCompletionBlock: {error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                // update sender latest message
                strongRef.database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String: Any]] else{
                        completion(false)
                        return
                    }
                    
                    let value: [String: Any] = [
                        "date": dateString,
                        "message": messageContent,
                        "is_read": false,
                    ]
                    var targetConversation: [String: Any]?
                    var position = 0
                    for curretConversation in currentUserConversations{
                        if let currentId = curretConversation["id"] as? String,
                           currentId == conversation{
                            targetConversation = curretConversation
                        break
                        }
                        position += 1
                    }
                    targetConversation?["latest_message"] = value
                    guard let finalConversation = targetConversation else{
                        completion(false)
                        return
                    }
                    currentUserConversations[position] = finalConversation
                    strongRef.database.child("\(safeEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: {error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        // update recepient latest message
                        strongRef.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String: Any]] else{
                                completion(false)
                                return
                            }
                            
                            let value: [String: Any] = [
                                "date": dateString,
                                "message": messageContent,
                                "is_read": false,
                            ]
                            var targetConversation: [String: Any]?
                            var position = 0
                            for curretConversation in otherUserConversations{
                                if let currentId = curretConversation["id"] as? String,
                                   currentId == conversation{
                                    targetConversation = curretConversation
                                break
                                }
                                position += 1
                            }
                            targetConversation?["latest_message"] = value
                            
                            guard let finalConversation = targetConversation else{
                                completion(false)
                                return
                            }
                            otherUserConversations[position] = finalConversation
                            strongRef.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: {error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })// End of setvalue for otherUserConversations
                        })// End of observeSingleEvent for otherUserConversations
                    })// End of setValue for currentUserConversations
                })// End of observeSingleEvent for currentUserConversations
            })
        })
    }
}
