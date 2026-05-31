import XCTest
@testable import WikiQuest

final class RevenueCatConfigTests: XCTestCase {
    func testRevenueCatKeyKindsIdentifySafeClientKeys() {
        XCTAssertEqual(RevenueCatAPIKeyKind(rawValue: ""), .missing)
        XCTAssertEqual(RevenueCatAPIKeyKind(rawValue: "appl_public_key"), .applePublic)
        XCTAssertEqual(RevenueCatAPIKeyKind(rawValue: "test_store_key"), .testStore)
        XCTAssertEqual(RevenueCatAPIKeyKind(rawValue: "sk_secret_key"), .secret)
        XCTAssertEqual(RevenueCatAPIKeyKind(rawValue: "unknown"), .unknown)
    }

    func testOnlyPublicAppleAndTestStoreKeysAreClientUsable() {
        XCTAssertTrue(RevenueCatAPIKeyKind(rawValue: "appl_public_key").isClientUsable)
        XCTAssertTrue(RevenueCatAPIKeyKind(rawValue: "test_store_key").isClientUsable)
        XCTAssertFalse(RevenueCatAPIKeyKind(rawValue: "sk_secret_key").isClientUsable)
        XCTAssertFalse(RevenueCatAPIKeyKind(rawValue: "").isClientUsable)
    }

    func testMemberProductIdentifiersStayStable() {
        XCTAssertEqual(PurchaseStore.memberEntitlementID, "member")
        XCTAssertEqual(PurchaseStore.monthlyProductID, "wikiquest_member_monthly")
        XCTAssertEqual(PurchaseStore.annualProductID, "wikiquest_member_annual")
    }
}
