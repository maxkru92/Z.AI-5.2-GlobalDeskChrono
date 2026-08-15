//
//  Models.swift
//  Global Desk Chrono — Powered by KruppCapital
//

import SwiftUI
import Foundation

enum ExchangeID: String, CaseIterable, Identifiable, Codable {
    case tokyo, hongKong, shanghai, seoul, sydney, singapore
    case frankfurt, paris, amsterdam, london
    case newYork, chicago, toronto, bombay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tokyo:      return "Tokyo (TSE/JPX)"
        case .hongKong:   return "Hong Kong (HKEX)"
        case .shanghai:   return "Shanghai (SSE)"
        case .seoul:      return "Seoul (KRX)"
        case .sydney:     return "Sydney (ASX)"
        case .singapore:  return "Singapore (SGX)"
        case .frankfurt:  return "Frankfurt (Xetra)"
        case .paris:      return "Paris (Euronext)"
        case .amsterdam:  return "Amsterdam (Euronext)"
        case .london:     return "London (LSE)"
        case .newYork:    return "New York (NYSE/NASDAQ)"
        case .chicago:    return "Chicago (CME)"
        case .toronto:    return "Toronto (TSX)"
        case .bombay:     return "Bombay (BSE/NSE)"
        }
    }

    var shortName: String {
        switch self {
        case .tokyo: return "TYO"; case .hongKong: return "HKG"; case .shanghai: return "SHA"
        case .seoul: return "SEL"; case .sydney: return "SYD"; case .singapore: return "SGP"
        case .frankfurt: return "FRA"; case .paris: return "PAR"; case .amsterdam: return "AMS"
        case .london: return "LON"; case .newYork: return "NYC"; case .chicago: return "CHI"
        case .toronto: return "TOR"; case .bombay: return "BOM"
        }
    }
}

struct TradingSegment: Codable, Identifiable, Hashable {
    let id: UUID
    let startHour: Int; let startMinute: Int
    let endHour: Int; let endMinute: Int

    init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.id = UUID(); self.startHour = startHour; self.startMinute = startMinute
        self.endHour = endHour; self.endMinute = endMinute
    }

    var startInMinutes: Int { startHour * 60 + startMinute }
    var endInMinutes: Int { endHour * 60 + endMinute }
    var startInSeconds: Int { startInMinutes * 60 }
    var endInSeconds: Int { endInMinutes * 60 }
    var durationInMinutes: Int { endInMinutes - startInMinutes }
}

struct LunchBreak: Codable, Hashable {
    let startHour: Int; let startMinute: Int
    let endHour: Int; let endMinute: Int
    var startInMinutes: Int { startHour * 60 + startMinute }
    var endInMinutes: Int { endHour * 60 + endMinute }
    var startInSeconds: Int { startInMinutes * 60 }
    var endInSeconds: Int { endInMinutes * 60 }
    var durationInMinutes: Int { endInMinutes - startInMinutes }
}

struct ExchangeSession: Codable, Identifiable, Hashable {
    let id: UUID
    let exchangeId: ExchangeID
    let displayName: String
    let shortName: String
    let timeZoneIdentifier: String
    let segments: [TradingSegment]
    let lunchBreak: LunchBreak?
    let hexColor: String
    let currency: String
    let region: String

