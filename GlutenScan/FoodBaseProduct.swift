import Foundation

/// The parts of a FoodBase product record that GlutenScan uses.
/// Field names match the API's snake_case JSON via `.convertFromSnakeCase`.
nonisolated struct FoodBaseProduct: Decodable {
    struct LocalizedText: Decodable {
        let lang: String?
        let text: String?
    }

    let id: String?
    let barcode: String?
    let nameDefault: String?
    let brand: String?
    let ingredients: [LocalizedText]?
    let ingredientsDefault: String?
    /// Allergen tags such as "en:gluten". `nil` means the source said nothing,
    /// which is NOT the same as "no allergens".
    let allergens: [String]?
    /// "May contain" tags, same style as `allergens`.
    let traces: [String]?
    /// Label tags such as "en:no-gluten" or "en:organic".
    let labels: [String]?

    /// "Spaghetti N° 5 · Barilla", or whichever parts exist.
    var displayName: String? {
        let parts = [nameDefault, brand]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Every ingredient text we have, in all languages.
    var allIngredientTexts: [String] {
        var texts = (ingredients ?? []).compactMap(\.text)
        if let main = ingredientsDefault { texts.append(main) }
        return texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func decode(from data: Data) throws -> FoodBaseProduct {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(FoodBaseProduct.self, from: data)
    }
}
