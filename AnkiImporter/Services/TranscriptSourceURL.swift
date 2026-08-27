import Foundation

enum TranscriptSourceURLError: LocalizedError, Equatable {
    case invalidURL
    case unsupportedHost
    case missingVideoIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid YouTube or TikTok video URL."
        case .unsupportedHost:
            return "Only YouTube and TikTok video URLs are supported. You can upload an authorized local file or paste a transcript instead."
        case .missingVideoIdentifier:
            return "The URL does not identify a video. Copy the full video URL and try again."
        }
    }
}

enum TranscriptSourceURL {
    static func validate(_ rawValue: String) throws -> VideoSource {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.lowercased() else {
            throw TranscriptSourceURLError.invalidURL
        }

        components.scheme = "https"
        components.fragment = nil

        if host == "youtu.be" || host == "www.youtu.be" {
            let identifier = components.path.split(separator: "/").first.map(String.init)
            guard let identifier, !identifier.isEmpty else {
                throw TranscriptSourceURLError.missingVideoIdentifier
            }
            return youtubeSource(identifier: identifier)
        }

        if host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" || host == "music.youtube.com" {
            let pathParts = components.path.split(separator: "/").map(String.init)
            let identifier: String?
            if components.path == "/watch" {
                identifier = components.queryItems?.first(where: { $0.name == "v" })?.value
            } else if let first = pathParts.first, ["shorts", "embed", "live"].contains(first) {
                identifier = pathParts.dropFirst().first
            } else {
                identifier = nil
            }
            guard let identifier, !identifier.isEmpty else {
                throw TranscriptSourceURLError.missingVideoIdentifier
            }
            return youtubeSource(identifier: identifier)
        }

        if host == "vm.tiktok.com" || host == "vt.tiktok.com" {
            guard let identifier = components.path.split(separator: "/").first.map(String.init),
                  !identifier.isEmpty else {
                throw TranscriptSourceURLError.missingVideoIdentifier
            }
            return VideoSource(
                canonicalURL: "https://\(host)/\(identifier)",
                platform: .tiktok,
                title: nil,
                durationSeconds: nil,
                primaryLanguage: nil
            )
        }

        if host == "tiktok.com" || host.hasSuffix(".tiktok.com") {
            let pathParts = components.path.split(separator: "/").map(String.init)
            guard let videoIndex = pathParts.firstIndex(of: "video"),
                  pathParts.indices.contains(videoIndex + 1),
                  !pathParts[videoIndex + 1].isEmpty else {
                throw TranscriptSourceURLError.missingVideoIdentifier
            }
            let identifier = pathParts[videoIndex + 1]
            let username = videoIndex > 0 ? pathParts[videoIndex - 1] : "@video"
            let canonical = "https://www.tiktok.com/\(username)/video/\(identifier)"
            return VideoSource(
                canonicalURL: canonical,
                platform: .tiktok,
                title: nil,
                durationSeconds: nil,
                primaryLanguage: nil
            )
        }

        throw TranscriptSourceURLError.unsupportedHost
    }

    private static func youtubeSource(identifier: String) -> VideoSource {
        VideoSource(
            canonicalURL: "https://www.youtube.com/watch?v=\(identifier)",
            platform: .youtube,
            title: nil,
            durationSeconds: nil,
            primaryLanguage: nil
        )
    }
}
