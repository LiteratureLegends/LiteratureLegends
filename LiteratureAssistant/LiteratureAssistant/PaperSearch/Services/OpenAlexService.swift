//
//  OpenAlexService.swift
//  LiteratureAssistant · PaperSearch
//
//  OpenAlex REST client (https://help.openalex.org/api/), checked against the docs on 2026-11-09:
//  • keyword:  GET /works?search=<q>
//  • DOI:      GET /works/doi:<doi>                  (singleton lookup, free)
//  • author:   GET /authors?search=<name>  → GET /works?filter=authorships.author.id:<A…>
//  • topic:    GET /topics?search=<q>      → GET /works?filter=topics.id:<T…>
//  • details:  GET /works/<W…>                       (singleton lookup, free)
//  The key goes in the `api_key` query parameter. Paging: per_page ≤ 100 and page × per_page ≤ 10,000.
//

import Foundation

nonisolated final class OpenAlexService: PaperSearchService {
    static let defaultBaseURL = URL(string: "https://api.openalex.org")!
    static let pageSize = 25
    /// OpenAlex basic paging stops at 10,000 results.
    static let maxResultWindow = 10_000

    /// Fields requested for list results. The abstract is left out to keep pages small;
    /// the detail screen fetches it with `getPaperDetails` (a free singleton call).
    static let listFields = [
        "id", "doi", "title", "display_name", "publication_date", "publication_year",
        "authorships", "primary_location", "cited_by_count",
    ]

    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let now: @Sendable () -> Date
    private let resolvedEntities = ResolvedEntityCache()

    init(
        apiKey: String,
        baseURL: URL = OpenAlexService.defaultBaseURL,
        session: URLSession = OpenAlexService.makeDefaultSession(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = baseURL
        self.session = session
        self.now = now
    }

    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    // MARK: PaperSearchService

    func searchPapers(query: String, mode: SearchMode, page: Int) async throws -> PaperSearchPage {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return .empty(page: page) }
        guard page >= 1 else { throw PaperSearchError.invalidQuery("Page numbers start at 1.") }
        guard !apiKey.isEmpty else { throw PaperSearchError.missingAPIKey }
        guard page * Self.pageSize <= Self.maxResultWindow else { return .empty(page: page) }

        switch SearchMode.effectiveMode(for: query, selected: mode) {
        case .keyword:
            return try await fetchWorksPage(url: worksSearchURL(query: query, page: page), page: page)

        case .doi:
            return try await searchByDOI(query, page: page)

        case .author:
            guard let author = try await resolveEntity(kind: .author, query: query) else {
                return .empty(page: page)
            }
            var result = try await fetchWorksPage(
                url: worksFilterURL(filter: "authorships.author.id:\(author.id)", page: page), page: page)
            result.matchedEntityName = author.name
            return result

        case .topic:
            guard let topic = try await resolveEntity(kind: .topic, query: query) else {
                return .empty(page: page)
            }
            var result = try await fetchWorksPage(
                url: worksFilterURL(filter: "topics.id:\(topic.id)", page: page), page: page)
            result.matchedEntityName = topic.name
            return result
        }
    }

    func getPaperDetails(id: String) async throws -> Paper {
        guard !apiKey.isEmpty else { throw PaperSearchError.missingAPIKey }
        let work: OpenAlexWork = try await get(workURL(id: id))
        guard let paper = OpenAlexMapper.paper(from: work, retrievedAt: now()) else {
            throw PaperSearchError.decoding
        }
        return paper
    }

    // MARK: URL construction (internal so tests can check it)

    func worksSearchURL(query: String, page: Int) -> URL {
        makeURL(path: "/works", items: [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "select", value: Self.listFields.joined(separator: ",")),
            URLQueryItem(name: "per_page", value: String(Self.pageSize)),
            URLQueryItem(name: "page", value: String(page)),
        ])
    }

    func worksFilterURL(filter: String, page: Int) -> URL {
        makeURL(path: "/works", items: [
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "sort", value: "cited_by_count:desc"),
            URLQueryItem(name: "select", value: Self.listFields.joined(separator: ",")),
            URLQueryItem(name: "per_page", value: String(Self.pageSize)),
            URLQueryItem(name: "page", value: String(page)),
        ])
    }

    func entityLookupURL(kind: EntityKind, query: String) -> URL {
        makeURL(path: "/\(kind.rawValue)", items: [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "select", value: "id,display_name"),
            URLQueryItem(name: "per_page", value: "1"),
        ])
    }

    /// `/works/doi:10.xxxx/yyy`. DOI slashes stay as path separators, which OpenAlex expects.
    func workURL(doi: String) -> URL {
        makeURL(path: "/works/doi:\(doi)", items: [])
    }

    func workURL(id: String) -> URL {
        makeURL(path: "/works/\(OpenAlexMapper.shortID(id))", items: [])
    }

    private func makeURL(path: String, items: [URLQueryItem]) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = (components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path) + path
        components.queryItems = items + [URLQueryItem(name: "api_key", value: apiKey)]
        // URLComponents leaves "+" alone in queries, but servers read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }

    // MARK: Mode helpers

    enum EntityKind: String, Sendable {
        case author = "authors"
        case topic = "topics"
    }

    private func searchByDOI(_ query: String, page: Int) async throws -> PaperSearchPage {
        guard let doi = SearchMode.normalizeDOI(query) else {
            throw PaperSearchError.invalidQuery("“\(query)” doesn't look like a DOI. DOIs start with “10.”, e.g. 10.7717/peerj.4375.")
        }
        // A DOI identifies at most one work, so there is never a second page.
        guard page == 1 else { return .empty(page: page) }
        do {
            let work: OpenAlexWork = try await get(workURL(doi: doi))
            guard let paper = OpenAlexMapper.paper(from: work, retrievedAt: now()) else { return .empty() }
            return PaperSearchPage(papers: [paper], totalCount: 1, page: 1, hasMore: false, matchedEntityName: nil)
        } catch PaperSearchError.notFound {
            return .empty()
        }
    }

    private func resolveEntity(kind: EntityKind, query: String) async throws -> ResolvedEntity? {
        let cacheKey = "\(kind.rawValue)|\(query.lowercased())"
        if let cached = await resolvedEntities.value(for: cacheKey) { return cached }
        let response: OpenAlexListResponse<OpenAlexEntity> = try await get(entityLookupURL(kind: kind, query: query))
        guard let first = response.results.first else { return nil }
        let entity = ResolvedEntity(id: OpenAlexMapper.shortID(first.id), name: first.displayName)
        await resolvedEntities.store(entity, for: cacheKey)
        return entity
    }

    private func fetchWorksPage(url: URL, page: Int) async throws -> PaperSearchPage {
        let response: OpenAlexListResponse<OpenAlexWork> = try await get(url)
        let retrievedAt = now()
        let papers = response.results.compactMap { OpenAlexMapper.paper(from: $0, retrievedAt: retrievedAt) }
        let total = response.meta?.count ?? papers.count
        let reachable = min(total, Self.maxResultWindow)
        let hasMore = !response.results.isEmpty && page * Self.pageSize < reachable
        return PaperSearchPage(papers: papers, totalCount: total, page: page, hasMore: hasMore, matchedEntityName: nil)
    }

    // MARK: Networking

    /// `@concurrent` keeps the request and JSON decoding off the caller's actor (usually the main actor).
    @concurrent
    private func get<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw PaperSearchError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw PaperSearchError.network }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(for: http, data: data)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PaperSearchError.decoding
        }
    }

    static func error(for response: HTTPURLResponse, data: Data) -> PaperSearchError {
        let body = try? JSONDecoder().decode(OpenAlexErrorBody.self, from: data)
        let reason = [body?.reason, body?.code, body?.error].compactMap { $0?.lowercased() }
        switch response.statusCode {
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return .rateLimited(retryAfterSeconds: retryAfter)
        case 401:
            return .invalidAPIKey
        case 403:
            return reason.contains { $0.contains("key_not_activated") } ? .keyNotActivated : .invalidAPIKey
        case 404:
            return .notFound
        case 408:
            return .timedOut
        case 400..<500:
            return .clientError(statusCode: response.statusCode)
        default:
            return .serverError(statusCode: response.statusCode)
        }
    }
}

nonisolated struct ResolvedEntity: Sendable, Equatable {
    var id: String
    var name: String?
}

/// Remembers which author/topic ID a query resolved to, so later pages skip the lookup.
private actor ResolvedEntityCache {
    private var storage: [String: ResolvedEntity] = [:]

    func value(for key: String) -> ResolvedEntity? { storage[key] }

    func store(_ entity: ResolvedEntity, for key: String) {
        if storage.count > 100 { storage.removeAll() }
        storage[key] = entity
    }
}
