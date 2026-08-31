import Foundation
import SeatLayer

struct DesiPassTicket: Decodable, Sendable {
    let ticketPrice: Double?
    let ticketType: String?
    let title: String?
    let remainingTicket: Int?
}

struct DesiPassVenue: Decodable, Sendable {
    let venueName: String?
    let venueAddress: String?
    let locationName: String?
}

struct DesiPassEvent: Decodable, Sendable {
    let id: String
    let slug: String
    let title: String
    let isSeatEvent: Bool
    let seatEngine: String?
    let seatEventKey: String?
    let currency: String?
    let cityName: String?
    let eventStartDate: String
    let eventStartTime: String
    let eventImageUrl: String?
    let venueDetail: DesiPassVenue?
    let eventTickets: [DesiPassTicket]?

    var minimumPrice: Double? {
        eventTickets?.compactMap(\.ticketPrice).min()
    }

    var location: String {
        for value in [venueDetail?.venueName, cityName, venueDetail?.locationName] {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return "Venue to be announced"
    }
}

struct DesiPassSeatLayerAccess: Sendable {
    let apiBase: String
    let provider: BuyerAccessTokenProvider
}

enum DesiPassClientError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case requestFailed(Int)
    case graphQL(String)
    case unavailable
    case noSeatLayerMap
    case invalidBuyerAccess

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Set DESIPASS_API_KEY in the app's Run environment."
        case .invalidEndpoint:
            return "The DesiPass endpoint is invalid."
        case .requestFailed(let status):
            return "DesiPass request failed (\(status))."
        case .graphQL(let message):
            return message
        case .unavailable:
            return "This event is no longer available."
        case .noSeatLayerMap:
            return "This event has no SeatLayer map configured."
        case .invalidBuyerAccess:
            return "The seat map could not be authorised."
        }
    }
}

