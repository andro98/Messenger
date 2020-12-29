//
//  ProfileViewController.swift
//  Messenger
//
//  Created by Andrew Maher on 28/12/2020.
//

import UIKit
import FirebaseAuth

class ProfileViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    let data = ["Log Out"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableViewHeader()
    }
    
    func createTableViewHeader()->UIView?{
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return nil
        }
        let safeEmail = DatabaseManager.getSafeEmail(from: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "images/" + fileName
        
        let headerView = UIView()
        headerView.frame = CGRect(x: 0, y: 0, width: self.view.width, height: 300)
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(frame: CGRect(x: ( headerView.width-150)/2  , y: 75, width: 150, height: 150))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = imageView.width/2 
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        headerView.addSubview(imageView)
        
        StorageManager.shared.getDownloadURL(for: path, completion: {
            [weak self] result in
            switch result{
            case .success(let url):
                self?.downloadImage(imageView: imageView, url: url)
            case .failure(let error):
                print("Failed to get URL: \(error)")
            }
        })
        return headerView
    }
    
    func downloadImage(imageView: UIImageView, url: URL){
        URLSession.shared.dataTask(with: url, completionHandler: {data,_,error in
            guard let data = data, error == nil else{
                return
            }
            
            DispatchQueue.main.async {
                let image = UIImage(data: data)
                imageView.image = image
            }
        }).resume()
    }
}

// MARK: - Table view Delegation
extension ProfileViewController: UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell  = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.textColor = .red
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        logout()
    }
}

extension ProfileViewController{
    /// Present action sheet to make sure user want to logout and if confirmed, he get logged out
    private func logout(){
        let actionSheet = UIAlertController(title: "", message: "", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: {
            [weak self] _ in
            
            guard let strongRef = self else{
                return
            }
            do{
                // Logging out
                try FirebaseAuth.Auth.auth().signOut()
                let vc = LoginViewController()
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .fullScreen
                strongRef.present(nav, animated: true)
            }catch{
                print("Failed to logout")
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:  nil))
        present(actionSheet, animated: true)
    }
}
