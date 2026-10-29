import CoreGraphics
import CoreImage
import ImageIO
import Vision

/// Reads a dog photo — ear shape and the colors of coat, ears, muzzle, chest and paws — into a `DogLook`.
nonisolated enum DogAnalyzer {
    enum Failure: Error { case unreadable, noDog }

    /// Body landmarks in normalized image coordinates (origin bottom-left, like Vision).
    struct Landmarks: Sendable {
        var nose: CGPoint?
        var eyes: [CGPoint] = []
        var ears: [(top: CGPoint, middle: CGPoint, bottom: CGPoint)] = []
        var neck: CGPoint?
        var frontElbows: [CGPoint] = []
        var frontKnees: [CGPoint] = []
        var frontPaws: [CGPoint] = []
    }

    /// RGBA pixels, top row first. Alpha 0 is not the dog.
    struct Bitmap: Sendable {
        let width, height: Int
        var bytes: [UInt8]
    }

    static func look(from data: Data) async throws -> DogLook {
        try await Task.detached(priority: .userInitiated) { try analyze(data) }.value
    }

    // MARK: Vision

    private static func analyze(_ data: Data) throws -> DogLook {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: 1024] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { throw Failure.unreadable }
        let handler = VNImageRequestHandler(cgImage: image)
        let pose = VNDetectAnimalBodyPoseRequest()
        let animals = VNRecognizeAnimalsRequest()
        let mask = VNGenerateForegroundInstanceMaskRequest()
        try? handler.perform([pose, animals, mask])

        let landmarks = pose.results?.max { $0.confidence < $1.confidence }.map(landmarks(from:))
        let dogBox = animals.results?.filter { $0.labels.contains { $0.identifier == "Dog" } }
            .max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }?.boundingBox

        var bitmap: Bitmap
        if let result = mask.results?.first, !result.allInstances.isEmpty,
           let buffer = try? result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false),
           let cut = CIContext().createCGImage(CIImage(cvPixelBuffer: buffer), from: CIImage(cvPixelBuffer: buffer).extent) {
            bitmap = render(cut)
        } else {
            // No cut-out (e.g. the Simulator): keep only the dog's box, or the middle of the photo.
            bitmap = render(image)
            keep(&bitmap, box: dogBox ?? landmarks?.bounds ?? CGRect(x: 0.2, y: 0.15, width: 0.6, height: 0.7))
        }
        return try look(bitmap, landmarks: landmarks)
    }

    private static func landmarks(from observation: VNAnimalBodyPoseObservation) -> Landmarks {
        func point(_ joint: VNAnimalBodyPoseObservation.JointName) -> CGPoint? {
            guard let found = try? observation.recognizedPoint(joint), found.confidence > 0.3 else { return nil }
            return found.location
        }
        var marks = Landmarks()
        marks.nose = point(.nose)
        marks.eyes = [point(.leftEye), point(.rightEye)].compactMap { $0 }
        for side in [(VNAnimalBodyPoseObservation.JointName.leftEarTop, VNAnimalBodyPoseObservation.JointName.leftEarMiddle, VNAnimalBodyPoseObservation.JointName.leftEarBottom),
                     (.rightEarTop, .rightEarMiddle, .rightEarBottom)] {
            if let top = point(side.0), let middle = point(side.1), let bottom = point(side.2) {
                marks.ears.append((top, middle, bottom))
            }
        }
        marks.neck = point(.neck)
        marks.frontElbows = [point(.leftFrontElbow), point(.rightFrontElbow)].compactMap { $0 }
        marks.frontKnees = [point(.leftFrontKnee), point(.rightFrontKnee)].compactMap { $0 }
        marks.frontPaws = [point(.leftFrontPaw), point(.rightFrontPaw)].compactMap { $0 }
        return marks
    }

    /// Small RGBA copy of the image, straight (not premultiplied) alpha.
    private static func render(_ image: CGImage, maxSide: Int = 160) -> Bitmap {
        let scale = Double(maxSide) / Double(max(image.width, image.height))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.interpolationQuality = .medium
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 && bytes[i + 3] < 255 {
            let alpha = Double(bytes[i + 3]) / 255
            for c in 0..<3 { bytes[i + c] = UInt8(min(255, Double(bytes[i + c]) / alpha)) }
        }
        return Bitmap(width: width, height: height, bytes: bytes)
    }

    private static func keep(_ bitmap: inout Bitmap, box: CGRect) {
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                let point = CGPoint(x: (Double(x) + 0.5) / Double(bitmap.width), y: 1 - (Double(y) + 0.5) / Double(bitmap.height))
                if !box.contains(point) { bitmap.bytes[(y * bitmap.width + x) * 4 + 3] = 0 }
            }
        }
    }

    // MARK: Reading traits

    /// Turns the dog's pixels and landmarks into a look. Without landmarks it falls back to the overall colors.
    static func look(_ bitmap: Bitmap, landmarks: Landmarks?) throws -> DogLook {
        let dog = (0..<bitmap.width * bitmap.height).filter { bitmap.bytes[$0 * 4 + 3] >= 128 }
        guard dog.count >= bitmap.width * bitmap.height / 50 else { throw Failure.noDog }
        func rgb(_ i: Int) -> RGB { RGB(bitmap.bytes[i * 4], bitmap.bytes[i * 4 + 1], bitmap.bytes[i * 4 + 2]) }

        // The dog's main colors, most common first.
        let clusters = kMeans(dog.map(rgb), k: 5)
        let coat = clusters[0].color
        var nearest = [Int: Int]()
        for i in dog { nearest[i] = clusters.indices.min { rgb(i).distance(to: clusters[$0].color) < rgb(i).distance(to: clusters[$1].color) }! }

        // On a light or mid coat, anything much darker is nose, mouth or shadow. Dark coats have no limit.
        let darkLimit = coat.luminance >= 80 ? coat.luminance - 30 : -1

        /// Dog pixels in a disc around a landmark (empty if the landmark is off the image).
        func disc(_ point: CGPoint, radius: Double) -> [Int] {
            let cx = point.x * Double(bitmap.width), cy = (1 - point.y) * Double(bitmap.height)
            let r = max(2, radius * Double(max(bitmap.width, bitmap.height)))
            let x0 = max(0, Int(cx - r)), x1 = min(bitmap.width - 1, Int(cx + r))
            let y0 = max(0, Int(cy - r)), y1 = min(bitmap.height - 1, Int(cy + r))
            guard x0 <= x1, y0 <= y1 else { return [] }
            var found: [Int] = []
            for y in y0...y1 {
                for x in x0...x1 {
                    let dx = Double(x) - cx, dy = Double(y) - cy
                    let i = y * bitmap.width + x
                    if dx * dx + dy * dy <= r * r, nearest[i] != nil { found.append(i) }
                }
            }
            return found
        }

        /// The most common main color in a small disc around a landmark.
        func vote(_ point: CGPoint, radius: Double, avoidDark: Bool = false) -> RGB? {
            var counts = [Int: Int]()
            for i in disc(point, radius: radius) {
                let cluster = nearest[i]!
                // The nose, mouth and shadows are dark; skip them when reading muzzle and paws.
                if avoidDark && clusters[cluster].color.luminance < darkLimit { continue }
                counts[cluster, default: 0] += 1
            }
            return counts.max { $0.value < $1.value }.map { clusters[$0.key].color }
        }

        // A light, common-enough color is usually the muzzle, chest and paws (cream, white).
        let light = clusters.dropFirst().first { $0.share >= 0.08 && $0.color.luminance > coat.luminance + 30 }?.color

        var look = DogLook(ears: .floppy, coat: coat.hex, earColor: DogSprite.shade(coat.hex, 0.8),
                           muzzle: (light ?? coat.lighter).hex, chest: (light ?? coat).hex, paws: coat.hex,
                           photoColors: clusters.filter { $0.share >= 0.03 }.map(\.color.hex))
        guard let marks = landmarks else { return look.cute }

        let eyeMid = marks.eyes.isEmpty ? nil : CGPoint(x: marks.eyes.map(\.x).reduce(0, +) / Double(marks.eyes.count),
                                                         y: marks.eyes.map(\.y).reduce(0, +) / Double(marks.eyes.count))
        let head = (marks.nose.flatMap { nose in eyeMid.map { nose.distance(to: $0) } }) ?? 0.08
        let radius = max(0.012, head * 0.3)
        // Which way the dog faces in the photo (+1 right, -1 left), to find the front of the chest.
        let facing: Double = (marks.nose?.x ?? 0.5) >= (marks.neck?.x ?? 0.5) ? 1 : -1

        // The sprite is mostly face: when the head is clearly a different color from the body
        // (a black head on a sun-grayed coat), use the head's color.
        if let eyeMid, !marks.ears.isEmpty {
            let earBase = CGPoint(x: marks.ears.map(\.bottom.x).reduce(0, +) / Double(marks.ears.count),
                                  y: marks.ears.map(\.bottom.y).reduce(0, +) / Double(marks.ears.count))
            let forehead = CGPoint(x: (eyeMid.x + earBase.x) / 2, y: (eyeMid.y + earBase.y) / 2)
            if let color = vote(forehead, radius: head * 0.6), abs(color.luminance - coat.luminance) > 60 {
                look.coat = color.hex
                look.earColor = DogSprite.shade(color.hex, 0.8)
                look.paws = color.hex
                if look.chest == coat.hex { look.chest = color.hex }
            }
        }

        if !marks.ears.isEmpty {
            // Vision's ear "top" is the tip: above the base for pointy ears, hanging below it for floppy ones.
            let lift = marks.ears.map { $0.top.y - $0.bottom.y }.reduce(0, +) / Double(marks.ears.count)
            look.ears = lift > 0 ? .pricked : .floppy
            let earVotes = marks.ears.compactMap { vote($0.middle, radius: radius) }
            if let ear = earVotes.first { look.earColor = ear.hex }
        }
        if let nose = marks.nose, let eyeMid {
            // The snout: a little way from the nose toward the eyes.
            let snout = CGPoint(x: nose.x + (eyeMid.x - nose.x) * 0.4, y: nose.y + (eyeMid.y - nose.y) * 0.4)
            if let muzzle = vote(snout, radius: radius, avoidDark: true) { look.muzzle = muzzle.hex }
        }
        if let neck = marks.neck, !marks.frontElbows.isEmpty {
            let elbow = CGPoint(x: marks.frontElbows.map(\.x).reduce(0, +) / Double(marks.frontElbows.count),
                                y: marks.frontElbows.map(\.y).reduce(0, +) / Double(marks.frontElbows.count))
            let chest = CGPoint(x: neck.x + (elbow.x - neck.x) * 0.5 + facing * head * 0.5, y: neck.y + (elbow.y - neck.y) * 0.5)
            if let color = vote(chest, radius: radius, avoidDark: true) { look.chest = color.hex }
        }
        let paws = zip(marks.frontPaws, marks.frontKnees).compactMap { paw, knee in
            vote(CGPoint(x: paw.x + (knee.x - paw.x) * 0.25, y: paw.y + (knee.y - paw.y) * 0.25), radius: radius * 0.7, avoidDark: true)
        }
        if let paw = paws.first { look.paws = paw.hex }

        // Collar: between the neck and the head, look for a color that isn't the dog's fur —
        // something colorful, or near-black on a lighter dog.
        if let neck = marks.neck, let eyeMid {
            let fur = clusters.filter { $0.share >= 0.08 }.map(\.color)
            var band = Set<Int>()
            // From a little below the neck point to a little above it, avoiding the nose and mouth.
            for step in -3...3 {
                let t = Double(step) / 10
                let center = CGPoint(x: neck.x + (eyeMid.x - neck.x) * t, y: neck.y + (eyeMid.y - neck.y) * t)
                if let nose = marks.nose, center.distance(to: nose) < head * 0.6 { continue }
                band.formUnion(disc(center, radius: head * 0.35))
            }
            let lightDog = coat.luminance > 110
            let odd = band.map(rgb).filter { (pixel: RGB) -> Bool in
                let unlikeFur = fur.allSatisfy { pixel.distance(to: $0) > 3025 }
                let standsOut = pixel.chroma > 60 || (lightDog && pixel.luminance < 45)
                return unlikeFur && standsOut
            }
            if !band.isEmpty, odd.count >= max(4, band.count / 25) {
                look.collar = kMeans(odd, k: 2)[0].color.hex
            }
        }
        return look.cute
    }

    // MARK: Color helpers

    struct RGB: Equatable, Sendable {
        var r, g, b: Double
        init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { self.r = Double(r); self.g = Double(g); self.b = Double(b) }
        init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
        var luminance: Double { 0.299 * r + 0.587 * g + 0.114 * b }
        var chroma: Double { max(r, g, b) - min(r, g, b) }
        var hex: UInt32 { UInt32(r.rounded()) << 16 | UInt32(g.rounded()) << 8 | UInt32(b.rounded()) }
        var lighter: RGB { RGB(r: r + (255 - r) * 0.45, g: g + (255 - g) * 0.45, b: b + (255 - b) * 0.45) }
        func distance(to other: RGB) -> Double {
            let dr = r - other.r, dg = g - other.g, db = b - other.b
            return dr * dr + dg * dg + db * db
        }
    }

    /// k-means seeded from luminance quantiles (deterministic); clusters sorted by size.
    static func kMeans(_ points: [RGB], k: Int) -> [(color: RGB, share: Double)] {
        let sorted = points.sorted { $0.luminance < $1.luminance }
        let k = max(1, min(k, points.count))
        var centers = (0..<k).map { sorted[(2 * $0 + 1) * sorted.count / (2 * k)] }
        var counts = [Int](repeating: 0, count: k)
        for _ in 0..<8 {
            var sums = [RGB](repeating: RGB(r: 0, g: 0, b: 0), count: k)
            counts = [Int](repeating: 0, count: k)
            for point in points {
                let c = centers.indices.min { point.distance(to: centers[$0]) < point.distance(to: centers[$1]) }!
                sums[c].r += point.r; sums[c].g += point.g; sums[c].b += point.b
                counts[c] += 1
            }
            for c in centers.indices where counts[c] > 0 {
                let n = Double(counts[c])
                centers[c] = RGB(r: sums[c].r / n, g: sums[c].g / n, b: sums[c].b / n)
            }
        }
        return centers.indices.filter { counts[$0] > 0 }
            .map { (centers[$0], Double(counts[$0]) / Double(points.count)) }
            .sorted { $0.share > $1.share }
    }
}

