import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var appIconManager: AppIconManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("App Icon") {
                    iconRow(tier: .free, label: "Default", imageName: nil)
                    iconRow(tier: .echo, label: "Claudette Echo", imageName: "AppIcon-Echo-60x60")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func iconRow(tier: UserTier, label: String, imageName: String?) -> some View {
        Button {
            appIconManager.upgradeTo(tier)
        } label: {
            HStack(spacing: 14) {
                if let imageName, let img = UIImage(named: imageName) {
                    Image(uiImage: img)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if tier == .echo {
                        Text("Echo tier exclusive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if appIconManager.currentTier == tier {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
