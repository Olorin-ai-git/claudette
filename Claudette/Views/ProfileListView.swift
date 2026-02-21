import SwiftUI

struct ProfileListView: View {
    @ObservedObject var viewModel: ProfileListViewModel
    let onSelectProfile: (ServerProfile) -> Void
    let onEditProfile: (ServerProfile?) -> Void

    var body: some View {
        Group {
            if viewModel.profiles.isEmpty {
                welcomeState
            } else {
                profileList
            }
        }
        .navigationTitle("Claudette")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { onEditProfile(nil) }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            viewModel.loadProfiles()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private var welcomeState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Welcome to Claudette")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect to any Mac running SSH to start a Claude Code session.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { onEditProfile(nil) }) {
                Label("Add Your First Mac", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var profileList: some View {
        List {
            ForEach(viewModel.profiles) { profile in
                Button(action: { onSelectProfile(profile) }) {
                    profileRow(profile)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteProfile(profile)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        onEditProfile(profile)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
    }

    private func profileRow(_ profile: ServerProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(profile.username + "@" + profile.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let lastConnected = profile.lastConnectedAt {
                    Text("Last connected: " + lastConnected.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
