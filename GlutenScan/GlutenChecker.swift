import Foundation

nonisolated enum GlutenVerdict: Equatable {
    case glutenFree(note: String?)
    case notGlutenFree(reason: String)
    /// The product exists but has no allergen or ingredient info to judge by.
    case unknown
}

/// Decides whether a product is gluten free from FoodBase data.
/// FoodBase has no gluten field, so this works from allergen tags,
/// labels, ingredient text and "may contain" traces, in that order.
nonisolated enum GlutenChecker {

    static func verdict(for product: FoodBaseProduct) -> GlutenVerdict {
        // 1. Allergen tags are the strongest signal.
        if product.allergens?.contains(where: isGlutenTag) == true {
            return .notGlutenFree(reason: "Contains gluten")
        }

        // 2. A "gluten free" label on the packet.
        if product.labels?.contains(where: isGlutenFreeLabel) == true {
            return .glutenFree(note: "Labelled gluten free")
        }

        // 3. Gluten grains named in the ingredient text, in any language.
        let texts = product.allIngredientTexts
        for text in texts {
            if let word = firstGlutenWord(in: text) {
                return .notGlutenFree(reason: "Ingredients mention \(word)")
            }
        }

        // 4. "May contain" traces.
        if product.traces?.contains(where: isGlutenTag) == true {
            return .notGlutenFree(reason: "May contain traces of gluten")
        }

        // 5. Allergens were listed and gluten wasn't one of them.
        if product.allergens != nil {
            return .glutenFree(note: nil)
        }

        // 6. No allergen info, but the ingredient list has nothing with gluten.
        if !texts.isEmpty {
            return .glutenFree(note: "No allergen info. Based on the ingredient list only.")
        }

        return .unknown
    }

    // MARK: - Tags

    private static let glutenTagWords: Set<String> = [
        "gluten", "wheat", "barley", "rye", "spelt", "kamut", "triticale", "oats", "oat",
    ]

    /// True for tags like "en:gluten" or "en:cereals-containing-gluten".
    /// Splitting on "-" keeps "en:buckwheat" from matching "wheat".
    static func isGlutenTag(_ tag: String) -> Bool {
        let words = tagValue(tag).split(separator: "-").map(String.init)
        if words.contains("free") || words.contains("no") { return false }
        return words.contains(where: glutenTagWords.contains)
    }

    /// True for label tags like "en:no-gluten" or "en:gluten-free".
    static func isGlutenFreeLabel(_ tag: String) -> Bool {
        let value = tagValue(tag)
        return ["no-gluten", "gluten-free", "sans-gluten", "senza-glutine",
                "sin-gluten", "glutenfrei", "glutenvrij", "crossed-grain"]
            .contains(where: value.contains)
    }

    /// "en:Cereals-Containing-Gluten" -> "cereals-containing-gluten"
    private static func tagValue(_ tag: String) -> String {
        let lower = tag.lowercased()
        if let colon = lower.firstIndex(of: ":") {
            return String(lower[lower.index(after: colon)...])
        }
        return lower
    }

    // MARK: - Ingredient text

    /// Phrases removed before searching, so they don't trigger a false match.
    private static let safePhrases = [
        "gluten-free", "gluten free", "glutenfree", "free from gluten", "without gluten", "no gluten",
        "sans gluten", "senza glutine", "sin gluten", "glutenfrei", "glutenvrij",
        "buckwheat", "blé noir", "ble noir", "sarrasin", "trigo sarraceno", "grano saraceno",
    ]

    /// Whole words: English, French, Spanish, Italian.
    private static let wholeWordPattern = #"\b(gluten|glutine|wheat|barley|rye|oats?|malt|malted|spelt|semolina|durum|kamut|triticale|couscous|bulgur|bulgar|farro|seitan|einkorn|emmer|freekeh|blé|ble|orge|seigle|épeautre|epeautre|avoine|trigo|cebada|centeno|avena|espelta|frumento|orzo|segale|semola)\b"#

    /// Word starts, for German and Dutch compound words like "Weizenmehl".
    /// "Buchweizen" (buckwheat) doesn't match because "weizen" isn't at a word start.
    private static let prefixPattern = #"\b(weizen|gerste|roggen|dinkel|hafer|tarwe|gerst|rogge|haver)"#

    private static let regexes: [NSRegularExpression] = [wholeWordPattern, prefixPattern].map {
        try! NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }

    /// The first gluten-related word in the text, lowercased, or nil.
    static func firstGlutenWord(in text: String) -> String? {
        var cleaned = text.lowercased()
        for phrase in safePhrases {
            cleaned = cleaned.replacingOccurrences(of: phrase, with: " ")
        }
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        let matches = regexes.compactMap { $0.firstMatch(in: cleaned, range: range) }
        guard let first = matches.min(by: { $0.range.location < $1.range.location }),
              let wordRange = Range(first.range, in: cleaned) else { return nil }
        return String(cleaned[wordRange])
    }
}
