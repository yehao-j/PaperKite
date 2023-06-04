//
//  File Name:  AppDelegate.swift
//  Product Name:   
//  Created Date:   2021/2/9 15:48
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusBar = PKStatusBar()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBar.setupStatusBar()
    }

}

