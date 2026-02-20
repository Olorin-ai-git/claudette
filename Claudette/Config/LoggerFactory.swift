import os

enum LoggerFactory {
    private static var subsystem: String = ""

    static func configure(subsystem: String) {
        self.subsystem = subsystem
    }

    static func logger(category: String) -> Logger {
        guard !subsystem.isEmpty else {
            fatalError("LoggerFactory not configured. Call configure(subsystem:) first.")
        }
        return Logger(subsystem: subsystem, category: category)
    }
}
