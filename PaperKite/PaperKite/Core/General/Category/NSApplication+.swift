//
//  File Name:  NSApplication+.swift
//  Product Name:   PaperKite
//  Created Date:   2023/6/4 13:06
//

import Foundation
import AppKit

extension NSApplication {
    var appDelegate: AppDelegate? {
        return delegate as? AppDelegate
    }
}
