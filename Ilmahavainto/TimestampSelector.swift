//
//  TimestampSelector.swift
//  Ilmahavainto
//
//  Created by Jukka Aittola on 22/10/2019.
//  Copyright © 2019 Jukka Aittola. All rights reserved.
//

import UIKit

protocol TimestampSelectorDelegate {
    func onObservationTimeSelected(_ value: Double)
}

class TimestampSelector: UIView {
    @IBOutlet var contentView: TimestampSelector!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var selector: UIStepper!

    var delegate: TimestampSelectorDelegate? = nil

    var value: Double {
        set(newValue) { selector.value = newValue }
        get { selector.value }
    }

    var maximumValue: Double {
        set(newValue) { selector.maximumValue = newValue }
        get { selector.maximumValue }
    }

    var text: String? {
        set(newText) { label.text = newText }
        get { label.text }
    }

    @IBAction func onValueChanged(_ sender: Any) {
        delegate?.onObservationTimeSelected(selector.value)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        Bundle.main.loadNibNamed("TimestampSelector", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        text = ""
        maximumValue = 0.0
        value = 0.0
    }
}
