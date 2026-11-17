import SwiftUI

/// Everything the result popup can show.
enum ScanOutcome: Equatable {
    case loading
    case product(name: String?, verdict: GlutenVerdict)
    case notFound
    case failed(String)

    /// Looks a barcode up and turns the answer into something to show.
    static func check(barcode: String) async -> ScanOutcome {
        do {
            switch try await FoodBaseService.shared.lookup(barcode: barcode) {
            case .found(let product):
                return .product(name: product.displayName, verdict: GlutenChecker.verdict(for: product))
            case .notFound:
                return .notFound
            }
        } catch let error as FoodBaseError {
            return .failed(error.message)
        } catch {
            return .failed("Something went wrong. Try again.")
        }
    }
}

struct ScanResultView: View {
    let barcode: String
    let outcome: ScanOutcome
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            if outcome == .loading {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 72)
                Text("Checking…")
                    .font(.title2.bold())
            } else {
                Image(systemName: style.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(style.color)
                    .frame(height: 72)
                Text(style.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
            }

            if let name = productName {
                Text(name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 8)

            Button(action: onDone) {
                Text("Scan again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            VStack(spacing: 2) {
                Text("Barcode \(barcode)")
                Text("Data from FoodBase and Open Food Facts. Always check the packet.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .animation(.default, value: outcome)
    }

    // MARK: - Content per outcome

    private struct Style {
        let icon: String
        let color: Color
        let title: String
    }

    private var style: Style {
        switch outcome {
        case .loading:
            Style(icon: "hourglass", color: .secondary, title: "Checking…")
        case .product(_, .glutenFree):
            Style(icon: "checkmark.circle.fill", color: .green, title: "Gluten free")
        case .product(_, .notGlutenFree):
            Style(icon: "xmark.circle.fill", color: .red, title: "Not gluten free")
        case .product(_, .unknown):
            Style(icon: "questionmark.circle.fill", color: .orange, title: "Can't tell")
        case .notFound:
            Style(icon: "magnifyingglass.circle.fill", color: .gray, title: "Not found in the database")
        case .failed:
            Style(icon: "exclamationmark.triangle.fill", color: .orange, title: "Couldn't check")
        }
    }

    private var productName: String? {
        if case .product(let name, _) = outcome { return name }
        return nil
    }

    private var detail: String? {
        switch outcome {
        case .product(_, .glutenFree(let note)): note
        case .product(_, .notGlutenFree(let reason)): reason
        case .product(_, .unknown): "This product is in the database, but it has no ingredient or allergen info."
        case .notFound: "Check the packet for a gluten-free label or the allergen list."
        case .failed(let message): message
        default: nil
        }
    }
}

#Preview("Gluten free") {
    ScanResultView(barcode: "5449000000996",
                   outcome: .product(name: "Original Taste · Coca-Cola",
                                     verdict: .glutenFree(note: "No allergen info. Based on the ingredient list only.")),
                   onDone: {})
}

#Preview("Not gluten free") {
    ScanResultView(barcode: "8076800195057",
                   outcome: .product(name: "Spaghetti N° 5 · Barilla", verdict: .notGlutenFree(reason: "Contains gluten")),
                   onDone: {})
}

#Preview("Not found") {
    ScanResultView(barcode: "4006381333931", outcome: .notFound, onDone: {})
}

#Preview("Loading") {
    ScanResultView(barcode: "4006381333931", outcome: .loading, onDone: {})
}
