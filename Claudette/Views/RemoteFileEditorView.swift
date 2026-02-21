import SwiftUI

struct RemoteFileEditorView: View {
    @ObservedObject var viewModel: RemoteFileEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading file...")
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await viewModel.loadFile() }
                        }
                    }
                } else {
                    TextEditor(text: $viewModel.content)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: viewModel.content) { _, _ in
                            viewModel.contentDidChange()
                        }
                }
            }
            .navigationTitle(viewModel.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await viewModel.saveFile() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                }
            }
            .task {
                await viewModel.loadFile()
            }
        }
    }
}
