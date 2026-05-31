import Foundation
import CoreLocation

enum MediaFallbackStyle: String, Codable, Equatable {
    case archive
    case article
    case mystery
    case map
}

struct WikiMedia: Codable, Equatable {
    let thumbnailURL: URL?
    let imageURL: URL?
    let sourceURL: URL?
    let credit: String?
    let license: String
    let fallbackStyle: MediaFallbackStyle

    init(
        thumbnailURL: URL?,
        imageURL: URL?,
        sourceURL: URL?,
        credit: String? = "Wikipedia / Wikimedia Commons",
        license: String = "CC BY-SA",
        fallbackStyle: MediaFallbackStyle = .article
    ) {
        self.thumbnailURL = thumbnailURL
        self.imageURL = imageURL
        self.sourceURL = sourceURL
        self.credit = credit
        self.license = license
        self.fallbackStyle = fallbackStyle
    }

    var bestURL: URL? {
        imageURL ?? thumbnailURL
    }

    static func from(thumbnail: String?, image: String?, source: String?, fallbackStyle: MediaFallbackStyle = .article) -> WikiMedia? {
        let thumbnailURL = webURL(thumbnail)
        let imageURL = webURL(image)
        let sourceURL = webURL(source)
        guard thumbnailURL != nil || imageURL != nil || sourceURL != nil else { return nil }
        return WikiMedia(
            thumbnailURL: thumbnailURL,
            imageURL: imageURL,
            sourceURL: sourceURL,
            fallbackStyle: fallbackStyle
        )
    }

    private static func webURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value) else { return nil }
        let scheme = url.scheme?.lowercased()
        guard scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}

enum MediaLoadState: Equatable {
    case idle
    case loading
    case loaded(WikiMedia)
    case empty
    case failed(String)
}

enum ArticleVisualState: Equatable {
    case locked
    case clue
    case revealed
}

struct WikiArticle: Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String?
    let extract: String?
    let url: URL?
    let media: WikiMedia?

    init(
        id: Int = Int.random(in: 1...Int.max),
        title: String,
        description: String?,
        extract: String?,
        url: URL? = nil,
        media: WikiMedia? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.extract = extract
        self.url = url
        self.media = media
    }
}

struct WikiLink: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let label: String
}

struct NearbyArticle: Identifiable {
    let id: Int
    let title: String
    let description: String?
    let extract: String?
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double
    let media: WikiMedia?
}

