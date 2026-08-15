//
//  SessionEngine.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Core session calculation engine. DST handled automatically
//  via Foundation TimeZone (IANA identifiers).
//

import Foundation
import Observation

@Observable
final class SessionEngine {

    let ntpSync: NTPClockSync

    init(ntpSync: NTPClockSync) {
        self.ntpSync = ntpSync
    }

    var now: Date { ntpSync.correctedNow }
    var userTimeZone: TimeZone { TimeZone.autoupdatingCurrent }

    func sessionState(for session: ExchangeSession, at date: Date) -> SessionState {
        let tz = session.timeZone
        let comps = date.components(in: tz)
        let weekday = comps.weekday ?? 1
        if weekday == 1 || weekday == 7 { return .closed }
        let currentSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        for segment in session.segments {
            if currentSeconds >= segment.startInSeconds && currentSeconds < segment.endInSeconds { return .open }
        }
        if let lunch = session.lunchBreak {
            if currentSeconds >= lunch.startInSeconds && currentSeconds < lunch.endInSeconds { return .lunchBreak }
        }
        let firstOpen = session.firstOpen.startInSeconds
        let lastClose = session.lastClose.endInSeconds
        if currentSeconds < firstOpen {
            if currentSeconds >= firstOpen - 900 { return .preMarket }
            return .closed
        }
        if currentSeconds >= lastClose { return .postMarket }
        return .closed
    }

    func sessionState(for clock: DashboardClock, at date: Date) -> SessionState {
        let primary = sessionState(for: clock.session, at: date)
        if primary.isActive { return primary }
        if let secondary = clock.secondarySession {
            let secondaryState = sessionState(for: secondary, at: date)
            if secondaryState.isActive { return secondaryState }
        }
        return primary
    }

    func sessionProgress(for session: ExchangeSession, at date: Date) -> Double {
        let tz = session.timeZone
        let comps = date.components(in: tz)
        let weekday = comps.weekday ?? 1
        if weekday == 1 || weekday == 7 { return 0 }
        let currentSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        let firstOpen = session.firstOpen.startInSeconds
        let lastClose = session.lastClose.endInSeconds
        if currentSeconds < firstOpen || currentSeconds > lastClose { return 0 }
        let totalSpan = lastClose - firstOpen
        let elapsed = currentSeconds - firstOpen
        guard totalSpan > 0 else { return 0 }
        return min(1.0, max(0.0, Double(elapsed) / Double(totalSpan)))
    }

    func sessionProgress(for clock: DashboardClock, at date: Date) -> Double {
        let primary = sessionProgress(for: clock.session, at: date)
        if primary > 0 { return primary }
        if let secondary = clock.secondarySession { return sessionProgress(for: secondary, at: date) }
        return 0
    }

    func remainingTime(for session: ExchangeSession, at date: Date) -> TimeInterval {
        let tz = session.timeZone
        let comps = date.components(in: tz)
        let weekday = comps.weekday ?? 1
        if weekday == 1 || weekday == 7 { return 0 }
        let currentSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        let lastClose = session.lastClose.endInSeconds
        if currentSeconds >= lastClose { return 0 }
        let state = sessionState(for: session, at: date)
        guard state.isActive else { return 0 }
        return TimeInterval(lastClose - currentSeconds)
    }

    func timeUntilOpen(for session: ExchangeSession, at date: Date) -> TimeInterval {
        let tz = session.timeZone
        let comps = date.components(in: tz)
        let weekday = comps.weekday ?? 1
        if weekday == 1 || weekday == 7 { return .infinity }
        let currentSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        let firstOpen = session.firstOpen.startInSeconds
        if currentSeconds < firstOpen { return TimeInterval(firstOpen - currentSeconds) }
        return 0
    }

    func localTimeString(for session: ExchangeSession, at date: Date) -> String {
        date.timeString(in: session.timeZone, format: "HH:mm:ss")
    }

