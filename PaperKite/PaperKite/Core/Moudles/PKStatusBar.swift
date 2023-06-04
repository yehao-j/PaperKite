//
//  File Name:  PKStatusBar.swift
//  Product Name:   PaperKite
//  Created Date:   2023/6/4 11:33
//

import Foundation
import AppKit
import ServiceManagement

class PKStatusBar: NSObject {
    private var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menu = NSMenu(title: "菜单")
    private var nextItem: NSMenuItem!
    // 下载动画定时器
    private var _animatedTimer: Timer?
    private var animatedTimer: Timer? {
        get {
            if (_animatedTimer != nil) {
                return _animatedTimer
            } else {
                _animatedTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
                    self?.downloadAnimatedEvent()
                }
                RunLoop.current.add(_animatedTimer!, forMode: .common)
                return _animatedTimer
            }
        }
        set {
            _animatedTimer = newValue
        }
    }
    // 动画状态
    private var isFly: Bool = false
    
    func setupStatusBar() {
        setupMenu()
        let icon = NSImage.init(named: "bar")
        icon?.isTemplate = true
        if #available(macOS 10.14, *) {
            statusItem.button?.image = icon
        } else {
            statusItem.image = icon
        }
        statusItem.menu = menu
        setupWallpaper()
    }
    
    // 开启下载动画
    func startAnimated() {
        animatedTimer?.fire()
    }
    
    // 停止下载动画
    func stopAnimated() {
        animatedTimer?.invalidate()
        animatedTimer = nil
        isFly = false
        let icon = NSImage(named: "bar")
        if #available(macOS 10.14, *) {
            statusItem.button?.image = icon
        } else {
            statusItem.image = icon
        }
        nextItem.target = self
        nextItem.title = "下一张"
        print("下载结束")
    }
}

private extension PKStatusBar {
    
    func createMenuItem(title: String, action: Selector?, keyEquivalent: String = "", tag: PKConfig.MenuTag) -> NSMenuItem {
        let item = NSMenuItem.init(title: title, action: action, keyEquivalent: keyEquivalent)
        item.tag = PKConfig.getTag(tag)
        item.target = self
        return item
    }
    
    func openPanel(_ fileTypes: [String]? = []) -> NSOpenPanel {
        let panel = NSOpenPanel.init()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = fileTypes
        panel.canCreateDirectories = false
        // 至于最顶层，防止被其他后打开的app覆盖
        panel.level = NSWindow.Level.init(21)
        return panel
    }
    
