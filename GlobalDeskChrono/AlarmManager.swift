//
//  AlarmManager.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Cascading alarm system for session openings and economic events.
//  Monitors time every second and triggers alarms at T-15m, T-5m, and T-0.
//

import Foundation
import Combine
import Observation
import UserNotifications

@Observable
final class AlarmManager {

    let sessionEngine: SessionEngine
    let audioEngine: AudioEngine
    let ntpSync: NTPClockSync

    private(set) var triggeredAlarms: Set<String> = []
    var alarmsEnabled: Bool = true

    private var timer: Timer?
    private var economicAlerts: [(event: EconomicEvent, leadTime: Int, fired: Bool)] = []

    init(sessionEngine: SessionEngine, audioEngine: AudioEngine, ntpSync: NTPClockSync) {
        self.sessionEngine = sessionEngine
        self.audioEngine = audioEngine
        self.ntpSync = ntpSync
    }

    func start(clocks: [DashboardClock]) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAlarms(clocks: clocks)
        }
    }

    func start(clocks: [DashboardClock], economicEvents: [EconomicEvent], filter: EventFilter) {
        stop()
        economicAlerts = economicEvents
            .filter { filter.impactLevels.contains($0.impact) }
            .filter { filter.currencies.isEmpty || filter.currencies.contains($0.currency) }
            .map { (event: $0, leadTime: filter.leadTimeMinutes, fired: false) }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAlarms(clocks: clocks)
            self?.checkEconomicAlerts()
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    func reset() {
        triggeredAlarms.removeAll()
        economicAlerts.indices.forEach { economicAlerts[$0].fired = false }
    }

    private func checkAlarms(clocks: [DashboardClock]) {
        guard alarmsEnabled else { return }
        let now = ntpSync.correctedNow
        for clock in clocks {
            guard clock.alarmsEnabled else { continue }
            checkSessionAlarms(for: clock.session, at: now)
            if let secondary = clock.secondarySession {
                checkSessionAlarms(for: secondary, at: now)
            }
        }
    }

    private func checkSessionAlarms(for session: ExchangeSession, at now: Date) {
        let tz = session.timeZone
        let comps = now.components(in: tz)
        let weekday = comps.weekday ?? 1
        if weekday == 1 || weekday == 7 { return }
        let currentSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        let firstOpen = session.firstOpen.startInSeconds

        // Pre-Alarm 1: 15 minutes before open
        let preAlarm1Time = firstOpen - 900
        if currentSeconds >= preAlarm1Time && currentSeconds <= preAlarm1Time + 2 {
            let key = "\(session.exchangeId.rawValue)_pre1_\(dayKey(from: now))"
            if !triggeredAlarms.contains(key) {
                triggeredAlarms.insert(key)
                triggerPreAlarm1(for: session)
            }
        }

        // Pre-Alarm 2: 5 minutes before open
        let preAlarm2Time = firstOpen - 300
        if currentSeconds >= preAlarm2Time && currentSeconds <= preAlarm2Time + 2 {
            let key = "\(session.exchangeId.rawValue)_pre2_\(dayKey(from: now))"
            if !triggeredAlarms.contains(key) {
                triggeredAlarms.insert(key)
                triggerPreAlarm2(for: session)
            }
        }

        // Opening Alarm: at open
        if currentSeconds >= firstOpen && currentSeconds <= firstOpen + 2 {
            let key = "\(session.exchangeId.rawValue)_open_\(dayKey(from: now))"
            if !triggeredAlarms.contains(key) {
                triggeredAlarms.insert(key)
                triggerOpeningAlarm(for: session)
            }
        }
    }

    private func dayKey(from date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func triggerPreAlarm1(for session: ExchangeSession) {
        audioEngine.playWarningClick()
        postNotification(title: "Pre-Alarm 1 — \(session.shortName) opens in 15 min",
            body: "Session opens at \(session.firstOpen.startInMinutes / 60):\(String(format: "%02d", session.firstOpen.startInMinutes % 60)) \(session.timeZoneIdentifier)",
            identifier: "pre1_\(session.exchangeId.rawValue)")
    }

    private func triggerPreAlarm2(for session: ExchangeSession) {
        audioEngine.playSonarPing()
        postNotification(title: "Pre-Alarm 2 — \(session.shortName) opens in 5 min",
            body: "Session opens at \(session.firstOpen.startInMinutes / 60):\(String(format: "%02d", session.firstOpen.startInMinutes % 60)) \(session.timeZoneIdentifier)",
            identifier: "pre2_\(session.exchangeId.rawValue)")
    }

    private func triggerOpeningAlarm(for session: ExchangeSession) {
        if session.exchangeId == .newYork {
            audioEngine.playNYSEBell()
        } else {
            audioEngine.playSonarPing()
        }
        postNotification(title: "Session Open — \(session.shortName)",
            body: "\(session.displayName) is now OPEN",
            identifier: "open_\(session.exchangeId.rawValue)")
    }

    func setEconomicEvents(_ events: [EconomicEvent], filter: EventFilter) {
        economicAlerts = events
            .filter { filter.impactLevels.contains($0.impact) }
            .filter { filter.currencies.isEmpty || filter.currencies.contains($0.currency) }
            .map { (event: $0, leadTime: filter.leadTimeMinutes, fired: false) }
    }

    private func checkEconomicAlerts() {
        guard alarmsEnabled else { return }
        let now = ntpSync.correctedNow
        for i in economicAlerts.indices {
            guard !economicAlerts[i].fired else { continue }
            let event = economicAlerts[i].event
            let leadTime = economicAlerts[i].leadTime
            let alertTime = event.eventTime.addingTimeInterval(-TimeInterval(leadTime * 60))
            if now >= alertTime && now < event.eventTime {
                economicAlerts[i].fired = true
                audioEngine.playEconomicAlert()
                postNotification(title: "High-Impact Event — \(event.title)",
                    body: "\(event.currency) - \(event.impact.displayName) - In \(leadTime) min",
                    identifier: "econ_\(event.id)")
            }
        }
    }

    private func postNotification(title: String, body: String, identifier: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .timeSensitive]) { _, _ in }
    }
}
