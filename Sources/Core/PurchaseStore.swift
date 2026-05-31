import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

struct MemberPackage: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let price: String
}

@MainActor
final class PurchaseStore: ObservableObject {
    @Published var isLoading = false
    @Published var message: String?
    @Published var packages: [MemberPackage] = [
        MemberPackage(id: "wikiquest_member_monthly", title: "Monthly", subtitle: "App Store plan", price: "Loading price"),
        MemberPackage(id: "wikiquest_member_annual", title: "Annual", subtitle: "App Store plan", price: "Loading price")
    ]
    @Published var storeEntitlementActive = false

    let productIds = ["wikiquest_member_monthly", "wikiquest_member_annual"]

    private static var revenueCatConfigured = false

    static func configureRevenueCatIfNeeded(appUserID: String? = nil) {
        #if canImport(RevenueCat)
        guard !revenueCatConfigured else {
            if let appUserID, !appUserID.isEmpty {
                Purchases.shared.logIn(appUserID) { _, _, _ in }
            }
            return
        }
        let apiKey = WikiQuestConfig.revenueCatAPIKey
        guard !apiKey.isEmpty else { return }
        Purchases.logLevel = .warn
        if let appUserID, !appUserID.isEmpty {
            Purchases.configure(withAPIKey: apiKey, appUserID: appUserID)
        } else {
            Purchases.configure(withAPIKey: apiKey)
        }
        revenueCatConfigured = true
        #endif
    }

    func prepareForUser(_ accountUserId: String?) async {
        Self.configureRevenueCatIfNeeded(appUserID: accountUserId)
        await loadPackages()
    }

    func loadPackages() async {
        #if canImport(RevenueCat)
        guard Self.revenueCatConfigured else {
            message = "The App Store purchase layer is not configured for this build."
            return
        }
        let allowedProductIds = productIds
        isLoading = true
        defer { isLoading = false }
        await withCheckedContinuation { continuation in
            Purchases.shared.getOfferings { [weak self] offerings, error in
                Task { @MainActor in
                    if let error {
                        self?.message = error.localizedDescription
                    }
                    let available = offerings?.current?.availablePackages ?? []
                    let mapped = available
                        .filter { allowedProductIds.contains($0.storeProduct.productIdentifier) }
                        .map { package in
                            MemberPackage(
                                id: package.storeProduct.productIdentifier,
                                title: package.storeProduct.productIdentifier.contains("annual") ? "Annual" : "Monthly",
                                subtitle: package.storeProduct.localizedDescription,
                                price: package.localizedPriceString
                            )
                        }
                    if !mapped.isEmpty {
                        self?.packages = mapped
                    }
                    continuation.resume()
                }
            }
        }
        #endif
    }

    func purchase(productId: String) async {
        isLoading = true
        defer { isLoading = false }
        #if canImport(RevenueCat)
        Self.configureRevenueCatIfNeeded()
        guard Self.revenueCatConfigured else {
            message = "The App Store purchase layer is not configured for this build."
            Haptics.error()
            return
        }
        await withCheckedContinuation { continuation in
            Purchases.shared.getOfferings { [weak self] offerings, error in
                if let error {
                    Task { @MainActor in
                        self?.message = error.localizedDescription
                        Haptics.error()
                        continuation.resume()
                    }
                    return
                }
                guard let package = offerings?.current?.availablePackages.first(where: {
                    $0.storeProduct.productIdentifier == productId
                }) else {
                    Task { @MainActor in
                        self?.message = "That Member product is not available in the current App Store offering."
                        Haptics.error()
                        continuation.resume()
                    }
                    return
                }
                Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
                    Task { @MainActor in
                        if userCancelled {
                            self?.message = "Purchase cancelled."
                        } else if let error {
                            self?.message = error.localizedDescription
                            Haptics.error()
                        } else {
                            self?.storeEntitlementActive = customerInfo?.entitlements["member"]?.isActive == true
                            self?.message = self?.storeEntitlementActive == true ? "Member is active." : "Purchase finished. Entitlement sync is pending."
                            Haptics.success()
                        }
                        continuation.resume()
                    }
                }
            }
        }
        #else
        message = "The App Store purchase layer is unavailable in this build."
        #endif
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        #if canImport(RevenueCat)
        Self.configureRevenueCatIfNeeded()
        guard Self.revenueCatConfigured else {
            message = "The App Store purchase layer is not configured for this build."
            Haptics.error()
            return
        }
        await withCheckedContinuation { continuation in
            Purchases.shared.restorePurchases { [weak self] customerInfo, error in
                Task { @MainActor in
                    if let error {
                        self?.message = error.localizedDescription
                        Haptics.error()
                    } else {
                        self?.storeEntitlementActive = customerInfo?.entitlements["member"]?.isActive == true
                        self?.message = self?.storeEntitlementActive == true ? "Member restored." : "No active Member purchase found."
                        Haptics.light()
                    }
                    continuation.resume()
                }
            }
        }
        #else
        message = "The App Store purchase layer is unavailable in this build."
        #endif
    }
}
