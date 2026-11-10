import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var payment: PaymentController

    var body: some View {
        VStack(spacing: 0) {
            FlagBar()
            TabView {
                MerchView()
                    .tabItem { Label("Merch", systemImage: "bag") }
                MembershipView()
                    .tabItem { Label("Mitglied werden", systemImage: "person.badge.plus") }
                HistoryView()
                    .tabItem { Label("Verlauf", systemImage: "clock") }
                SettingsView()
                    .tabItem { Label("Einstellungen", systemImage: "gearshape") }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .tint(Theme.primary)
        .overlay {
            ZStack {
                if payment.isProcessing {
                    ProcessingOverlay(isTest: store.settings.testMode)
                        .transition(.opacity)
                }
                if let outcome = payment.outcome {
                    if outcome.approved {
                        SuccessOverlay(outcome: outcome, onDone: { payment.dismiss() })
                            .id(outcome.id)
                            .transition(.opacity)
                    } else {
                        DeclineOverlay(outcome: outcome, onRetry: { payment.retry() }, onCancel: { payment.dismiss() })
                            .id(outcome.id)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: payment.isProcessing)
            .animation(.easeInOut(duration: 0.25), value: payment.outcome?.id)
        }
        .confirmationDialog(
            testDialogTitle,
            isPresented: Binding(
                get: { payment.pendingTest != nil },
                set: { if !$0 { payment.pendingTest = nil } }
            ),
            titleVisibility: .visible,
            presenting: payment.pendingTest
        ) { request in
            Button("Zahlung annehmen") {
                payment.resolveTest(request, approve: true)
            }
            Button("Zahlung ablehnen", role: .destructive) {
                payment.resolveTest(request, approve: false)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Testmodus ist aktiv. Es wird keine echte Zahlung ausgeführt.")
        }
    }

    private var testDialogTitle: String {
        guard let request = payment.pendingTest else { return "Testzahlung" }
        return "Testzahlung über \(Format.euro(request.amount))"
    }
}

/// Banner shown above the sales screens when payments will not work as expected.
struct PaymentStateBanner: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var sumUp: SumUpService

    var body: some View {
        if store.settings.testMode {
            InfoBanner(
                title: "Testmodus aktiv",
                text: "Zahlungen werden nur simuliert. Zum echten Kassieren den Testmodus in den Einstellungen ausschalten.",
                accent: Theme.dotAmber
            )
        } else if !sumUp.isSetUp {
            InfoBanner(
                title: "SumUp ist nicht eingerichtet",
                text: "In den Einstellungen den Affiliate-Key eintragen und danach bei SumUp anmelden.",
                accent: Theme.danger
            )
        } else if !sumUp.isLoggedIn {
            InfoBanner(
                title: "Nicht bei SumUp angemeldet",
                text: "Bitte in den Einstellungen bei SumUp anmelden und den Kartenleser verbinden.",
                accent: Theme.danger
            )
        }
    }
}
