//
//  StatusPanelView.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Institutional Status Workflow & Progress Trackers.
//

import SwiftUI

// MARK: - Status Banner

struct StatusBannerView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        HStack {
            Circle().fill(bannerColor).frame(width: 10, height: 10)
                .glow(color: bannerColor, radius: 6, opacity: 0.6)
                .scaleEffect(appModel.activeClocks.isEmpty ? 1.0 : 1.1)
                .animation(appModel.activeClocks.isEmpty ? .none : .easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: appModel.activeClocks.isEmpty)
            Text(appModel.statusText).font(palette.monoFont.weight(.bold)).foregroundStyle(bannerColor).tracking(1)
            Spacer()
            HStack(spacing: 8) {
                ForEach(appModel.overlaps, id: \.self) { overlap in
                    Text(overlap).font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(palette.warningColor)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(palette.warningColor.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            if appModel.isPowerHour {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").foregroundStyle(palette.dangerColor)
                    Text("POWER HOUR").font(palette.monoFont.caption().weight(.bold)).foregroundStyle(palette.dangerColor)
                }.padding(.horizontal, 8).padding(.vertical, 3).background(palette.dangerColor.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
                .pulsingBorder(color: palette.dangerColor, isActive: true, speed: 0.6)
            }
            if appModel.isNearEconomicEvent {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(palette.warningColor)
                    Text("HIGH-IMPACT EVENT IMMINENT").font(palette.monoFont.caption().weight(.bold)).foregroundStyle(palette.warningColor)
                }.padding(.horizontal, 8).padding(.vertical, 3).background(palette.warningColor.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
                .pulsingBorder(color: palette.warningColor, isActive: true, speed: 0.8)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(palette.surfaceBackground.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.gridLineColor, lineWidth: 1))
    }

    private var bannerColor: Color {
        if appModel.isPowerHour { return palette.dangerColor }
        if appModel.isNearEconomicEvent { return palette.warningColor }
        if !appModel.activeClocks.isEmpty { return palette.successColor }
        return palette.secondaryText
    }
}

// MARK: - Macro Day Tracker

struct MacroDayTrackerView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("GLOBAL MACRO DAY").font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(palette.secondaryText).tracking(1)
                Spacer()
                Text("\(Int(appModel.macroProgress * 100))%").font(palette.monoFont.caption()).foregroundStyle(palette.secondaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(palette.gridLineColor).frame(height: 24)
                    HStack(spacing: 0) {
                        ForEach(sessionZones, id: \.id) { zone in
                            zone.color.opacity(zone.isActive ? 0.3 : 0.12).frame(width: geo.size.width * zone.widthFraction)
                        }
                    }.frame(height: 24).clipShape(RoundedRectangle(cornerRadius: 4))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [palette.accentColor.opacity(0.4), palette.accentColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * appModel.macroProgress, height: 24)
                    Rectangle().fill(palette.primaryText).frame(width: 2, height: 32)
                        .offset(x: geo.size.width * appModel.macroProgress - 1).glow(color: palette.accentColor, radius: 6, opacity: 0.8)
                    HStack {
                        Text("ASIA").font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText)
                        Spacer()
                        Text("EU").font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText)
                        Spacer()
                        Text("US").font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText)
                    }.padding(.horizontal, 8).frame(height: 24)
                }
            }.frame(height: 32)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(palette.surfaceBackground.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
    }

    private struct SessionZone: Identifiable { let id = UUID(); let label: String; let startFraction: Double; let endFraction: Double; let color: Color; var widthFraction: Double { endFraction - startFraction }; let isActive: Bool }

    private var sessionZones: [SessionZone] {
        let now = appModel.currentTime; let userTZ = TimeZone.autoupdatingCurrent
        func frac(_ s: ExchangeSession) -> (start: Double, width: Double, active: Bool) {
            let cal = Calendar(identifier: .gregorian); var sCal = cal; sCal.timeZone = s.timeZone
            let nc = sCal.dateComponents([.year, .month, .day], from: now)
            var sc = nc; sc.hour = s.firstOpen.startHour; sc.minute = s.firstOpen.startMinute
            var ec = nc; ec.hour = s.lastClose.endHour; ec.minute = s.lastClose.endMinute
            guard let sd = sCal.date(from: sc), let ed = sCal.date(from: ec) else { return (0, 0, false) }
            var uCal = cal; uCal.timeZone = userTZ
            let su = uCal.dateComponents([.hour, .minute], from: sd)
            let eu = uCal.dateComponents([.hour, .minute], from: ed)
            let sf = (Double(su.hour ?? 0) + Double(su.minute ?? 0) / 60.0) / 24.0
            var ef = (Double(eu.hour ?? 0) + Double(eu.minute ?? 0) / 60.0) / 24.0
            if ef < sf { ef += 1.0 }
            return (sf, ef - sf, appModel.sessionEngine.sessionState(for: s, at: now).isActive)
        }
        let asia = frac(.tokyo); let fra = frac(.frankfurt); let lon = frac(.london); let ny = frac(.newYork)
        return [
            SessionZone(label: "ASIA", startFraction: asia.start, endFraction: asia.start + asia.width, color: Color(hex: "FF6B6B") ?? .red, isActive: asia.active),
            SessionZone(label: "EU", startFraction: fra.start, endFraction: fra.start + fra.width, color: Color(hex: "54A0FF") ?? .blue, isActive: fra.active || lon.active),
            SessionZone(label: "US", startFraction: ny.start, endFraction: ny.start + ny.width, color: Color(hex: "5F27CD") ?? .purple, isActive: ny.active)
        ]
    }
}

