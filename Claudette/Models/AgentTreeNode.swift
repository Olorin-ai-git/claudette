import Foundation

final class AgentTreeNode: Identifiable, ObservableObject {
    let id: String
    let agentType: String
    let description: String
    let startTime: Date
    @Published var isCompleted: Bool
    @Published var children: [AgentTreeNode]

    init(
        id: String,
        agentType: String,
        description: String,
        startTime: Date = Date(),
        isCompleted: Bool = false,
        children: [AgentTreeNode] = []
    ) {
        self.id = id
        self.agentType = agentType
        self.description = description
        self.startTime = startTime
        self.isCompleted = isCompleted
        self.children = children
    }

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var displayDuration: String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)m \(remainingSeconds)s"
    }
}
