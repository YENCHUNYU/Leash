import Foundation

/// Level, treats and collections derived from walk history and encounter results.
struct GameProgress: Equatable {
    struct Day: Equatable {
        var minutes = 0
        var poop = false
        var photos = 0
        var indoor = false
        /// Walked 20 minutes (or played indoors), took a photo and logged a poop.
        var allQuestsDone: Bool { (minutes >= 20 || indoor) && photos >= 1 && poop }
    }

    static let eggMinutes = 120
    static let startingTreats = 5

    var xp = 0
    var treats = startingTreats
    var days: [Date: Day] = [:]
    var visitedSpotIDs: Set<String> = []
    var visitedRegions: Set<String> = []
    var outdoorMinutes = 0
    var outdoorWalkCount = 0
    var bestStreak = 0
    var currentStreak = 0
    var friends: [String: Int] = [:]

    /// Level n starts at 60·(n−1)² XP.
    var level: Int { Int((Double(xp) / 60).squareRoot()) + 1 }
    var levelStartXP: Int { 60 * (level - 1) * (level - 1) }
    var nextLevelXP: Int { 60 * level * level }
    var levelFraction: Double { Double(xp - levelStartXP) / Double(nextLevelXP - levelStartXP) }
    var hatchedEggs: Int { outdoorMinutes / Self.eggMinutes }
    var eggMinutesLeft: Int { Self.eggMinutes - outdoorMinutes % Self.eggMinutes }
    var friendKinds: Int { friends.values.filter { $0 > 0 }.count }

    func title(in language: AppLanguage) -> String {
        let english = ["Rookie Walker", "Block Explorer", "Park Regular", "Zoomies Champ", "Trail Pro", "City Roamer", "Road Tripper", "Legend of the Leash"]
        let chinese = ["散步新手", "巷口探險家", "公園常客", "草地放電王", "河濱達人", "城市漫遊家", "跨縣市旅人", "全台足跡王"]
        let index = min(english.count, level) - 1
        return language.text(english[index], chinese[index])
    }

    func day(_ date: Date, calendar: Calendar = .current) -> Day { days[calendar.startOfDay(for: date)] ?? Day() }

    init() {}

    init(walks: [Walk], photos: [Photo], customSpotCount: Int, game: GameState,
         spot: (String) -> Spot?, now: Date = .now, calendar: Calendar = .current) {
        var stopBonuses: Set<String> = []
        for walk in walks.sorted(by: { $0.startedAt < $1.startedAt }) {
            let key = calendar.startOfDay(for: walk.startedAt)
            if walk.isIndoor {
                xp += 15
                days[key, default: Day()].indoor = true
                continue
            }
            let minutes = walk.minutes()
            outdoorWalkCount += 1
            outdoorMinutes += minutes
            xp += 10 + min(60, minutes)
            if !walk.events.isEmpty { xp += 5 }
            treats += 3 + min(6, minutes / 10)
            days[key, default: Day()].minutes += minutes
            if walk.count(of: .poop) > 0 { days[key, default: Day()].poop = true }
            if let id = walk.spotID, let place = spot(id) {
                if place.hasAmenities, stopBonuses.insert("\(key.timeIntervalSince1970)|\(id)").inserted { treats += 5 }
                if visitedSpotIDs.insert(id).inserted {
                    xp += 30
                    visitedRegions.insert(place.region)
                }
            }
        }
        for photo in photos {
            xp += 5
            treats += 1
            days[calendar.startOfDay(for: photo.takenAt), default: Day()].photos += 1
        }
        xp += customSpotCount * 20
        for day in days.values where day.allQuestsDone {
            xp += 20
            treats += 5
        }
        treats += hatchedEggs * 10
        friends = game.friends
        for breed in Breed.all {
            if let count = game.friends[breed.id], count > 0 { xp += breed.rarity.xp + (count - 1) * 10 }
        }
        treats = max(0, treats - game.treatsSpent)

        let walkDays = Set(walks.filter { !$0.isIndoor }.map { calendar.startOfDay(for: $0.startedAt) })
        var run = 0, previous: Date?
        for day in walkDays.sorted() {
            let consecutive = previous.flatMap { calendar.dateComponents([.day], from: $0, to: day).day } == 1
            run = consecutive ? run + 1 : 1
            bestStreak = max(bestStreak, run)
            previous = day
        }
        var cursor = calendar.startOfDay(for: now)
        if !walkDays.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor)! }
        while walkDays.contains(cursor) {
            currentStreak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
    }
}

struct Quest: Identifiable, Equatable {
    enum Kind: String { case walk, indoor, photo, poop }
    let kind: Kind
    let title: String
    let detail: String
    let isDone: Bool
    var id: Kind { kind }
    /// Indoor play is self-reported with a Done button.
    var canComplete: Bool { kind == .indoor && !isDone }

    static func indoorActivity(on date: Date, language: AppLanguage, calendar: Calendar = .current) -> String {
        let english = ["Snuffle game: hide treats in a towel", "Practice a new trick for 10 min", "Feed a meal from a puzzle toy"]
        let chinese = ["在家玩嗅聞遊戲：把零食藏在毛巾裡", "練習一個新指令 10 分鐘", "用益智玩具餵一餐"]
        let index = calendar.component(.day, from: date) % english.count
        return language.text(english[index], chinese[index])
    }

