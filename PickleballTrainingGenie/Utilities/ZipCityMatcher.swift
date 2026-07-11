import Foundation

/// Matches a user's zip code to the closest city the tournaments API has data for.
///
/// Uses a bundled table of 3-digit zip-prefix centroids (generated from the US Census
/// ZCTA Gazetteer) and the haversine distance between the user's prefix centroid and
/// each candidate city's prefix centroid. 3-digit prefixes are accurate to roughly
/// 30–50 miles, which is plenty for picking the nearest major tournament city, and the
/// user can always override the match manually.
enum ZipCityMatcher {
    private static let centroids: [String: [Double]] = {
        guard let url = Bundle.main.url(forResource: "ZipPrefixCentroids", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Double]].self, from: data)
        else {
            return [:]
        }
        return decoded
    }()

    static func isValidZip(_ zip: String) -> Bool {
        zip.count == 5 && zip.allSatisfy(\.isNumber)
    }

    static func closestCity(toZip zip: String, in cities: [City]) -> City? {
        guard isValidZip(zip), !cities.isEmpty else { return nil }

        if let userCoordinate = coordinate(forZip: zip) {
            let located: [(City, Double)] = cities.compactMap { city in
                guard let cityCoordinate = coordinate(forZip: city.zip) else { return nil }
                return (city, haversineMiles(userCoordinate, cityCoordinate))
            }
            if let best = located.min(by: { $0.1 < $1.1 }) {
                return best.0
            }
        }

        // Fallback when a prefix is missing from the table: numeric zip proximity.
        guard let zipValue = Int(zip) else { return nil }
        return cities.min { a, b in
            let da = Int(a.zip).map { abs($0 - zipValue) } ?? Int.max
            let db = Int(b.zip).map { abs($0 - zipValue) } ?? Int.max
            return da < db
        }
    }

    private static func coordinate(forZip zip: String) -> (lat: Double, lon: Double)? {
        let prefix = String(zip.prefix(3))
        guard let pair = centroids[prefix], pair.count == 2 else { return nil }
        return (pair[0], pair[1])
    }

    private static func haversineMiles(_ a: (lat: Double, lon: Double), _ b: (lat: Double, lon: Double)) -> Double {
        let earthRadiusMiles = 3958.8
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMiles * asin(min(1, sqrt(h)))
    }
}
