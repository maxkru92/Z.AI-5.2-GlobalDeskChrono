//
//  AudioEngine.swift
//  Global Desk Chrono — Powered by KruppCapital
//
//  Audio pipeline for session alarms and economic event alerts.
//  Includes NYSE Opening Bell with synthetic fallback, sonar pings,
//  and warning clicks generated via AVAudioEngine.
//

import Foundation
import AVFoundation
import Observation

@Observable
final class AudioEngine {

    private var avEngine: AVAudioEngine?
    private var players: [String: AVAudioPlayer] = [:]
    private var isInitialized = false

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
    }

    func playSound(named name: String, fallback: (() -> Void)? = nil) {
        initialize()
        if let cached = players[name] {
            cached.currentTime = 0
            cached.play()
            return
        }
        if let url = Bundle.main.url(forResource: name, withExtension: nil) ??
           Bundle.main.url(forResource: name, withExtension: "mp3") ??
           Bundle.main.url(forResource: name, withExtension: "wav") ??
           Bundle.main.url(forResource: name, withExtension: "caf") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[name] = player
                player.play()
                return
            } catch { fallback?() }
        } else { fallback?() }
    }

    func playNYSEBell() {
        playSound(named: "nyse_bell.mp3") { [weak self] in
            self?.playSyntheticBell()
        }
    }

    func playSyntheticBell() {
        initialize()
        let sampleRate: Double = 44100
        let totalDuration: Double = 4.0
        let totalSamples = Int(totalDuration * sampleRate)
        var samples = [Float](repeating: 0, count: totalSamples)

        // Bell partials — inharmonic frequencies for metallic timbre
        let partials: [(freq: Double, amp: Double, decay: Double)] = [
            (440.0, 1.00, 3.5), (660.0, 0.50, 2.8), (880.0, 0.35, 2.2),
            (1108.0, 0.25, 1.8), (1320.0, 0.20, 1.5), (1760.0, 0.15, 1.2), (2200.0, 0.10, 0.8)
        ]

        // First strike
        for (freq, amp, decay) in partials {
            for i in 0..<totalSamples {
                let t = Double(i) / sampleRate
                let envelope = amp * exp(-t / decay)
                let fm = 1.0 + 0.002 * sin(2.0 * .pi * 5.0 * t)
                samples[i] += Float(envelope * sin(2.0 * .pi * freq * t * fm))
            }
        }

        // Mechanical strike noise
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            if t < 0.05 {
                samples[i] += Float.random(in: -0.4...0.4) * Float(exp(-t * 80.0))
            }
        }

        // Second strike (double clang)
        let strikeOffset = Int(0.15 * sampleRate)
        for (freq, amp, decay) in partials {
            for i in 0..<(totalSamples - strikeOffset) {
                let t = Double(i) / sampleRate
                let envelope = amp * 0.6 * exp(-t / decay)
                samples[i + strikeOffset] += Float(envelope * sin(2.0 * .pi * freq * t))
            }
        }

        // Third strike
        let strikeOffset2 = Int(0.30 * sampleRate)
        for (freq, amp, decay) in partials {
            for i in 0..<(totalSamples - strikeOffset2) {
                let t = Double(i) / sampleRate
                let envelope = amp * 0.4 * exp(-t / decay)
                samples[i + strikeOffset2] += Float(envelope * sin(2.0 * .pi * freq * t))
            }
        }

        // Normalize
        let maxSample = samples.map { abs($0) }.max() ?? 1.0
        if maxSample > 0 {
            let normFactor = Float(0.7 / maxSample)
            for i in 0..<samples.count { samples[i] *= normFactor }
        }

        playSamples(samples, sampleRate: sampleRate)
    }

    func playSonarPing() {
        initialize()
        let sampleRate: Double = 44100
        let duration: Double = 0.4
        let totalSamples = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: totalSamples)
        let frequency: Double = 2400.0
        let decayTime: Double = 0.35
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let sweepFreq = frequency + 400.0 * (t / duration)
            let envelope = exp(-t / decayTime)
            samples[i] = Float(envelope * sin(2.0 * .pi * sweepFreq * t))
        }
        // Echo
        let echoDelay = Int(0.08 * sampleRate)
        var echoed = [Float](repeating: 0, count: totalSamples + echoDelay)
        for i in 0..<totalSamples {
            echoed[i] = samples[i]
            echoed[i + echoDelay] += samples[i] * 0.3
        }
        playSamples(echoed, sampleRate: sampleRate)
    }

    func playWarningClick() {
        initialize()
        let sampleRate: Double = 44100
        let duration: Double = 0.05
        let totalSamples = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: totalSamples)
        let frequency: Double = 1200.0
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 100.0)
            samples[i] = Float(envelope * sin(2.0 * .pi * frequency * t) * 0.5)
        }
        playSamples(samples, sampleRate: sampleRate)
    }

    func playEconomicAlert() {
        initialize()
        let sampleRate: Double = 44100
        let duration: Double = 0.6
        let totalSamples = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: totalSamples)
        let tone1Freq: Double = 880.0
        let tone2Freq: Double = 1318.5
        let switchPoint = Int(0.3 * sampleRate)
        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let freq = i < switchPoint ? tone1Freq : tone2Freq
            let envelope = 0.5 * (1.0 - exp(-t * 50.0)) * exp(-max(0, t - 0.3) * 5.0)
            samples[i] = Float(envelope * sin(2.0 * .pi * freq * t))
        }
        playSamples(samples, sampleRate: sampleRate)
    }

    private func playSamples(_ samples: [Float], sampleRate: Double) {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData![0]
        for i in 0..<samples.count { channelData[i] = samples[i] }

        let engine = avEngine ?? {
            let e = AVAudioEngine(); avEngine = e; return e
        }()

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }

        player.scheduleBuffer(buffer, at: nil, options: [.interrupts]) { }
        player.play()

        let stopDelay = Double(samples.count) / sampleRate + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + stopDelay) { [weak self] in
            if let engine = self?.avEngine, engine.isRunning { player.stop() }
        }
    }
}
