import Foundation

@MainActor
final class DataStore: ObservableObject {
    @Published var products: [Product] { didSet { save() } }
    @Published var tiers: [MembershipTier] { didSet { save() } }
    @Published var members: [Member] { didSet { save() } }
    @Published var records: [PaymentRecord] { didSet { save() } }
    @Published var settings: AppSettings {
        didSet {
            SoundEngine.shared.isEnabled = settings.soundsEnabled
            save()
        }
    }

    private struct Snapshot: Codable {
        var products: [Product]
        var tiers: [MembershipTier]
        var members: [Member]
        var records: [PaymentRecord]
        var settings: AppSettings
    }

    private let fileURL: URL
    private var isLoaded = false

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("fsn-kasse.json")

        let snapshot = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
            ?? DataStore.initialSnapshot

        products = snapshot.products
        tiers = snapshot.tiers
        members = snapshot.members
        records = snapshot.records
        settings = snapshot.settings
        isLoaded = true
        SoundEngine.shared.isEnabled = snapshot.settings.soundsEnabled
    }

    private func save() {
        guard isLoaded else { return }
        let snapshot = Snapshot(products: products, tiers: tiers, members: members, records: records, settings: settings)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    // MARK: Payments

    static func makeReference() -> String {
        "FSN-" + UUID().uuidString
    }

    /// Stores the payment and, if approved, books stock and activates the membership.
    /// Returns the new member number for approved membership payments.
    @discardableResult
    func record(_ request: PaymentRequest, approved: Bool, reference: String, transactionCode: String?, message: String?, isTest: Bool) -> String? {
        var memberNumber: String?
        var lines: [SaleLine] = []
        var memberID: UUID?
        let kind: TransactionKind

        switch request.purpose {
        case .merch(let saleLines):
            kind = .merch
            lines = saleLines
            if approved && !isTest {
                bookStock(for: saleLines)
            }
        case .membership(let id, _):
            kind = .membership
            memberID = id
            if approved, let index = members.firstIndex(where: { $0.id == id }) {
                var member = members[index]
                let number = isTest ? "TEST-\(Int.random(in: 1000...9999))" : nextMemberNumber()
                member.status = .active
                member.memberNumber = number
                member.paidAt = Date()
                member.transactionCode = transactionCode
                member.isTest = isTest
                members[index] = member
                memberNumber = number
            }
        }

        let entry = PaymentRecord(
            kind: kind,
            title: request.title,
            amount: request.amount,
            lines: lines,
            memberID: memberID,
            status: approved ? .paid : .declined,
            reference: reference,
            transactionCode: transactionCode,
            message: message,
            isTest: isTest
        )
        records.insert(entry, at: 0)
        return memberNumber
    }

    private func bookStock(for lines: [SaleLine]) {
        var updated = products
        for line in lines {
            guard let id = line.productID,
                  let index = updated.firstIndex(where: { $0.id == id }),
                  let stock = updated[index].stock else { continue }
            updated[index].stock = max(0, stock - line.quantity)
        }
        products = updated
    }

    private func nextMemberNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let sequence = settings.nextMemberSequence
        settings.nextMemberSequence = sequence + 1
        return String(format: "FSN-%ld-%04ld", year, sequence)
    }

    // MARK: Products and tiers

    func upsert(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        } else {
            products.append(product)
        }
    }

    func upsert(_ tier: MembershipTier) {
        if let index = tiers.firstIndex(where: { $0.id == tier.id }) {
            tiers[index] = tier
        } else {
            tiers.append(tier)
        }
    }

    func product(withID id: UUID) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: Export

    func recordsCSV() -> URL? {
        let header = ["Datum", "Uhrzeit", "Art", "Bezeichnung", "Positionen", "Betrag", "Status", "SumUp-Transaktion", "Referenz", "Hinweis", "Test"]
        let rows = records.map { record in
            [
                Format.date(record.date),
                Format.time(record.date),
                record.kind == .merch ? "Merch" : "Mitgliedsbeitrag",
                record.title,
                record.lines.map(\.summary).joined(separator: ", "),
                Format.plain(record.amount),
                record.status == .paid ? "Bezahlt" : "Abgelehnt",
                record.transactionCode ?? "",
                record.reference,
                record.message ?? "",
                record.isTest ? "Ja" : "Nein"
            ]
        }
        return writeCSV(named: "FSN-Zahlungen", header: header, rows: rows)
    }

    func membersCSV() -> URL? {
        let header = ["Mitgliedsnummer", "Status", "Vorname", "Nachname", "Geburtsdatum", "E-Mail", "Straße", "PLZ", "Ort", "Discord", "Beitragsart", "Beitrag", "Bezahlt am", "SumUp-Transaktion", "Zustimmung Erziehungsberechtigte", "Erfasst am", "Test"]
        let rows = members.map { member in
            [
                member.memberNumber ?? "",
                member.status == .active ? "Mitglied" : "Offen",
                member.firstName,
                member.lastName,
                Format.date(member.birthDate),
                member.email,
                member.street,
                member.postalCode,
                member.city,
                member.discordName,
                member.tierName,
                Format.plain(member.fee),
                member.paidAt.map(Format.dateTime) ?? "",
                member.transactionCode ?? "",
                member.guardianConsent ? "Ja" : "",
                Format.dateTime(member.createdAt),
                member.isTest ? "Ja" : "Nein"
            ]
        }
        return writeCSV(named: "FSN-Mitglieder", header: header, rows: rows)
    }

    private func writeCSV(named name: String, header: [String], rows: [[String]]) -> URL? {
        func escape(_ field: String) -> String {
            guard field.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let lines = ([header] + rows).map { $0.map(escape).joined(separator: ";") }
        let content = "\u{FEFF}" + lines.joined(separator: "\r\n")
        let stamp = Date().formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(stamp).csv")
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Defaults

    private static var initialSnapshot: Snapshot {
        Snapshot(
            products: [
                Product(name: "Sticker", price: 2),
                Product(name: "Button", price: 3),
                Product(name: "T-Shirt", price: 20, variants: ["S", "M", "L", "XL"]),
                Product(name: "Hoodie", price: 40, variants: ["S", "M", "L", "XL"]),
                Product(name: "Stoffbeutel", price: 12)
            ],
            tiers: [
                MembershipTier(name: "Ordentliche Mitgliedschaft", fee: 24, period: "pro Jahr"),
                MembershipTier(name: "Ermäßigt", fee: 12, period: "pro Jahr", note: "Für Schüler*innen, Studierende, Azubis und Menschen mit wenig Einkommen"),
                MembershipTier(name: "Fördermitgliedschaft", fee: 60, period: "pro Jahr", note: "Unterstützt den Verein, ohne Stimmrecht")
            ],
            members: [],
            records: [],
            settings: AppSettings()
        )
    }
}

@MainActor
final class Cart: ObservableObject {
    @Published private(set) var lines: [CartLine] = []

    var isEmpty: Bool { lines.isEmpty }
    var count: Int { lines.reduce(0) { $0 + $1.quantity } }
    var total: Decimal { lines.reduce(Decimal(0)) { $0 + $1.total } }

    func quantity(of productID: UUID) -> Int {
        lines.filter { $0.productID == productID }.reduce(0) { $0 + $1.quantity }
    }

    /// Returns `false` if the product is out of stock.
    @discardableResult
    func add(_ product: Product, variant: String?) -> Bool {
        if let stock = product.stock, quantity(of: product.id) >= stock {
            return false
        }
        if let index = lines.firstIndex(where: { $0.productID == product.id && $0.variant == variant }) {
            lines[index].quantity += 1
        } else {
            lines.append(CartLine(productID: product.id, name: product.name, variant: variant, unitPrice: product.price, quantity: 1))
        }
        return true
    }

    @discardableResult
    func increment(_ line: CartLine, stock: Int?) -> Bool {
        if let stock, quantity(of: line.productID) >= stock {
            return false
        }
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else { return false }
        lines[index].quantity += 1
        return true
    }

    func decrement(_ line: CartLine) {
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else { return }
        if lines[index].quantity > 1 {
            lines[index].quantity -= 1
        } else {
            lines.remove(at: index)
        }
    }

    func clear() {
        lines.removeAll()
    }
}
