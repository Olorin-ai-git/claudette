import SwiftUI

struct ProfileEditorView: View {
    @ObservedObject var viewModel: ProfileEditorViewModel
    let onSave: (ServerProfile) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name (e.g. Work Mac)", text: $viewModel.profileName)
                        .autocorrectionDisabled()
                }

                Section("Server") {
                    TextField("Hostname or IP", text: $viewModel.host)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Port", text: $viewModel.port)
                        .keyboardType(.numberPad)

                    TextField("Username", text: $viewModel.username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    bonjourSection
                }

                Section("Authentication") {
                    Picker("Method", selection: $viewModel.authMethodSelection) {
                        ForEach(ProfileEditorViewModel.AuthMethodSelection.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }

                    if viewModel.authMethodSelection == .password {
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                    }

                    if viewModel.authMethodSelection == .sshKey {
                        SSHKeyManagementSection(viewModel: viewModel)
                    }
                }

                if let error = viewModel.validationError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(viewModel.profileName.isEmpty ? "New Profile" : viewModel.profileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let profile = viewModel.save() {
                            onSave(profile)
                        }
                    }
                }
            }
            .onAppear {
                viewModel.startBonjourDiscovery()
            }
            .onDisappear {
                viewModel.stopBonjourDiscovery()
            }
            .sheet(isPresented: $viewModel.showImportKeySheet) {
                ImportKeySheet(onImport: { pemString in
                    viewModel.importSSHKey(pemString)
                })
            }
        }
    }

    @ViewBuilder
    private var bonjourSection: some View {
        if !viewModel.bonjourHosts.isEmpty {
            DisclosureGroup("Discovered Macs") {
                ForEach(viewModel.bonjourHosts) { host in
                    Button(action: { viewModel.selectBonjourHost(host) }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(host.displayName)
                                    .font(.body)
                                Text(host.hostname + ":" + String(host.port))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "wifi")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
    }
}

struct ImportKeySheet: View {
    let onImport: (String) -> Void
    @State private var pemText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("Paste your Ed25519 private key in PEM format:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $pemText)
                    .font(.system(.caption, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
            }
            .navigationTitle("Import SSH Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(pemText)
                    }
                    .disabled(pemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
