//
//  MultiClockGridView.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Multi-Clock Grid View with dynamic add (+) and remove (-) buttons.
//  Default: ASIA, FRANKFURT, LONDON, NEW YORK (4 clocks).
//

import SwiftUI

struct MultiClockGridView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    @State private var showingAddSheet = false
    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(appModel.clocks) { clock in
                ClockCardView(clock: clock)
                    .contextMenu {
                        Button("Remove Clock", role: .destructive) { appModel.removeClock(id: clock.id) }
                        Divider()
                        Toggle("Alarms Enabled", isOn: Binding(get: { clock.alarmsEnabled }, set: { newValue in
                            if let idx = appModel.clocks.firstIndex(where: { $0.id == clock.id }) {
                                appModel.clocks[idx].alarmsEnabled = newValue; appModel.restartAlarmManager()
                            }
                        }))
                        Toggle("Dial Arc Visible", isOn: Binding(get: { clock.arcVisible }, set: { newValue in
                            if let idx = appModel.clocks.firstIndex(where: { $0.id == clock.id }) { appModel.clocks[idx].arcVisible = newValue }
                        }))
                    }
            }
            AddClockButton { showingAddSheet = true }
        }
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            AddClockSheet().environment(appModel)
        }
    }
}

struct ClockCardView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    let clock: DashboardClock

    private var sessionState: SessionState { appModel.sessionEngine.sessionState(for: clock, at: appModel.currentTime) }
    private var progress: Double { appModel.sessionEngine.sessionProgress(for: clock, at: appModel.currentTime) }
    private var isPowerHour: Bool { clock.session.exchangeId == .newYork && appModel.isPowerHour }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clock.label).font(palette.titleFont).foregroundStyle(palette.primaryText)
                    Text(clock.session.displayName).font(.caption).foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button(action: { appModel.removeClock(id: clock.id) }) {
                    Image(systemName: "minus.circle.fill").font(.title3).foregroundStyle(palette.dangerColor.opacity(0.7))
                }.buttonStyle(.borderless).help("Remove this clock")
            }
            Divider().background(palette.gridLineColor)
            VStack(spacing: 4) {
                Text(appModel.sessionEngine.localTimeString(for: clock.session, at: appModel.currentTime))
                    .font(palette.largeFont)
                    .foregroundStyle(sessionState.isActive ? clock.session.color : palette.secondaryText)
                    .glow(color: clock.session.color, radius: sessionState.isActive ? 10 : 0, opacity: sessionState.isActive ? 0.4 : 0)
                Text("\(clock.session.shortName) - \(clock.session.timeZoneIdentifier)")
                    .font(palette.monoFont.caption()).foregroundStyle(palette.secondaryText)
            }
            if let secondary = clock.secondarySession {
                VStack(spacing: 2) {
                    Divider().background(palette.gridLineColor)
                    HStack {
                        Text(secondary.shortName).font(palette.monoFont.caption()).foregroundStyle(palette.secondaryText)
                        Spacer()
                        Text(appModel.sessionEngine.localTimeString(for: secondary, at: appModel.currentTime))
                            .font(palette.monoFont.caption())
                            .foregroundStyle(appModel.sessionEngine.sessionState(for: secondary, at: appModel.currentTime).isActive ? secondary.color : palette.secondaryText)
                    }
                }
            }
            HStack {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(sessionState.label).font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(statusColor)
                Spacer()
                if sessionState.isActive {
                    Text("\(Int(progress * 100))%").font(palette.monoFont.caption()).foregroundStyle(palette.secondaryText)
                } else if sessionState == .preMarket {
                    let remaining = appModel.sessionEngine.timeUntilOpen(for: clock.session, at: appModel.currentTime)
                    if remaining > 0 && remaining != .infinity {
                        Text("Opens in \(formatDuration(remaining))").font(palette.monoFont.caption()).foregroundStyle(palette.warningColor)
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(palette.gridLineColor).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(sessionState.isActive ? clock.session.color : palette.gridLineColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }.frame(height: 6)
        }
        .padding(16)
        .themedCard(palette: palette, isActive: sessionState.isActive)
        .pulsingBorder(color: palette.dangerColor, isActive: isPowerHour, speed: 0.8)
    }

    private var statusColor: Color {
        switch sessionState {
        case .open: return palette.successColor; case .preMarket: return palette.warningColor
        case .lunchBreak: return palette.warningColor.opacity(0.7)
        case .postMarket: return palette.secondaryText; case .closed: return palette.secondaryText.opacity(0.5)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600; let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

struct AddClockButton: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill").font(.system(size: 36)).foregroundStyle(palette.accentColor.opacity(0.6))
                Text("Add Exchange Clock").font(palette.bodyFont).foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .background(palette.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.gridLineColor, style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
        }.buttonStyle(.plain)
    }
}

struct AddClockSheet: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var availableExchanges: [ExchangeID] {
        let existing = Set(appModel.clocks.map { $0.session.exchangeId })
        let all = ExchangeID.allCases.filter { !existing.contains($0) }
        if searchText.isEmpty { return all }
        return all.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Exchange Clock").font(palette.titleFont).foregroundStyle(palette.primaryText)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }.padding()
            Divider().background(palette.gridLineColor)
            TextField("Search exchanges…", text: $searchText).textFieldStyle(.roundedBorder).padding(.horizontal)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(availableExchanges, id: \.self) { exchangeId in
                        let session = ExchangeSession.exchange(for: exchangeId)
                        Button {
                            appModel.addClock(for: exchangeId); dismiss()
                        } label: {
                            HStack {
                                Circle().fill(session.color).frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.displayName).font(palette.bodyFont).foregroundStyle(palette.primaryText)
                                    Text("\(session.region) - \(session.currency) - \(session.timeZoneIdentifier)").font(.caption).foregroundStyle(palette.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "plus.circle").foregroundStyle(palette.accentColor)
                            }
                            .padding(12).background(palette.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
                        }.buttonStyle(.plain)
                    }
                    if availableExchanges.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle").font(.title).foregroundStyle(palette.successColor)
                            Text("All exchanges already added").foregroundStyle(palette.secondaryText)
                        }.padding(40)
                    }
                }.padding()
            }
        }
        .frame(width: 450, height: 500).background(palette.background)
    }
}
