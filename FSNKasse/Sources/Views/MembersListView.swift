import SwiftUI

struct MembersListView: View {
    @EnvironmentObject private var store: DataStore

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case active = "Bezahlt"
        case pending = "Offen"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .all
    @State private var shareItem: ShareItem?

    private var visibleMembers: [Member] {
        switch filter {
        case .all: return store.members
        case .active: return store.members.filter { $0.status == .active }
        case .pending: return store.members.filter { $0.status == .pending }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
            }

            if visibleMembers.isEmpty {
                Text(filter == .pending ? "Keine offenen Anträge." : "Noch keine Anträge erfasst.")
                    .font(.fsn(15))
                    .foregroundColor(Theme.muted)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(visibleMembers) { member in
                    NavigationLink(value: MembershipRoute.member(member.id)) {
                        MemberRow(member: member)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { visibleMembers[$0].id }
                    store.members.removeAll { ids.contains($0.id) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Anträge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let url = store.membersCSV() {
                        shareItem = ShareItem(url: url)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Als CSV exportieren")
                .disabled(store.members.isEmpty)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }
}

private struct MemberRow: View {
    let member: Member

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(member.fullName)
                    .font(.fsn(17, bold: true))
                    .foregroundColor(Theme.text)
                Spacer()
                MemberStatusTag(member: member)
            }
            Text([member.memberNumber, member.tierName, Format.euro(member.fee)].compactMap { $0 }.joined(separator: " · "))
                .font(.fsn(14))
                .foregroundColor(Theme.muted)
            Text("Erfasst am \(Format.dateTime(member.createdAt))")
                .font(.fsn(12))
                .foregroundColor(Theme.dotGrey)
        }
        .padding(.vertical, 6)
    }
}

struct MemberStatusTag: View {
    let member: Member

    var body: some View {
        HStack(spacing: 6) {
            if member.isTest {
                StatusTag(text: "Test", dot: Theme.flagBlue)
            }
            if member.status == .active {
                StatusTag(text: "Mitglied", dot: Theme.dotGreen)
            } else {
                StatusTag(text: "Offen", dot: Theme.dotAmber)
            }
        }
    }
}

struct MemberDetailView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var payment: PaymentController
    @Environment(\.dismiss) private var dismiss

    let memberID: UUID
    @State private var confirmDelete = false

    private var member: Member? {
        store.members.first { $0.id == memberID }
    }

    var body: some View {
        ScrollView {
            if let member {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(member.fullName)
                            .font(.fsn(26, bold: true))
                            .foregroundColor(Theme.text)
                        MemberStatusTag(member: member)
                    }

                    SectionCard("Mitgliedschaft") {
                        DetailGrid(rows: [
                            ("Nummer", member.memberNumber ?? "Noch keine"),
                            ("Art", member.tierName),
                            ("Beitrag", Format.euro(member.fee)),
                            ("Bezahlt am", member.paidAt.map(Format.dateTime) ?? "Noch nicht bezahlt"),
                            ("SumUp", member.transactionCode ?? "-")
                        ])
                    }

                    SectionCard("Angaben") {
                        DetailGrid(rows: [
                            ("Geboren", Format.date(member.birthDate)),
                            ("E-Mail", member.email),
                            ("Anschrift", "\(member.street)\n\(member.postalCode) \(member.city)"),
                            ("Discord", member.discordName.isEmpty ? "-" : member.discordName),
                            ("Erziehungsb.", member.guardianConsent ? "Zugestimmt" : "Nicht nötig"),
                            ("Erfasst", Format.dateTime(member.createdAt))
                        ])
                    }

                    if member.status == .pending {
                        Button("Beitrag jetzt bezahlen · \(Format.euro(member.fee))") {
                            pay(member)
                        }
                        .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true))
                        .disabled(payment.isBusy)
                    }

                    Button("Antrag löschen") {
                        confirmDelete = true
                    }
                    .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                }
                .padding(16)
            } else {
                Text("Dieser Antrag wurde gelöscht.")
                    .font(.fsn(15))
                    .foregroundColor(Theme.muted)
                    .padding(16)
            }
        }
        .background(Color.white)
        .navigationTitle("Antrag")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Antrag wirklich löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                store.members.removeAll { $0.id == memberID }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private func pay(_ member: Member) {
        let request = PaymentRequest(
            title: "Mitgliedsbeitrag",
            amount: member.fee,
            purpose: .membership(memberID: member.id, firstName: member.firstName)
        )
        payment.start(request)
    }
}

struct DetailGrid: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(row.0.uppercased())
                        .font(.fsn(12, bold: true))
                        .tracking(0.6)
                        .foregroundColor(Theme.muted)
                        .frame(width: 110, alignment: .leading)
                    Text(row.1)
                        .font(.fsn(16))
                        .foregroundColor(Theme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
