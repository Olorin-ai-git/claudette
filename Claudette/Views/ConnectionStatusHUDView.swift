import SwiftUI

struct ConnectionStatusHUDView: View {
    let status: NetworkStatus
    let onWake: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .shadow(color: dotColor.opacity(0.6), radius: 3)

            if let latency = status.latencyMs {
                Text(String(format: "%.0fms", latency))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if case .unreachable = status, onWake != nil {
                Button {
                    onWake?()
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var dotColor: Color {
        switch status {
        case .unknown: return .gray
        case .reachable: return .green
        case .degraded: return .orange
        case .unreachable: return .red
        }
    }
}
