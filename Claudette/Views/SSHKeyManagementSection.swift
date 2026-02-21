import SwiftUI

struct SSHKeyManagementSection: View {
    @ObservedObject var viewModel: ProfileEditorViewModel

    var body: some View {
        if let publicKey = viewModel.publicKeyString {
            VStack(alignment: .leading, spacing: 8) {
                Text("Public Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(publicKey)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button(action: {
                    UIPasteboard.general.string = publicKey
                }) {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Text("Add this to ~/.ssh/authorized_keys on the server.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        Button(action: { viewModel.generateSSHKey() }) {
            Label("Generate New Ed25519 Key", systemImage: "key.fill")
        }

        Button(action: { viewModel.showImportKeySheet = true }) {
            Label("Import Existing Key...", systemImage: "square.and.arrow.down")
        }
    }
}
