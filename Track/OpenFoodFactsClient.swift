import Foundation

struct MealItem: Identifiable, Hashable {
    let id: String
    let name: String
    let calories: Int
    let carbs: Int
    let protein: Int
    let fats: Int
    let measureOptions: [MealMeasureOption]

    init(
        id: String = UUID().uuidString,
        name: String,
        calories: Int,
        carbs: Int,
        protein: Int,
        fats: Int,
        measureOptions: [MealMeasureOption] = []
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.fats = fats
        self.measureOptions = measureOptions
    }
}

struct MealMeasureOption: Identifiable, Hashable {
    let id: String
    let title: String
    let grams: Double

    var displayTitle: String {
        "\(title) (\(Self.formatGrams(grams)) g)"
    }

    init(title: String, grams: Double) {
        self.title = title
        self.grams = grams
        id = "\(title)-\(Self.formatGrams(grams))"
    }

    private static func formatGrams(_ grams: Double) -> String {
        let roundedValue = grams.rounded()

        if abs(grams - roundedValue) < 0.05 {
            return "\(Int(roundedValue))"
        }

        return grams.formatted(.number.precision(.fractionLength(1)))
    }
}

struct MealSearchPage {
    let meals: [MealItem]
    let nextPage: Int?
}

struct OpenFoodFactsClient {
    private let baseURL = URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!
    private let productBaseURL = URL(string: "https://world.openfoodfacts.org/api/v2/product")!
    private let fallbackURL = URL(string: "https://search.openfoodfacts.org/search")!
    private let pageSize = 50
    private let session: URLSession
    private let productFields = "code,product_name,brands,quantity,serving_size,serving_quantity,nutriments,countries_tags"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchMeals(matching query: String, page: Int = 1) async throws -> MealSearchPage {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return MealSearchPage(meals: [], nextPage: nil)
        }

        let primaryQueryItems = [
            URLQueryItem(name: "search_terms", value: trimmedQuery),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "fields", value: productFields),
            URLQueryItem(name: "tagtype_0", value: "countries"),
            URLQueryItem(name: "tag_contains_0", value: "contains"),
            URLQueryItem(name: "tag_0", value: "germany")
        ]

        do {
            return try await fetchMealPage(from: baseURL, queryItems: primaryQueryItems, page: page)
        } catch let error as OpenFoodFactsError {
            switch error {
            case .badStatusCode:
                return try await fetchMealPage(
                    from: fallbackURL,
                    queryItems: [
                        URLQueryItem(name: "q", value: trimmedQuery),
                        URLQueryItem(name: "langs", value: "de"),
                        URLQueryItem(name: "fields", value: productFields)
                    ],
                    page: page
                )
            case .invalidURL, .requestFailed:
                throw error
            }
        }
    }

    func meal(forBarcode barcode: String) async throws -> MealItem? {
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBarcode.isEmpty else {
            return nil
        }

        let productURL = productBaseURL
            .appending(path: trimmedBarcode)
            .appendingPathExtension("json")

        let response = try await fetchProductResponse(
            from: productURL,
            queryItems: [
                URLQueryItem(name: "fields", value: productFields)
            ]
        )

        guard response.status == 1 else {
            return nil
        }

        return response.product.mealItem
    }

    private func fetchMealPage(
        from url: URL,
        queryItems: [URLQueryItem],
        page: Int
    ) async throws -> MealSearchPage {
        let response = try await fetchSearchResponse(
            from: url,
            queryItems: queryItems + [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "page_size", value: "\(pageSize)")
            ]
        )
        var seenIDs: Set<String> = []

        let meals = response.products
            .filter(\.isAvailableInGermany)
            .compactMap(\.mealItem)
            .filter { meal in
                seenIDs.insert(meal.id).inserted
            }

        return MealSearchPage(
            meals: meals,
            nextPage: page < response.pageCount ? page + 1 : nil
        )
    }

    private func fetchSearchResponse(
        from url: URL,
        queryItems: [URLQueryItem]
    ) async throws -> OpenFoodFactsSearchResponse {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw OpenFoodFactsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Track/1.0 (contact: local-development)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.requestFailed
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw OpenFoodFactsError.badStatusCode(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
    }

    private func fetchProductResponse(
        from url: URL,
        queryItems: [URLQueryItem]
    ) async throws -> OpenFoodFactsProductResponse {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw OpenFoodFactsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Track/1.0 (contact: local-development)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.requestFailed
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw OpenFoodFactsError.badStatusCode(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(OpenFoodFactsProductResponse.self, from: data)
    }
}

enum OpenFoodFactsError: LocalizedError {
    case invalidURL
    case requestFailed
    case badStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Die Suche konnte nicht vorbereitet werden."
        case .requestFailed:
            "Open Food Facts ist gerade nicht erreichbar."
        case .badStatusCode(let statusCode):
            if statusCode == 429 {
                "Zu viele Suchanfragen. Bitte warte kurz und suche dann erneut."
            } else {
                "Open Food Facts hat die Suche abgelehnt. Statuscode: \(statusCode)"
            }
        }
    }
}

