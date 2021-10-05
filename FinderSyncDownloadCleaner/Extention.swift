//
//  Extention.swift
//  FinderSyncDownloadCleaner
//
//  Created by 遠藤拓弥 on 2021/10/04.
//

import Foundation
import Cocoa



extension FileManager {
    static var homeDirectoryURL: URL? {
        guard let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir else { return nil }
        let homePath:String = self.default.string(withFileSystemRepresentation: home,
                                           length: strlen(home))

        return URL(fileURLWithPath: homePath)
    }
}
