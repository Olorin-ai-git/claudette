import SwiftUI

struct ClaudeResourcesSidebarView: View {
    let resources: [ClaudeResource]
    let isLoading: Bool
    let onExecute: (String) -> Void
    let onRefresh: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ClaudeResourceType = .command

    private func resources(for type: ClaudeResourceType) -> [ClaudeResource] {
        resources.filter { $0.type == type }
    }

    private func count(for type: ClaudeResourceType) -> Int {
        resources(for: type).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                picker
                tabContent
            }
            .navigationTitle("Claude Resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private var picker: some View {
        Picker("Resource Type", selection: $selectedTab) {
            tabLabel("Commands", type: .command)
                .tag(ClaudeResourceType.command)
            tabLabel("Skills", type: .skill)
                .tag(ClaudeResourceType.skill)
            tabLabel("Agents", type: .agent)
                .tag(ClaudeResourceType.agent)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func tabLabel(_ title: String, type: ClaudeResourceType) -> some View {
        let c = count(for: type)
        return Text(c > 0 ? "\(title) (\(c))" : title)
    }

    @ViewBuilder
    private var tabContent: some View {
        if isLoading {
            Spacer()
            ProgressView("Discovering resources...")
            Spacer()
        } else {
            let items = resources(for: selectedTab)
            if items.isEmpty {
                ContentUnavailableView(
                    "No \(selectedTab.displayTitle) Found",
                    systemImage: selectedTab.icon,
                    description: Text("No .claude/\(selectedTab.directoryName)/ found")
                )
            } else {
                resourceList(items)
            }
        }
    }

    private func resourceList(_ items: [ClaudeResource]) -> some View {
        List {
            ForEach(items) { resource in
                Button {
                    onExecute(resource.triggerCommand)
                } label: {
                    resourceRow(resource)
                }
            }
        }
    }

    private func resourceRow(_ resource: ClaudeResource) -> some View {
        HStack {
            Image(systemName: resource.type.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(resource.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if resource.isUserInvocable {
                        Text("invocable")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }

                if let desc = resource.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Text(resource.invokeCommand)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