    init(exchangeId: ExchangeID, displayName: String, shortName: String,
         timeZoneIdentifier: String, segments: [TradingSegment],
         lunchBreak: LunchBreak? = nil, hexColor: String, currency: String, region: String) {
        self.id = UUID(); self.exchangeId = exchangeId; self.displayName = displayName
        self.shortName = shortName; self.timeZoneIdentifier = timeZoneIdentifier
        self.segments = segments; self.lunchBreak = lunchBreak; self.hexColor = hexColor
        self.currency = currency; self.region = region
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
    var color: Color { Color(hex: hexColor) ?? .blue }
    var firstOpen: TradingSegment { segments.first! }
    var lastClose: TradingSegment { segments.last! }
    var sessionOpenInMinutes: Int { firstOpen.startInMinutes }
    var sessionCloseInMinutes: Int { lastClose.endInMinutes }
    var sessionOpenInSeconds: Int { firstOpen.startInSeconds }
    var sessionCloseInSeconds: Int { lastClose.endInSeconds }
    var totalTradingMinutes: Int { segments.reduce(0) { $0 + $1.durationInMinutes } }

    static let tokyo = ExchangeSession(exchangeId: .tokyo, displayName: "Tokyo (TSE/JPX)", shortName: "TYO",
        timeZoneIdentifier: "Asia/Tokyo",
        segments: [TradingSegment(startHour: 9, startMinute: 0, endHour: 11, endMinute: 30),
                   TradingSegment(startHour: 12, startMinute: 30, endHour: 15, endMinute: 30)],
        lunchBreak: LunchBreak(startHour: 11, startMinute: 30, endHour: 12, endMinute: 30),
        hexColor: "FF6B6B", currency: "JPY", region: "Asia-Pacific")

    static let hongKong = ExchangeSession(exchangeId: .hongKong, displayName: "Hong Kong (HKEX)", shortName: "HKG",
        timeZoneIdentifier: "Asia/Hong_Kong",
        segments: [TradingSegment(startHour: 9, startMinute: 30, endHour: 12, endMinute: 0),
                   TradingSegment(startHour: 13, startMinute: 0, endHour: 16, endMinute: 0)],
        lunchBreak: LunchBreak(startHour: 12, startMinute: 0, endHour: 13, endMinute: 0),
        hexColor: "FF9F43", currency: "HKD", region: "Asia-Pacific")

    static let shanghai = ExchangeSession(exchangeId: .shanghai, displayName: "Shanghai (SSE)", shortName: "SHA",
        timeZoneIdentifier: "Asia/Shanghai",
        segments: [TradingSegment(startHour: 9, startMinute: 30, endHour: 11, endMinute: 30),
                   TradingSegment(startHour: 13, startMinute: 0, endHour: 15, endMinute: 0)],
        lunchBreak: LunchBreak(startHour: 11, startMinute: 30, endHour: 13, endMinute: 0),
        hexColor: "EE5A24", currency: "CNY", region: "Asia-Pacific")

    static let seoul = ExchangeSession(exchangeId: .seoul, displayName: "Seoul (KRX)", shortName: "SEL",
        timeZoneIdentifier: "Asia/Seoul",
        segments: [TradingSegment(startHour: 9, startMinute: 0, endHour: 15, endMinute: 30)],
        hexColor: "D980FA", currency: "KRW", region: "Asia-Pacific")

    static let sydney = ExchangeSession(exchangeId: .sydney, displayName: "Sydney (ASX)", shortName: "SYD",
        timeZoneIdentifier: "Australia/Sydney",
        segments: [TradingSegment(startHour: 10, startMinute: 0, endHour: 16, endMinute: 0)],
        hexColor: "F368E0", currency: "AUD", region: "Asia-Pacific")

    static let singapore = ExchangeSession(exchangeId: .singapore, displayName: "Singapore (SGX)", shortName: "SGP",
        timeZoneIdentifier: "Asia/Singapore",
        segments: [TradingSegment(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)],
        hexColor: "FF9FF3", currency: "SGD", region: "Asia-Pacific")

    static let frankfurt = ExchangeSession(exchangeId: .frankfurt, displayName: "Frankfurt (Xetra)", shortName: "FRA",
        timeZoneIdentifier: "Europe/Berlin",
        segments: [TradingSegment(startHour: 9, startMinute: 0, endHour: 17, endMinute: 30)],
        hexColor: "54A0FF", currency: "EUR", region: "Europe")

    static let paris = ExchangeSession(exchangeId: .paris, displayName: "Paris (Euronext)", shortName: "PAR",
        timeZoneIdentifier: "Europe/Paris",
        segments: [TradingSegment(startHour: 9, startMinute: 0, endHour: 17, endMinute: 30)],
        hexColor: "341F97", currency: "EUR", region: "Europe")

    static let amsterdam = ExchangeSession(exchangeId: .amsterdam, displayName: "Amsterdam (Euronext)", shortName: "AMS",
        timeZoneIdentifier: "Europe/Amsterdam",
        segments: [TradingSegment(startHour: 9, startMinute: 0, endHour: 17, endMinute: 30)],
        hexColor: "006BA6", currency: "EUR", region: "Europe")

    static let london = ExchangeSession(exchangeId: .london, displayName: "London (LSE)", shortName: "LON",
        timeZoneIdentifier: "Europe/London",
        segments: [TradingSegment(startHour: 8, startMinute: 0, endHour: 16, endMinute: 30)],
        hexColor: "00D2D3", currency: "GBP", region: "Europe")

    static let newYork = ExchangeSession(exchangeId: .newYork, displayName: "New York (NYSE/NASDAQ)", shortName: "NYC",
        timeZoneIdentifier: "America/New_York",
        segments: [TradingSegment(startHour: 9, startMinute: 30, endHour: 16, endMinute: 0)],
        hexColor: "5F27CD", currency: "USD", region: "Americas")

    static let chicago = ExchangeSession(exchangeId: .chicago, displayName: "Chicago (CME)", shortName: "CHI",
        timeZoneIdentifier: "America/Chicago",
        segments: [TradingSegment(startHour: 8, startMinute: 30, endHour: 15, endMinute: 0)],
        hexColor: "222F3E", currency: "USD", region: "Americas")

    static let toronto = ExchangeSession(exchangeId: .toronto, displayName: "Toronto (TSX)", shortName: "TOR",
        timeZoneIdentifier: "America/Toronto",
        segments: [TradingSegment(startHour: 9, startMinute: 30, endHour: 16, endMinute: 0)],
        hexColor: "EA2027", currency: "CAD", region: "Americas")

    static let bombay = ExchangeSession(exchangeId: .bombay, displayName: "Bombay (BSE/NSE)", shortName: "BOM",
        timeZoneIdentifier: "Asia/Kolkata",
        segments: [TradingSegment(startHour: 9, startMinute: 15, endHour: 15, endMinute: 30)],
        hexColor: "FFC312", currency: "INR", region: "Asia-Pacific")

    static let allExchanges: [ExchangeSession] = [
        .tokyo, .hongKong, .shanghai, .seoul, .sydney, .singapore,
        .frankfurt, .paris, .amsterdam, .london, .newYork, .chicago, .toronto, .bombay
    ]

    static func exchange(for id: ExchangeID) -> ExchangeSession {
        switch id {
        case .tokyo: return .tokyo; case .hongKong: return .hongKong; case .shanghai: return .shanghai
        case .seoul: return .seoul; case .sydney: return .sydney; case .singapore: return .singapore
        case .frankfurt: return .frankfurt; case .paris: return .paris; case .amsterdam: return .amsterdam
        case .london: return .london; case .newYork: return .newYork; case .chicago: return .chicago
        case .toronto: return .toronto; case .bombay: return .bombay
        }
    }
}

struct DashboardClock: Codable, Identifiable, Hashable {
    let id: UUID
    var session: ExchangeSession
    var secondarySession: ExchangeSession?
    var label: String
    var isEnabled: Bool
    var alarmsEnabled: Bool
    var arcVisible: Bool

