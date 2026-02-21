import SwiftUI

struct RemoteFileBrowserView: View {
    @ObservedObject var viewModel: RemoteFileBrowserViewModel
    let onSelectFolder: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                breadcrumbBar

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else if let error = viewModel.error {
                    Spacer()
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
                            Task { await viewModel.loadInitialDirectory() }
                        }
                    }
                    Spacer()
                } else {
                    fileList
                }
            }
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.disconnect()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select This Folder") {
                        let path = viewModel.selectCurrentDirectory()
                        onSelectFolder(path)
                    }
                    .disabled(viewModel.currentPath.isEmpty)
                }
            }
            .task {
                await viewModel.loadInitialDirectory()
            }
        }
    }

    private var indexedPathComponents: [IndexedComponent] {
        viewModel.pathComponents.enumerated().map { IndexedComponent(offset: $0.offset, name: $0.element) }
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(indexedPathComponents) { item in
                    breadcrumbItem(item: item)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private func breadcrumbItem(item: IndexedComponent) -> some View {
        if item.offset > 0 {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }

        Button(item.name) {
            Task { await viewModel.navigateToPathComponent(index: item.offset) }
        }
        .font(.caption)
        .foregroundColor(item.offset == viewModel.pathComponents.count - 1 ? .primary : .blue)
    }

    private var fileList: some View {
        List {
            if viewModel.currentPath != "/" {
                Button(action: {
                    Task { await viewModel.navigateUp() }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("..")
                            .foregroundStyle(.primary)
                    }
                }
            }

            ForEach(viewModel.entries) { entry in
                Button(action: {
                    if entry.isDirectory {
                        Task { await viewModel.navigateTo(entry) }
                    }
                }) {
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                            .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading) {
                            Text(entry.name)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if !entry.isDirectory, let size = entry.size {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        if entry.isDirectory {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(!entry.isDirectory)
            }
        }
    }
}

private struct IndexedComponent: Identifiable {
    let offset: Int
    let name: String
    var id: Int {
        offset
    }
}