// MARK: - Session Progress Panel

struct SessionProgressPanel: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SESSION PROGRESS").font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(palette.secondaryText).tracking(1)
                Spacer()
                Text("\(appModel.activeClocks.count) ACTIVE").font(palette.monoFont.caption()).foregroundStyle(appModel.activeClocks.isEmpty ? palette.secondaryText : palette.successColor)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appModel.clocks) { clock in SessionProgressSlider(clock: clock).frame(width: 180) }
                }.padding(.vertical, 4)
            }
        }
    }
}

struct SessionProgressSlider: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    let clock: DashboardClock

    private var state: SessionState { appModel.sessionEngine.sessionState(for: clock, at: appModel.currentTime) }
    private var progress: Double { appModel.sessionEngine.sessionProgress(for: clock, at: appModel.currentTime) }
    private var isPowerHour: Bool { clock.session.exchangeId == .newYork && appModel.isPowerHour }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(clock.session.shortName).font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(state.isActive ? clock.session.color : palette.secondaryText)
                Spacer()
                Text(state.label).font(palette.monoFont.caption2()).foregroundStyle(state.isActive ? palette.successColor : palette.secondaryText.opacity(0.5))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(state.isActive ? palette.gridLineColor : palette.gridLineColor.opacity(0.3)).frame(height: 8)
                    if state.isActive {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [clock.session.color.opacity(0.6), clock.session.color], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 8).animation(.easeInOut(duration: 0.5), value: progress)
                            .glow(color: clock.session.color, radius: 4, opacity: 0.3)
                    }
                    if isPowerHour {
                        RoundedRectangle(cornerRadius: 3).stroke(palette.dangerColor, lineWidth: 1).frame(height: 8).pulsingBorder(color: palette.dangerColor, isActive: true, speed: 0.8)
                    }
                }
            }.frame(height: 8)
            HStack {
                if state.isActive {
                    Text("\(Int(progress * 100))%").font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText)
                    Spacer()
                    let remaining = appModel.sessionEngine.remainingTime(for: clock.session, at: appModel.currentTime)
                    if remaining > 0 { Text(fmt(remaining)).font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText) }
                } else if state == .preMarket {
                    let remaining = appModel.sessionEngine.timeUntilOpen(for: clock.session, at: appModel.currentTime)
                    if remaining > 0 && remaining != .infinity { Text("Opens in \(fmt(remaining))").font(palette.monoFont.caption2()).foregroundStyle(palette.warningColor) }
                    else { Spacer() }
                } else { Text("-").font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText.opacity(0.5)); Spacer() }
            }
        }
        .padding(10).background(palette.cardBackground.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(state.isActive ? clock.session.color.opacity(0.3) : Color.clear, lineWidth: 1))
    }

    private func fmt(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }; return "\(m)m"
    }
}

// MARK: - Menu Bar Content

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Global Desk Chrono").font(palette.titleFont)
                Spacer()
                Text("Powered by KruppCapital").font(.caption2).foregroundStyle(palette.secondaryText)
            }
            Divider()
            HStack {
                Text("LOCAL TIME").font(palette.monoFont.caption()).foregroundStyle(palette.secondaryText)
                Spacer()
                Text(appModel.currentTime.timeString(in: .autoupdatingCurrent)).font(palette.monoFont.weight(.semibold)).foregroundStyle(palette.primaryText)
            }
            Divider()
            Text(appModel.statusText).font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(palette.accentColor)
            Divider()
            if !appModel.activeClocks.isEmpty {
                Text("ACTIVE SESSIONS").font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText)
                ForEach(appModel.activeClocks) { clock in
                    HStack {
                        Circle().fill(clock.session.color).frame(width: 8, height: 8)
                        Text(clock.session.shortName).font(palette.monoFont.caption())
                        Spacer()
                        let p = appModel.sessionEngine.sessionProgress(for: clock, at: appModel.currentTime)
                        Text("\(Int(p * 100))%").font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText)
                    }
                }
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }.padding().frame(width: 280)
    }
}
