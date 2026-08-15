//
//  GlobalDeskChronoApp.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Main application entry point. Contains AppModel (central state hub),
//  ContentView (primary view with toggle), and window/menu-bar configuration.
//
//  REGULATORY COMPLIANCE:
//  This application is strictly a time/session monitoring tool.
//  It does NOT provide investment advice, order execution, broker
//  connectivity, or live market prices.
//

import SwiftUI
import AppKit
import Combine

// MARK: - App Model

@Observable
final class AppModel {
    var clocks: [DashboardClock] = DashboardClock.defaultClocks
    var viewMode: ViewMode = .grid
    let themeManager = ThemeManager()
    var palette: ThemePalette { themeManager.palette }

    let ntpSync = NTPClockSync()
    var sessionEngine: SessionEngine!
    let audioEngine = AudioEngine()
    var alarmManager: AlarmManager!
    let economicCalendar = EconomicCalendarService()

    var currentTime: Date = Date()
    var isFloating: Bool = false
    var windowOpacity: Double = 1.0
    var showMenuBarExtra: Bool = true
    var dialArcsVisible: Set<ExchangeID> = Set(ExchangeID.allCases)
    var showEconomicCalendar: Bool = false

    private var clockTimer: Timer?
    private var hasInitialized = false

    func initialize() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        sessionEngine = SessionEngine(ntpSync: ntpSync)
        alarmManager = AlarmManager(sessionEngine: sessionEngine, audioEngine: audioEngine, ntpSync: ntpSync)
        alarmManager.requestNotificationPermission()
        ntpSync.startPeriodicSync()
        await ntpSync.sync()
        alarmManager.start(clocks: clocks)
        economicCalendar.startBackgroundWorker()
        await economicCalendar.fetchEvents()
        alarmManager.setEconomicEvents(economicCalendar.events, filter: economicCalendar.filter)
        startClockTimer()
    }

    private func startClockTimer() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = self.ntpSync.correctedNow
        }
    }

    func addClock(for exchangeId: ExchangeID) {
        let session = ExchangeSession.exchange(for: exchangeId)
        guard !clocks.contains(where: { $0.session.exchangeId == exchangeId }) else { return }
        clocks.append(DashboardClock(session: session))
        restartAlarmManager()
    }

    func removeClock(id: UUID) {
        clocks.removeAll { $0.id == id }
        restartAlarmManager()
    }

    func resetToDefaults() {
        clocks = DashboardClock.defaultClocks
        restartAlarmManager()
    }

    func restartAlarmManager() {
        alarmManager.start(clocks: clocks, economicEvents: economicCalendar.events, filter: economicCalendar.filter)
    }

    func setTheme(_ theme: AppTheme) { themeManager.current = theme }

    var activeClocks: [DashboardClock] { sessionEngine?.activeSessions(at: currentTime, from: clocks) ?? [] }
    var statusText: String { sessionEngine?.statusBanner(at: currentTime) ?? "-" }
    var isPowerHour: Bool { sessionEngine?.isPowerHour(at: currentTime) ?? false }
    var isNearEconomicEvent: Bool { economicCalendar.isNearHighImpactEvent(within: 5, at: currentTime) }
    var macroProgress: Double { sessionEngine?.macroDayProgress(at: currentTime) ?? 0 }
    var overlaps: [String] { sessionEngine?.activeOverlaps(at: currentTime) ?? [] }
}

// MARK: - Main App