    init(session: ExchangeSession, secondarySession: ExchangeSession? = nil, label: String? = nil,
         isEnabled: Bool = true, alarmsEnabled: Bool = true, arcVisible: Bool = true) {
        self.id = UUID(); self.session = session; self.secondarySession = secondarySession
        self.label = label ?? session.displayName; self.isEnabled = isEnabled
        self.alarmsEnabled = alarmsEnabled; self.arcVisible = arcVisible
    }

    static let defaultClocks: [DashboardClock] = [
        DashboardClock(session: .tokyo, secondarySession: .hongKong, label: "ASIA Session"),
        DashboardClock(session: .frankfurt, label: "FRANKFURT Session"),
        DashboardClock(session: .london, label: "LONDON Session"),
        DashboardClock(session: .newYork, label: "NEW YORK Session")
    ]
}

enum SessionState: String, Codable {
    case closed, preMarket, open, lunchBreak, postMarket
    var label: String {
        switch self {
        case .closed: return "CLOSED"; case .preMarket: return "PRE-MARKET"; case .open: return "OPEN"
        case .lunchBreak: return "LUNCH BREAK"; case .postMarket: return "POST-MARKET"
        }
    }
    var isActive: Bool { self == .open || self == .lunchBreak }
}

enum AlarmPhase: Int, Codable, CaseIterable {
    case none = 0, preAlarm1 = 1, preAlarm2 = 2, opening = 3
    var label: String {
        switch self {
        case .none: return "-"; case .preAlarm1: return "Pre-Alarm 1 (T-15m)"
        case .preAlarm2: return "Pre-Alarm 2 (T-5m)"; case .opening: return "Opening Alarm"
        }
    }
    var leadTimeMinutes: Int {
        switch self { case .preAlarm1: return 15; case .preAlarm2: return 5; default: return 0 }
    }
}

enum ViewMode: String, CaseIterable, Codable {
    case grid = "Multi-Clock Grid"; case dial = "24-Hour Chrono Dial"
}

enum AppTheme: String, CaseIterable, Codable {
    case vintage = "Vintage Chrono"; case modern = "Modern Minimalist"; case digital = "Digital Matrix"
    var icon: String {
        switch self { case .vintage: return "clock.fill"; case .modern: return "square.grid.2x2"; case .digital: return "terminal.fill" }
    }
}

enum ImpactLevel: String, Codable, CaseIterable {
    case low = "low"; case medium = "medium"; case high = "high"
    var stars: Int { switch self { case .low: return 1; case .medium: return 2; case .high: return 3 } }
    var displayName: String { rawValue.capitalized }
    var color: Color {
        switch self { case .low: return Color(hex: "2ECC71") ?? .green; case .medium: return Color(hex: "F39C12") ?? .orange; case .high: return Color(hex: "E74C3C") ?? .red }
    }
}

struct EconomicEvent: Codable, Identifiable, Hashable {
    let id: String; let title: String; let currency: String; let country: String
    let impact: ImpactLevel; let eventTime: Date
    let forecast: String?; let previous: String?; let actual: String?; let sector: String?
}

struct EventFilter: Codable, Equatable {
    var currencies: Set<String>; var impactLevels: Set<ImpactLevel>; var sectors: Set<String>; var leadTimeMinutes: Int
    static let `default` = EventFilter(currencies: ["USD", "EUR", "GBP", "JPY"], impactLevels: [.high], sectors: [], leadTimeMinutes: 5)
}

extension Color {
    init?(hex: String) {
        var hexValue = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexValue.hasPrefix("#") { hexValue.removeFirst() }
        guard hexValue.count == 6 else { return nil }
        var intValue: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&intValue)
        self.init(red: Double((intValue >> 16) & 0xFF) / 255.0, green: Double((intValue >> 8) & 0xFF) / 255.0, blue: Double(intValue & 0xFF) / 255.0)
    }
}

extension Date {
    func components(in timeZone: TimeZone) -> DateComponents {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        return cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: self)
    }
    func timeString(in timeZone: TimeZone, format: String = "HH:mm:ss") -> String {
        let formatter = DateFormatter(); formatter.timeZone = timeZone; formatter.dateFormat = format
        return formatter.string(from: self)
    }
    var isWeekend: Bool {
        let weekday = self.components(in: .current).weekday ?? 1
        return weekday == 1 || weekday == 7
    }
}
