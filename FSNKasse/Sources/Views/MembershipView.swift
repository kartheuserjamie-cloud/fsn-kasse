import SwiftUI

enum MembershipRoute: Hashable {
    case list
    case member(UUID)
}

struct MembershipView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var payment: PaymentController

    @State private var form = MembershipForm()
    @State private var showErrors = false
    @State private var pendingMemberID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeroHeader(
                        title: "Mitglied werden",
                        text: "Antrag ausfüllen und den Beitrag direkt mit Karte bezahlen. Die Mitgliedschaft gilt ab der Zahlung."
                    )

                    VStack(alignment: .leading, spacing: 20) {
                        PaymentStateBanner()

                        tierSection
                        personSection
                        addressSection
                        consentSection

                        if showErrors && !missingFields.isEmpty {
                            AlertBox(style: .error, lines: ["Bitte noch ausfüllen:"] + missingFields)
                                .transition(.opacity)
                        }

                        Button(action: submit) {
                            Text(selectedTier.map { "Beitrag bezahlen · \(Format.euro($0.fee))" } ?? "Beitrag bezahlen")
                        }
                        .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true))
                        .disabled(selectedTier == nil || payment.isBusy)

                        Text("Bezahlt wird per Karte über SumUp. Die Angaben werden nur auf diesem Gerät gespeichert, bis sie exportiert werden.")
                            .font(.fsn(13))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .animation(.easeInOut(duration: 0.2), value: showErrors)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.white)
            .navigationTitle("Mitglied werden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: MembershipRoute.list) {
                        Text("Anträge")
                            .font(.fsn(16, bold: true))
                    }
                }
            }
            .navigationDestination(for: MembershipRoute.self) { route in
                switch route {
                case .list:
                    MembersListView()
                case .member(let id):
                    MemberDetailView(memberID: id)
                }
            }
        }
    }

    // MARK: Sections

    private var tierSection: some View {
        SectionCard("Art der Mitgliedschaft") {
            if store.tiers.isEmpty {
                Text("Es sind noch keine Beiträge angelegt. Das geht unter Einstellungen.")
                    .font(.fsn(15))
                    .foregroundColor(Theme.muted)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.tiers) { tier in
                        TierOption(tier: tier, isSelected: selectedTier?.id == tier.id) {
                            form.tierID = tier.id
                            Haptics.tap()
                        }
                    }
                }
            }
        }
    }

    private var personSection: some View {
        SectionCard("Persönliche Angaben") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    FSNField(label: "Vorname", text: $form.firstName, contentType: .givenName, capitalization: .words, invalid: showErrors && form.firstName.trimmed.isEmpty)
                    FSNField(label: "Nachname", text: $form.lastName, contentType: .familyName, capitalization: .words, invalid: showErrors && form.lastName.trimmed.isEmpty)
                }
                FSNField(label: "E-Mail-Adresse", text: $form.email, placeholder: "mail@beispiel.de", keyboard: .emailAddress, contentType: .emailAddress, capitalization: .never, invalid: showErrors && !form.isEmailValid)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Geburtsdatum")
                        .font(.fsn(15, bold: true))
                        .foregroundColor(Theme.text)
                    DatePicker("Geburtsdatum", selection: $form.birthDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    if form.isMinor {
                        Text("Unter 18: Die Erziehungsberechtigten müssen zustimmen.")
                            .font(.fsn(13))
                            .foregroundColor(Theme.muted)
                    }
                }

                FSNField(label: "Discord-Name (optional)", text: $form.discordName, placeholder: "z. B. maxmuster", capitalization: .never)
            }
        }
    }

    private var addressSection: some View {
        SectionCard("Anschrift") {
            VStack(alignment: .leading, spacing: 14) {
                FSNField(label: "Straße und Hausnummer", text: $form.street, contentType: .fullStreetAddress, capitalization: .words, invalid: showErrors && form.street.trimmed.isEmpty)
                HStack(alignment: .top, spacing: 12) {
                    FSNField(label: "PLZ", text: $form.postalCode, keyboard: .numberPad, contentType: .postalCode, invalid: showErrors && form.postalCode.trimmed.isEmpty)
                        .frame(maxWidth: 120)
                    FSNField(label: "Ort", text: $form.city, contentType: .addressCity, capitalization: .words, invalid: showErrors && form.city.trimmed.isEmpty)
                }
            }
        }
    }

    private var consentSection: some View {
        SectionCard("Zustimmung") {
            VStack(alignment: .leading, spacing: 14) {
                CheckRow(
                    text: "Ich habe die Satzung des Femboy Support Network e. V. gelesen und erkenne sie an.",
                    isOn: $form.acceptsStatute,
                    invalid: showErrors && !form.acceptsStatute
                )
                CheckRow(
                    text: "Ich bin einverstanden, dass meine Angaben zur Mitgliederverwaltung gespeichert werden.",
                    isOn: $form.acceptsPrivacy,
                    invalid: showErrors && !form.acceptsPrivacy
                )
                if form.isMinor {
                    CheckRow(
                        text: "Meine Erziehungsberechtigten sind mit der Mitgliedschaft einverstanden.",
                        isOn: $form.guardianConsent,
                        invalid: showErrors && !form.guardianConsent
                    )
                }
            }
        }
    }

    // MARK: Logic

    private var selectedTier: MembershipTier? {
        store.tiers.first { $0.id == form.tierID } ?? store.tiers.first
    }

    private var missingFields: [String] {
        var fields: [String] = []
        if form.firstName.trimmed.isEmpty { fields.append("Vorname") }
        if form.lastName.trimmed.isEmpty { fields.append("Nachname") }
        if !form.isEmailValid { fields.append("Gültige E-Mail-Adresse") }
        if form.street.trimmed.isEmpty { fields.append("Straße und Hausnummer") }
        if form.postalCode.trimmed.isEmpty { fields.append("PLZ") }
        if form.city.trimmed.isEmpty { fields.append("Ort") }
        if !form.acceptsStatute { fields.append("Zustimmung zur Satzung") }
        if !form.acceptsPrivacy { fields.append("Zustimmung zur Datenspeicherung") }
        if form.isMinor && !form.guardianConsent { fields.append("Zustimmung der Erziehungsberechtigten") }
        return fields
    }

    private func submit() {
        showErrors = true
        guard missingFields.isEmpty, let tier = selectedTier else {
            Haptics.error()
            return
        }

        let member = Member(
            firstName: form.firstName.trimmed,
            lastName: form.lastName.trimmed,
            email: form.email.trimmed,
            birthDate: form.birthDate,
            street: form.street.trimmed,
            postalCode: form.postalCode.trimmed,
            city: form.city.trimmed,
            discordName: form.discordName.trimmed,
            tierName: tier.name,
            fee: tier.fee,
            guardianConsent: form.isMinor && form.guardianConsent,
            isTest: store.settings.testMode
        )

        let memberID: UUID
        if let existingID = pendingMemberID,
           let index = store.members.firstIndex(where: { $0.id == existingID && $0.status == .pending }) {
            var updated = member
            updated.id = existingID
            updated.createdAt = store.members[index].createdAt
            store.members[index] = updated
            memberID = existingID
        } else {
            store.members.insert(member, at: 0)
            memberID = member.id
        }
        pendingMemberID = memberID

        let request = PaymentRequest(
            title: "Mitgliedsbeitrag",
            amount: tier.fee,
            purpose: .membership(memberID: memberID, firstName: member.firstName),
            onApproved: {
                form = MembershipForm()
                showErrors = false
                pendingMemberID = nil
            }
        )
        payment.start(request)
    }
}

struct MembershipForm {
    var tierID: UUID?
    var firstName = ""
    var lastName = ""
    var email = ""
    var birthDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    var street = ""
    var postalCode = ""
    var city = ""
    var discordName = ""
    var acceptsStatute = false
    var acceptsPrivacy = false
    var guardianConsent = false

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var isMinor: Bool { age < 18 }

    var isEmailValid: Bool {
        let value = email.trimmed
        guard let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".") && !domain.hasSuffix(".") && !value.contains(" ")
    }
}

private struct TierOption: View {
    let tier: MembershipTier
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.name)
                        .font(.fsn(17, bold: true))
                    if !tier.note.isEmpty {
                        Text(tier.note)
                            .font(.fsn(14))
                            .opacity(0.85)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.euro(tier.fee))
                        .font(.fsn(18, bold: true))
                    Text(tier.period)
                        .font(.fsn(13))
                        .opacity(0.85)
                }
            }
            .foregroundColor(isSelected ? .white : Theme.text)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.primary : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
