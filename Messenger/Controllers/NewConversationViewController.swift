//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by Andrew Maher on 28/12/2020.
//

import UIKit

class NewConversationViewController: UIViewController {
    
    // MARK: UIView Components
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    private let noResultLable: UILabel = {
       let label = UILabel()
        label.isHidden = true
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = .green
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    // MARK: End Of UIView Components
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action:  #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }
 
    @objc func dismissSelf(){
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Search Bar Delegation
extension NewConversationViewController: UISearchBarDelegate{
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        //
    }
}
