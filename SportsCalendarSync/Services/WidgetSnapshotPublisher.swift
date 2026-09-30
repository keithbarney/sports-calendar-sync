import Foundation
import SwiftData
import WidgetKit
import os
import UIKit

@MainActor
enum WidgetSnapshotPublisher {
    private static let logger = Logger(subsystem: "com.keithbarney.sportssync", category: "WidgetSnapshot")

    private static var artworkTask: Task<Void, Never>?

    static func publish(context: ModelContext) {
        var isReview = false
        #if DEBUG
        if ScreenshotFixtures.isEnabled {
            #if targetEnvironment(simulator)
            guard CommandLine.arguments.contains("-mock-widget-review") else { return }
            isReview = true
            #else
            return
            #endif
        }
        #endif
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.groupID) else {
            logger.error("Widget app group is unavailable")
            return
        }
        do {
            let snapshot = WidgetSnapshot.make(teams: try context.fetch(FetchDescriptor<TrackedTeam>()),
                                               games: try context.fetch(FetchDescriptor<TrackedGame>()))
            var filename = WidgetSnapshot.filename
            #if DEBUG && targetEnvironment(simulator)
            if isReview { filename = WidgetSnapshot.reviewFilename }
            #endif
            let url = directory.appendingPathComponent(filename)
            #if DEBUG
            if !isReview {
                let reviewURL = directory.appendingPathComponent(WidgetSnapshot.reviewFilename)
                if FileManager.default.fileExists(atPath: reviewURL.path) {
                    try FileManager.default.removeItem(at: reviewURL)
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
                }
            }
            #endif
            let data = try JSONEncoder().encode(snapshot)
            if (try? Data(contentsOf: url)) != data {
                try data.write(to: url, options: .atomic)
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
            }
            cacheArtwork(for: snapshot, review: isReview)
        } catch {
            logger.error("Could not publish widget fixtures: \(error.localizedDescription)")
        }
    }

    private static func cacheArtwork(for snapshot: WidgetSnapshot, review: Bool) {
        artworkTask?.cancel()
        let references = Set(snapshot.fixtures.flatMap { [$0.homeLogoURL, $0.awayLogoURL].compactMap { $0 } })
        artworkTask = Task {
            var changed = false
            for reference in references.sorted() {
                guard !Task.isCancelled else { break }
                guard let destination = WidgetSnapshot.crestURL(for: reference, review: review),
                      !FileManager.default.fileExists(atPath: destination.path) else { continue }
                do {
                    let image: UIImage?
                    if review {
                        #if DEBUG && targetEnvironment(simulator)
                        image = ScreenshotFixtures.artwork(for: reference)
                        #else
                        image = nil
                        #endif
                    } else {
                        guard let url = URL(string: reference), url.scheme == "https",
                              let host = url.host, host == "a.espncdn.com" || host.hasSuffix(".espncdn.com") else { continue }
                        let (data, response) = try await URLSession.shared.data(from: url)
                        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                              data.count < 2_000_000, !Task.isCancelled else { continue }
                        image = UIImage(data: data)
                    }
                    guard let image, image.size.width > 0, image.size.height > 0 else { continue }
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format)
                    let png = renderer.pngData { _ in
                        let scale = min(96 / image.size.width, 96 / image.size.height)
                        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        image.draw(in: CGRect(x: (96 - size.width) / 2, y: (96 - size.height) / 2, width: size.width, height: size.height))
                    }
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try png.write(to: destination, options: .atomic)
                    changed = true
                } catch {
                    if !Task.isCancelled { logger.debug("Widget crest unavailable: \(error.localizedDescription)") }
                }
            }
            if changed {
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
                NotificationCenter.default.post(name: WidgetSnapshot.artworkDidChange, object: nil)
            }
        }
    }

}
