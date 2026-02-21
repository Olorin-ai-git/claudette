import SwiftUI

struct AgentVisualizerView: View {
    @ObservedObject var parser: AgentActivityParser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if parser.rootNodes.isEmpty {
                    ContentUnavailableView(
                        "No Agent Activity",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("Agent spawns will appear here as Claude Code launches subagents")
                    )
                } else {
                    List {
                        ForEach(parser.rootNodes) { node in
                            AgentNodeView(node: node, depth: 0)
                        }
                    }
                }
            }
            .navigationTitle("Agent Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(parser.activeAgentCount > 0 ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text("\(parser.activeAgentCount) active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        parser.reset()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}

private struct AgentNodeView: View {
    @ObservedObject var node: AgentTreeNode
    let depth: Int

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if !node.children.isEmpty {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .onTapGesture { isExpanded.toggle() }
                }

                Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(node.isCompleted ? .green : .orange)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 1) {
                    Text(node.agentType)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)

                    Text(node.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(node.displayDuration)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, CGFloat(depth) * 16)

            if isExpanded {
                ForEach(node.children) { child in
                    AgentNodeView(node: child, depth: depth + 1)
                }
            }
        }
    }
}
