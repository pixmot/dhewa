import Foundation
import os

enum OrdinatioLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.ordinatio"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let database = Logger(subsystem: subsystem, category: "database")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}

#if DEBUG
    enum OrdinatioSignpost {
        static let signposter = OSSignposter(subsystem: OrdinatioLog.subsystem, category: "performance")
    }
#endif
