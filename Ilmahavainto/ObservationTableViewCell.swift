//
//  ObservationTableViewCell.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 31/07/15.
//  Copyright (c) 2015 Jukka Aittola. All rights reserved.
//

import UIKit

class ObservationTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var value: UILabel!
}
