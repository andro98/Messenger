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
        ], withCompletionBlock: {error, _ in
            guard error == nil else{
                print("Failed to add user to database")
                completion(false)
                return
            }
            completion(true)
        })
    }
}