private struct OpenFoodFactsSearchResponse: Decodable {
    let products: [OpenFoodFactsProduct]
    let pageCount: Int

    enum CodingKeys: String, CodingKey {
        case products
        case hits
        case pageCount = "page_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        products = try container.decodeIfPresent([OpenFoodFactsProduct].self, forKey: .products)
            ?? container.decodeIfPresent([OpenFoodFactsProduct].self, forKey: .hits)
            ?? []
        pageCount = max(try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1, 1)
    }
}

private struct OpenFoodFactsProductResponse: Decodable {
    let status: Int
    let product: OpenFoodFactsProduct
}

private struct OpenFoodFactsProduct: Decodable {
    let code: FlexibleString?
    let productName: FlexibleString?
    let brands: FlexibleString?
    let quantity: FlexibleString?
    let servingSize: FlexibleString?
    let servingQuantity: FlexibleDouble?
    let countriesTags: [String]?
    let nutriments: OpenFoodFactsNutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case quantity
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case countriesTags = "countries_tags"
        case nutriments
    }

    var isAvailableInGermany: Bool {
        guard let countriesTags else {
            return true
        }

        return countriesTags.contains { countryTag in
            let normalizedTag = countryTag.lowercased()
            return normalizedTag == "en:germany"
                || normalizedTag == "de:deutschland"
                || normalizedTag == "germany"
                || normalizedTag == "deutschland"
        }
    }

    var mealItem: MealItem? {
        guard let productName = productName?.value,
              !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let calories = nutriments?.calories,
              let carbs = nutriments?.carbs,
              let protein = nutriments?.protein,
              let fats = nutriments?.fats else {
            return nil
        }

        let trimmedBrand = brands?.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = if let trimmedBrand, !trimmedBrand.isEmpty {
            "\(productName) - \(trimmedBrand)"
        } else {
            productName
        }

        return MealItem(
            id: code?.value ?? "\(productName)-\(trimmedBrand ?? "")",
            name: name,
            calories: Int(calories.rounded()),
            carbs: Int(carbs.rounded()),
            protein: Int(protein.rounded()),
            fats: Int(fats.rounded()),
            measureOptions: measureOptions
        )
    }

    private var measureOptions: [MealMeasureOption] {
        var options: [MealMeasureOption] = []
        var seenIDs: Set<String> = []

        appendServingMeasure(to: &options, seenIDs: &seenIDs)
        appendPackageMeasure(to: &options, seenIDs: &seenIDs)

        return options
    }

    private func appendServingMeasure(to options: inout [MealMeasureOption], seenIDs: inout Set<String>) {
        let servingText = servingSize?.value
        let parsedServingGrams = servingText.flatMap { Self.extractGramValue(from: $0) }
        let grams = servingQuantity?.value ?? parsedServingGrams

        guard let grams, grams > 0 else {
            return
        }

        let title = servingText.flatMap { Self.extractCountUnitTitle(from: $0) } ?? "Portion"
        appendUniqueMeasure(
            MealMeasureOption(title: title, grams: grams),
            to: &options,
            seenIDs: &seenIDs
        )

        if title.localizedCaseInsensitiveCompare("Portion") != .orderedSame {
            appendUniqueMeasure(
                MealMeasureOption(title: "Portion", grams: grams),
                to: &options,
                seenIDs: &seenIDs
            )
        }
    }

    private func appendPackageMeasure(to options: inout [MealMeasureOption], seenIDs: inout Set<String>) {
        guard let quantityText = quantity?.value,
              let grams = Self.extractPackageGramValue(from: quantityText),
              grams > 0,
              !options.contains(where: { option in
                  option.title.localizedCaseInsensitiveCompare("Portion") == .orderedSame
                      && Self.hasSameGramValue(option.grams, grams)
              }) else {
            return
        }

        appendUniqueMeasure(
            MealMeasureOption(title: "Package", grams: grams),
            to: &options,
            seenIDs: &seenIDs
        )
    }

    private func appendUniqueMeasure(
        _ option: MealMeasureOption,
        to options: inout [MealMeasureOption],
        seenIDs: inout Set<String>
    ) {
        guard seenIDs.insert(option.id).inserted else {
            return
        }

        options.append(option)
    }

    nonisolated private static func extractCountUnitTitle(from text: String) -> String? {
        let normalizedText = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let pattern = #"(?i)^\s*(?:\d+(?:\.\d+)?|one|a|an)\s*([^\d\(\),;]+)"#
        guard let match = normalizedText.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        let matchedText = String(normalizedText[match])
        let unitText = matchedText
            .replacingOccurrences(
                of: #"(?i)^\s*(?:\d+(?:\.\d+)?|one|a|an)\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !unitText.isEmpty,
              !Self.isGramLikeUnit(unitText) else {
            return nil
        }

        return Self.localizedUnitTitle(for: unitText)
    }

    nonisolated private static func extractPackageGramValue(from text: String) -> Double? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")
        let multipackPattern = #"(?i)(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\b"#

        if let match = normalizedText.firstMatch(pattern: multipackPattern),
           match.count == 4,
           let count = Double(match[1]),
           let amount = Double(match[2]) {
            return count * grams(from: amount, unit: match[3])
        }

        return extractGramValue(from: normalizedText)
    }

    nonisolated private static func extractGramValue(from text: String) -> Double? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")
        let pattern = #"(?i)(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\b"#

        guard let match = normalizedText.firstMatch(pattern: pattern),
              match.count == 3,
              let amount = Double(match[1]) else {
            return nil
        }

        return grams(from: amount, unit: match[2])
    }

    nonisolated private static func grams(from amount: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "kg", "l":
            amount * 1_000
        default:
            amount
        }
    }

    nonisolated private static func hasSameGramValue(_ firstValue: Double, _ secondValue: Double) -> Bool {
        abs(firstValue - secondValue) < 0.05
    }

    nonisolated private static func isGramLikeUnit(_ unit: String) -> Bool {
        let normalizedUnit = unit.lowercased()
        return normalizedUnit == "g"
            || normalizedUnit == "gram"
            || normalizedUnit == "grams"
            || normalizedUnit == "gramm"
            || normalizedUnit == "kg"
            || normalizedUnit == "ml"
            || normalizedUnit == "l"
            || normalizedUnit == "liter"
            || normalizedUnit == "litre"
    }

    nonisolated private static func localizedUnitTitle(for unit: String) -> String {
        let normalizedUnit = unit
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return switch normalizedUnit {
        case "piece", "pieces", "pc", "pcs", "stuck", "stück", "stueck":
            "Piece"
        case "serving", "servings", "portion", "portions":
            "Portion"
        case "slice", "slices":
            "Scheibe"
        case "bar", "bars":
            "Riegel"
        case "cookie", "cookies", "biscuit", "biscuits":
            "Keks"
        case "cup", "cups":
            "Becher"
        case "bottle", "bottles":
            "Flasche"
        case "can", "cans":
            "Dose"
        default:
            unit
        }
    }
}

