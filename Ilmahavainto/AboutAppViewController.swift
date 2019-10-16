//
//  AboutAppViewController.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 16/10/2019.
//  Copyright © 2019 Jukka Aittola. All rights reserved.
//

import UIKit

class AboutAppViewController: UIViewController {
    @IBOutlet weak var appInfo: UITextView!

    override func viewDidLoad() {
        appInfo.text = NSLocalizedString("app-info", comment: "")
    }
}
