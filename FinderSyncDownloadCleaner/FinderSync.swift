//
//  FinderSync.swift
//  FinderSyncDownloadCleaner
//
//  Created by 遠藤拓弥 on 2021/10/04.
//

import Cocoa
import FinderSync
import UserNotifications

class FinderSync: FIFinderSync {


    enum FileStatus {
        case available
        case partiallyAvailable
        case unavailable
        var name:String {
            switch self {

            case .available:
                return "Available"
            case .partiallyAvailable:
                return "PartiallyAvailable"
            case .unavailable:
                return "Unavailable"
            }

        }

    }

    override init() {
        super.init()
        
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)
        


        if let homeDirURL = FileManager.homeDirectoryURL {
            let downloadDirectory = homeDirURL.appendingPathComponent("Downloads", isDirectory: true)
            FIFinderSyncController.default().directoryURLs = [downloadDirectory]
        }

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert]) { granted, error in
                NSLog(granted.description)
        }
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.

        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.statusAvailableName)!, label: FileStatus.available.name, forBadgeIdentifier: FileStatus.available.name)
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.statusPartiallyAvailableName)!, label: FileStatus.partiallyAvailable.name, forBadgeIdentifier: FileStatus.partiallyAvailable.name)
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.statusUnavailableName)!, label: FileStatus.unavailable.name, forBadgeIdentifier: FileStatus.unavailable.name)
    }
    
    // MARK: - Primary Finder Sync protocol methods
    
    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        NSLog("beginObservingDirectoryAtURL: %@", url.path as NSString)
        let files:[URL] = contentsOfDirectory(atPath: url.path as String)
        var deletedFiles:[URL] = []
        files.forEach { file in
            NSLog("file: %@", file.path)
            let status:FileStatus = fileStatus(filePass: file)
            switch status{
                case .unavailable:
                    do {
                        try FileManager.default.removeItem(atPath: file.path)
                        deletedFiles.append(file)
                        NSLog("deletefile: %@", file.absoluteString)
                    }catch{
                        NSLog(error.localizedDescription)
                    }
                case .available,.partiallyAvailable: break
            }

        }
        if deletedFiles.count > 0 {
            postUserNotification(subtitle: "ファイル削除のお知らせ", body: "使われていない不要なファイルを削除しました")
        }
    }
    
    
    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        NSLog("endObservingDirectoryAtURL: %@", url.path as NSString)

    }
    
    override func requestBadgeIdentifier(for url: URL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.path as NSString)
        
        // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.



        let status:FileStatus = fileStatus(filePass: url)

        FIFinderSyncController.default().setBadgeIdentifier(status.name, for: url)


    }
    
    // MARK: - Menu and toolbar item support
    
    override var toolbarItemName: String {
        return "FinderSy"
    }
    
    override var toolbarItemToolTip: String {
        return "FinderSy: Click the toolbar item for a menu."
    }
    
    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.cautionName)!
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: "To Documents", action: #selector(moveToDocuments(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "To Music", action: #selector(moveToMusic(_:)), keyEquivalent: "")
        return menu
    }
    


    @IBAction func moveToDocuments(_ sender: AnyObject?) {

        let items = FIFinderSyncController.default().selectedItemURLs()
        guard let homeDirURL = FileManager.homeDirectoryURL else { return }
        let documentsDirectory = homeDirURL.appendingPathComponent("Documents", isDirectory: false)

        for obj in items! {
            let fromURL = URL(string: obj.absoluteString)!
            let toURL = documentsDirectory.absoluteURL.appendingPathComponent(fromURL.lastPathComponent)

            do {
                NSLog("    %@", fromURL.absoluteString as NSString)
                try FileManager.default.moveItem(
                        at: fromURL,
                        to: toURL
                    )
                defer { finishMessage(directory: documentsDirectory.absoluteString) }
            } catch {
              // エラー処理
                NSLog(error.localizedDescription)
            }
        }

    }

    @IBAction func moveToMusic(_ sender: AnyObject?) {

        let items = FIFinderSyncController.default().selectedItemURLs()
        guard let homeDirURL = FileManager.homeDirectoryURL else { return }
        let documentsDirectory = homeDirURL.appendingPathComponent("Music", isDirectory: false)

        for obj in items! {
            let fromURL = URL(string: obj.absoluteString)!
            let toURL = documentsDirectory.absoluteURL.appendingPathComponent(fromURL.lastPathComponent)

            do {
                NSLog("    %@", fromURL.absoluteString as NSString)
                try FileManager.default.moveItem(
                        at: fromURL,
                        to: toURL
                    )
                defer { finishMessage(directory: documentsDirectory.absoluteString) }
            } catch {
              // エラー処理
                NSLog(error.localizedDescription)
            }
        }

    }

    func finishMessage(directory: String) -> Void {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "\(directory)移動しました!"
            alert.runModal()
        }
    }

    func fileStatus(filePass: URL) -> FileStatus {
        let calendar = Calendar(identifier: .gregorian)
        let attributes = try? FileManager.default.attributesOfItem(atPath: filePass.path)
        let creationDate = attributes?[FileAttributeKey.creationDate] as? Date ?? Date()
        let modDate = attributes?[FileAttributeKey.modificationDate] as? Date ?? Date()
        let fromCreationDate:Int = calendar.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        let fromModDate:Int = calendar.dateComponents([.day], from: modDate, to: Date()).day ?? 0
        let refCount = attributes?[FileAttributeKey.referenceCount] as? Int ?? 0

        NSLog("filename: %@,fromCreationDate: %@,fromModDate: %@", filePass.absoluteString, String(fromCreationDate), String(fromModDate))
        if fromCreationDate > 30 && fromModDate > 30{
            return FileStatus.unavailable
        }else if (fromCreationDate > 30 && fromModDate < 30) || refCount > 100{
            return FileStatus.partiallyAvailable
        }else{
            return FileStatus.available
        }
    }

    func contentsOfDirectory(atPath path: String) -> [URL] {
        do {
            guard let baseUrl = URL(string: path) else { return [] }
            let filenames:[String] = try FileManager.default.contentsOfDirectory(atPath: path)
            let filepaths:[URL] = filenames.map {
                baseUrl.appendingPathComponent($0)
            }
            return filepaths
        } catch let error {
            NSLog(error.localizedDescription)
            return []
        }
    }

    private func postUserNotification(subtitle: String, body: String) {

        let name: String = Bundle.main.object(forInfoDictionaryKey:"CFBundleName") as? String ?? ""

        let content = UNMutableNotificationContent()
            content.title = name
            content.subtitle = subtitle
            content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString,content: content,trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }



}