struct WikipediaClient {
    func summary(title: String) async throws -> WikiArticle {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            throw APIError.invalidResponse
        }
        let summary = try await fetchSummary(url: url)
        return article(from: summary, fallbackTitle: title)
    }

    func links(title: String) async throws -> [WikiLink] {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let raw = "https://en.wikipedia.org/w/api.php?action=query&prop=links&titles=\(encoded)&pllimit=30&format=json&origin=*"
        let (data, _) = try await URLSession.shared.data(from: URL(string: raw)!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let query = json?["query"] as? [String: Any]
        let pages = query?["pages"] as? [String: Any]
        let page = pages?.values.first as? [String: Any]
        let links = page?["links"] as? [[String: Any]] ?? []
        return links.compactMap { item in
            guard let title = item["title"] as? String else { return nil }
            return WikiLink(title: title, label: title)
        }
    }

    func searchTitles(prefix: String, limit: Int = 6) async throws -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "prefixsearch"),
            URLQueryItem(name: "pssearch", value: trimmed),
            URLQueryItem(name: "psnamespace", value: "0"),
            URLQueryItem(name: "pslimit", value: "\(limit)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "origin", value: "*")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(PrefixSearchResponse.self, from: data)
        return decoded.query.prefixsearch.map(\.title)
    }

    func randomSummary() async throws -> WikiArticle {
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/random/summary") else {
            throw APIError.invalidResponse
        }
        let summary = try await fetchSummary(url: url)
        guard summary.type != "disambiguation" else { return try await randomSummary() }
        return article(from: summary, fallbackTitle: "Wikipedia")
    }

    func pickLinkRaceTargets() async throws -> LinkRaceTargets {
        var lastError: Error?
        for _ in 0..<6 {
            do {
                let start = try await randomSummary()
                guard start.extract?.isEmpty == false else { continue }
                let startLinks = try await links(title: start.title)
                guard startLinks.count >= 15 else { continue }
                let sample = Array(startLinks.shuffled().prefix(8))
                var frontier = Set<String>()
                for link in sample {
                    if let expanded = try? await links(title: link.title) {
                        expanded.forEach { candidate in
                            if candidate.title != start.title && !startLinks.contains(where: { $0.title == candidate.title }) {
                                frontier.insert(candidate.title)
                            }
                        }
                    }
                }
                for candidate in frontier.shuffled().prefix(8) {
                    let target = try await summary(title: candidate)
                    if target.extract?.isEmpty == false {
                        return LinkRaceTargets(start: start.title, target: target.title)
                    }
                }
            } catch {
                lastError = error
            }
        }
        throw lastError ?? APIError.invalidResponse
    }

    func nearby(latitude: Double, longitude: Double, radiusMeters: Int = 8_000, limit: Int = 12) async throws -> [NearbyArticle] {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "geosearch"),
            URLQueryItem(name: "gscoord", value: "\(latitude)|\(longitude)"),
            URLQueryItem(name: "gsradius", value: "\(min(radiusMeters, 10_000))"),
            URLQueryItem(name: "gslimit", value: "\(limit)"),
            URLQueryItem(name: "gsnamespace", value: "0"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "origin", value: "*")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(GeoSearchResponse.self, from: data)
        var articles: [NearbyArticle] = []
        for hit in decoded.query.geosearch {
            let articleSummary = try? await summary(title: hit.title)
            articles.append(
                NearbyArticle(
                    id: hit.pageid,
                    title: hit.title,
                    description: articleSummary?.description,
                    extract: articleSummary?.extract,
                    coordinate: CLLocationCoordinate2D(latitude: hit.lat, longitude: hit.lon),
                    distanceMeters: hit.dist,
                    media: articleSummary?.media
                )
            )
        }
        return articles
    }

    private func fetchSummary(url: URL) async throws -> RestSummary {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("WikiQuest/1.0 iOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(RestSummary.self, from: data)
    }

    private func article(from summary: RestSummary, fallbackTitle: String) -> WikiArticle {
        let pageURL = summary.contentUrls?.desktop?.page.flatMap(URL.init(string:))
        let media = WikiMedia.from(
            thumbnail: summary.thumbnail?.source,
            image: summary.originalImage?.source,
            source: pageURL?.absoluteString,
            fallbackStyle: .article
        )
        return WikiArticle(
            id: summary.pageid ?? Int.random(in: 1...Int.max),
            title: summary.title ?? fallbackTitle,
            description: summary.description,
            extract: summary.extract,
            url: pageURL,
            media: media
        )
    }
}

struct LinkRaceTargets: Equatable {
    let start: String
    let target: String
}

private struct PrefixSearchResponse: Decodable {
    let query: Query

    struct Query: Decodable {
        let prefixsearch: [Item]
    }

    struct Item: Decodable {
        let title: String
    }
}

private struct GeoSearchResponse: Decodable {
    let query: Query

    struct Query: Decodable {
        let geosearch: [Hit]
    }

    struct Hit: Decodable {
        let pageid: Int
        let title: String
        let lat: Double
        let lon: Double
        let dist: Double
    }
}

private struct RestSummary: Decodable {
    let type: String?
    let title: String?
    let pageid: Int?
    let description: String?
    let extract: String?
    let thumbnail: RestImage?
    let originalImage: RestImage?
    let contentUrls: RestContentURLs?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case pageid
        case description
        case extract
        case thumbnail
        case originalImage = "originalimage"
        case contentUrls = "content_urls"
    }
}

private struct RestImage: Decodable {
    let source: String?
}

private struct RestContentURLs: Decodable {
    let desktop: RestPageURL?
}

private struct RestPageURL: Decodable {
    let page: String?
}
