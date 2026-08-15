//
//  SettingsView.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Settings, Info/About, and Window configuration panel.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        TabView {
            GeneralSettingsTab().tabItem { Label("General", systemImage: "gearshape") }
            ThemeSettingsTab().tabItem { Label("Theme", systemImage: "paintpalette") }
            AlarmSettingsTab().tabItem { Label("Alarms", systemImage: "bell.fill") }
            NTPSettingsTab().tabItem { Label("NTP Sync", systemImage: "network") }
            AboutTab().tabItem { Label("About", systemImage: "info.circle") }
        }.frame(width: 560, height: 420).background(palette.background)
    }
}

struct GeneralSettingsTab: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        Form {
            Section("Window") {
                Toggle("Always on Top (Float)", isOn: Binding(get: { appModel.isFloating }, set: { appModel.isFloating = $0 }))
                HStack {
                    Text("Window Opacity")
                    Slider(value: Binding(get: { appModel.windowOpacity }, set: { appModel.windowOpacity = $0 }), in: 0.3...1.0, step: 0.05)
                    Text("\(Int(appModel.windowOpacity * 100))%").frame(width: 40).foregroundStyle(palette.secondaryText)
                }
                Toggle("Menu Bar Extra", isOn: Binding(get: { appModel.showMenuBarExtra }, set: { appModel.showMenuBarExtra = $0 }))
            }
            Section("Layout") {
                Picker("Default View", selection: Binding(get: { appModel.viewMode }, set: { appModel.viewMode = $0 })) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                }.pickerStyle(.segmented)
            }
            Section("Clocks") {
                Text("Active Clocks: \(appModel.clocks.count)").foregroundStyle(palette.secondaryText)
                ForEach(appModel.clocks) { clock in
                    HStack {
                        Circle().fill(clock.session.color).frame(width: 10, height: 10)
                        Text(clock.label)
                        Spacer()
                        Toggle("", isOn: Binding(get: { clock.alarmsEnabled }, set: { v in
                            if let idx = appModel.clocks.firstIndex(where: { $0.id == clock.id }) { appModel.clocks[idx].alarmsEnabled = v; appModel.restartAlarmManager() }
                        })).toggleStyle(.switch)
                    }
                }
                Button("Reset to Defaults") { appModel.resetToDefaults() }
            }
        }.formStyle(.grouped)
    }
}

struct ThemeSettingsTab: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        VStack(spacing: 20) {
            Text("Visual Theme").font(palette.titleFont).foregroundStyle(palette.primaryText)
            VStack(spacing: 12) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button { appModel.setTheme(theme) } label: {
                        HStack {
                            Image(systemName: theme.icon).font(.title2).frame(width: 30)
                            VStack(alignment: .leading) {
                                Text(theme.rawValue).font(palette.bodyFont.weight(.semibold))
                                Text(desc(theme)).font(.caption).foregroundStyle(palette.secondaryText)
                            }
                            Spacer()
                            if appModel.themeManager.current == theme { Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.successColor) }
                        }
                        .padding(12)
                        .background(appModel.themeManager.current == theme ? palette.accentColor.opacity(0.15) : palette.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(appModel.themeManager.current == theme ? palette.accentColor : palette.gridLineColor, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
        }.padding()
    }

    private func desc(_ t: AppTheme) -> String {
        switch t {
        case .vintage: return "Skeuomorphic mechanical watch faces with sweeping seconds, tourbillon animations, and patinaed luminescent indices"
        case .modern: return "Clean flat vector layout with sharp SF Pro Display typography, focus on data-density and negative space"
        case .digital: return "Cyberpunk/Bloomberg terminal inspired digital grids, neon monospace fonts, absolute geometric precision"
        }
    }
}

struct AlarmSettingsTab: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        Form {
            Section("Session Alarms") {
                Toggle("Enable All Alarms", isOn: Binding(get: { appModel.alarmManager.alarmsEnabled }, set: { appModel.alarmManager.alarmsEnabled = $0 }))
                Text("Cascading Alert Schedule:").font(palette.bodyFont.weight(.semibold)).foregroundStyle(palette.primaryText)
                VStack(alignment: .leading, spacing: 6) {
                    row("Pre-Alarm 1", "15 min before open", "Amber visual pulse + subtle warning click", palette.warningColor)
                    row("Pre-Alarm 2", "5 min before open", "Faster pulse + discrete sonar ping", palette.warningColor.opacity(0.8))
                    row("Opening Alarm", "At session open", "Sonar ping (or NYSE Bell for New York)", palette.successColor)
                }.padding(.leading, 8)
            }
            Section("NYSE Opening Bell") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Image(systemName: "bell.fill").foregroundStyle(palette.accentColor); Text("NYSE Bell Audio Asset").font(palette.bodyFont.weight(.semibold)) }
                    Text("The app loads 'nyse_bell.mp3' from the app bundle for the New York Session opening alarm. If the file is not present, a synthetic resonant metallic bell is generated automatically.").font(.caption).foregroundStyle(palette.secondaryText)
                    Button("Test NYSE Bell") { appModel.audioEngine.playNYSEBell() }.buttonStyle(.bordered)
                    Button("Test Sonar Ping") { appModel.audioEngine.playSonarPing() }.buttonStyle(.bordered)
                    Button("Test Warning Click") { appModel.audioEngine.playWarningClick() }.buttonStyle(.bordered)
                    Button("Test Economic Alert") { appModel.audioEngine.playEconomicAlert() }.buttonStyle(.bordered)
                }
            }
            Section("Economic Event Alerts") {
                Text("Alert lead time: \(appModel.economicCalendar.filter.leadTimeMinutes) min before event").foregroundStyle(palette.secondaryText)
                Button("Open Economic Calendar") { appModel.showEconomicCalendar = true }
            }
        }.formStyle(.grouped)
    }

    private func row(_ phase: String, _ time: String, _ desc: String, _ color: Color) -> some View {
        HStack(alignment: .top) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack { Text(phase).font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(palette.primaryText); Text("- \(time)").font(.caption2).foregroundStyle(palette.secondaryText) }
                Text(desc).font(.caption2).foregroundStyle(palette.secondaryText)
            }
        }
    }
}

