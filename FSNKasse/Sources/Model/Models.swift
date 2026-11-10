import Foundation

struct Product: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var price: Decimal
    var variants: [String] = []
    /// `nil` means unlimited.
    var stock: Int? = nil
    var isActive = true
}

struct CartLine: Identifiable, Hashable {
    let productID: UUID
    let name: String
    let variant: String?
    let unitPrice: Decimal
    var quantity: Int

    var id: String { productID.uuidString + "|" + (variant ?? "") }
    var total: Decimal { unitPrice * Decimal(quantity) }
    var displayName: String { variant.map { "\(name) (\($0))" } ?? name }
}

struct SaleLine: Codable, Hashable {
    var productID: UUID?
    var name: String
    var variant: String?
    var quantity: Int
    var unitPrice: Decimal

    var total: Decimal { unitPrice * Decimal(quantity) }
    var summary: String {
        let label = variant.map { "\(name) (\($0))" } ?? name
        return "\(quantity)× \(label)"
    }
}

struct MembershipTier: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var fee: Decimal
    var period: String
    var note: String = ""
}

enum MemberStatus: String, Codable {
    case pending, active
}

struct Member: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var firstName: String
    var lastName: String
    var email: String
    var birthDate: Date
    var street: String
    var postalCode: String
    var city: String
    var discordName: String
    var tierName: String
    var fee: Decimal
    var guardianConsent: Bool
    var status: MemberStatus = .pending
    var memberNumber: String?
    var paidAt: Date?
    var transactionCode: String?
    var isTest = false

    var fullName: String { "\(firstName) \(lastName)" }
}

enum TransactionKind: String, Codable {
    case merch, membership
}

enum TransactionStatus: String, Codable {
    case paid, declined
}

struct PaymentRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var kind: TransactionKind
    var title: String
    var amount: Decimal
    var lines: [SaleLine] = []
    var memberID: UUID?
    var status: TransactionStatus
    var reference: String
    var transactionCode: String?
    var message: String?
    var isTest: Bool
}

struct AppSettings: Codable, Hashable {
    var soundsEnabled = true
    var testMode = false
    var affiliateKeyOverride = ""
    var nextMemberSequence = 1
}

extension Decimal {
    func rounded(scale: Int = 2) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }

    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }

    /// Accepts "12", "12,5" and "12.50".
    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return value.rounded()
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum Format {
    static let locale = Locale(identifier: "de_DE")

    static func euro(_ value: Decimal) -> String {
        value.formatted(.currency(code: "EUR").locale(locale))
    }

    static func plain(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(locale))
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(locale))
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
    }

    static func dateTime(_ date: Date) -> String {
        "\(Format.date(date)), \(Format.time(date)) Uhr"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale))
    }
}
