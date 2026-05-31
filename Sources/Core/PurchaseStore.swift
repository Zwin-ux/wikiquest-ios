import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

struct MemberPackage: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let price: String

    var isAnnual: Bool {
        id == PurchaseStore.annualProductID || id.localizedCaseInsensitiveContains("annual")
    }
}

struct MemberSubscriptionSnapshot: Equatable {
    let isMember: Bool
    let activeProductIds: [String]
    let expirationDate: Date?
    let managementURL: URL?

    static let inactive = MemberSubscriptionSnapshot(
        isMember: false,
        activeProductIds: [],
        expirationDate: nil,
        managementURL: nil
    )

    var statusText: String {
        guard isMember else { return "No active App Store Member purchase." }
        if let expirationDate {
            return "Member active through \(expirationDate.formatted(date: .abbreviated, time: .omitted))."
        }
        return "Member is active."
    }
}

@MainActor
final class PurchaseStore: ObservableObject {
    static let memberEntitlementID = "member"
    static let monthlyProductID = "wikiquest_member_monthly"
    static let annualProductID = "wikiquest_member_annual"

    @Published var isLoading = false
    @Published var message: String?
    @Published var packages: [MemberPackage] = []
    @Published var subscription = MemberSubscriptionSnapshot.inactive
    @Published var storeEntitlementActive = false
    @Published var hasLoadedOfferings = false

    let productIds = [Self.monthlyProductID, Self.annualProductID]

    private static var revenueCatConfigured = false

    static func configureRevenueCatIfNeeded(appUserID: String? = nil) {
        #if canImport(RevenueCat)
        let apiKey = WikiQuestConfig.revenueCatAPIKey
        let keyKind = WikiQuestConfig.revenueCatAPIKeyKind

        guard keyKind.isClientUsable else {
            return
        }

        guard !revenueCatConfigured else {
            if let appUserID, !appUserID.isEmpty {
                Purchases.shared.logIn(appUserID) { _, _, error in
                    if let error {
                        print("RevenueCat login failed: \(error.localizedDescription)")
                    }
                }
            }
            return
        }

        Purchases.logLevel = keyKind == .testStore ? .debug : .warn
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
        await refreshCustomerInfo()
        await loadPackages()
    }

    func loadPackages() async {
        #if canImport(RevenueCat)
        guard Self.revenueCatConfigured else {
            message = revenueCatConfigurationMessage
            packages = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let offerings = try await fetchOfferings()
            let allowedProductIds = Set(productIds)
            let availablePackages = offerings.current?.availablePackages ?? []
            let mapped = availablePackages
                .filter { allowedProductIds.contains($0.storeProduct.productIdentifier) }
                .map(MemberPackage.init(package:))

            hasLoadedOfferings = true
            packages = mapped
            if mapped.isEmpty {
                message = "No Member packages are available yet. Add monthly and annual products to the current RevenueCat Offering."
            } else if message == revenueCatConfigurationMessage {
                message = nil
            }
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
        #else
        message = "The App Store purchase layer is unavailable in this build."
        packages = []
        #endif
    }

    func refreshCustomerInfo() async {
        #if canImport(RevenueCat)
        guard Self.revenueCatConfigured else {
            subscription = .inactive
            storeEntitlementActive = false
            return
        }

        do {
            let customerInfo = try await fetchCustomerInfo()
            apply(customerInfo: customerInfo)
        } catch {
            message = error.localizedDescription
        }
        #endif
    }

    func purchase(productId: String) async {
        isLoading = true
        defer { isLoading = false }

        #if canImport(RevenueCat)
        Self.configureRevenueCatIfNeeded()
        guard Self.revenueCatConfigured else {
            message = revenueCatConfigurationMessage
            Haptics.error()
            return
        }

        do {
            let package = try await package(for: productId)
            let result = try await purchase(package: package)
            if result.userCancelled {
                message = "Purchase cancelled."
                Haptics.light()
                return
            }

            apply(customerInfo: result.customerInfo)
            message = storeEntitlementActive ? "Member is active." : "Purchase finished. Entitlement sync is pending."
            Haptics.success()
        } catch {
            message = error.localizedDescription
            Haptics.error()
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
            message = revenueCatConfigurationMessage
            Haptics.error()
            return
        }

        do {
            let customerInfo = try await restorePurchases()
            apply(customerInfo: customerInfo)
            message = storeEntitlementActive ? "Member restored." : "No active Member purchase found."
            Haptics.light()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
        #else
        message = "The App Store purchase layer is unavailable in this build."
        #endif
    }

    private var revenueCatConfigurationMessage: String {
        switch WikiQuestConfig.revenueCatAPIKeyKind {
        case .missing:
            return "RevenueCat is not configured for this build."
        case .secret:
            return "RevenueCat needs a public iOS SDK key here, not a secret API key."
        case .unknown:
            return "RevenueCat API key format is not recognized."
        case .testStore:
            return "RevenueCat Test Store is active for development."
        case .applePublic:
            return "RevenueCat is configured."
        }
    }
}

#if canImport(RevenueCat)
private extension MemberPackage {
    init(package: Package) {
        let productIdentifier = package.storeProduct.productIdentifier
        self.init(
            id: productIdentifier,
            title: productIdentifier == PurchaseStore.annualProductID ? "Annual" : "Monthly",
            subtitle: package.storeProduct.localizedDescription,
            price: package.localizedPriceString
        )
    }
}

private extension PurchaseStore {
    func fetchOfferings() async throws -> Offerings {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getOfferings { offerings, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let offerings {
                    continuation.resume(returning: offerings)
                } else {
                    continuation.resume(throwing: PurchaseStoreError.missingOfferings)
                }
            }
        }
    }

    func fetchCustomerInfo() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let customerInfo {
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: PurchaseStoreError.missingCustomerInfo)
                }
            }
        }
    }

    func package(for productId: String) async throws -> Package {
        let offerings = try await fetchOfferings()
        guard let package = offerings.current?.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == productId
        }) else {
            throw PurchaseStoreError.productUnavailable(productId)
        }
        return package
    }

    func purchase(package: Package) async throws -> WikiPurchaseResult {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
                if let error {
                    continuation.resume(throwing: error)
                } else if let customerInfo {
                    continuation.resume(returning: WikiPurchaseResult(customerInfo: customerInfo, userCancelled: userCancelled))
                } else {
                    continuation.resume(throwing: PurchaseStoreError.missingCustomerInfo)
                }
            }
        }
    }

    func restorePurchases() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.restorePurchases { customerInfo, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let customerInfo {
                    continuation.resume(returning: customerInfo)
                } else {
                    continuation.resume(throwing: PurchaseStoreError.missingCustomerInfo)
                }
            }
        }
    }

    func apply(customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[Self.memberEntitlementID]
        let isMember = entitlement?.isActive == true
        subscription = MemberSubscriptionSnapshot(
            isMember: isMember,
            activeProductIds: Array(customerInfo.activeSubscriptions).sorted(),
            expirationDate: entitlement?.expirationDate,
            managementURL: customerInfo.managementURL
        )
        storeEntitlementActive = isMember
    }
}

private struct WikiPurchaseResult {
    let customerInfo: CustomerInfo
    let userCancelled: Bool
}
#endif

private enum PurchaseStoreError: LocalizedError {
    case missingOfferings
    case missingCustomerInfo
    case productUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingOfferings:
            return "RevenueCat did not return an Offering."
        case .missingCustomerInfo:
            return "RevenueCat did not return customer information."
        case .productUnavailable(let productId):
            return "\(productId) is not available in the current RevenueCat Offering."
        }
    }
}