struct NTPSettingsTab: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        Form {
            Section("NTP Clock Synchronization") {
                info("Status", appModel.ntpSync.isSyncing ? "Syncing…" : (appModel.ntpSync.lastSync != nil ? "Synced" : "Not synced"))
                info("Clock Offset", String(format: "%.3f ms", appModel.ntpSync.offset * 1000))
                info("Round-Trip Delay", String(format: "%.3f ms", appModel.ntpSync.roundTripDelay * 1000))
                info("Last Sync", appModel.ntpSync.lastSync?.formatted(date: .omitted, time: .standard) ?? "-")
                info("Total Syncs", "\(appModel.ntpSync.syncCount)")
                if let e = appModel.ntpSync.syncError { info("Error", e) }
                Button("Sync Now") { Task { await appModel.ntpSync.sync() } }.buttonStyle(.borderedProminent).disabled(appModel.ntpSync.isSyncing)
            }
            Section("NTP Servers") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configured NTP servers (queried in order):").font(.caption).foregroundStyle(palette.secondaryText)
                    Text("- pool.ntp.org").font(palette.monoFont.caption())
                    Text("- time.apple.com").font(palette.monoFont.caption())
                    Text("- time.cloudflare.com").font(palette.monoFont.caption())
                    Text("Resync interval: every 5 minutes").font(.caption2).foregroundStyle(palette.secondaryText)
                }
            }
            Section("User Timezone Anchor") {
                info("Detected Timezone", TimeZone.autoupdatingCurrent.identifier)
                info("Abbreviation", TimeZone.autoupdatingCurrent.abbreviation() ?? "-")
                info("UTC Offset", String(format: "%+.1f hours", Double(TimeZone.autoupdatingCurrent.secondsFromGMT()) / 3600.0))
                info("DST Active", TimeZone.autoupdatingCurrent.isDaylightSavingTime() ? "Yes" : "No")
            }
        }.formStyle(.grouped)
    }

    private func info(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(palette.secondaryText); Spacer(); Text(value).font(palette.monoFont.caption()).foregroundStyle(palette.primaryText) }
    }
}

struct AboutTab: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(palette.accentColor.opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: "globe.europe.africa.fill").font(.system(size: 36)).foregroundStyle(palette.accentColor)
            }
            VStack(spacing: 6) {
                Text("Global Desk Chrono").font(palette.titleFont.weight(.bold)).foregroundStyle(palette.primaryText)
                Text("Version 1.0.0").font(.caption).foregroundStyle(palette.secondaryText)
                Text("Powered by KruppCapital").font(palette.bodyFont.weight(.semibold)).foregroundStyle(palette.accentColor).padding(.top, 8)
            }
            Divider().frame(width: 280)
            VStack(spacing: 6) {
                Text("REGULATORY COMPLIANCE").font(palette.monoFont.caption().weight(.bold)).foregroundStyle(palette.secondaryText).tracking(1)
                Text("This application is strictly a time/session monitoring tool. It does NOT provide investment advice, order execution, broker connectivity, or live market prices.")
                    .font(.caption).foregroundStyle(palette.secondaryText).multilineTextAlignment(.center).frame(maxWidth: 360)
            }
            Divider().frame(width: 280)
            VStack(alignment: .leading, spacing: 4) {
                feat("NTP-synchronized clocks"); feat("Daylight Saving Time aware")
                feat("Cascading session alarms (T-15m / T-5m / T-0)")
                feat("NYSE Opening Bell (with synthetic fallback)")
                feat("Economic calendar with high-impact event alerts")
                feat("24-hour chrono dial with session arcs")
                feat("Three institutional visual themes")
                feat("Menu bar extra & floating window support")
            }.padding(.horizontal, 40)
            Spacer()
            Text("© 2024–2026 KruppCapital. All rights reserved.").font(.caption2).foregroundStyle(palette.secondaryText)
            Spacer()
        }.padding()
    }

    private func feat(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.successColor).font(.caption)
            Text(text).font(.caption).foregroundStyle(palette.secondaryText)
        }
    }
}
