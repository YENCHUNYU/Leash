import Foundation
import CoreLocation

nonisolated struct Spot: Identifiable, Hashable, Sendable {
    enum Country: String, Codable, Sendable { case taiwan, unitedStates }

    /// Raw values are bit positions in the bundled OSM data.
    enum Tag: Int, CaseIterable, Codable, Sendable {
        case fence, zone, water, wash, bag, shade, offLeash, grass, allDay, free

        func label(in language: AppLanguage) -> String {
            switch self {
            case .fence: language.text("Fenced", "有圍欄")
            case .zone: language.text("Small/large areas", "大小型犬分區")
            case .water: language.text("Water", "洗手台／水")
            case .wash: language.text("Dog wash", "洗狗設備")
            case .bag: language.text("Bags & bins", "便袋／垃圾桶")
            case .shade: language.text("Shade", "遮蔭")
            case .offLeash: language.text("Off-leash", "可放繩")
            case .grass: language.text("Grass", "草地")
            case .allDay: language.text("24 hours", "24 小時")
            case .free: language.text("Free", "免費")
            }
        }
    }

    let id: String
    let name: String
    let country: Country
    /// Taiwan county or US state code.
    let region: String
    /// Taiwan district or US county.
    let subregion: String
    /// Human-readable place line, e.g. district or "City, ST · address".
    let detail: String
    let tags: Set<Tag>
    let latitude: Double?
    let longitude: Double?
    var isCustom = false

    var location: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    /// Grass or off-leash space, where big dogs are easier to meet.
    var isField: Bool { tags.contains(.grass) || tags.contains(.offLeash) }
    /// Water or waste stations earn a treat bonus once per day.
    var hasAmenities: Bool { tags.contains(.water) || tags.contains(.bag) }

    static let indoorID = "indoor"
}

/// A spot the user added. Stored on device without coordinates.
struct CustomSpot: Codable, Identifiable, Equatable {
    var id = "c" + UUID().uuidString
    var name: String
    var area: String
    var tags: Set<Spot.Tag>
    var country: Spot.Country
    var region: String

    var spot: Spot {
        Spot(id: id, name: name, country: country, region: region, subregion: "", detail: area,
             tags: tags, latitude: nil, longitude: nil, isCustom: true)
    }
}

enum Regions {
    static let taiwan = ["臺北市", "新北市", "基隆市", "桃園市", "新竹市", "新竹縣", "苗栗縣", "臺中市", "彰化縣", "南投縣", "雲林縣",
                         "嘉義市", "嘉義縣", "臺南市", "高雄市", "屏東縣", "宜蘭縣", "花蓮縣", "臺東縣", "澎湖縣", "金門縣", "連江縣"]
    static let unitedStates: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California", "CO": "Colorado",
        "CT": "Connecticut", "DE": "Delaware", "DC": "Washington DC", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
        "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas", "KY": "Kentucky",
        "LA": "Louisiana", "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
        "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada", "NH": "New Hampshire",
        "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York", "NC": "North Carolina", "ND": "North Dakota",
        "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island",
        "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont",
        "VA": "Virginia", "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming", "PR": "Puerto Rico", "GU": "Guam",
    ]

    static func displayName(_ region: String) -> String { unitedStates[region] ?? region }
    /// Matches a typed area like "台北市大安區" to a county.
    static func taiwanCounty(in text: String) -> String? {
        taiwan.first { text.contains($0) || text.contains($0.replacingOccurrences(of: "臺", with: "台")) }
    }
}
