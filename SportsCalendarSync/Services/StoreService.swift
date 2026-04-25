import os
import StoreKit
import SwiftUI

private let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "StoreService")

@MainActor
class StoreService: ObservableObject {
    static let productId = "com.keithbarney.sportssync.unlimited"
    static let freeLimit = 10

    @Published var isPurchased = false
    @Published var product: Product?

    init() {
        Task { await loadProduct() }
        Task { await checkPurchased() }
        observeTransactions()
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productId])
            product = products.first
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    private func checkPurchased() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productId {
                isPurchased = true
                return
            }
        }
    }

    private func observeTransactions() {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result,
                   transaction.productID == Self.productId {
                    await MainActor.run { self.isPurchased = true }
                    await transaction.finish()
                }
            }
        }
    }

    func purchase() async -> Bool {
        guard let product else { return false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isPurchased = true
                    await transaction.finish()
                    return true
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
        }
        return false
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkPurchased()
    }
}
