import Foundation

enum DatabasePaths {
    static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("Ordinatio", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func appDatabaseURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("ordinatio.sqlite")
    }
}

enum ErrorDisplay {
    static func message(_ error: Error) -> String {
#if DEBUG
        String(describing: error)
#else
        error.localizedDescription
#endif
    }
}
