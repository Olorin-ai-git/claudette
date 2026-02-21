import SwiftUI

struct HookEditorFormView: View {
    let hook: ClaudeHook?
    let onSave: (ClaudeHook, String) -> Void
    let onCancel: () -> Void

    @State private var eventType: String
    @State private var hookType: String
    @State private var command: String
    @State private var matcher: String

    private static let eventTypes = [
        "PreToolUse",
        "PostToolUse",
        "Notification",
        "Stop",
    ]

    private static let hookTypes = [
        "command",
        "script",
    ]

    init(
        hook: ClaudeHook?,
        eventType: String,
        onSave: @escaping (ClaudeHook, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.hook = hook
        self.onSave = onSave
        self.onCancel = onCancel
        _eventType = State(initialValue: eventType)
        _hookType = State(initialValue: hook?.type ?? "command")
        _command = State(initialValue: hook?.command ?? "")
        _matcher = State(initialValue: hook?.matcher ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Event Type", selection: $eventType) {
                        ForEach(Self.eventTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                Section("Hook") {
                    Picker("Type", selection: $hookType) {
                        ForEach(Self.hookTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    TextField("Command", text: $command)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Matcher (optional)", text: $matcher)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(hook == nil ? "New Hook" : "Edit Hook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let result = ClaudeHook(
                            id: hook?.id ?? UUID(),
                            type: hookType,
                            command: command,
                            matcher: matcher.isEmpty ? nil : matcher
                        )
                        onSave(result, eventType)
                    }
                    .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
