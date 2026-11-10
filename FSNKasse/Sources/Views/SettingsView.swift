import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var sumUp: SumUpService
    @EnvironmentObject private var payment: PaymentController

    @State private var editingProduct: ProductDraft?
    @State private var editingTier: TierDraft?
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sumUpSection
                    registerSection
                    productsSection
                    tiersSection
                    dataSection
                    footer
                }
                .padding(16)
            }
            .background(Color.white)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingProduct) { draft in
                ProductEditor(draft: draft)
            }
            .sheet(item: $editingTier) { draft in
                TierEditor(draft: draft)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .alert(
                "SumUp",
                isPresented: Binding(
                    get: { sumUp.lastError != nil },
                    set: { if !$0 { sumUp.lastError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sumUp.lastError ?? "")
            }
        }
    }

    // MARK: SumUp

    private var sumUpSection: some View {
        SectionCard("SumUp") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    if !sumUp.isSetUp {
                        StatusTag(text: "Nicht eingerichtet", dot: Theme.dotRed)
                    } else if sumUp.isLoggedIn {
                        StatusTag(text: "Angemeldet", dot: Theme.dotGreen)
                    } else {
                        StatusTag(text: "Nicht angemeldet", dot: Theme.dotAmber)
                    }
                    if let code = sumUp.merchantCode, sumUp.isLoggedIn {
                        Text("Händlerkonto \(code)")
                            .font(.fsn(14))
                            .foregroundColor(Theme.muted)
                    }
                }

                if !sumUp.isSetUp {
                    FSNField(
                        label: "Affiliate-Key",
                        text: $store.settings.affiliateKeyOverride,
                        placeholder: "aus dem SumUp-Entwicklerportal",
                        capitalization: .never
                    )
                    Text("Den Key findest du im SumUp-Entwicklerportal unter Affiliate Keys. Dort muss auch die Bundle-ID dieser App eingetragen sein.")
                        .font(.fsn(13))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("SumUp einrichten") {
                        sumUp.setUp(overrideKey: store.settings.affiliateKeyOverride)
                    }
                    .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true))
                    .disabled(store.settings.affiliateKeyOverride.trimmed.isEmpty && !sumUp.hasAnyKey)
                } else if !sumUp.isLoggedIn {
                    Button("Bei SumUp anmelden") {
                        Task { await sumUp.login() }
                    }
                    .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true))
                } else {
                    Button("Kartenleser verbinden") {
                        Task { await sumUp.presentReaderSettings() }
                    }
                    .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true))
                    Button("Abmelden") {
                        Task { await sumUp.logout() }
                    }
                    .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                }
            }
        }
    }

    // MARK: Register

    private var registerSection: some View {
        SectionCard("Kasse") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $store.settings.soundsEnabled) {
                    settingLabel("Töne beim Bezahlen", "Kurzer Ton bei erfolgreicher und abgelehnter Zahlung.")
                }
                Toggle(isOn: $store.settings.testMode) {
                    settingLabel("Testmodus", "Zahlungen werden nur simuliert. Gut zum Ausprobieren ohne Kartenleser.")
                }

                Text("Animationen ansehen")
                    .font(.fsn(15, bold: true))
                    .foregroundColor(Theme.text)
                    .padding(.top, 4)
                HStack(spacing: 10) {
                    Button("Bezahlt") { payment.preview(approved: true) }
                        .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true, compact: true))
                    Button("Abgelehnt") { payment.preview(approved: false) }
                        .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true, compact: true))
                }
            }
            .tint(Theme.primary)
        }
    }

    private func settingLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.fsn(16, bold: true))
                .foregroundColor(Theme.text)
            Text(detail)
                .font(.fsn(13))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Products

    private var productsSection: some View {
        SectionCard("Merch-Artikel") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.products) { product in
                    Button {
                        editingProduct = ProductDraft(product: product, isNew: false)
                    } label: {
                        EditRow(
                            title: product.name,
                            detail: productDetail(product),
                            trailing: Format.euro(product.price),
                            dimmed: !product.isActive
                        )
                    }
                    .buttonStyle(.plain)
                    Theme.border.frame(height: 1)
                }
                Button("Artikel hinzufügen") {
                    editingProduct = ProductDraft(product: Product(name: "", price: 0), isNew: true)
                }
                .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                .padding(.top, 14)
            }
        }
    }

    private func productDetail(_ product: Product) -> String {
        var parts: [String] = []
        if !product.variants.isEmpty { parts.append(product.variants.joined(separator: ", ")) }
        if let stock = product.stock { parts.append("Bestand \(stock)") }
        if !product.isActive { parts.append("ausgeblendet") }
        return parts.joined(separator: " · ")
    }

    // MARK: Tiers

    private var tiersSection: some View {
        SectionCard("Mitgliedsbeiträge") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.tiers) { tier in
                    Button {
                        editingTier = TierDraft(tier: tier, isNew: false)
                    } label: {
                        EditRow(title: tier.name, detail: tier.note, trailing: "\(Format.euro(tier.fee)) \(tier.period)", dimmed: false)
                    }
                    .buttonStyle(.plain)
                    Theme.border.frame(height: 1)
                }
                Button("Beitragsart hinzufügen") {
                    editingTier = TierDraft(tier: MembershipTier(name: "", fee: 0, period: "pro Jahr"), isNew: true)
                }
                .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                .padding(.top, 14)
            }
        }
    }

    // MARK: Data

    private var dataSection: some View {
        SectionCard("Daten") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Exportiert wird eine CSV-Datei, die sich in Excel oder Numbers öffnen lässt.")
                    .font(.fsn(13))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Zahlungen exportieren") {
                    if let url = store.recordsCSV() { shareItem = ShareItem(url: url) }
                }
                .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                .disabled(store.records.isEmpty)
                Button("Mitglieder exportieren") {
                    if let url = store.membersCSV() { shareItem = ShareItem(url: url) }
                }
                .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                .disabled(store.members.isEmpty)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Femboy Support Network e. V.")
                .font(.fsn(14, bold: true))
            Text("kontakt@femboysupportnetwork-ev.de")
                .font(.fsn(13))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.fsn(12))
                .foregroundColor(Theme.muted)
        }
        .foregroundColor(Theme.text)
        .padding(.top, 8)
    }
}

