//
//  ChronoDialView.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  24-Hour Chrono Dial — analog clock face with session arcs.
//

import SwiftUI

struct ChronoDialView: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    @State private var dialSize: CGFloat = 360

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                ChronoDialCanvas(
                    size: dialSize,
                    clocks: appModel.clocks.filter { $0.arcVisible },
                    currentTime: appModel.currentTime,
                    palette: appModel.palette,
                    theme: appModel.themeManager.current
                ).frame(width: dialSize, height: dialSize)
            }.padding()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) { ForEach(appModel.clocks) { clock in ArcToggleButton(clock: clock) } }.padding(.horizontal)
            }
            HStack(spacing: 16) {
                ForEach(Array(appModel.clocks.prefix(6))) { clock in
                    HStack(spacing: 4) {
                        Circle().fill(clock.session.color).frame(width: 10, height: 10)
                        Text(clock.session.shortName).font(palette.monoFont.caption()).foregroundStyle(palette.secondaryText)
                    }
                }
                Spacer()
            }.padding(.horizontal, 32)
        }.padding()
    }
}

struct ChronoDialCanvas: View {
    let size: CGFloat; let clocks: [DashboardClock]; let currentTime: Date
    let palette: ThemePalette; let theme: AppTheme
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TimelineView(.animation(minimumInterval: theme == .vintage ? 1.0/60.0 : 1.0, paused: false)) { context in
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = min(canvasSize.width, canvasSize.height) / 2 - 20
                let displayTime = appModel.ntpSync.correctedNow
                drawBackground(context: context, center: center, radius: radius)
                drawHourMarks(context: context, center: center, radius: radius)
                drawSessionArcs(context: context, center: center, radius: radius, time: displayTime)
                drawHands(context: context, center: center, radius: radius, time: displayTime)
                drawCenterHub(context: context, center: center)
            }
        }
    }

    private func drawBackground(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(palette.surfaceBackground))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 4, dy: 4)), with: .color(palette.gridLineColor), lineWidth: 2)
        switch theme {
        case .vintage:
            for i in 0..<20 {
                let r = radius * CGFloat(i) / 20
                let alpha = 0.02 * (1.0 - Double(i) / 20.0)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(palette.accentColor.opacity(alpha)), lineWidth: 1)
            }
        case .digital:
            for angle in stride(from: 0.0, through: 360.0, by: 15.0) {
                let rad = angle * .pi / 180
                context.stroke(Path { p in p.move(to: center); p.addLine(to: CGPoint(x: center.x + cos(rad) * radius, y: center.y + sin(rad) * radius)) }, with: .color(palette.gridLineColor.opacity(0.3)), lineWidth: 0.5)
            }
        case .modern:
            context.fill(Path(ellipseIn: rect.insetBy(dx: 12, dy: 12)), with: .color(palette.background.opacity(0.5)))
        }
    }

    private func drawHourMarks(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for h in 0..<24 {
            let angle = (Double(h) / 24.0) * 2.0 * .pi - .pi / 2
            let isMajor = h % 6 == 0; let isSecondary = h % 3 == 0
            let outerR = radius - 4
            let tickLength: CGFloat = isMajor ? 16 : (isSecondary ? 10 : 5)
            let innerR = outerR - tickLength
            context.stroke(Path { p in p.move(to: CGPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR)); p.addLine(to: CGPoint(x: center.x + cos(angle) * outerR, y: center.y + sin(angle) * outerR)) }, with: .color(isMajor ? palette.primaryText : palette.secondaryText), lineWidth: isMajor ? 2 : 1)
            if isMajor {
                let tr = radius - 32
                context.draw(Text(String(format: "%02d", h)).font(palette.monoFont.caption().weight(.semibold)).foregroundColor(palette.primaryText), at: CGPoint(x: center.x + cos(angle) * tr, y: center.y + sin(angle) * tr))
            }
        }
        for m in 0..<96 where m % 4 != 0 {
            let angle = (Double(m) / 96.0) * 2.0 * .pi - .pi / 2
            let outerR = radius - 4; let innerR = outerR - 3
            context.stroke(Path { p in p.move(to: CGPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR)); p.addLine(to: CGPoint(x: center.x + cos(angle) * outerR, y: center.y + sin(angle) * outerR)) }, with: .color(palette.gridLineColor), lineWidth: 0.5)
        }
    }

    private func drawSessionArcs(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Date) {
        let userTZ = TimeZone.autoupdatingCurrent
        for clock in clocks {
            for segment in clock.session.segments {
                drawArc(context: context, center: center, radius: radius, session: clock.session, segment: segment, sessionTZ: clock.session.timeZone, userTZ: userTZ, currentTime: time)
            }
            if let secondary = clock.secondarySession {
                for segment in secondary.segments {
                    drawArc(context: context, center: center, radius: radius, session: secondary, segment: segment, sessionTZ: secondary.timeZone, userTZ: userTZ, currentTime: time)
                }
            }
        }
    }

    private func drawArc(context: GraphicsContext, center: CGPoint, radius: CGFloat, session: ExchangeSession, segment: TradingSegment, sessionTZ: TimeZone, userTZ: TimeZone, currentTime: Date) {
        let cal = Calendar(identifier: .gregorian)
        var sCal = cal; sCal.timeZone = sessionTZ
        let nowComps = sCal.dateComponents([.year, .month, .day], from: currentTime)
        var stComps = nowComps; stComps.hour = segment.startHour; stComps.minute = segment.startMinute; stComps.second = 0
        var enComps = nowComps; enComps.hour = segment.endHour; enComps.minute = segment.endMinute; enComps.second = 0
        guard let startDate = sCal.date(from: stComps), let endDate = sCal.date(from: enComps) else { return }
        var uCal = cal; uCal.timeZone = userTZ
        let stUser = uCal.dateComponents([.hour, .minute], from: startDate)
        let enUser = uCal.dateComponents([.hour, .minute], from: endDate)
        let startHour = Double(stUser.hour ?? 0) + Double(stUser.minute ?? 0) / 60.0
        var endHour = Double(enUser.hour ?? 0) + Double(enUser.minute ?? 0) / 60.0
        if endHour < startHour { endHour += 24.0 }
        let startAngle = (startHour / 24.0) * 2.0 * .pi - .pi / 2
        let endAngle = (endHour / 24.0) * 2.0 * .pi - .pi / 2
        let arcRadius = radius * 0.82; let arcWidth: CGFloat = 16
        let path = Path { p in p.addArc(center: center, radius: arcRadius, startAngle: Angle(radians: startAngle), endAngle: Angle(radians: endAngle), clockwise: false) }
        let state = appModel.sessionEngine.sessionState(for: session, at: currentTime)
        let opacity: Double = state.isActive ? 0.8 : 0.25
        context.stroke(path, with: .color(session.color.opacity(opacity)), style: StrokeStyle(lineWidth: arcWidth, lineCap: .round))
        if state.isActive {
            let wp = Path { p in p.move(to: center); p.addArc(center: center, radius: arcRadius, startAngle: Angle(radians: startAngle), endAngle: Angle(radians: endAngle), clockwise: false); p.closeSubpath() }
            context.fill(wp, with: .color(session.color.opacity(0.1)))
        }
    }

    private func drawHands(context: GraphicsContext, center: CGPoint, radius: CGFloat, time: Date) {
        let comps = time.components(in: .autoupdatingCurrent)
        let hours = Double(comps.hour ?? 0); let minutes = Double(comps.minute ?? 0); let seconds = Double(comps.second ?? 0)
        let totalHours = hours + minutes / 60.0 + seconds / 3600.0

        // Hour hand
        let hAngle = (totalHours / 24.0) * 2.0 * .pi - .pi / 2
        context.stroke(Path { p in p.move(to: center); p.addLine(to: CGPoint(x: center.x + cos(hAngle) * radius * 0.45, y: center.y + sin(hAngle) * radius * 0.45)) }, with: .color(palette.primaryText), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        // Minute hand
        let mAngle = ((minutes + seconds / 60.0) / 60.0) * 2.0 * .pi - .pi / 2
        context.stroke(Path { p in p.move(to: center); p.addLine(to: CGPoint(x: center.x + cos(mAngle) * radius * 0.65, y: center.y + sin(mAngle) * radius * 0.65)) }, with: .color(palette.accentColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Second hand — sweeping for vintage, ticking for others
        let sAngle: Double
        if theme == .vintage {
            let ts = seconds + (time.timeIntervalSince1970.truncatingRemainder(dividingBy: 1))
            sAngle = (ts / 60.0) * 2.0 * .pi - .pi / 2
        } else {
            sAngle = (seconds / 60.0) * 2.0 * .pi - .pi / 2
        }
        context.stroke(Path { p in p.move(to: center); p.addLine(to: CGPoint(x: center.x + cos(sAngle) * radius * 0.72, y: center.y + sin(sAngle) * radius * 0.72)) }, with: .color(theme == .vintage ? palette.accentColor : palette.dangerColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        // Digital readout
        context.draw(Text(time.timeString(in: .autoupdatingCurrent)).font(palette.monoFont.weight(.semibold)).foregroundColor(palette.primaryText), at: CGPoint(x: center.x, y: center.y - radius + 12))
    }

    private func drawCenterHub(context: GraphicsContext, center: CGPoint) {
        let hubR: CGFloat = theme == .vintage ? 8 : 5
        context.fill(Path(ellipseIn: CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)), with: .color(palette.accentColor))
        context.fill(Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)), with: .color(palette.background))
    }
}

struct ArcToggleButton: View {
    @Environment(AppModel.self) private var appModel
    private var palette: ThemePalette { appModel.palette }
    let clock: DashboardClock

    var body: some View {
        Button(action: {
            if let idx = appModel.clocks.firstIndex(where: { $0.id == clock.id }) { appModel.clocks[idx].arcVisible.toggle() }
        }) {
            HStack(spacing: 6) {
                Circle().fill(clock.session.color).frame(width: 10, height: 10).opacity(clock.arcVisible ? 1.0 : 0.3)
                Text(clock.session.shortName).font(palette.monoFont.caption()).foregroundStyle(clock.arcVisible ? palette.primaryText : palette.secondaryText)
                Image(systemName: clock.arcVisible ? "eye.fill" : "eye.slash.fill").font(.caption2).foregroundStyle(clock.arcVisible ? palette.accentColor : palette.secondaryText)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(palette.cardBackground).clipShape(RoundedRectangle(cornerRadius: palette.cornerRadius))
        }.buttonStyle(.plain)
    }
}
