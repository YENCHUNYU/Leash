import Foundation

nonisolated struct Breed: Identifiable, Equatable, Sendable {
    enum Rarity: Int, CaseIterable, Sendable {
        case common, uncommon, rare, legendary

        /// Relative odds of meeting each rarity.
        var weight: Double { [60, 28, 10, 2][rawValue] }
        /// Chance a single treat makes friends.
        var befriendChance: Double { [0.8, 0.55, 0.35, 0.2][rawValue] }
        var xp: Int { [30, 50, 80, 150][rawValue] }

        func name(in language: AppLanguage) -> String {
            switch self {
            case .common: language.text("Common", "常見")
            case .uncommon: language.text("Uncommon", "少見")
            case .rare: language.text("Rare", "稀有")
            case .legendary: language.text("Legendary", "傳說")
            }
        }
    }

    enum Ears: Sendable { case pricked, floppy, curly }
    enum Trait: Sendable { case big, dark, flatFaced, taiwanese }

    let id: String
    let english: String
    let chinese: String
    let rarity: Rarity
    let coat: UInt32
    let muzzle: UInt32
    let ears: Ears
    var traits: Set<Trait> = []

    func name(in language: AppLanguage) -> String { language.text(english, chinese) }

    static func named(_ id: String) -> Breed { all.first { $0.id == id } ?? all[0] }
    /// Coats available before making any friends.
    static let starterIDs: Set<String> = ["mixy", "mixk", "shiba"]

    static let all: [Breed] = [
        Breed(id: "mixy", english: "Mixed · Tan", chinese: "米克斯・黃", rarity: .common, coat: 0xD9A35B, muzzle: 0xF1D7AE, ears: .pricked),
        Breed(id: "mixk", english: "Mixed · Black", chinese: "米克斯・黑", rarity: .common, coat: 0x2E2A27, muzzle: 0x4A433E, ears: .pricked, traits: [.dark]),
        Breed(id: "shiba", english: "Shiba Inu", chinese: "柴犬", rarity: .common, coat: 0xD4884A, muzzle: 0xFBF1E3, ears: .pricked),
        Breed(id: "poodle", english: "Poodle", chinese: "貴賓", rarity: .common, coat: 0xB5733F, muzzle: 0xC98C58, ears: .curly),
        Breed(id: "pom", english: "Pomeranian", chinese: "博美", rarity: .common, coat: 0xE3A35A, muzzle: 0xF4CF9B, ears: .pricked),
        Breed(id: "malt", english: "Maltese", chinese: "馬爾濟斯", rarity: .common, coat: 0xF7F4EE, muzzle: 0xFFFFFF, ears: .floppy),
        Breed(id: "dachs", english: "Dachshund", chinese: "臘腸", rarity: .common, coat: 0x8A4A26, muzzle: 0xA9653A, ears: .floppy),
        Breed(id: "corgi", english: "Corgi", chinese: "柯基", rarity: .common, coat: 0xD98C3E, muzzle: 0xFFFFFF, ears: .pricked),
        Breed(id: "golden", english: "Golden Retriever", chinese: "黃金獵犬", rarity: .uncommon, coat: 0xE0A955, muzzle: 0xEDC383, ears: .floppy, traits: [.big]),
        Breed(id: "lab", english: "Labrador", chinese: "拉布拉多", rarity: .uncommon, coat: 0xE9CD8F, muzzle: 0xF2DDAE, ears: .floppy, traits: [.big]),
        Breed(id: "frenchie", english: "French Bulldog", chinese: "法鬥", rarity: .uncommon, coat: 0xCDBBA5, muzzle: 0x3A322C, ears: .pricked, traits: [.flatFaced]),
        Breed(id: "schnauzer", english: "Schnauzer", chinese: "雪納瑞", rarity: .uncommon, coat: 0x8E8E8E, muzzle: 0xE2E2E2, ears: .floppy),
        Breed(id: "bichon", english: "Bichon Frise", chinese: "比熊", rarity: .uncommon, coat: 0xFFFFFF, muzzle: 0xFFFFFF, ears: .curly),
        Breed(id: "chi", english: "Chihuahua", chinese: "吉娃娃", rarity: .uncommon, coat: 0xE2B77F, muzzle: 0xF5DFC0, ears: .pricked),
        Breed(id: "brindle", english: "Mixed · Brindle", chinese: "米克斯・虎斑", rarity: .uncommon, coat: 0x8B5E34, muzzle: 0xA87A4E, ears: .pricked),
        Breed(id: "socks", english: "Mixed · White Socks", chinese: "米克斯・白襪", rarity: .uncommon, coat: 0x2E2A27, muzzle: 0xFFFFFF, ears: .pricked, traits: [.dark]),
        Breed(id: "blackmouth", english: "Mixed · Black Mouth", chinese: "米克斯・黑嘴", rarity: .uncommon, coat: 0xD9A35B, muzzle: 0x2A2522, ears: .pricked),
        Breed(id: "husky", english: "Husky", chinese: "哈士奇", rarity: .rare, coat: 0x6E7178, muzzle: 0xFFFFFF, ears: .pricked, traits: [.big]),
        Breed(id: "bc", english: "Border Collie", chinese: "邊境牧羊犬", rarity: .rare, coat: 0x26221F, muzzle: 0xFFFFFF, ears: .floppy, traits: [.big, .dark]),
        Breed(id: "akita", english: "Akita", chinese: "秋田犬", rarity: .rare, coat: 0xD08A4C, muzzle: 0xFFF6EA, ears: .pricked, traits: [.big]),
        Breed(id: "bernese", english: "Bernese Mountain Dog", chinese: "伯恩山犬", rarity: .rare, coat: 0x1F1C1A, muzzle: 0xFFFFFF, ears: .floppy, traits: [.big, .dark]),
        Breed(id: "pug", english: "Pug", chinese: "巴哥", rarity: .rare, coat: 0xE3C9A0, muzzle: 0x2E2824, ears: .floppy, traits: [.flatFaced]),
        Breed(id: "samoyed", english: "Samoyed", chinese: "薩摩耶", rarity: .rare, coat: 0xFFFFFF, muzzle: 0xFFFFFF, ears: .pricked, traits: [.big]),
        Breed(id: "formosan", english: "Formosan Mountain Dog", chinese: "台灣犬", rarity: .legendary, coat: 0x2A2623, muzzle: 0x3A3430, ears: .pricked, traits: [.taiwanese, .dark]),
        Breed(id: "calico", english: "Mixed · Tricolor", chinese: "米克斯・三色", rarity: .legendary, coat: 0xF4ECDF, muzzle: 0xFFFFFF, ears: .pricked),
    ]
}