private struct EditRow: View {
    let title: String
    let detail: String
    let trailing: String
    let dimmed: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.isEmpty ? "Ohne Namen" : title)
                    .font(.fsn(16, bold: true))
                    .foregroundColor(Theme.text)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.fsn(13))
                        .foregroundColor(Theme.muted)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(trailing)
                .font(.fsn(15, bold: true))
                .foregroundColor(Theme.primary)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.dotGrey)
        }
        .padding(.vertical, 12)
        .opacity(dimmed ? 0.5 : 1)
        .contentShape(Rectangle())
    }
}

// MARK: - Editors

struct ProductDraft: Identifiable {
    var id: UUID { product.id }
    var product: Product
    var isNew: Bool
}

struct TierDraft: Identifiable {
    var id: UUID { tier.id }
    var tier: MembershipTier
    var isNew: Bool
}

private struct ProductEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var product: Product
    @State private var priceText: String
    @State private var variantsText: String
    @State private var stockText: String
    @State private var confirmDelete = false

    init(draft: ProductDraft) {
        isNew = draft.isNew
        _product = State(initialValue: draft.product)
        _priceText = State(initialValue: draft.isNew ? "" : Format.plain(draft.product.price))
        _variantsText = State(initialValue: draft.product.variants.joined(separator: ", "))
        _stockText = State(initialValue: draft.product.stock.map { String($0) } ?? "")
    }

    private var price: Decimal? {
        guard let value = Decimal.parse(priceText), value > 0 else { return nil }
        return value
    }

    private var stockIsValid: Bool {
        stockText.trimmed.isEmpty || Int(stockText.trimmed).map { $0 >= 0 } == true
    }

    private var canSave: Bool {
        !product.name.trimmed.isEmpty && price != nil && stockIsValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Artikel") {
                    TextField("Name", text: $product.name)
                        .textInputAutocapitalization(.sentences)
                    TextField("Preis in Euro, z. B. 12,50", text: $priceText)
                        .keyboardType(.decimalPad)
                }
                Section {
                    TextField("z. B. S, M, L, XL", text: $variantsText)
                        .textInputAutocapitalization(.characters)
                } header: {
                    Text("Größen oder Varianten")
                } footer: {
                    Text("Mit Komma trennen. Leer lassen, wenn es keine Varianten gibt.")
                }
                Section {
                    TextField("Leer lassen für unbegrenzt", text: $stockText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Bestand")
                } footer: {
                    Text("Wird nach jedem Verkauf automatisch heruntergezählt.")
                }
                Section {
                    Toggle("Im Verkauf anzeigen", isOn: $product.isActive)
                        .tint(Theme.primary)
                }
                if !isNew {
                    Section {
                        Button("Artikel löschen", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .font(.fsn(16))
            .navigationTitle(isNew ? "Neuer Artikel" : "Artikel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("Artikel löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.products.removeAll { $0.id == product.id }
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let price else { return }
        var saved = product
        saved.name = product.name.trimmed
        saved.price = price
        saved.variants = variantsText
            .split(separator: ",")
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
        saved.stock = Int(stockText.trimmed)
        store.upsert(saved)
        dismiss()
    }
}

private struct TierEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var tier: MembershipTier
    @State private var feeText: String
    @State private var confirmDelete = false

    init(draft: TierDraft) {
        isNew = draft.isNew
        _tier = State(initialValue: draft.tier)
        _feeText = State(initialValue: draft.isNew ? "" : Format.plain(draft.tier.fee))
    }

    private var fee: Decimal? {
        guard let value = Decimal.parse(feeText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Beitragsart") {
                    TextField("Name, z. B. Ermäßigt", text: $tier.name)
                    TextField("Betrag in Euro", text: $feeText)
                        .keyboardType(.decimalPad)
                    TextField("Zeitraum, z. B. pro Jahr", text: $tier.period)
                }
                Section {
                    TextField("Optional", text: $tier.note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Hinweis")
                } footer: {
                    Text("Wird im Antrag unter dem Namen angezeigt.")
                }
                if !isNew {
                    Section {
                        Button("Beitragsart löschen", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .font(.fsn(16))
            .navigationTitle(isNew ? "Neue Beitragsart" : "Beitragsart bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(tier.name.trimmed.isEmpty || fee == nil)
                }
            }
            .confirmationDialog("Beitragsart löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.tiers.removeAll { $0.id == tier.id }
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let fee else { return }
        var saved = tier
        saved.name = tier.name.trimmed
        saved.fee = fee
        saved.period = tier.period.trimmed
        saved.note = tier.note.trimmed
        store.upsert(saved)
        dismiss()
    }
}
