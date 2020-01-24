//
//  InputViewController.swift
//  GoproGpx
//
//  Created by Karl Bono on 28/03/2019.
//  Copyright © 2019 Karl Bono. All rights reserved.
//

import Cocoa

class InputViewController: NSViewController {

    @IBOutlet var titleLabel: NSTextField!
    @IBOutlet var inputLabel: NSTextField!
    @IBOutlet var inputField: NSTextField!
    
    var windowTitle = ""
    var didAccept = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func viewDidAppear() {
        self.view.window?.title = windowTitle
    }
    
    @IBAction func okButton(_ sender: Any) {
        didAccept = true
        let application = NSApplication.shared
        application.stopModal()
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        didAccept = false
        let application = NSApplication.shared
        application.stopModal()
    }
}
