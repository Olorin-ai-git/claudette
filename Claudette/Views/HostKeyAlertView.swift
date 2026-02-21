import SwiftUI

struct HostKeyAlertView: View {
    let alertState: HostKeyAlertState
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            switch alertState.result {
            case .newHost:
                newHostContent
            case let .keyChanged(previousFingerprint, newFingerprint):
                keyChangedContent(previous: previousFingerprint, new: newFingerprint)
            case .trusted:
                EmptyView()
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private var newHostContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("New Host")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connecting to \(alertState.hostIdentifier) for the first time.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            fingerprintDisplay(alertState.fingerprint)

            Text("Verify this fingerprint matches the server before trusting.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Reject", role: .cancel, action: onReject)
                    .buttonStyle(.bordered)

                Button("Trust", action: onAccept)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func keyChangedContent(previous: String, new: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Host Key Changed")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.red)

            Text("The host key for \(alertState.hostIdentifier) has changed. This could indicate a man-in-the-middle attack.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Previous:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                fingerprintDisplay(previous)

                Text("New:")
                    .font(.caption)
                    .foregroundStyle(.red)
                fingerprintDisplay(new)
            }

            HStack(spacing: 16) {
                Button("Reject", role: .cancel, action: onReject)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                Button("Trust Anyway", role: .destructive, action: onAccept)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func fingerprintDisplay(_ fingerprint: String) -> some View {
        Text(fingerprint)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
