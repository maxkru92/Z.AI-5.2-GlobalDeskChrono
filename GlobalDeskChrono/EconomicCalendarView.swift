//
//  EconomicCalendarView.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Detail-Granular Economic Calendar Filter Dashboard.
//

import SwiftUI

struct EconomicCalendarView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Economic Calendar").font(palette.titleFont).foregroundStyle(palette.primaryText)
                    Text("High-impact macroeconomic events — filtered & alertable").font(.caption).foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button(action: { Task { await appModel.economicCalendar.fetchEvents() } }) { Label("Refresh", systemImage: "arrow.clockwise") }.buttonStyle(.bordered).disabled(appModel.economicCalendar.isLoading)
                Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
            }.padding().background(palette.surfaceBackground)
            Divider().background(palette.gridLineColor)
            EconomicFilterBar().padding().background(palette.surfaceBackground.opacity(0.5))
            Divider().background(palette.gridLineColor)
            if appModel.economicCalendar.isLoading && appModel.economicCalendar.events.isEmpty {
                VStack(spacing: 12) { ProgressView().scaleEffect(1.2); Text("Fetching economic events…").font(palette.bodyFont).foregroundStyle(palette.secondaryText) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { EconomicEventList() }
            if let error = appModel.economicCalendar.fetchError {
                HStack { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(palette.warningColor); Text(error).font(.caption).foregroundStyle(palette.warningColor); Spacer() }.padding(8).background(palette.warningColor.opacity(0.1))
            }
        }.background(palette.background).frame(minWidth: 700, minHeight: 500)
    }
}

struct EconomicFilterBar: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CURRENCY").font(palette.monoFont.caption2().weight(.semibold)).foregroundStyle(palette.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(appModel.economicCalendar.availableCurrencies + ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "NZD", "CNY", "HKD"], id: \.self) { currency in
                            FilterChip(text: currency, isSelected: appModel.economicCalendar.filter.currencies.contains(currency), color: palette.accentColor) {
                                if appModel.economicCalendar.filter.currencies.contains(currency) { appModel.economicCalendar.filter.currencies.remove(currency) }
                                else { appModel.economicCalendar.filter.currencies.insert(currency) }
                                appModel.restartAlarmManager()
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("IMPACT LEVEL").font(palette.monoFont.caption2().weight(.semibold)).foregroundStyle(palette.secondaryText)
                HStack(spacing: 6) {
                    ForEach(ImpactLevel.allCases, id: \.self) { level in
                        FilterChip(text: "\(level.displayName) (\(String(repeating: "★", count: level.stars)))", isSelected: appModel.economicCalendar.filter.impactLevels.contains(level), color: level.color) {
                            if appModel.economicCalendar.filter.impactLevels.contains(level) { appModel.economicCalendar.filter.impactLevels.remove(level) }
                            else { appModel.economicCalendar.filter.impactLevels.insert(level) }
                            appModel.restartAlarmManager()
                        }
                    }
                }
            }
            HStack {
                Text("ALERT LEAD TIME:").font(palette.monoFont.caption2().weight(.semibold)).foregroundStyle(palette.secondaryText)
                Picker("", selection: Binding(get: { appModel.economicCalendar.filter.leadTimeMinutes }, set: { v in appModel.economicCalendar.filter.leadTimeMinutes = v; appModel.restartAlarmManager() })) {
                    Text("1 min").tag(1); Text("5 min").tag(5); Text("10 min").tag(10); Text("15 min").tag(15); Text("30 min").tag(30); Text("60 min").tag(60)
                }.pickerStyle(.segmented).frame(width: 360)
            }
        }
    }
}

struct FilterChip: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    let text: String; let isSelected: Bool; let color: Color; let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text).font(palette.monoFont.caption().weight(.semibold)).foregroundStyle(isSelected ? .white : palette.secondaryText)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(isSelected ? color : palette.cardBackground).clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? color : palette.gridLineColor, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