private extension String {
    nonisolated func firstMatch(pattern: String) -> [String]? {
        guard let regularExpression = try? NSRegularExpression(pattern: pattern),
              let match = regularExpression.firstMatch(
                in: self,
                range: NSRange(startIndex..., in: self)
              ) else {
            return nil
        }

        return (0..<match.numberOfRanges).compactMap { rangeIndex in
            guard let range = Range(match.range(at: rangeIndex), in: self) else {
                return nil
            }

            return String(self[range])
        }
    }
}

private struct OpenFoodFactsNutriments: Decodable {
    let caloriesPer100g: FlexibleDouble?
    let caloriesValue: FlexibleDouble?
    let carbsPer100g: FlexibleDouble?
    let carbsValue: FlexibleDouble?
    let proteinPer100g: FlexibleDouble?
    let proteinValue: FlexibleDouble?
    let fatsPer100g: FlexibleDouble?
    let fatsValue: FlexibleDouble?

    enum CodingKeys: String, CodingKey {
        case caloriesPer100g = "energy-kcal_100g"
        case caloriesValue = "energy-kcal"
        case carbsPer100g = "carbohydrates_100g"
        case carbsValue = "carbohydrates"
        case proteinPer100g = "proteins_100g"
        case proteinValue = "proteins"
        case fatsPer100g = "fat_100g"
        case fatsValue = "fat"
    }

    var calories: Double? {
        caloriesPer100g?.value ?? caloriesValue?.value
    }

    var carbs: Double? {
        carbsPer100g?.value ?? carbsValue?.value
    }

    var protein: Double? {
        proteinPer100g?.value ?? proteinValue?.value
    }

    var fats: Double? {
        fatsPer100g?.value ?? fatsValue?.value
    }
}

private struct FlexibleString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let stringValues = try? container.decode([String].self) {
            value = stringValues.joined(separator: ", ")
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a String or array of Strings."
                )
            )
        }
    }
}

private struct FlexibleDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self),
                  let doubleValue = Double(stringValue) {
            value = doubleValue
        } else {
            throw DecodingError.typeMismatch(
                Double.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a Double or numeric String."
                )
            )
        }
    }
}
