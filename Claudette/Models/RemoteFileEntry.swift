import Foundation

struct RemoteFileEntry: Identifiable, Hashable, Sendable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: UInt64?
    let modifiedAt: Date?

    var id: String {
        path
    }
}
