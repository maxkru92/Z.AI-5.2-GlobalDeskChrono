//
//  EconomicCalendarService.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Background worker that fetches high-impact economic news events
//  from a free financial API (forex-calendar.pro) and provides
//  filtering by currency, impact level, and sector.
//

import Foundation
import Observation

@Observable
final class EconomicCalendarService {

    private(set) var events: [EconomicEvent] = []
    private(set) var isLoading = false
    private(set) var lastFetch: Date?
    private(set) var fetchError: String?
    var filter: EventFilter = .default

    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 300

    private let apiURL = URL(string: "https://api.forex-calendar.pro/events/upcoming")!
    private let userAgent = "GlobalDeskChrono/1.0 (Powered by KruppCapital)"

    func startBackgroundWorker() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                await self.fetchEvents()
                try? await Task.sleep(for: .seconds(self.refreshInterval))
            }
        }
    }

    func stopBackgroundWorker() { refreshTask?.cancel(); refreshTask = nil }

    func fetchEvents() async {
        guard !isLoading else { return }
        isLoading = true; fetchError = nil
        do {
            let fetched = try await fetchFromAPI()
            self.events = fetched.sorted { $0.eventTime < $1.eventTime }
            self.lastFetch = Date(); self.fetchError = nil
        } catch {
            self.events = Self.mockEvents()
            self.lastFetch = Date()
            self.fetchError = "Live API unavailable — showing sample data: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func fetchFromAPI() async throws -> [EconomicEvent] {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EconomicCalendarError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let rawEvents = try decoder.decode([RawEconomicEvent].self, from: data)
            return rawEvents.compactMap { raw in
                let impact = ImpactLevel(rawValue: raw.impact?.lowercased() ?? "medium") ?? .medium
                return EconomicEvent(
                    id: raw.id ?? UUID().uuidString,
                    title: raw.title ?? "Unknown Event",
                    currency: raw.currency ?? "USD",
                    country: raw.country ?? "",
                    impact: impact,
                    eventTime: raw.date ?? Date(),
                    forecast: raw.forecast,
                    previous: raw.previous,
                    actual: raw.actual,
                    sector: raw.sector
                )
            }
        } catch {
            return try parseAlternativeFormat(data: data)
        }
    }

    private func parseAlternativeFormat(data: Data) throws -> [EconomicEvent] {
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw EconomicCalendarError.parseError
        }
        return jsonArray.compactMap { dict in
            let id = dict["id"] as? String ?? UUID().uuidString
            let title = dict["title"] as? String ?? dict["event"] as? String ?? "Unknown"
            let currency = dict["currency"] as? String ?? "USD"
            let country = dict["country"] as? String ?? ""
            let impactStr = (dict["impact"] as? String ?? "medium").lowercased()
            let impact = ImpactLevel(rawValue: impactStr) ?? .medium
            let dateStr = dict["date"] as? String ?? dict["time"] as? String ?? ""
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let eventTime = formatter.date(from: dateStr) ?? Date()
            return EconomicEvent(
                id: id, title: title, currency: currency, country: country,
                impact: impact, eventTime: eventTime,
                forecast: dict["forecast"] as? String,
                previous: dict["previous"] as? String,
                actual: dict["actual"] as? String,
                sector: dict["sector"] as? String
            )
        }
    }

    var filteredEvents: [EconomicEvent] {
        events.filter { event in
            if !filter.currencies.isEmpty && !filter.currencies.contains(event.currency) { return false }
            if !filter.impactLevels.isEmpty && !filter.impactLevels.contains(event.impact) { return false }
            if !filter.sectors.isEmpty {
                guard let sector = event.sector, filter.sectors.contains(sector) else { return false }
            }
            return true
        }
    }

    var upcomingHighImpactEvents: [EconomicEvent] {
        filteredEvents.filter { $0.impact == .high && $0.eventTime > Date() }.sorted { $0.eventTime < $1.eventTime }
    }

    var availableSectors: [String] { Array(Set(events.compactMap { $0.sector }.filter { !$0.isEmpty })).sorted() }
    var availableCurrencies: [String] { Array(Set(events.map { $0.currency })).sorted() }

    var nextEvent: EconomicEvent? {
        filteredEvents.filter { $0.eventTime > Date() }.sorted { $0.eventTime < $1.eventTime }.first
    }

    func isNearHighImpactEvent(within minutes: Int = 5, at date: Date) -> Bool {
        upcomingHighImpactEvents.contains { event in
            let timeUntil = event.eventTime.timeIntervalSince(date)
            return timeUntil > 0 && timeUntil <= TimeInterval(minutes * 60)
        }
    }

    enum EconomicCalendarError: LocalizedError {
        case invalidResponse; case parseError
        var errorDescription: String? {
            switch self { case .invalidResponse: return "Invalid API response"; case .parseError: return "Failed to parse economic calendar data" }
        }
    }
}

private struct RawEconomicEvent: Codable {
    let id: String?; let title: String?; let currency: String?; let country: String?
    let impact: String?; let date: Date?; let forecast: String?
    let previous: String?; let actual: String?; let sector: String?
}

extension EconomicCalendarService {
    static func mockEvents() -> [EconomicEvent] {
        let now = Date(); let cal = Calendar(identifier: .gregorian)
        return [
            EconomicEvent(id: "mock_1", title: "Non-Farm Payrolls", currency: "USD", country: "United States",
                impact: .high, eventTime: cal.date(byAdding: .hour, value: 2, to: now)!,
                forecast: "180K", previous: "175K", sector: "Employment"),
            EconomicEvent(id: "mock_2", title: "CPI m/m", currency: "USD", country: "United States",
                impact: .high, eventTime: cal.date(byAdding: .hour, value: 5, to: now)!,
                forecast: "0.3%", previous: "0.2%", sector: "Inflation"),
            EconomicEvent(id: "mock_3", title: "ECB Interest Rate Decision", currency: "EUR", country: "Eurozone",
                impact: .high, eventTime: cal.date(byAdding: .hour, value: 8, to: now)!,
                forecast: "4.25%", previous: "4.25%", sector: "Monetary Policy"),
            EconomicEvent(id: "mock_4", title: "GDP q/q", currency: "GBP", country: "United Kingdom",
                impact: .medium, eventTime: cal.date(byAdding: .hour, value: 12, to: now)!,
                forecast: "0.2%", previous: "0.1%", sector: "Growth"),
            EconomicEvent(id: "mock_5", title: "BoJ Policy Rate", currency: "JPY", country: "Japan",
                impact: .high, eventTime: cal.date(byAdding: .hour, value: 24, to: now)!,
                forecast: "0.10%", previous: "0.10%", sector: "Monetary Policy")
        ]
    }
}
