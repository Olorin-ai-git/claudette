import Foundation

enum HostKeyVerificationResult: Sendable {
    case trusted
    case newHost
    case keyChanged(previousFingerprint: String, newFingerprint: String)
}