    func setupMenu() {
        // 移除所有item
        menu.removeAllItems()
        
        nextItem = createMenuItem(title: "下一个", action: #selector(nextWallpaper), tag: .next)
        
        let video = createMenuItem(title: "动态壁纸", action: #selector(wallpaperStyle(_:)), tag: .video)
        let wallpaper = createMenuItem(title: "静态壁纸", action: #selector(wallpaperStyle(_:)), tag: .wallpaper)
        if PKDataManager.shared.style == .wallpaper {
            wallpaper.state = .on
            video.state = .off
        } else {
            video.state = .on
            wallpaper.state = .off
        }
        
        let local = createMenuItem(title: "选择视频", action: #selector(pickerVideo), tag: .local)
        if PKDataManager.shared.style == .wallpaper {
            local.action = nil
        }
        let export = createMenuItem(title: "导出壁纸/视频", action: #selector(saveWallpaper), tag: .export)
        let daily = createMenuItem(title: "每日切换", action: #selector(dailyWallpaper(_:)), tag: .daily)
        daily.state = PKDataManager.shared.isDaily ? .on : .off
        
        let showIcon = createMenuItem(title: "显示图标", action: #selector(showDesktopIcon(_:)), tag: .showIcon)
        if PKDataManager.shared.style == .wallpaper {
            showIcon.action = nil
        }
        let hideIcon = createMenuItem(title: "隐藏图标", action: #selector(hideDesktopIcon(_:)), tag: .hideIcon)
        if PKDataManager.shared.style == .wallpaper {
            hideIcon.action = nil
        }
        if PKDataManager.shared.iconStatus == .show {
            showIcon.state = .on
            hideIcon.state = .off
        } else {
            hideIcon.state = .on
            showIcon.state = .off
        }
        
        let start = createMenuItem(title: "开机自启", action: #selector(startLoad(_:)), tag: .start)
        start.state = PKDataManager.shared.isStartUp ? .on : .off
        
        let clean = createMenuItem(title: "清除缓存", action: #selector(cleanCache), tag: .clean)
        let help = createMenuItem(title: "常见问题", action: #selector(helpDoc), tag: .help)
        let feedback = createMenuItem(title: "意见反馈", action: #selector(issueFeedback), tag: .feedback)
        let about = createMenuItem(title: "关于我们", action: #selector(aboutUs), tag: .about)
        let exit = createMenuItem(title: "退出", action: #selector(exitApp), tag: .exit)
        menu.addItem(nextItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(video)
        menu.addItem(wallpaper)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(local)
        menu.addItem(export)
        menu.addItem(NSMenuItem.separator())
        // 暂未实现
//        menu.addItem(daily)
//        menu.addItem(NSMenuItem.separator())
        menu.addItem(showIcon)
        menu.addItem(hideIcon)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(start)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(clean)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(help)
        menu.addItem(feedback)
        menu.addItem(about)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(exit)
    }
    
    // 配置壁纸
    func setupWallpaper() {
        // 取消所有请求，防止切换壁纸类型，下载完成设置混乱
        PKNetwork.shared.cancelAllRequests()
        if PKDataManager.shared.style == .video {
            // 检测是否有旧视频
            if let path = PKDataManager.shared.currentVideoPath, FileManager.default.fileExists(atPath: path) {
                let url = URL.init(fileURLWithPath: path)
                NotificationCenter.default.post(name: PKConfig.updateVideoNotification, object: nil, userInfo: ["path": url])
            } else {    // 获取新视频
                nextWallpaper()
            }
        } else {
            // 移除动态壁纸
            NotificationCenter.default.post(name: PKConfig.updateVideoNotification, object: nil, userInfo: ["path": ""])
            // 检测是否有旧壁纸
            if let path = PKDataManager.shared.currentWallpaperPath, FileManager.default.fileExists(atPath: path) {
                let url = URL.init(fileURLWithPath: path)
                if let screen = NSScreen.main {
                    try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [NSWorkspace.DesktopImageOptionKey.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue])
                } else {
                    PKAlert.show("壁纸获取失败请重试")
                }
            } else {   // 获取新壁纸
                nextWallpaper()
            }
        }
    }
    
    // 下载事件处理
    func downloadAnimatedEvent() {
        isFly = !isFly
        let icon = NSImage(named: isFly ? "bar_fly" : "bar")
        if #available(macOS 10.14, *) {
            statusItem.button?.image = icon
        } else {
            statusItem.image = icon
        }
        print("下载中: \(isFly)")
    }
    
    /// 下一张
    @objc func nextWallpaper() {
        nextItem.target = nil
        nextItem.title = "下载中..."
        NotificationCenter.default.post(name: PKConfig.nextWallpaperNotification, object: nil)
    }
    
    /// 设置壁纸样式
    @objc func wallpaperStyle(_ item: NSMenuItem) {
        item.state = .on
        
        let items = menu.items.filter { $0.tag == PKConfig.getTag(.showIcon) || $0.tag == PKConfig.getTag(.hideIcon) || $0.tag == PKConfig.getTag(.local) }
        
        if item.tag == PKConfig.getTag(.video) {    // 视频
            PKDataManager.shared.style = .video
            let wallpaperItem = menu.items.filter { $0.tag == PKConfig.getTag(.wallpaper) }.first
            wallpaperItem?.state = .off
            
            // 启用动态壁纸相关功能
            items.forEach { (item) in
                if item.tag == PKConfig.getTag(.showIcon) {
                    item.action = #selector(showDesktopIcon(_:))
                } else if item.tag == PKConfig.getTag(.hideIcon) {
                    item.action = #selector(hideDesktopIcon(_:))
                } else if item.tag == PKConfig.getTag(.local) {
                    item.action = #selector(pickerVideo)
                }
            }
        } else {
            PKDataManager.shared.style = .wallpaper
            let videoItem = menu.items.filter { $0.tag == PKConfig.getTag(.video) }.first
            videoItem?.state = .off
            
            // 禁用动态壁纸相关功能
            items.forEach { $0.action = nil }
        }
        
        // 配置壁纸
        setupWallpaper()
    }
    
    // 选择本地视频
    @objc func pickerVideo() {
        let panel = openPanel(["AVI","MP4","3GP","M4V","MOV"])
        panel.begin { (response) in
            if response == .OK, let url = panel.url {
                NotificationCenter.default.post(name: PKConfig.updateVideoNotification, object: nil, userInfo: ["path": url])
            } else {
                PKAlert.show("获取视频失败，请重试")
            }
        }
    }
    
    // 导出壁纸/视频
    @objc func saveWallpaper() {
        var filepath: String?
        var title = ""
        var fileTypes: [String] = []
        if PKDataManager.shared.style == .video {
            filepath = PKDataManager.shared.currentVideoPath ?? ""
            title = "导出视频到"
            fileTypes = ["mp4"]
        } else {
            filepath = PKDataManager.shared.currentWallpaperPath ?? ""
            title = "导出壁纸到"
            fileTypes = ["jpg"]
        }
        guard let path = filepath else {
            return
        }
        let panel = NSSavePanel.init()
        panel.title = title
        panel.message = "设置保存路径"
        panel.allowsOtherFileTypes = true;
        panel.allowedFileTypes = fileTypes
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true
        panel.level = NSWindow.Level.init(21)
        panel.begin { (response) in
            if response == .OK {
                try? FileManager.default.copyItem(atPath: path, toPath: panel.url?.path ?? "")
            }
        }
    }
    
    // 每日切换
    @objc func dailyWallpaper(_ item: NSMenuItem) {
        if item.state == .off {
            item.state = .on
            PKDataManager.shared.isDaily = true
        } else {
            PKDataManager.shared.isDaily = false
            item.state = .off
        }
    }
    
    // 显示图标
    @objc func showDesktopIcon(_ item: NSMenuItem) {
        PKDataManager.shared.iconStatus = .show
        // 选择图标显示状态
        let hideItem = menu.items.filter { $0.tag == PKConfig.getTag(.hideIcon) }.first
        hideItem?.state = .off
        item.state = .on
        
        // 设置playerWindow level 以显示图标
        let window = NSApp.windows.filter { $0 is PKPlayerWindow }.first
        window?.level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGWindowLevelForKey(.desktopWindow) - 1))
    }
    
    // 隐藏桌面图标
    @objc func hideDesktopIcon(_ item: NSMenuItem) {
        PKDataManager.shared.iconStatus = .hide
        // 选择图标显示状态
        let showItem = menu.items.filter { $0.tag == PKConfig.getTag(.showIcon) }.first
        showItem?.state = .off
        item.state = .on
        
        // 设置playerWindow level 以隐藏图标
        let window = NSApp.windows.filter { $0 is PKPlayerWindow }.first
        window?.level = NSWindow.Level(rawValue: NSWindow.Level.RawValue(CGWindowLevelForKey(.backstopMenu)))
    }
    
    // 配置启动项
    @objc func startLoad(_ item: NSMenuItem) {
        if item.state == .off {
            item.state = .on
            PKDataManager.shared.isStartUp = true
        } else {
            item.state = .off
            PKDataManager.shared.isStartUp = false
        }
        let helperAppIdentifier = PKConfig.helperBundleIdentifier
        let success = SMLoginItemSetEnabled(helperAppIdentifier as CFString, PKDataManager.shared.isStartUp)
        if success {
            print("启动项配置成功: ", PKDataManager.shared.isStartUp)
        } else {
            print("启动项配置失败")
        }
    }
    
    @objc func cleanCache() {
        PKDataManager.shared.cleanCache()
    }
    
    // 帮助
    @objc func helpDoc() {
        guard let url = URL.init(string: "https://github.com/liyb93/PaperKite/wiki/%E4%BD%BF%E7%94%A8%E8%AF%B4%E6%98%8E") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    // 关于我们
    @objc func aboutUs() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    // 反馈
    @objc func issueFeedback() {
        guard let url = URL.init(string: "https://github.com/liyb93/PaperKite/issues") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    // 退出
    @objc func exitApp() {
        NSApp.terminate(nil)
    }
}
