import Citadel
import CryptoKit
import Foundation
import NIOSSH
import os

@MainActor
final class ClaudeResourceDiscoveryService: ObservableObject {
    @Published private(set) var resources: [ClaudeResource] = []
    @Published private(set) var isLoading: Bool = false
    @Published var error: String?

    private let fileBrowserService: RemoteFileBrowserService
    private let logger: Logger

    init(fileBrowserService: RemoteFileBrowserService, logger: Logger) {
        self.fileBrowserService = fileBrowserService
        self.logger = logger
    }

    func discover(projectPath: String, username: String) async {
        isLoading = true
        error = nil
        var discovered: [ClaudeResource] = []

        let homeDir: String
        do {
            homeDir = try await fileBrowserService.getHomeDirectory(username: username)
        } catch {
            homeDir = "/Users/" + username
        }

        // --- Commands: flat .md files + subdirectories with colon notation ---
        let commandPaths = [
            projectPath + "/.claude/commands",
            homeDir + "/.claude/commands",
        ]
        for dirPath in commandPaths {
            let files = await collectCommandFiles(under: dirPath, rootPath: dirPath)
            logger.info("Found \(files.count) commands in \(dirPath, privacy: .public)")

            for (entry, qualifiedName) in files {
                guard !discovered.contains(where: { $0.filePath == entry.path }) else { continue }
                var resource = await parseResource(entry: entry, qualifiedName: qualifiedName, type: .command)
                if resource.isUserInvocable {
                    resource = ClaudeResource(
                        id: resource.id,
                        name: resource.name,
                        type: .skill,
                        description: resource.description,
                        isUserInvocable: true,
                        filePath: resource.filePath
                    )
                }
                discovered.append(resource)
            }
        }

        // --- Skills: each subdirectory is a skill, SKILL.md is the entry point ---
        let skillPaths = [
            projectPath + "/.claude/skills",
            homeDir + "/.claude/skills",
        ]
        for dirPath in skillPaths {
            let skills = await collectBundledResources(under: dirPath, type: .skill)
            logger.info("Found \(skills.count) skills in \(dirPath, privacy: .public)")
            for resource in skills where !discovered.contains(where: { $0.filePath == resource.filePath }) {
                discovered.append(resource)
            }
        }

        // --- Agents: same bundle layout as skills ---
        let agentPaths = [
            projectPath + "/.claude/agents",
            homeDir + "/.claude/agents",
        ]
        for dirPath in agentPaths {
            let agents = await collectBundledResources(under: dirPath, type: .agent)
            logger.info("Found \(agents.count) agents in \(dirPath, privacy: .public)")
            for resource in agents where !discovered.contains(where: { $0.filePath == resource.filePath }) {
                discovered.append(resource)
            }
        }

        resources = discovered
        isLoading = false
        logger.info("Discovered \(discovered.count) Claude resources total")
    }

    // MARK: - Commands (recursive, colon-joined)

    /// Recursively collects `.md` files under a commands directory.
    /// Subdirectories produce colon-separated names (e.g. `tools/fix.md` → `tools:fix.md`).
    private func collectCommandFiles(
        under dirPath: String,
        rootPath: String
    ) async -> [(entry: RemoteFileEntry, qualifiedName: String)] {
        var results: [(RemoteFileEntry, String)] = []

        let entries: [RemoteFileEntry]
        do {
            entries = try await fileBrowserService.listDirectory(atPath: dirPath)
        } catch {
            return results
        }

        for entry in entries {
            if entry.isDirectory {
                let nested = await collectCommandFiles(under: entry.path, rootPath: rootPath)
                results.append(contentsOf: nested)
            } else if entry.name.hasSuffix(".md") {
                let relative = String(entry.path.dropFirst(rootPath.count + 1))
                let qualifiedName = relative.replacingOccurrences(of: "/", with: ":")
                results.append((entry, qualifiedName))
            }
        }

        return results
    }

    // MARK: - Skills & Agents (bundled directories)

    /// Discovers bundled resources where each immediate subdirectory is a resource.
    /// The resource name comes from the directory name.
    /// Entry point is `SKILL.md` (for skills) or any `.md` at the top of the dir;
    /// also picks up bare `.md` files directly in the root.
    private func collectBundledResources(
        under dirPath: String,
        type: ClaudeResourceType
    ) async -> [ClaudeResource] {
        var results: [ClaudeResource] = []

        let entries: [RemoteFileEntry]
        do {
            entries = try await fileBrowserService.listDirectory(atPath: dirPath)
        } catch {
            return results
        }

        for entry in entries {
            if entry.isDirectory {
                // Subdirectory = one resource. Look for SKILL.md as entry point,
                // fall back to the first .md file found.
                if let resource = await discoverBundleEntryPoint(
                    dirName: entry.name,
                    dirPath: entry.path,
                    type: type
                ) {
                    results.append(resource)
                }
            } else if entry.name.hasSuffix(".md") {
                // Bare .md file directly in the root (e.g. agents/orchestrator.md)
                let resource = await parseResource(
                    entry: entry,
                    qualifiedName: entry.name,
                    type: type
                )
                results.append(resource)
            }
        }

        return results
    }

    /// Given a skill/agent bundle directory, find the entry point .md file
    /// and return a ClaudeResource named after the directory.
    private func discoverBundleEntryPoint(
        dirName: String,
        dirPath: String,
        type: ClaudeResourceType
    ) async -> ClaudeResource? {
        let entries: [RemoteFileEntry]
        do {
            entries = try await fileBrowserService.listDirectory(atPath: dirPath)
        } catch {
            return nil
        }

        // Prefer SKILL.md, then any top-level .md
        let mdFiles = entries.filter { !$0.isDirectory && $0.name.hasSuffix(".md") }
        let entryPoint = mdFiles.first(where: { $0.name.uppercased() == "SKILL.MD" })
            ?? mdFiles.first

        guard let entryPoint else { return nil }

        // Resource name = directory name + .md (so slug stripping produces clean name)
        return await parseResource(
            entry: entryPoint,
            qualifiedName: dirName + ".md",
            type: type
        )
    }

    // MARK: - Parsing

    private func parseResource(
        entry: RemoteFileEntry,
        qualifiedName: String,
        type: ClaudeResourceType
    ) async -> ClaudeResource {
        var description: String?
        var isUserInvocable = false

        do {
            let data = try await fileBrowserService.readFile(atPath: entry.path)
            if let content = String(data: data, encoding: .utf8) {
                let parsed = parseFrontmatter(content)
                description = parsed.description
                isUserInvocable = parsed.isUserInvocable
            }
        } catch {
            logger.debug("Could not read resource file: \(entry.path, privacy: .public)")
        }

        return ClaudeResource(
            id: entry.path,
            name: qualifiedName,
            type: type,
            description: description,
            isUserInvocable: isUserInvocable,
            filePath: entry.path
        )
    }

    private func parseFrontmatter(_ content: String) -> (description: String?, isUserInvocable: Bool) {
        guard content.hasPrefix("---") else {
            return (nil, false)
        }

        let lines = content.components(separatedBy: "\n")
        var inFrontmatter = false
        var description: String?
        var isUserInvocable = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                if inFrontmatter { break }
                inFrontmatter = true
                continue
            }

            if inFrontmatter {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("description:") {
                    description = trimmed
                        .replacingOccurrences(of: "description:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
                if trimmed.contains("user-invocable"), trimmed.contains("true") {
                    isUserInvocable = true
                }
            }
        }

        return (description, isUserInvocable)
    }
}
