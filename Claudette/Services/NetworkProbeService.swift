import Foundation
import Network
import os

@MainActor
final class NetworkProbeService: ObservableObject {
    @Published private(set) var status: NetworkStatus = .unknown

    private let host: String
    private let port: UInt16
    private let intervalSeconds: Double
    private let timeoutSeconds: Double
    private let degradedThresholdMs: Double
    private let logger: Logger
    private var probeTask: Task<Void, Never>?

    init(
        host: String,
        port: Int,
        config: AppConfiguration,
        logger: Logger
    ) {
        self.host = host
        self.port = UInt16(port)
        intervalSeconds = config.networkProbeIntervalSeconds
        timeoutSeconds = config.networkProbeTimeoutSeconds
        degradedThresholdMs = config.networkProbeDegradedThresholdMs
        self.logger = logger
    }

    func startProbing() {
        stopProbing()
        probeTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.probe()
                try? await Task.sleep(nanoseconds: UInt64(self.intervalSeconds * 1_000_000_000))
            }
        }
    }

    func stopProbing() {
        probeTask?.cancel()
        probeTask = nil
    }

    private func probe() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        let host = self.host
        let port = self.port
        let timeout = timeoutSeconds
        let threshold = degradedThresholdMs

        let result: NetworkStatus = await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let connection = NWConnection(to: endpoint, using: .tcp)

            let timeoutWork = DispatchWorkItem {
                connection.cancel()
                continuation.resume(returning: .unreachable)
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeout,
                execute: timeoutWork
            )

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeoutWork.cancel()
                    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    connection.cancel()
                    if elapsed > threshold {
                        continuation.resume(returning: .degraded(latencyMs: elapsed))
                    } else {
                        continuation.resume(returning: .reachable(latencyMs: elapsed))
                    }
                case .failed:
                    timeoutWork.cancel()
                    connection.cancel()
                    continuation.resume(returning: .unreachable)
                default:
                    break
                }
            }

            connection.start(queue: DispatchQueue.global())
        }

        status = result
    }
}
