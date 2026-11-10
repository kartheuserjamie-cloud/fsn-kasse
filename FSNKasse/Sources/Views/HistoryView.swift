import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: DataStore

    @State private var shareItem: ShareItem?
    @State private var confirmClear = false

    private struct DayGroup: Identifiable {
        let id: Date
        let records: [PaymentRecord]
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.records) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { DayGroup(id: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.id > $1.id }
    }

    private var todayPaid: [PaymentRecord] {
        store.records.filter { $0.status == .paid && !$0.isTest && Calendar.current.isDateInToday($0.date) }
    }

    private func sum(_ records: [PaymentRecord]) -> Decimal {
        records.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TodaySummary(
                        merch: sum(todayPaid.filter { $0.kind == .merch }),
                        memberships: sum(todayPaid.filter { $0.kind == .membership }),
                        count: todayPaid.count
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                }

                if groups.isEmpty {
                    Text("Noch keine Zahlungen.")
                        .font(.fsn(15))
                        .foregroundColor(Theme.muted)
                        .listRowSeparator(.hidden)
                }

                ForEach(groups) { group in
                    Section {
                        ForEach(group.records) { record in
                            RecordRow(record: record)
                        }
                    } header: {
                        Text(Format.day(group.id))
                            .font(.fsn(14, bold: true))
                            .foregroundColor(Theme.text)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.white)
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            if let url = store.recordsCSV() {
                                shareItem = ShareItem(url: url)
                            }
                        } label: {
                            Label("Als CSV exportieren", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("Verlauf löschen", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(store.records.isEmpty)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .confirmationDialog("Gesamten Verlauf löschen?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Verlauf löschen", role: .destructive) {
                    store.records.removeAll()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Zahlungen bleiben in deinem SumUp-Konto erhalten. Gelöscht wird nur die Liste auf diesem Gerät.")
            }
        }
    }
}

private struct TodaySummary: View {
    let merch: Decimal
    let memberships: Decimal
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HEUTE EINGENOMMEN")
                    .font(.fsn(12, bold: true))
                    .tracking(1)
                    .foregroundColor(Theme.accent)
                Text(Format.euro(merch + memberships))
                    .font(.fsn(34, bold: true))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            HStack(spacing: 24) {
                figure("Merch", Format.euro(merch))
                figure("Beiträge", Format.euro(memberships))
                figure("Zahlungen", "\(count)")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.fsn(13))
                .foregroundColor(.white.opacity(0.75))
            Text(value)
                .font(.fsn(17, bold: true))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }
}

private struct RecordRow: View {
    let record: PaymentRecord

    private var detail: String {
        if record.kind == .merch {
            return record.lines.map(\.summary).joined(separator: ", ")
        }
        return record.title
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(record.kind == .merch ? "Merch" : "Mitgliedsbeitrag")
                        .font(.fsn(16, bold: true))
                        .foregroundColor(Theme.text)
                    Text(Format.time(record.date))
                        .font(.fsn(13))
                        .foregroundColor(Theme.muted)
                }
                if !detail.isEmpty {
                    Text(detail)
                        .font(.fsn(14))
                        .foregroundColor(Theme.muted)
                        .lineLimit(3)
                }
                if let message = record.message, record.status == .declined {
                    Text(message)
                        .font(.fsn(13))
                        .foregroundColor(Theme.errorText)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if record.isTest {
                        StatusTag(text: "Test", dot: Theme.flagBlue)
                    }
                    StatusTag(
                        text: record.status == .paid ? "Bezahlt" : "Abgelehnt",
                        dot: record.status == .paid ? Theme.dotGreen : Theme.dotRed
                    )
                }
            }
            Spacer()
            Text(Format.euro(record.amount))
                .font(.fsn(17, bold: true))
                .foregroundColor(record.status == .paid ? Theme.text : Theme.muted)
                .strikethrough(record.status == .declined)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }
}