@main
struct GlobalDeskChronoApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .frame(minWidth: 1000, minHeight: 650)
                .background(appModel.palette.background)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("View") {
                Picker("Layout", selection: Binding(get: { appModel.viewMode }, set: { appModel.viewMode = $0 })) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                }
                Divider()
                Toggle("Always on Top", isOn: Binding(get: { appModel.isFloating }, set: { appModel.isFloating = $0 }))
                    .keyboardShortcut("f", modifiers: [.command])
                Slider(value: Binding(get: { appModel.windowOpacity }, set: { appModel.windowOpacity = $0 }), in: 0.3...1.0) { Text("Window Opacity") }
                Divider()
                Toggle("Menu Bar Mode", isOn: Binding(get: { appModel.showMenuBarExtra }, set: { appModel.showMenuBarExtra = $0 }))
            }
            CommandMenu("Theme") {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button(theme.rawValue) { appModel.setTheme(theme) }
                }
            }
            CommandMenu("Clocks") {
                Button("Reset to Defaults") { appModel.resetToDefaults() }.keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                ForEach(ExchangeID.allCases, id: \.self) { exchangeId in
                    Button("Add \(exchangeId.displayName)") { appModel.addClock(for: exchangeId) }
                }
            }
        }
        Settings {
            SettingsView().environment(appModel)
        }
        MenuBarExtra("Global Desk Chrono", systemImage: menuBarIcon) {
            MenuBarContentView().environment(appModel)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        if appModel.activeClocks.isEmpty { return "clock.badge.xmark" }
        else if appModel.isPowerHour { return "clock.badge.exclamationmark.fill" }
        else { return "clock.badge.checkmark.fill" }
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack {
            appModel.palette.background.ignoresSafeArea()
            if appModel.themeManager.current == .digital {
                DigitalGridBackground(palette: appModel.palette).ignoresSafeArea().opacity(0.5)
            }
            if appModel.themeManager.current == .vintage {
                VintageTextureOverlay().ignoresSafeArea()
            }
            VStack(spacing: 0) {
                TopToolbarView()
                Divider().background(appModel.palette.gridLineColor)
                MacroDayTrackerView().padding(.horizontal).padding(.top, 8)
                StatusBannerView().padding(.horizontal).padding(.vertical, 4)
                ScrollView {
                    if appModel.viewMode == .grid { MultiClockGridView() }
                    else { ChronoDialView() }
                }
                if appModel.viewMode == .grid {
                    Divider().background(appModel.palette.gridLineColor)
                    SessionProgressPanel().padding()
                }
            }
        }
        .opacity(appModel.windowOpacity)
        .background(FloatingWindowAccessor(floating: appModel.isFloating))
        .sheet(isPresented: Binding(get: { appModel.showEconomicCalendar }, set: { appModel.showEconomicCalendar = $0 })) {
            EconomicCalendarView().environment(appModel)
        }
        .task { await appModel.initialize() }
    }
}

// MARK: - Top Toolbar

struct TopToolbarView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let palette = appModel.palette
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "globe.europe.africa.fill").font(.title3).foregroundStyle(palette.accentColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Global Desk Chrono").font(palette.titleFont).foregroundStyle(palette.primaryText)
                    Text("Powered by KruppCapital").font(.caption2).foregroundStyle(palette.secondaryText)
                }
            }
            Spacer()
            VStack(alignment: .center, spacing: 0) {
                Text(appModel.currentTime.timeString(in: .autoupdatingCurrent)).font(palette.monoFont.weight(.semibold)).foregroundStyle(palette.primaryText)
                Text("LOCAL (\(TimeZone.autoupdatingCurrent.abbreviation() ?? "UTC"))").font(.caption2).foregroundStyle(palette.secondaryText)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(appModel.ntpSync.lastSync != nil ? palette.successColor : palette.warningColor).frame(width: 8, height: 8)
                Text(appModel.ntpSync.lastSync != nil ? "NTP SYNCED" : "SYNCING…").font(.caption2).foregroundStyle(palette.secondaryText)
            }
            Divider().frame(height: 24)
            Picker("", selection: Binding(get: { appModel.viewMode }, set: { appModel.viewMode = $0 })) {
                ForEach(ViewMode.allCases, id: \.self) { mode in Image(systemName: mode == .grid ? "square.grid.2x2" : "clock.fill").tag(mode) }
            }.pickerStyle(.segmented).frame(width: 80)
            Menu {
                ForEach(AppTheme.allCases, id: \.self) { theme in Button(theme.rawValue) { appModel.setTheme(theme) } }
            } label: { Image(systemName: appModel.themeManager.current.icon) }.frame(width: 32)
            Button(action: { appModel.showEconomicCalendar.toggle() }) { Image(systemName: "calendar.badge.clock") }.buttonStyle(.borderless)
            Button(action: { openSettings() }) { Image(systemName: "gearshape") }.buttonStyle(.borderless)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - Floating Window

struct FloatingWindowAccessor: NSViewRepresentable {
    let floating: Bool
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = floating ? .floating : .normal
                window.collectionBehavior = floating ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.default]
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.level = floating ? .floating : .normal
                window.collectionBehavior = floating ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.default]
            }
        }
    }
}
