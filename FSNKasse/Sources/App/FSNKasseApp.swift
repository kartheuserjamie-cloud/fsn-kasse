import SwiftUI

@main
struct FSNKasseApp: App {
    @StateObject private var store: DataStore
    @StateObject private var cart = Cart()
    @StateObject private var payment: PaymentController
    @StateObject private var sumUp = SumUpService.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Appearance.apply()
        let store = DataStore()
        _store = StateObject(wrappedValue: store)
        _payment = StateObject(wrappedValue: PaymentController(store: store, sumUp: SumUpService.shared))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(cart)
                .environmentObject(payment)
                .environmentObject(sumUp)
                .environment(\.locale, Format.locale)
                .preferredColorScheme(.light)
                .task {
                    sumUp.setUp(overrideKey: store.settings.affiliateKeyOverride)
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                sumUp.refresh()
            }
        }
    }
}
