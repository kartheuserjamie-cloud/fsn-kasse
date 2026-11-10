import SumUpSDK
import UIKit

enum CheckoutOutcome {
    case approved(transactionCode: String?)
    case declined(message: String?)
}

@MainActor
final class SumUpService: ObservableObject {
    static let shared = SumUpService()

    @Published private(set) var isSetUp = false
    @Published private(set) var isLoggedIn = false
    @Published private(set) var merchantCode: String?
    @Published var lastError: String?

    private init() {}

    /// Key baked into the build via the `SUMUP_AFFILIATE_KEY` build setting.
    var bundledAffiliateKey: String {
        let value = (Bundle.main.object(forInfoDictionaryKey: "SumUpAffiliateKey") as? String ?? "").trimmed
        return value.hasPrefix("$(") ? "" : value
    }

    var hasAnyKey: Bool { !bundledAffiliateKey.isEmpty }

    /// The SDK may only be set up once per app launch.
    func setUp(overrideKey: String) {
        guard !isSetUp else { return }
        let key = overrideKey.trimmed.isEmpty ? bundledAffiliateKey : overrideKey.trimmed
        guard !key.isEmpty else { return }
        isSetUp = SumUpSDK.setup(affiliateKey: key)
        refresh()
    }

    func refresh() {
        guard isSetUp else { return }
        isLoggedIn = SumUpSDK.isLoggedIn
        merchantCode = SumUpSDK.currentMerchant?.merchantCode
    }

    func login() async {
        guard isSetUp, let host = UIApplication.topViewController() else { return }
        do {
            _ = try await SumUpSDK.presentLogin(from: host, animated: true)
        } catch {
            lastError = Self.describe(error)
        }
        refresh()
    }

    func logout() async {
        guard isSetUp else { return }
        do {
            _ = try await SumUpSDK.logout()
        } catch {
            lastError = Self.describe(error)
        }
        refresh()
    }

    func presentReaderSettings() async {
        guard isSetUp, isLoggedIn, let host = UIApplication.topViewController() else { return }
        do {
            _ = try await SumUpSDK.presentCardReaderSettings(from: host, animated: true)
        } catch {
            lastError = Self.describe(error)
        }
    }

    /// Lets the SDK wake the card reader while the cart is being put together.
    func wakeReader() {
        guard isSetUp, SumUpSDK.isLoggedIn else { return }
        SumUpSDK.prepare(forCheckout: { _, _ in })
    }

    func checkout(title: String, amount: Decimal, reference: String) async -> CheckoutOutcome {
        guard isSetUp else {
            return .declined(message: "SumUp ist noch nicht eingerichtet. Bitte in den Einstellungen den Affiliate-Key eintragen.")
        }
        guard SumUpSDK.isLoggedIn,
              let currency = SumUpSDK.currentMerchant?.currencyCode,
              !currency.isEmpty else {
            refresh()
            return .declined(message: "Kein SumUp-Konto angemeldet. Bitte in den Einstellungen anmelden.")
        }
        guard let host = UIApplication.topViewController() else {
            return .declined(message: "Die Zahlung konnte nicht gestartet werden.")
        }

        let request = CheckoutRequest(total: NSDecimalNumber(decimal: amount.rounded()), title: title, currencyCode: currency)
        request.foreignTransactionID = reference
        request.skipScreenOptions = [.success, .failed]

        do {
            let result = try await SumUpSDK.checkout(with: request, from: host)
            if result.success {
                return .approved(transactionCode: result.transactionCode)
            }
            return .declined(message: nil)
        } catch {
            return .declined(message: Self.describe(error))
        }
    }

    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == SumUpSDKErrorDomain else {
            return nsError.localizedDescription
        }
        switch nsError.code {
        case SumUpSDKError.accountNotLoggedIn.rawValue, SumUpSDKError.invalidAccessToken.rawValue:
            return "Kein SumUp-Konto angemeldet. Bitte in den Einstellungen anmelden."
        case SumUpSDKError.checkoutInProgress.rawValue:
            return "Es läuft bereits eine andere Zahlung."
        case SumUpSDKError.checkoutCurrencyCodeMismatch.rawValue:
            return "Die Währung passt nicht zum SumUp-Konto."
        case SumUpSDKError.activationNeeded.rawValue:
            return "Das SumUp-Konto ist noch nicht freigeschaltet."
        default:
            return nsError.localizedDescription
        }
    }
}

extension UIApplication {
    /// The SDK presents its screens modally, so it needs the top-most view controller.
    @MainActor
    static func topViewController() -> UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