actor DesiPassClient {
    static let shared = DesiPassClient()

    private static let defaultEndpoint = "https://desipass-dev.flutterscript.com/v1/graphql"
    private let endpoint: URL?
    private let apiKey: String

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        endpoint = URL(string: environment["DESIPASS_GRAPHQL_URL"] ?? Self.defaultEndpoint)
        apiKey = environment["DESIPASS_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func fetchDemoEvents() async throws -> [DesiPassEvent] {
        let data: EventListData = try await request(
            query: Self.eventListQuery,
            variables: [
                "filterType": "UPCOMING",
                "page": 1,
                "limit": 50,
                "upcomingFilterType": "ALL",
            ]
        )
        // The list projection is authoritative only for assigned seating. The
        // event detail validates the concrete SeatLayer engine before Book Now.
        let seatLayerEvents = (data.getUserEventList?.events ?? []).filter(\.isSeatEvent)
        let today = Self.apiDateFormatter.string(from: Date())
        let future = seatLayerEvents.filter { $0.eventStartDate >= today }
        return Array((future.count >= 2 ? future : seatLayerEvents).prefix(3))
    }

    func fetchEventDetail(eventId: String) async throws -> DesiPassEvent {
        let data: EventDetailData = try await request(
            query: Self.eventDetailQuery,
            variables: ["eventId": eventId]
        )
        guard let event = data.getUserEvent?.eventDetail else {
            throw DesiPassClientError.unavailable
        }
        guard event.seatEngine == "SEATLAYER",
              !(event.seatEventKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else {
            throw DesiPassClientError.noSeatLayerMap
        }
        return event
    }

    func makeSeatLayerAccess(eventId: String) async throws -> DesiPassSeatLayerAccess {
        let prefetched = try await mintBuyerAccess(eventId: eventId)
        let source = BuyerAccessSource(client: self, eventId: eventId, prefetched: prefetched)
        return DesiPassSeatLayerAccess(
            apiBase: prefetched.apiBase,
            provider: { _ in try await source.nextToken() }
        )
    }

    fileprivate func mintBuyerAccess(eventId: String) async throws -> BuyerAccess {
        let data: BuyerAccessData = try await request(
            query: Self.buyerAccessMutation,
            variables: ["eventId": eventId],
            origin: SeatLayer.mobileOrigin
        )
        guard let payload = data.createSeatLayerBuyerAccessSession,
              let token = payload.token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              let apiBase = payload.apiBase?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiBase.isEmpty,
              let expiresAt = Self.epochMilliseconds(from: payload.expiresAt) else {
            throw DesiPassClientError.invalidBuyerAccess
        }
        return BuyerAccess(token: token, expiresAt: expiresAt, apiBase: apiBase)
    }

    private func request<T: Decodable>(
        query: String,
        variables: [String: Any],
        origin: String? = nil
    ) async throws -> T {
        guard !apiKey.isEmpty else { throw DesiPassClientError.missingAPIKey }
        guard let endpoint else { throw DesiPassClientError.invalidEndpoint }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if let origin { request.setValue(origin, forHTTPHeaderField: "Origin") }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "variables": variables,
        ])

        let (body, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let envelope = try JSONDecoder().decode(GraphQLEnvelope<T>.self, from: body)
        if let message = envelope.errors?.first?.message, !message.isEmpty {
            throw DesiPassClientError.graphQL(message)
        }
        guard (200..<300).contains(status) else {
            throw DesiPassClientError.requestFailed(status)
        }
        guard let data = envelope.data else { throw DesiPassClientError.unavailable }
        return data
    }

    private static func epochMilliseconds(from value: String?) -> Double? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let regular = ISO8601DateFormatter()
        guard let date = fractional.date(from: value) ?? regular.date(from: value) else { return nil }
        return date.timeIntervalSince1970 * 1_000
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let eventListQuery = """
    query getUserEventList(
      $filterType: FilterType!
      $page: Int
      $limit: Int
      $upcomingFilterType: UpcomingFilterType!
    ) {
      getUserEventList(
        filterType: $filterType
        page: $page
        limit: $limit
        upcomingFilterType: $upcomingFilterType
      ) {
        events {
          id slug title isSeatEvent seatEngine cityName
          eventStartDate eventStartTime eventImageUrl
          venueDetail { venueName venueAddress locationName }
          eventTickets { ticketPrice ticketType title }
        }
      }
    }
    """

    private static let eventDetailQuery = """
    query getUserEvent($eventId: String!) {
      getUserEvent(eventId: $eventId) {
        eventDetail {
          id slug title isSeatEvent seatEngine seatEventKey currency cityName
          eventStartDate eventStartTime eventImageUrl
          venueDetail { venueName venueAddress locationName }
          eventTickets { ticketPrice ticketType title remainingTicket }
        }
      }
    }
    """

    private static let buyerAccessMutation = """
    mutation createSeatLayerBuyerAccessSession($eventId: String!) {
      createSeatLayerBuyerAccessSession(eventId: $eventId) {
        token expiresAt apiBase
      }
    }
    """
}

private actor BuyerAccessSource {
    let client: DesiPassClient
    let eventId: String
    var prefetched: BuyerAccess?

    init(client: DesiPassClient, eventId: String, prefetched: BuyerAccess) {
        self.client = client
        self.eventId = eventId
        self.prefetched = prefetched
    }

    func nextToken() async throws -> BuyerAccessToken {
        let access: BuyerAccess
        let refreshBoundary = Date().timeIntervalSince1970 * 1_000 + 30_000
        if let prefetched, prefetched.expiresAt > refreshBoundary {
            access = prefetched
        } else {
            access = try await client.mintBuyerAccess(eventId: eventId)
        }
        prefetched = nil
        return BuyerAccessToken(token: access.token, expiresAt: access.expiresAt)
    }
}

private struct BuyerAccess: Sendable {
    let token: String
    let expiresAt: Double
    let apiBase: String
}

private struct GraphQLErrorPayload: Decodable {
    let message: String?
}

private struct GraphQLEnvelope<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLErrorPayload]?
}

private struct EventListData: Decodable {
    struct EventList: Decodable { let events: [DesiPassEvent]? }
    let getUserEventList: EventList?
}

private struct EventDetailData: Decodable {
    struct EventDetail: Decodable { let eventDetail: DesiPassEvent? }
    let getUserEvent: EventDetail?
}

private struct BuyerAccessData: Decodable {
    struct Access: Decodable {
        let token: String?
        let expiresAt: String?
        let apiBase: String?
    }
    let createSeatLayerBuyerAccessSession: Access?
}
