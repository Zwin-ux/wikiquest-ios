import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct RevenueCatPaywallSheet: View {
    @ObservedObject var purchases: PurchaseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            sheetContent
                .navigationTitle("Member")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.callout.weight(.bold))
                    }
                }
        }
        .task {
            await purchases.refreshCustomerInfo()
        }
        .onDisappear {
            Task { await purchases.refreshCustomerInfo() }
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        #if canImport(RevenueCatUI)
        PaywallView(displayCloseButton: true)
            .tint(WikiTheme.blue)
            .background(WikiTheme.paper)
        #else
        MissingRevenueCatUIView(
            title: "Paywall unavailable",
            detail: "RevenueCatUI is not linked in this build."
        )
        #endif
    }
}

struct RevenueCatCustomerCenterSheet: View {
    @ObservedObject var purchases: PurchaseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            sheetContent
                .navigationTitle("Purchases")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.callout.weight(.bold))
                    }
                }
        }
        .task {
            await purchases.refreshCustomerInfo()
        }
        .onDisappear {
            Task { await purchases.refreshCustomerInfo() }
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        #if canImport(RevenueCatUI)
        CustomerCenterView()
            .tint(WikiTheme.blue)
            .background(WikiTheme.paper)
        #else
        MissingRevenueCatUIView(
            title: "Customer Center unavailable",
            detail: "RevenueCatUI is not linked in this build."
        )
        #endif
    }
}

private struct MissingRevenueCatUIView: View {
    let title: String
    let detail: String

    var body: some View {
        WikiScreen(navigationTitle: title) {
            InlineNotice(title: "STORE", detail: detail, tint: WikiTheme.red)
        }
    }
}
