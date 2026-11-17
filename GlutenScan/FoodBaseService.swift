import Foundation

enum FoodBaseError: Error {
    case invalidKey
    case rateLimited
    case server(status: Int)
    case offline
    case badData

    var message: String {
        switch self {
        case .invalidKey: "The FoodBase API key was rejected. Check Secrets.swift."
        case .rateLimited: "Too many lookups. FoodBase's free plan allows 100 a day. Try again later."
        case .server(let status): "FoodBase had a problem (error \(status)). Try again in a moment."
        case .offline: "No internet connection."
        case .badData: "Couldn't read the product data from FoodBase."
        }
    }
}

enum LookupResult {
    case found(FoodBaseProduct)
    case notFound
}

/// Looks products up on FoodBase by barcode.
/// Results are kept in memory for the session, so scanning the same
/// product twice only uses one of your daily requests.
final class FoodBaseService {
    static let shared = FoodBaseService()

    private let baseURL = "https://foodbase.dev/v1/foods/barcode/"
    private var cache: [String: LookupResult] = [:]

    func lookup(barcode raw: String) async throws -> LookupResult {
        let barcode = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // FoodBase accepts GTIN-8 to GTIN-14: digits only. Anything else
        // (a QR code, a URL) can't be a product, so skip the request.
        guard (8...14).contains(barcode.count), barcode.allSatisfy(\.isASCII), barcode.allSatisfy(\.isNumber) else {
            return .notFound
        }

        if let cached = cache[barcode] { return cached }

        guard let url = URL(string: baseURL + barcode) else { return .notFound }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(Secrets.foodbaseAPIKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FoodBaseError.offline
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let result: LookupResult
        switch status {
        case 200:
            do {
                result = .found(try FoodBaseProduct.decode(from: data))
            } catch {
                throw FoodBaseError.badData
            }
        case 404:
            result = .notFound
        case 401, 403:
            throw FoodBaseError.invalidKey
        case 429:
            throw FoodBaseError.rateLimited
        default:
            throw FoodBaseError.server(status: status)
        }

        cache[barcode] = result
        return result
    }
}
