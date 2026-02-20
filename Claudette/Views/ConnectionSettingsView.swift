import SwiftUI

struct ConnectionSettingsView: View {
    @ObservedObject var viewModel: ConnectionSettingsViewModel
    let onConnect: (ConnectionSettings) -> Void

    var body: some View {
        Form {
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
            }

            Section("Project") {
                Picker("Folder", selection: $viewModel.selectedProject) {
                    ForEach(viewModel.availableProjects, id: \.self) { folder in
                        Text(folder).tag(folder)
                    }
                }
            }

            Section("Authentication") {
                Picker("Method", selection: $viewModel.authMethod) {
                    Text("Password").tag(AuthMethod.password)
                }

                if case .password = viewModel.authMethod {
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                }
            }

            if let error = viewModel.validationError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button(action: connectTapped) {
                    HStack {
                        Spacer()
                        Label("Connect", systemImage: "link")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Connection")
    }

    private func connectTapped() {
        if let settings = viewModel.saveAndConnect() {
            onConnect(settings)
        }
    }
}
