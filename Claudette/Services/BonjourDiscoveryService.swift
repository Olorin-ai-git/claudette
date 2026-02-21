import Foundation
import os

@MainActor
final class BonjourDiscoveryService: NSObject, ObservableObject {
    @Published private(set) var discoveredHosts: [BonjourHost] = []
    @Published private(set) var isSearching: Bool = false

    private let serviceType: String
    private let domain: String
    private let logger: Logger

    private var browser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []

    init(serviceType: String, domain: String, logger: Logger) {
        self.serviceType = serviceType
        self.domain = domain
        self.logger = logger
        super.init()
    }

    func startDiscovery() {
        stopDiscovery()

        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: serviceType, inDomain: domain)
        self.browser = browser
        isSearching = true
        let svcType = serviceType
        logger.info("Started Bonjour discovery for \(svcType, privacy: .public)")
    }

    func stopDiscovery() {
        browser?.stop()
        browser = nil
        resolvingServices.removeAll()
        isSearching = false
        logger.info("Stopped Bonjour discovery")
    }
}

extension BonjourDiscoveryService: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowser(_: NetServiceBrowser, didFind service: NetService, moreComing _: Bool) {
        let serviceCopy = service
        Task { @MainActor in
            serviceCopy.delegate = self
            resolvingServices.append(serviceCopy)
            serviceCopy.resolve(withTimeout: 5.0)
            logger.info("Found Bonjour service: \(service.name, privacy: .public)")
        }
    }

    nonisolated func netServiceBrowser(_: NetServiceBrowser, didRemove service: NetService, moreComing _: Bool) {
        let name = service.name
        Task { @MainActor in
            discoveredHosts.removeAll { $0.serviceName == name }
            resolvingServices.removeAll { $0.name == name }
            logger.info("Removed Bonjour service: \(name, privacy: .public)")
        }
    }

    nonisolated func netServiceBrowser(_: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Task { @MainActor in
            logger.error("Bonjour search failed: \(errorDict)")
            isSearching = false
        }
    }

    nonisolated func netServiceBrowserDidStopSearch(_: NetServiceBrowser) {
        Task { @MainActor in
            isSearching = false
        }
    }
}

extension BonjourDiscoveryService: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        let hostname = sender.hostName ?? sender.name
        let port = sender.port

        var txtRecord: [String: String] = [:]
        if let txtData = sender.txtRecordData() {
            let dict = NetService.dictionary(fromTXTRecord: txtData)
            for (key, value) in dict {
                if let stringValue = String(data: value, encoding: .utf8) {
                    txtRecord[key] = stringValue
                }
            }
        }

        let host = BonjourHost(
            serviceName: name,
            hostname: hostname,
            port: port,
            txtRecord: txtRecord
        )

        Task { @MainActor in
            // Remove any existing entry for this service
            discoveredHosts.removeAll { $0.serviceName == name }
            discoveredHosts.append(host)
            resolvingServices.removeAll { $0.name == name }
            logger.info("Resolved Bonjour host: \(hostname, privacy: .public):\(port)")
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve _: [String: NSNumber]) {
        let name = sender.name
        Task { @MainActor in
            resolvingServices.removeAll { $0.name == name }
            logger.warning("Failed to resolve Bonjour service: \(name, privacy: .public)")
        }
    }
}