    /// Today's three quests. On hot days the walk quest becomes indoor play.
    static func daily(_ progress: GameProgress, now: Date = .now, language: AppLanguage) -> [Quest] {
        let today = progress.day(now)
        let walked = today.minutes >= 20 || today.indoor
        let first = Heat.isHot(now, language: language)
            ? Quest(kind: .indoor, title: indoorActivity(on: now, language: language),
                    detail: language.text("Too hot out, indoor play counts", "太熱了，在家玩也算"), isDone: walked)
            : Quest(kind: .walk, title: language.text("Walk 20 min", "散步 20 分鐘"), detail: "\(min(today.minutes, 20)) / 20", isDone: walked)
        return [
            first,
            Quest(kind: .photo, title: language.text("Take a photo", "拍一張照"), detail: "\(min(today.photos, 1)) / 1", isDone: today.photos >= 1),
            Quest(kind: .poop, title: language.text("Log a poop", "記一次便便"), detail: today.poop ? "1 / 1" : "0 / 1", isDone: today.poop),
        ]
    }
}

struct Badge: Identifiable {
    let id: Int
    let emoji: String
    let title: String
    let earned: Bool

    static func all(_ progress: GameProgress, walks: [Walk], customSpotCount: Int, language: AppLanguage, calendar: Calendar = .current) -> [Badge] {
        let outdoor = walks.filter { !$0.isIndoor }
        let hours = outdoor.map { calendar.component(.hour, from: $0.startedAt) }
        let hotIndoor = walks.filter { $0.isIndoor && Heat.isHot($0.startedAt, language: language, calendar: calendar) }.count
        let legend = Breed.all.contains { $0.rarity == .legendary && (progress.friends[$0.id] ?? 0) > 0 }
        let entries: [(String, String, String, Bool)] = [
            ("🐾", "First walk", "第一次出門", !outdoor.isEmpty),
            ("🤝", "First friend", "第一個朋友", progress.friendKinds >= 1),
            ("🎒", "10 friends", "10 種朋友", progress.friendKinds >= 10),
            ("✨", "Met a legend", "遇見傳說", legend),
            ("🌅", "Early bird", "早起散步", hours.contains { $0 < 7 }),
            ("🌙", "Night walk", "夜間散步", hours.contains { $0 >= 20 }),
            ("🔥", "7-day streak", "連續 7 天", progress.bestStreak >= 7),
            ("🗺️", "3 spots", "收集 3 個地點", progress.visitedSpotIDs.count >= 3),
            ("🚗", "Road trip", "跨區出遊", progress.visitedRegions.count >= 2),
            ("🩺", "Health watcher", "健康觀察員", outdoor.filter { $0.count(of: .poop) > 0 }.count >= 10),
            ("🧊", "Heat smart", "避暑高手", hotIndoor >= 3),
            ("📍", "Trailblazer", "地點開拓者", customSpotCount >= 1),
        ]
        return entries.enumerated().map { Badge(id: $0, emoji: $1.0, title: language.text($1.1, $1.2), earned: $1.3) }
    }
}

enum WalkTips {
    /// One tip unlocks with each hatched egg.
    static func unlocked(_ count: Int, language: AppLanguage) -> [String] {
        let english = [
            "Dogs explore with their noses. Ten minutes of slow sniffing tires the brain as much as a run.",
            "Before a summer walk, press the back of your hand to the pavement for 5 seconds. Too hot for you means too hot for paws.",
            "Flat-faced breeds (French Bulldogs, Pugs) overheat easily. Walk them early morning or after dark.",
            "If stool color or shape suddenly changes and lasts more than two days, it's worth a vet visit.",
            "At a new park, do a leashed lap first so your dog can get to know the place.",
            "When greeting a new dog, let them approach side by side rather than head-on.",
            "For senior dogs, routine matters more than distance. Short and frequent is best.",
            "After zoomies, let your dog rest a bit before a big drink or meal.",
            "On rainy days, hide treats around the house for a snuffle game. It burns energy too.",
            "After walks, check between the paw pads. Summer means foxtails and hot-pavement burns.",
        ]
        let chinese = [
            "狗狗用鼻子探索世界，讓牠慢慢聞 10 分鐘，消耗的腦力不輸跑步。",
            "夏天出門前用手背貼地 5 秒，燙手就代表也會燙腳掌。",
            "短吻犬（法鬥、巴哥）怕熱，散步時間改在清晨或入夜後比較安全。",
            "便便顏色、形狀突然改變並持續兩天以上，值得帶去給獸醫看看。",
            "到新的公園先牽繩繞一圈，讓狗熟悉環境再放開。",
            "和陌生狗打招呼時，讓兩隻狗從側面靠近，比正面衝過去更友善。",
            "老犬的散步重點是規律而不是距離，短而頻繁更好。",
            "放電後別馬上大量喝水和吃飯，休息一下再給。",
            "雨天可以在家藏零食玩嗅聞遊戲，同樣能消耗精力。",
            "散步回家後檢查腳掌縫，夏天容易卡草籽或被燙傷。",
        ]
        return Array((language == .english ? english : chinese).prefix(count))
    }
}