struct EconomicEventList: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let nextEvent = appModel.economicCalendar.nextEvent {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock").font(.title3).foregroundStyle(palette.warningColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextEvent.title).font(palette.bodyFont.weight(.semibold)).foregroundStyle(palette.primaryText)
                            Text("\(nextEvent.currency) - \(nextEvent.impact.displayName) - In \(fmt(nextEvent.eventTime))").font(.caption).foregroundStyle(palette.warningColor)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(nextEvent.eventTime.timeString(in: .autoupdatingCurrent, format: "HH:mm")).font(palette.monoFont.weight(.semibold)).foregroundStyle(palette.primaryText)
                            Text(nextEvent.eventTime, style: .relative).font(.caption2).foregroundStyle(palette.secondaryText)
                        }
                    }.padding(12).background(palette.warningColor.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: palette.cornerRadius).stroke(palette.warningColor.opacity(0.3), lineWidth: 1)).padding(.horizontal).padding(.vertical, 8)
                    Divider().background(palette.gridLineColor).padding(.horizontal)
                }
                ForEach(appModel.economicCalendar.filteredEvents) { event in EconomicEventRow(event: event); Divider().background(palette.gridLineColor.opacity(0.5)) }
                if appModel.economicCalendar.filteredEvents.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark").font(.largeTitle).foregroundStyle(palette.secondaryText)
                        Text("No events match your filters").font(palette.bodyFont).foregroundStyle(palette.secondaryText)
                    }.padding(60)
                }
            }
        }
    }

    private func fmt(_ date: Date) -> String {
        let i = date.timeIntervalSinceNow
        if i < 60 { return "\(Int(i))s" }
        if i < 3600 { return "\(Int(i / 60))m" }
        if i < 86400 { return "\(Int(i / 3600))h \(Int((i.truncatingRemainder(dividingBy: 3600)) / 60))m" }
        return "\(Int(i / 86400))d"
    }
}

struct EconomicEventRow: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    let event: EconomicEvent

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) { ForEach(0..<3) { i in Image(systemName: i < event.impact.stars ? "star.fill" : "star").font(.system(size: 8)).foregroundStyle(event.impact.color) } }.frame(width: 16)
            Text(event.currency).font(palette.monoFont.caption().weight(.bold)).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 3).background(event.impact.color).clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(palette.bodyFont).foregroundStyle(palette.primaryText)
                HStack(spacing: 8) {
                    if let sector = event.sector { Text(sector).font(.caption2).foregroundStyle(palette.secondaryText) }
                    if !event.country.isEmpty { Text("- \(event.country)").font(.caption2).foregroundStyle(palette.secondaryText) }
                }
            }
            Spacer()
            HStack(spacing: 12) {
                if let f = event.forecast { VStack(alignment: .trailing, spacing: 0) { Text("FCST").font(.system(size: 8, weight: .medium)).foregroundStyle(palette.secondaryText); Text(f).font(palette.monoFont.caption()).foregroundStyle(palette.accentColor) } }
                if let p = event.previous { VStack(alignment: .trailing, spacing: 0) { Text("PREV").font(.system(size: 8, weight: .medium)).foregroundStyle(palette.secondaryText); Text(p).font(palette.monoFont.caption()).foregroundStyle(palette.secondaryText) } }
                if let a = event.actual { VStack(alignment: .trailing, spacing: 0) { Text("ACT").font(.system(size: 8, weight: .medium)).foregroundStyle(palette.secondaryText); Text(a).font(palette.monoFont.caption().weight(.bold)).foregroundStyle(palette.successColor) } }
            }
            Text(event.eventTime.timeString(in: .autoupdatingCurrent, format: "HH:mm")).font(palette.monoFont.caption2()).foregroundStyle(palette.secondaryText)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(event.eventTime.timeIntervalSinceNow < 3600 && event.eventTime.timeIntervalSinceNow > 0 ? palette.warningColor.opacity(0.05) : Color.clear)
    }
}
