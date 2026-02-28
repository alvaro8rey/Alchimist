import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private let engine   = AVAudioEngine()
    private let popNode   = AVAudioPlayerNode()
    private let chimeNode = AVAudioPlayerNode()
    private let swooshNode = AVAudioPlayerNode()

    private let popBuffer:    AVAudioPCMBuffer?
    private let chimeBuffer:  AVAudioPCMBuffer?
    private let swooshBuffer: AVAudioPCMBuffer?

    private static let sr: Double = 44100

    private init() {
        // Mezclar con audio de fondo sin interrumpirlo
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        // Generar buffers antes de arrancar el motor
        popBuffer    = SoundManager.makePop()
        chimeBuffer  = SoundManager.makeChime()
        swooshBuffer = SoundManager.makeSwoosh()

        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        for node in [popNode, chimeNode, swooshNode] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: fmt)
        }
        engine.mainMixerNode.outputVolume = 0.55
        try? engine.start()
    }

    // MARK: - Public

    func playPop()    { play(popNode,    buffer: popBuffer) }
    func playChime()  { play(chimeNode,  buffer: chimeBuffer) }
    func playSwoosh() { play(swooshNode, buffer: swooshBuffer) }

    // MARK: - Playback

    private func play(_ node: AVAudioPlayerNode, buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }
        node.stop()
        node.scheduleBuffer(buffer)
        node.play()
    }

    // MARK: - Síntesis

    /// Golpe corto tipo "pop" — seno a 680 Hz con caída rápida (90 ms)
    private static func makePop() -> AVAudioPCMBuffer? {
        let duration = 0.09
        guard let buf = makeBuffer(duration: duration) else { return nil }
        let ptr = buf.floatChannelData![0]
        for i in 0..<Int(buf.frameLength) {
            let t = Double(i) / sr
            ptr[i] = Float(sin(2 * .pi * 680 * t) * exp(-t * 48) * 0.6)
        }
        return buf
    }

    /// Campana cristalina — 4 armónicos con caída lenta (1 s)
    private static func makeChime() -> AVAudioPCMBuffer? {
        let duration = 1.0
        guard let buf = makeBuffer(duration: duration) else { return nil }
        let ptr = buf.floatChannelData![0]
        // (frecuencia Hz, amplitud, velocidad de caída)
        let partials: [(Double, Double, Double)] = [
            (1320, 0.40, 3.2),
            (2640, 0.22, 5.0),
            (3960, 0.12, 7.5),
            (1980, 0.16, 4.2)
        ]
        for i in 0..<Int(buf.frameLength) {
            let t = Double(i) / sr
            var s = 0.0
            for (freq, amp, decay) in partials {
                s += sin(2 * .pi * freq * t) * amp * exp(-t * decay)
            }
            ptr[i] = Float(s * 0.48)
        }
        return buf
    }

    /// Barrido descendente 720 Hz → 110 Hz con fade-out (220 ms)
    private static func makeSwoosh() -> AVAudioPCMBuffer? {
        let duration = 0.22
        guard let buf = makeBuffer(duration: duration) else { return nil }
        let ptr = buf.floatChannelData![0]
        var phase = 0.0
        for i in 0..<Int(buf.frameLength) {
            let t        = Double(i) / sr
            let progress = t / duration
            let freq     = 720 * pow(110.0 / 720.0, progress)   // barrido exponencial
            let envelope = (1.0 - progress) * 0.48
            phase += 2 * .pi * freq / sr
            ptr[i] = Float(sin(phase) * envelope)
        }
        return buf
    }

    private static func makeBuffer(duration: Double) -> AVAudioPCMBuffer? {
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let frames = UInt32(sr * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        return buf
    }
}
