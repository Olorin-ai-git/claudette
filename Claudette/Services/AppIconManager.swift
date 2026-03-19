import UIKit

@MainActor
final class AppIconManager: ObservableObject {
    @Published private(set) var currentTier: UserTier

    init() {
        self.currentTier = UserTier.current()
    }

    func upgradeTo(_ tier: UserTier) {
        currentTier = tier
        tier.save()
        applyIcon(for: tier)
    }

    func applyIcon(for tier: UserTier) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let iconName = tier.alternateIconName
        guard UIApplication.shared.alternateIconName != iconName else { return }
        UIApplication.shared.setAlternateIconName(iconName)
    }

    func syncIconWithTier() {
        applyIcon(for: currentTier)
    }
}
