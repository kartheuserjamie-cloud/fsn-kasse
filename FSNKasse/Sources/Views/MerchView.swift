import SwiftUI

struct MerchView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var cart: Cart
    @EnvironmentObject private var payment: PaymentController
    @EnvironmentObject private var sumUp: SumUpService

    @State private var showCart = false
    @State private var variantProduct: Product?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    private var activeProducts: [Product] {
        store.products.filter(\.isActive)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HeroHeader(
                        title: "Merch",
                        text: "Artikel antippen, um sie in den Warenkorb zu legen. Bezahlt wird mit Karte über SumUp."
                    )

                    PaymentStateBanner()
                        .padding([.horizontal, .top], 16)

                    if activeProducts.isEmpty {
                        InfoBanner(
                            title: "Noch keine Artikel",
                            text: "Artikel legst du unter Einstellungen an."
                        )
                        .padding(16)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(activeProducts) { product in
                                ProductTile(product: product, inCart: cart.quantity(of: product.id)) {
                                    tapped(product)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                .padding(.bottom, cart.isEmpty ? 16 : 96)
            }
            .background(Color.white)
            .navigationTitle("Merch")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if !cart.isEmpty {
                    CartBar(count: cart.count, total: cart.total) {
                        sumUp.wakeReader()
                        showCart = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: cart.isEmpty)
            .sheet(isPresented: $showCart) {
                CartView(onPay: pay)
            }
            .confirmationDialog(
                variantProduct?.name ?? "Variante",
                isPresented: Binding(
                    get: { variantProduct != nil },
                    set: { if !$0 { variantProduct = nil } }
                ),
                titleVisibility: .visible,
                presenting: variantProduct
            ) { product in
                ForEach(product.variants, id: \.self) { variant in
                    Button(variant) {
                        add(product, variant: variant)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: { _ in
                Text("Größe oder Variante wählen")
            }
        }
    }

    private func tapped(_ product: Product) {
        if product.variants.isEmpty {
            add(product, variant: nil)
        } else {
            variantProduct = product
        }
    }

    private func add(_ product: Product, variant: String?) {
        if cart.add(product, variant: variant) {
            SoundEngine.shared.playTap()
            Haptics.tap()
        } else {
            Haptics.error()
        }
    }

    private func pay() {
        let lines = cart.lines.map {
            SaleLine(productID: $0.productID, name: $0.name, variant: $0.variant, quantity: $0.quantity, unitPrice: $0.unitPrice)
        }
        let request = PaymentRequest(
            title: "FSN Merch",
            amount: cart.total,
            purpose: .merch(lines: lines),
            onApproved: { [cart] in cart.clear() }
        )
        showCart = false
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            await payment.start(request)
        }
    }
}

private struct ProductTile: View {
    let product: Product
    let inCart: Int
    let onTap: () -> Void

    @State private var bumped = false

    private var soldOut: Bool {
        if let stock = product.stock { return stock <= inCart }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Theme.primary.frame(height: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.fsn(18, bold: true))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(Format.euro(product.price))
                        .font(.fsn(20, bold: true))
                        .foregroundColor(Theme.primary)

                    if !product.variants.isEmpty {
                        Text(product.variants.joined(separator: " · "))
                            .font(.fsn(13))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if let stock = product.stock {
                        Text(stock == 0 ? "Ausverkauft" : (soldOut ? "Alles im Warenkorb" : "Noch \(stock - inCart) Stück"))
                            .font(.fsn(13, bold: stock == 0))
                            .foregroundColor(stock == 0 ? Theme.danger : Theme.muted)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(inCart > 0 ? Theme.primary : Theme.border, lineWidth: inCart > 0 ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if inCart > 0 {
                    Text("\(inCart)")
                        .font(.fsn(15, bold: true))
                        .foregroundColor(.white)
                        .frame(minWidth: 30, minHeight: 30)
                        .background(Circle().fill(Theme.primary))
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(bumped ? 1.05 : 1)
            .opacity(soldOut ? 0.55 : 1)
        }
        .buttonStyle(TileButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: inCart)
        .onChange(of: inCart) { newValue in
            guard newValue > 0 else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { bumped = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 140_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bumped = false }
            }
        }
        .accessibilityLabel("\(product.name), \(Format.euro(product.price))")
        .accessibilityValue(inCart > 0 ? "\(inCart) im Warenkorb" : "")
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct CartBar: View {
    let count: Int
    let total: Decimal
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 1 ? "1 Artikel" : "\(count) Artikel")
                        .font(.fsn(13))
                        .foregroundColor(.white.opacity(0.85))
                    Text(Format.euro(total))
                        .font(.fsn(22, bold: true))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                Spacer()
                Text("Zum Warenkorb")
                    .font(.fsn(15, bold: true))
                    .foregroundColor(Theme.text)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            }
            .padding(14)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(TileButtonStyle())
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

struct CartView: View {
    @EnvironmentObject private var cart: Cart
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let onPay: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(cart.lines) { line in
                        CartRow(line: line, stock: store.product(withID: line.productID)?.stock)
                        Theme.border.frame(height: 1)
                    }

                    HStack {
                        Text("Gesamt")
                            .font(.fsn(20, bold: true))
                        Spacer()
                        Text(Format.euro(cart.total))
                            .font(.fsn(24, bold: true))
                            .foregroundColor(Theme.primary)
                            .monospacedDigit()
                    }
                    .foregroundColor(Theme.text)
                    .padding(.vertical, 20)

                    Button {
                        onPay()
                    } label: {
                        Text("Mit Karte bezahlen")
                    }
                    .buttonStyle(FSNButtonStyle(kind: .primary, fullWidth: true))
                    .disabled(cart.isEmpty)

                    Button("Warenkorb leeren") {
                        cart.clear()
                        dismiss()
                    }
                    .buttonStyle(FSNButtonStyle(kind: .secondary, fullWidth: true))
                    .padding(.top, 10)
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle("Warenkorb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onChange(of: cart.isEmpty) { isEmpty in
                if isEmpty { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CartRow: View {
    @EnvironmentObject private var cart: Cart
    let line: CartLine
    let stock: Int?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(line.displayName)
                    .font(.fsn(17, bold: true))
                    .foregroundColor(Theme.text)
                Text("je \(Format.euro(line.unitPrice))")
                    .font(.fsn(14))
                    .foregroundColor(Theme.muted)
            }
            Spacer()
            HStack(spacing: 0) {
                stepButton(systemImage: "minus") {
                    cart.decrement(line)
                    Haptics.tap()
                }
                Text("\(line.quantity)")
                    .font(.fsn(17, bold: true))
                    .frame(minWidth: 34)
                    .monospacedDigit()
                stepButton(systemImage: "plus") {
                    if cart.increment(line, stock: stock) {
                        SoundEngine.shared.playTap()
                        Haptics.tap()
                    } else {
                        Haptics.error()
                    }
                }
            }
            Text(Format.euro(line.total))
                .font(.fsn(17, bold: true))
                .foregroundColor(Theme.text)
                .monospacedDigit()
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.primary)
                .frame(width: 36, height: 36)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(TileButtonStyle())
    }
}
