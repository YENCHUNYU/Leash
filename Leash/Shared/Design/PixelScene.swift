import SwiftUI

// Rectangle artwork translated directly from the supplied HTML reference.
struct PixelScene: View {
    let outdoors: Bool
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let hour = Calendar.current.component(.hour, from: context.date)
            let night = hour < 6 || hour >= 19
            let pixels = outdoors ? (night ? Self.parkNight : Self.parkDay) : (night ? Self.roomNight : Self.roomDay)
            Canvas { context, size in
                for pixel in pixels {
                    let rect = CGRect(x: pixel.x * size.width / 80, y: pixel.y * size.height / 100, width: pixel.w * size.width / 80, height: pixel.h * size.height / 100)
                    context.fill(Path(rect), with: .color(Color(leashHex: pixel.color)))
                }
            }
        }.accessibilityHidden(true)
    }
    private struct Pixel {
        let x, y, w, h: Double
        let color: UInt32
        init(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32) {
            self.x = x; self.y = y; self.w = w; self.h = h; self.color = color
        }
    }
    // Day and night share everything except what is visible through the window or in the sky.
    private static let roomDay = roomBase + dayWindow + roomFurniture
    private static let roomNight = roomBase + nightWindow + roomFurniture
    private static let parkDay = daySky + parkGround
    private static let parkNight = nightSky + parkGround

    private static let roomBase: [Pixel] = [
        Pixel(0, 0, 80, 46, 0xECDDC4),
        Pixel(3, 0, 2, 40, 0xE4D2B4),
        Pixel(11, 0, 2, 40, 0xE4D2B4),
        Pixel(19, 0, 2, 40, 0xE4D2B4),
        Pixel(27, 0, 2, 40, 0xE4D2B4),
        Pixel(35, 0, 2, 40, 0xE4D2B4),
        Pixel(43, 0, 2, 40, 0xE4D2B4),
        Pixel(51, 0, 2, 40, 0xE4D2B4),
        Pixel(59, 0, 2, 40, 0xE4D2B4),
        Pixel(67, 0, 2, 40, 0xE4D2B4),
        Pixel(75, 0, 2, 40, 0xE4D2B4),
        Pixel(0, 40, 80, 6, 0xCDB594),
        Pixel(0, 40, 80, 1, 0xB39C78),
        Pixel(0, 46, 80, 54, 0xDDBD8E),
        Pixel(0, 52, 80, 1, 0xC9A675),
        Pixel(6, 46, 1, 6, 0xC9A675),
        Pixel(30, 46, 1, 6, 0xC9A675),
        Pixel(54, 46, 1, 6, 0xC9A675),
        Pixel(78, 46, 1, 6, 0xC9A675),
        Pixel(0, 59, 80, 1, 0xC9A675),
        Pixel(6, 53, 1, 6, 0xC9A675),
        Pixel(30, 53, 1, 6, 0xC9A675),
        Pixel(54, 53, 1, 6, 0xC9A675),
        Pixel(78, 53, 1, 6, 0xC9A675),
        Pixel(0, 66, 80, 1, 0xC9A675),
        Pixel(6, 60, 1, 6, 0xC9A675),
        Pixel(30, 60, 1, 6, 0xC9A675),
        Pixel(54, 60, 1, 6, 0xC9A675),
        Pixel(78, 60, 1, 6, 0xC9A675),
        Pixel(0, 73, 80, 1, 0xC9A675),
        Pixel(6, 67, 1, 6, 0xC9A675),
        Pixel(30, 67, 1, 6, 0xC9A675),
        Pixel(54, 67, 1, 6, 0xC9A675),
        Pixel(78, 67, 1, 6, 0xC9A675),
        Pixel(0, 80, 80, 1, 0xC9A675),
        Pixel(6, 74, 1, 6, 0xC9A675),
        Pixel(30, 74, 1, 6, 0xC9A675),
        Pixel(54, 74, 1, 6, 0xC9A675),
        Pixel(78, 74, 1, 6, 0xC9A675),
        Pixel(0, 87, 80, 1, 0xC9A675),
        Pixel(6, 81, 1, 6, 0xC9A675),
        Pixel(30, 81, 1, 6, 0xC9A675),
        Pixel(54, 81, 1, 6, 0xC9A675),
        Pixel(78, 81, 1, 6, 0xC9A675),
        Pixel(0, 94, 80, 1, 0xC9A675),
        Pixel(6, 88, 1, 6, 0xC9A675),
        Pixel(30, 88, 1, 6, 0xC9A675),
        Pixel(54, 88, 1, 6, 0xC9A675),
        Pixel(78, 88, 1, 6, 0xC9A675),
        Pixel(7, 9, 24, 20, 0x8B6B4A),
    ]

    private static let dayWindow: [Pixel] = [
        Pixel(9, 11, 20, 16, 0xA9DBF2),
        Pixel(22, 13, 4, 4, 0xFCE38A),
        Pixel(11, 20, 6, 2, 0xffffff),
        Pixel(12, 19, 3, 1, 0xffffff),
    ]

    private static let nightWindow: [Pixel] = [
        Pixel(9, 11, 20, 16, 0x2E3A63),
        Pixel(12, 13, 1, 1, 0xffffff),
        Pixel(22, 15, 1, 1, 0xffffff),
        Pixel(16, 20, 1, 1, 0xffffff),
        Pixel(24, 12, 3, 3, 0xF7E6A1),
        Pixel(25, 12, 2, 1, 0x2E3A63),
    ]

    /// Drawn after the window so its frame covers the glass.
    private static let roomFurniture: [Pixel] = [
        Pixel(18, 11, 2, 16, 0x8B6B4A),
        Pixel(9, 18, 20, 2, 0x8B6B4A),
        Pixel(5, 28, 28, 2, 0xA8875F),
        Pixel(36, 32, 6, 8, 0xC46A4A),
        Pixel(35, 32, 8, 2, 0xA85A3E),
        Pixel(36, 24, 2, 8, 0x5DA052),
        Pixel(39, 22, 2, 10, 0x4F8F46),
        Pixel(41, 26, 2, 6, 0x5DA052),
        Pixel(51, 12, 23, 35, 0x5E4030),
        Pixel(53, 14, 19, 33, 0xA9714A),
        Pixel(55, 16, 15, 12, 0x946039),
        Pixel(55, 31, 15, 13, 0x946039),
        Pixel(56, 17, 13, 10, 0xB47C52),
        Pixel(56, 32, 13, 11, 0xB47C52),
        Pixel(68, 29, 2, 2, 0xF4C34A),
        Pixel(49, 46, 27, 2, 0x7A5843),
        Pixel(20, 64, 40, 16, 0xB7C7E8),
        Pixel(22, 66, 36, 12, 0xCAD7F0),
        Pixel(20, 64, 40, 1, 0x97A8D0),
        Pixel(20, 79, 40, 1, 0x97A8D0),
        Pixel(4, 82, 22, 10, 0xD9705D),
        Pixel(6, 84, 18, 6, 0xF4C2B3),
        Pixel(4, 82, 22, 1, 0xB95A4A),
        Pixel(62, 86, 10, 4, 0x5E8FD0),
        Pixel(63, 86, 8, 1, 0xA9D3F5),
        Pixel(62, 89, 10, 1, 0x4A75B0),
    ]

    /// Colours reuse the room's day window.
    private static let daySky: [Pixel] = [
        Pixel(0, 0, 80, 40, 0xA9DBF2),
        Pixel(10, 9, 8, 2, 0xffffff),
        Pixel(12, 8, 4, 1, 0xffffff),
        Pixel(34, 14, 9, 2, 0xffffff),
        Pixel(36, 13, 4, 1, 0xffffff),
        Pixel(62, 6, 5, 5, 0xFCE38A),
    ]

    private static let nightSky: [Pixel] = [
        Pixel(0, 0, 80, 40, 0x2E3A63),
        Pixel(8, 6, 1, 1, 0xffffff),
        Pixel(30, 10, 1, 1, 0xffffff),
        Pixel(52, 5, 1, 1, 0xffffff),
        Pixel(70, 12, 1, 1, 0xffffff),
        Pixel(44, 16, 1, 1, 0xffffff),
        Pixel(62, 6, 5, 5, 0xF7E6A1),
    ]

    private static let parkGround: [Pixel] = [
        Pixel(0, 30, 30, 10, 0x9FCF8F),
        Pixel(26, 33, 30, 7, 0xA9D69A),
        Pixel(50, 29, 30, 11, 0x9FCF8F),
        Pixel(0, 40, 80, 60, 0x8CC46E),
        Pixel(0, 44, 1, 2, 0x77B05A),
        Pixel(1, 45, 1, 1, 0x77B05A),
        Pixel(37, 97, 1, 2, 0x77B05A),
        Pixel(38, 98, 1, 1, 0x77B05A),
        Pixel(74, 96, 1, 2, 0x77B05A),
        Pixel(75, 97, 1, 1, 0x77B05A),
        Pixel(33, 95, 1, 2, 0x77B05A),
        Pixel(34, 96, 1, 1, 0x77B05A),
        Pixel(70, 94, 1, 2, 0x77B05A),
        Pixel(71, 95, 1, 1, 0x77B05A),
        Pixel(29, 93, 1, 2, 0x77B05A),
        Pixel(30, 94, 1, 1, 0x77B05A),
        Pixel(66, 92, 1, 2, 0x77B05A),
        Pixel(67, 93, 1, 1, 0x77B05A),
        Pixel(25, 91, 1, 2, 0x77B05A),
        Pixel(26, 92, 1, 1, 0x77B05A),
        Pixel(62, 90, 1, 2, 0x77B05A),
        Pixel(63, 91, 1, 1, 0x77B05A),
        Pixel(21, 89, 1, 2, 0x77B05A),
        Pixel(22, 90, 1, 1, 0x77B05A),
        Pixel(58, 88, 1, 2, 0x77B05A),
        Pixel(59, 89, 1, 1, 0x77B05A),
        Pixel(17, 87, 1, 2, 0x77B05A),
        Pixel(18, 88, 1, 1, 0x77B05A),
        Pixel(54, 86, 1, 2, 0x77B05A),
        Pixel(55, 87, 1, 1, 0x77B05A),
        Pixel(13, 85, 1, 2, 0x77B05A),
        Pixel(14, 86, 1, 1, 0x77B05A),
        Pixel(50, 84, 1, 2, 0x77B05A),
        Pixel(51, 85, 1, 1, 0x77B05A),
        Pixel(9, 83, 1, 2, 0x77B05A),
        Pixel(10, 84, 1, 1, 0x77B05A),
        Pixel(46, 82, 1, 2, 0x77B05A),
        Pixel(47, 83, 1, 1, 0x77B05A),
        Pixel(5, 81, 1, 2, 0x77B05A),
        Pixel(6, 82, 1, 1, 0x77B05A),
        Pixel(42, 80, 1, 2, 0x77B05A),
        Pixel(43, 81, 1, 1, 0x77B05A),
        Pixel(1, 79, 1, 2, 0x77B05A),
        Pixel(2, 80, 1, 1, 0x77B05A),
        Pixel(38, 78, 1, 2, 0x77B05A),
        Pixel(39, 79, 1, 1, 0x77B05A),
        Pixel(75, 77, 1, 2, 0x77B05A),
        Pixel(76, 78, 1, 1, 0x77B05A),
        Pixel(34, 76, 1, 2, 0x77B05A),
        Pixel(35, 77, 1, 1, 0x77B05A),
        Pixel(71, 75, 1, 2, 0x77B05A),
        Pixel(72, 76, 1, 1, 0x77B05A),
        Pixel(30, 74, 1, 2, 0x77B05A),
        Pixel(31, 75, 1, 1, 0x77B05A),
        Pixel(67, 73, 1, 2, 0x77B05A),
        Pixel(68, 74, 1, 1, 0x77B05A),
        Pixel(26, 72, 1, 2, 0x77B05A),
        Pixel(27, 73, 1, 1, 0x77B05A),
        Pixel(63, 71, 1, 2, 0x77B05A),
        Pixel(64, 72, 1, 1, 0x77B05A),
        Pixel(22, 70, 1, 2, 0x77B05A),
        Pixel(23, 71, 1, 1, 0x77B05A),
        Pixel(59, 69, 1, 2, 0x77B05A),
        Pixel(60, 70, 1, 1, 0x77B05A),
        Pixel(18, 68, 1, 2, 0x77B05A),
        Pixel(19, 69, 1, 1, 0x77B05A),
        Pixel(55, 67, 1, 2, 0x77B05A),
        Pixel(56, 68, 1, 1, 0x77B05A),
        Pixel(14, 66, 1, 2, 0x77B05A),
        Pixel(15, 67, 1, 1, 0x77B05A),
        Pixel(51, 65, 1, 2, 0x77B05A),
        Pixel(52, 66, 1, 1, 0x77B05A),
        Pixel(10, 64, 1, 2, 0x77B05A),
        Pixel(11, 65, 1, 1, 0x77B05A),
        Pixel(47, 63, 1, 2, 0x77B05A),
        Pixel(48, 64, 1, 1, 0x77B05A),
        Pixel(6, 62, 1, 2, 0x77B05A),
        Pixel(7, 63, 1, 1, 0x77B05A),
        Pixel(43, 61, 1, 2, 0x77B05A),
        Pixel(44, 62, 1, 1, 0x77B05A),
        Pixel(2, 60, 1, 2, 0x77B05A),
        Pixel(3, 61, 1, 1, 0x77B05A),
        Pixel(39, 59, 1, 2, 0x77B05A),
        Pixel(40, 60, 1, 1, 0x77B05A),
        Pixel(0, 70, 80, 8, 0xE6D3A6),
        Pixel(0, 70, 80, 1, 0xD1BC8C),
        Pixel(0, 77, 80, 1, 0xD1BC8C),
        Pixel(44, 34, 2, 10, 0xF2E8D8),
        Pixel(50, 34, 2, 10, 0xF2E8D8),
        Pixel(56, 34, 2, 10, 0xF2E8D8),
        Pixel(62, 34, 2, 10, 0xF2E8D8),
        Pixel(68, 34, 2, 10, 0xF2E8D8),
        Pixel(74, 34, 2, 10, 0xF2E8D8),
        Pixel(42, 37, 38, 1, 0xE0D2BC),
        Pixel(42, 41, 38, 1, 0xE0D2BC),
        Pixel(9, 26, 5, 22, 0x8B5E3C),
        Pixel(2, 12, 20, 14, 0x5FA24E),
        Pixel(5, 8, 14, 6, 0x6DB25A),
        Pixel(4, 22, 16, 6, 0x4F8F46),
        Pixel(64, 48, 3, 12, 0x9AA3B5),
        Pixel(64, 48, 7, 2, 0x9AA3B5),
        Pixel(69, 50, 2, 2, 0x7FC4F0),
        Pixel(62, 59, 8, 2, 0x7D869A),
        Pixel(68, 53, 1, 2, 0x7FC4F0),
        Pixel(22, 52, 18, 3, 0xB9784A),
        Pixel(22, 56, 18, 2, 0xA0653C),
        Pixel(24, 58, 2, 4, 0x6B4A33),
        Pixel(36, 58, 2, 4, 0x6B4A33),
        Pixel(48, 84, 2, 2, 0xF28CA0),
        Pixel(55, 90, 2, 2, 0xFCE38A),
        Pixel(12, 88, 2, 2, 0xF28CA0),
        Pixel(70, 94, 2, 2, 0xffffff),
    ]
}
