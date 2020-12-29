//
//  StorgeManager.swift
//  Messenger
//
//  Created by Andrew Maher on 29/12/2020.
//

import Foundation
import FirebaseStorage

final class StorageManager{
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    public typealias UploadProfilePictureCompletion = (Result<String, Error>) -> Void
}

// MARK: - Storage Profile Picture Handler
extension StorageManager{
    /// Upload picture to firebase storage and return completion with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadProfilePictureCompletion){
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metaData, error in
            // Failed to upload
            guard error == nil else{
                print("Failed to upload data for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            //Getting downloaded url
            self.storage.child("images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else{
                    print("failedToGetDownloadUrl")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("Donwload URL: \(url)")
                completion(.success(urlString))
            })
        })
    }
    
    public func getDownloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void){
        let refrence = storage.child(path)
        refrence.downloadURL(completion: {url, error in
            guard let url = url, error == nil else{
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            completion(.success(url))
        })
    }
}

// MARK: - Storage Error Enum
extension StorageManager{
    public enum StorageErrors: Error{
        case failedToUpload
        case  failedToGetDownloadUrl
    }
}