    func userLocalTimeString(at date: Date) -> String {
        date.timeString(in: userTimeZone, format: "HH:mm:ss")
    }

    func activeSessions(at date: Date, from clocks: [DashboardClock]) -> [DashboardClock] {
        clocks.filter { clock in sessionState(for: clock, at: date).isActive }
    }

    func macroDayProgress(at date: Date) -> Double {
        let comps = date.components(in: userTimeZone)
        let currentSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        return Double(currentSeconds) / 86400.0
    }

    func isPowerHour(at date: Date) -> Bool {
        let state = sessionState(for: .newYork, at: date)
        guard state == .open else { return false }
        let progress = sessionProgress(for: .newYork, at: date)
        return progress >= 0.94
    }

    func activeOverlaps(at date: Date) -> [String] {
        let states: [(String, SessionState)] = [
            ("ASIA", sessionState(for: .tokyo, at: date)),
            ("ASIA", sessionState(for: .hongKong, at: date)),
            ("FRANKFURT", sessionState(for: .frankfurt, at: date)),
            ("LONDON", sessionState(for: .london, at: date)),
            ("NEW YORK", sessionState(for: .newYork, at: date))
        ]
        let active = Array(Set(states.filter { $0.1.isActive }.map { $0.0 })).sorted()
        var overlaps: [String] = []
        if active.contains("FRANKFURT") && active.contains("NEW YORK") { overlaps.append("EU/US OVERLAP ACTIVE") }
        if active.contains("LONDON") && active.contains("NEW YORK") { overlaps.append("LONDON/NY OVERLAP ACTIVE") }
        if active.contains("FRANKFURT") && active.contains("LONDON") { overlaps.append("EUROPEAN SESSIONS ACTIVE") }
        if active.contains("ASIA") && active.contains("FRANKFURT") { overlaps.append("ASIA/EUROPE OVERLAP ACTIVE") }
        return overlaps
    }

    func statusBanner(at date: Date) -> String {
        let nyState = sessionState(for: .newYork, at: date)
        let londonState = sessionState(for: .london, at: date)
        let frankfurtState = sessionState(for: .frankfurt, at: date)
        let tokyoState = sessionState(for: .tokyo, at: date)
        let hkState = sessionState(for: .hongKong, at: date)
        let overlaps = activeOverlaps(at: date)
        if let first = overlaps.first { return first }
        if nyState == .preMarket { return "US PRE-MARKET OPEN" }
        if nyState == .open { return "US SESSION ACTIVE" }
        if londonState == .open && frankfurtState == .open { return "EUROPEAN SESSIONS ACTIVE" }
        if frankfurtState == .preMarket { return "FRANKFURT PRE-MARKET" }
        if londonState == .preMarket { return "LONDON PRE-MARKET" }
        if frankfurtState == .open { return "FRANKFURT SESSION ACTIVE" }
        if londonState == .open { return "LONDON SESSION ACTIVE" }
        if tokyoState == .open || hkState == .open { return "ASIA SESSION ACTIVE" }
        if tokyoState == .preMarket || hkState == .preMarket { return "ASIA PRE-MARKET" }
        if let next = nextOpeningSession(at: date) { return "ALL SESSIONS CLOSED / \(next.shortName) NEXT" }
        return "ALL SESSIONS CLOSED"
    }

    func nextOpeningSession(at date: Date) -> ExchangeSession? {
        let allSessions: [ExchangeSession] = [.tokyo, .hongKong, .frankfurt, .london, .newYork]
        var earliest: (session: ExchangeSession, time: TimeInterval)?
        for session in allSessions {
            let state = sessionState(for: session, at: date)
            if state.isActive { continue }
            let t = timeUntilOpen(for: session, at: date)
            if t > 0 && t != .infinity {
                if earliest == nil || t < earliest!.time { earliest = (session, t) }
            }
        }
        return earliest?.session
    }
}
