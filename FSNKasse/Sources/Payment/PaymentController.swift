import Foundation

enum PaymentPurpose {
    case merch(lines: [SaleLine])
    case membership(memberID: UUID, firstName: String)
}

struct PaymentRequest: Identifiable {
    let id = UUID()
    let title: String
    let amount: Decimal
    let purpose: PaymentPurpose
    var onApproved: (@MainActor () -> Void)? = nil
}

struct PaymentOutcome: Identifiable {
    let id = UUID()
    let request: PaymentRequest
    let approved: Bool
    let message: String?
    let memberNumber: String?
    let isTest: Bool
    var isPreview = false
}

@MainActor
final class PaymentController: ObservableObject {
    @Published private(set) var outcome: PaymentOutcome?
    @Published var pendingTest: PaymentRequest?
    @Published private(set) var isProcessing = false

    private let store: DataStore
    private let sumUp: SumUpService

    init(store: DataStore, sumUp: SumUpService) {
        self.store = store
        self.sumUp = sumUp
    }

    var isBusy: Bool { isProcessing || outcome != nil || pendingTest != nil }

    func start(_ request: PaymentRequest) {
        guard !isBusy, request.amount > 0 else { return }

        if store.settings.testMode {
            pendingTest = request
            return
        }

        isProcessing = true
        let reference = DataStore.makeReference()
        Task {
            let result = await sumUp.checkout(title: request.title, amount: request.amount, reference: reference)
            finish(request, result: result, reference: reference, isTest: false)
        }
    }

    func resolveTest(_ request: PaymentRequest, approve: Bool) {
        pendingTest = nil
        isProcessing = true
        let reference = DataStore.makeReference()
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            let result: CheckoutOutcome = approve
                ? .approved(transactionCode: "TEST\(Int.random(in: 100_000...999_999))")
                : .declined(message: "Testzahlung abgelehnt. Es wurde nichts abgebucht.")
            finish(request, result: result, reference: reference, isTest: true)
        }
    }

    func preview(approved: Bool) {
        guard !isBusy else { return }
        let request = PaymentRequest(title: "Vorschau", amount: 20, purpose: .merch(lines: []))
        outcome = PaymentOutcome(
            request: request,
            approved: approved,
            message: approved ? nil : "Die Karte wurde abgelehnt. Es wurde nichts abgebucht.",
            memberNumber: nil,
            isTest: true,
            isPreview: true
        )
        playFeedback(approved: approved)
    }

    func retry() {
        guard let last = outcome, !last.approved else { return }
        outcome = nil
        guard !last.isPreview else { return }
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            start(last.request)
        }
    }

    func dismiss() {
        outcome = nil
    }

    private func finish(_ request: PaymentRequest, result: CheckoutOutcome, reference: String, isTest: Bool) {
        isProcessing = false
        switch result {
        case .approved(let code):
            let number = store.record(request, approved: true, reference: reference, transactionCode: code, message: nil, isTest: isTest)
            request.onApproved?()
            outcome = PaymentOutcome(request: request, approved: true, message: nil, memberNumber: number, isTest: isTest)
            playFeedback(approved: true)
        case .declined(let message):
            store.record(request, approved: false, reference: reference, transactionCode: nil, message: message, isTest: isTest)
            outcome = PaymentOutcome(request: request, approved: false, message: message, memberNumber: nil, isTest: isTest)
            playFeedback(approved: false)
        }
    }

    private func playFeedback(approved: Bool) {
        if approved {
            SoundEngine.shared.playSuccess()
            Haptics.success()
        } else {
            SoundEngine.shared.playDecline()
            Haptics.error()
        }
    }
}
