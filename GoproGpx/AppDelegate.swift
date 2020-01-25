//
//  AppDelegate.swift
//  GoproGpx
//
//  Created by Karl Bono on 22/03/2019.
//  Copyright © 2019 Karl Bono. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    @IBAction func fileOpen(_ sender: NSMenuItem) {
        if let window = NSApplication.shared.mainWindow {
            let vc = window.contentViewController as! ViewController
            vc.addMP4(NSButton())
        }
    }
    @IBAction func fileSave(_ sender: NSMenuItem) {
        if let window = NSApplication.shared.mainWindow {
            let vc = window.contentViewController as! ViewController
            vc.generateGPX(NSButton())
        }
    }
}