private extension DogAnalyzer.Landmarks {
    nonisolated var bounds: CGRect? {
        let all = [nose].compactMap { $0 } + eyes + ears.flatMap { [$0.top, $0.bottom] } + [neck].compactMap { $0 } + frontPaws
        guard let minX = all.map(\.x).min(), let maxX = all.map(\.x).max(),
              let minY = all.map(\.y).min(), let maxY = all.map(\.y).max() else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(dx: -0.05, dy: -0.05)
    }
}

private extension CGPoint {
    nonisolated func distance(to other: CGPoint) -> Double { hypot(x - other.x, y - other.y) }
}

private extension DogLook {
    /// Photos are a bit dull next to pixel art: add a touch of saturation to every color.
    nonisolated var cute: DogLook {
        func pop(_ hex: UInt32) -> UInt32 {
            let c = DogAnalyzer.RGB(UInt8(hex >> 16 & 255), UInt8(hex >> 8 & 255), UInt8(hex & 255))
            func push(_ v: Double) -> Double { min(255, max(0, c.luminance + (v - c.luminance) * 1.25)) }
            return DogAnalyzer.RGB(r: push(c.r), g: push(c.g), b: push(c.b)).hex
        }
        var look = self
        look.coat = pop(coat); look.earColor = pop(earColor); look.muzzle = pop(muzzle)
        look.chest = pop(chest); look.paws = pop(paws); look.photoColors = photoColors.map(pop)
        look.collar = collar.map(pop)
        return look
    }
}
