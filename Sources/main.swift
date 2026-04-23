
/* 
 *  CYBER KINECT v1.0 | THE TRUE VIBE
 *  Core: Apple Metal API
 *  Hardware: OpenKinect/libfreenect2
 */

import AppKit; import MetalKit; import Foundation; import simd; import AVFoundation; import Accelerate

struct Uniforms {
    var mvm: matrix_float4x4
    var pz: Float; var dMin: Float; var dMax: Float; var dens: Float
    var jit: Float; var t: Float; var aL: Float; var aM: Float
    var aH: Float; var fb: Float; var vM: Int32; var asp: Float
    var fx: Float; var fy: Float; var cx: Float; var cy: Float
    var zm: Float; var stT: Float; var lS: Float; var mS: Float
    var hS: Float; var p1: Float; var p2: Float; var p3: Float
    var cB: simd_float4
}

@_silgen_name("kinect2_init") func kinect2_init() -> Int32
@_silgen_name("kinect2_get_data") func kinect2_get_data(_ d: UnsafeMutablePointer<Float>, _ c: UnsafeMutablePointer<UInt8>, _ p: UnsafeMutablePointer<Float>) -> Int32
@_silgen_name("kinect2_shutdown") func kinect2_shutdown()

class FFT: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    var l: Float = 0; var m: Float = 0; var h: Float = 0
    var gS: Float = 0.4; var lS: Float = 1.0; var mS: Float = 1.0; var hS: Float = 1.0
    var s = AVCaptureSession(); private let fS = 1024; private var b = [Float]()
    private lazy var fStp = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fS), vDSP_DFT_Direction.FORWARD)
    func start() {
        AVCaptureDevice.requestAccess(for: .audio) { g in
            if g {
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let d = AVCaptureDevice.default(for: .audio), let i = try? AVCaptureDeviceInput(device: d) else { return }
                    self.s.beginConfiguration()
                    if self.s.canAddInput(i) { self.s.addInput(i) }
                    let o = AVCaptureAudioDataOutput(); o.setSampleBufferDelegate(self, queue: .global())
                    o.audioSettings = [AVFormatIDKey: kAudioFormatLinearPCM, AVNumberOfChannelsKey: 1, AVSampleRateKey: 44100.0, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true]
                    if self.s.canAddOutput(o) { self.s.addOutput(o) }
                    self.s.commitConfiguration(); self.s.startRunning()
                }
            }
        }
    }
    func captureOutput(_ o: AVCaptureOutput, didOutput b: CMSampleBuffer, from c: AVCaptureConnection) {
        guard let bb = CMSampleBufferGetDataBuffer(b) else { return }
        let len = CMBlockBufferGetDataLength(bb); var tmp = [Float](repeating: 0, count: len / 4); CMBlockBufferCopyDataBytes(bb, atOffset: 0, dataLength: len, destination: &tmp)
        self.b.append(contentsOf: tmp)
        while self.b.count >= fS {
            let d = Array(self.b.prefix(fS)); self.b.removeFirst(fS / 2)
            var r = [Float](repeating: 0, count: fS); var i = [Float](repeating: 0, count: fS)
            vDSP_DFT_Execute(fStp!, d, [Float](repeating: 0, count: fS), &r, &i)
            var mags = [Float](repeating: 0, count: fS / 2)
            r.withUnsafeMutableBufferPointer { rP in i.withUnsafeMutableBufferPointer { iP in
                var sc = DSPSplitComplex(realp: rP.baseAddress!, imagp: iP.baseAddress!)
                vDSP_zvabs(&sc, 1, &mags, 1, vDSP_Length(fS / 2))
            }}
            var bl: Float = 0; var bm: Float = 0; var bh: Float = 0
            for k in 1..<10 { bl += mags[k] }; for k in 10..<100 { bm += mags[k] }; for k in 100..<512 { bh += mags[k] }
            DispatchQueue.main.async {
                let x = self.gS * 0.1
                self.l = self.l * 0.8 + (bl / 9.0 * x * self.lS) * 0.2
                self.m = self.m * 0.8 + (bm / 90.0 * x * self.mS) * 0.2
                self.h = self.h * 0.8 + (bh / 412.0 * x * self.hS) * 0.2
            }
        }
    }
}

class Engine: NSObject, MTKViewDelegate {
    var ps: MTLRenderPipelineState?; var q: MTLCommandQueue?; var db: MTLBuffer?; var cp: MTLBuffer?
    var mode: Int32 = 0; var start = Date(); var last = Date(); var fps: Float = 0
    var sz: Float = 10.0; var dMin: Float = 500; var dMax: Float = 4500; var dns: Float = 1.0; var jit: Float = 0.002; var fdb: Float = 0.8; var zm: Float = 1.2
    var stT: Float = 0.8; var run = true; var st = "SEARCHING"; var tck = 0
    let clrs: [simd_float4] = [simd_float4(0,1,1,1), simd_float4(1,0.3,0,1), simd_float4(0,1,0.2,1), simd_float4(1,0,1,1), simd_float4(1,1,1,1), simd_float4(0.5,0,1,1), simd_float4(1,1,0,1), simd_float4(0,0.5,1,1), simd_float4(1,0,0,1)]
    let audio = FFT()
    init(device: MTLDevice) {
        super.init(); q = device.makeCommandQueue(); audio.start()
        let p = Bundle.main.path(forResource: "default", ofType: "metallib") ?? "default.metallib"
        guard let l = try? device.makeLibrary(URL: URL(fileURLWithPath: p)) else { return }
        let d = MTLRenderPipelineDescriptor(); d.vertexFunction = l.makeFunction(name: "v_m"); d.fragmentFunction = l.makeFunction(name: "f_m"); d.colorAttachments[0].pixelFormat = .bgra8Unorm
        d.colorAttachments[0].isBlendingEnabled = true; d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha; d.colorAttachments[0].destinationRGBBlendFactor = .one
        ps = try? device.makeRenderPipelineState(descriptor: d)
        db = device.makeBuffer(length: 512 * 424 * 4, options: .storageModeShared); cp = device.makeBuffer(length: 4 * 4, options: .storageModeShared)
        DispatchQueue.global(qos: .userInteractive).async {
            if kinect2_init() == 0 { self.st = "ACTIVE"; while self.run { _ = kinect2_get_data(self.db!.contents().assumingMemoryBound(to: Float.self), self.db!.contents().assumingMemoryBound(to: UInt8.self), self.cp!.contents().assumingMemoryBound(to: Float.self)); Thread.sleep(forTimeInterval: 0.005) } }
            else { self.st = "DEMO"; while self.run { let p = self.db!.contents().assumingMemoryBound(to: Float.self); let t = Float(Date().timeIntervalSince(self.start)); for y in 0..<424 { for x in 0..<512 { p[y*512+x] = 1500.0 + 800.0 * sin(Float(x)*0.03 + t) * cos(Float(y)*0.03 + t) } }; Thread.sleep(forTimeInterval: 0.033) } }
        }
    }
    func auto() {
        let p = db!.contents().assumingMemoryBound(to: Float.self); var mi: Float = 10000; var ma: Float = 0
        for i in 0..<(512*424) { let z = p[i]; if z > 300 && z < 15000 { if z < mi { mi = z }; if z > ma { ma = z } } }
        if ma > mi { self.dMin = max(100, mi - 200); self.dMax = min(20000, ma + 200) }
    }
    func mtkView(_ v: MTKView, drawableSizeWillChange s: CGSize) {}
    func draw(in v: MTKView) {
        tck += 1; let n = Date(); let d = n.timeIntervalSince(last)
        if d > 0.5 { fps = Float(tck) / Float(n.timeIntervalSince(start)); last = n; v.window?.title = "CYBER KINECT | \(st) | \(Int(fps)) FPS" }
        guard let dr = v.currentDrawable, let rpd = v.currentRenderPassDescriptor, let q = q, let ps = ps else { return }
        let cb = q.makeCommandBuffer(); let asp = Float(v.bounds.width / v.bounds.height)
        let e = cb?.makeRenderCommandEncoder(descriptor: rpd); let c = cp?.contents().assumingMemoryBound(to: Float.self)
        let fx = (c?[0] ?? 0) > 100 ? c![0] : 365.0; let fy = (c?[1] ?? 0) > 100 ? c![1] : 365.0; let cx = (c?[2] ?? 0) > 100 ? c![2] : 256.0; let cy = (c?[3] ?? 0) > 100 ? c![3] : 212.0
        var u = Uniforms(mvm: matrix_identity_float4x4, pz: sz, dMin: dMin, dMax: dMax, dens: dns, jit: jit, t: Float(Date().timeIntervalSince(start)), aL: audio.l, aM: audio.m, aH: audio.h, fb: fdb, vM: mode, asp: asp, fx: fx, fy: fy, cx: cx, cy: cy, zm: zm, stT: stT, lS: audio.lS, mS: audio.mS, hS: audio.hS, p1: 0, p2: 0, p3: 0, cB: clrs[Int(mode) % clrs.count])
        e?.setRenderPipelineState(ps); e?.setVertexBuffer(db, offset: 0, index: 0); e?.setVertexBytes(&u, length: MemoryLayout<Uniforms>.size, index: 2); e?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 512 * 424); e?.endEncoding(); cb?.present(dr); cb?.commit()
    }
}

class Control: NSViewController {
    var eng: Engine?; var labs = [String: NSTextField](); var bars = [NSLevelIndicator]()
    var onUI: (() -> Void)?; var onFS: (() -> Void)?
    override func loadView() {
        let r = NSStackView(); r.orientation = .vertical; r.spacing = 10; r.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20); r.alignment = .leading; r.translatesAutoresizingMaskIntoConstraints = false
        func h(_ t: String) { let l = NSTextField(labelWithString: t); l.font = .boldSystemFont(ofSize: 12); l.textColor = .systemPurple; r.addArrangedSubview(l) }
        func s(_ l: String, _ min: Double, _ max: Double, _ d: Double, _ k: String, _ a: Selector) {
            let row = NSStackView(); row.orientation = .horizontal; row.spacing = 8; row.alignment = .centerY
            let t = NSTextField(labelWithString: l); t.font = .systemFont(ofSize: 11); t.textColor = .lightGray; t.widthAnchor.constraint(equalToConstant: 75).isActive = true; row.addArrangedSubview(t)
            let cur = UserDefaults.standard.object(forKey: k) != nil ? UserDefaults.standard.double(forKey: k) : d
            let sl = NSSlider(); sl.minValue = min; sl.maxValue = max; sl.doubleValue = cur; sl.target = self; sl.action = a; sl.isContinuous = true; sl.widthAnchor.constraint(equalToConstant: 90).isActive = true; row.addArrangedSubview(sl)
            let v = NSTextField(labelWithString: String(format: "%.2f", cur)); v.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold); v.textColor = .systemPurple; v.widthAnchor.constraint(equalToConstant: 35).isActive = true; row.addArrangedSubview(v); labs[k] = v; r.addArrangedSubview(row)
        }
        func b(_ c: NSColor) { let i = NSLevelIndicator(); i.levelIndicatorStyle = .continuousCapacity; i.maxValue = 1.0; i.minValue = 0; i.doubleValue = 0; i.fillColor = c; i.widthAnchor.constraint(equalToConstant: 210).isActive = true; i.heightAnchor.constraint(equalToConstant: 4).isActive = true; bars.append(i); r.addArrangedSubview(i) }
        h("AUDIO"); b(.systemBlue); b(.systemGreen); b(.systemRed)
        s("GAIN", 0, 10, 0.4, "aS", #selector(au)); s("BASS", 0, 2, 1, "lS", #selector(ls)); s("MID", 0, 2, 1, "mS", #selector(ms)); s("TOP", 0, 4, 1, "hS", #selector(hs))
        h("STAGE")
        let bA = NSButton(title: "AUTO", target: self, action: #selector(atC)); bA.bezelStyle = .rounded; bA.widthAnchor.constraint(equalToConstant: 210).isActive = true; r.addArrangedSubview(bA)
        let bF = NSButton(title: "FULL (F)", target: self, action: #selector(fsC)); bF.bezelStyle = .rounded; bF.widthAnchor.constraint(equalToConstant: 210).isActive = true; r.addArrangedSubview(bF)
        let bH = NSButton(title: "UI (Tab)", target: self, action: #selector(hiC)); bH.bezelStyle = .rounded; bH.widthAnchor.constraint(equalToConstant: 210).isActive = true; r.addArrangedSubview(bH)
        h("ENGINE"); s("ZOOM", 0.1, 10, 1.2, "z", #selector(zm)); s("SIZE", 1, 100, 10, "s", #selector(sz)); s("DNS", 0.01, 1, 1, "d", #selector(dn)); s("JIT", 0, 0.1, 0.002, "j", #selector(jt)); s("FDB", 0, 0.99, 0.8, "f", #selector(fb))
        h("CLIP"); s("MIN", 10, 8000, 500, "mn", #selector(mn)); s("MAX", 500, 20000, 4500, "mx", #selector(mx))
        h("MODES"); let mR = NSStackView(); mR.orientation = .horizontal; mR.spacing = 2; for i in 1...9 { let b = NSButton(title: "\(i)", target: self, action: #selector(mC)); b.tag = i-1; b.widthAnchor.constraint(equalToConstant: 22).isActive = true; mR.addArrangedSubview(b) }; r.addArrangedSubview(mR)
        let sc = NSScrollView(); sc.documentView = r; sc.hasVerticalScroller = true; sc.drawsBackground = false; self.view = sc
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in self.bars[0].doubleValue = Double(self.eng?.audio.l ?? 0); self.bars[1].doubleValue = Double(self.eng?.audio.m ?? 0); self.bars[2].doubleValue = Double(self.eng?.audio.h ?? 0) }
    }
    @objc func atC() { eng?.auto() }
    @objc func fsC() { onFS?() }
    @objc func hiC() { onUI?() }
    @objc func mC(_ s: NSButton) { eng?.mode = Int32(s.tag) }
    func up(_ s: NSSlider, _ k: String) { UserDefaults.standard.set(s.doubleValue, forKey: k); if let t = labs[k] { t.stringValue = String(format: "%.2f", s.doubleValue) } }
    @objc func au(_ s: NSSlider) { eng?.audio.gS = Float(s.doubleValue); up(s, "aS") }
    @objc func ls(_ s: NSSlider) { eng?.audio.lS = Float(s.doubleValue); up(s, "lS") }
    @objc func ms(_ s: NSSlider) { eng?.audio.mS = Float(s.doubleValue); up(s, "mS") }
    @objc func hs(_ s: NSSlider) { eng?.audio.hS = Float(s.doubleValue); up(s, "hS") }
    @objc func zm(_ s: NSSlider) { eng?.zm = Float(s.doubleValue); up(s, "z") }
    @objc func sz(_ s: NSSlider) { eng?.sz = Float(s.doubleValue); up(s, "s") }
    @objc func dn(_ s: NSSlider) { eng?.dns = Float(s.doubleValue); up(s, "d") }
    @objc func jt(_ s: NSSlider) { eng?.jit = Float(s.doubleValue); up(s, "j") }
    @objc func fb(_ s: NSSlider) { eng?.fdb = Float(s.doubleValue); up(s, "f") }
    @objc func mn(_ s: NSSlider) { eng?.dMin = Float(s.doubleValue); up(s, "mn") }
    @objc func mx(_ s: NSSlider) { eng?.dMax = Float(s.doubleValue); up(s, "mx") }
}

class AppDel: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var w: NSWindow?; var eng: Engine?; var side: NSView?
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true); setupMenu()
        guard let d = MTLCreateSystemDefaultDevice() else { return }
        let kv = MTKView(frame: .zero, device: d); self.eng = Engine(device: d); kv.delegate = eng; kv.isPaused = false; kv.enableSetNeedsDisplay = false; kv.preferredFramesPerSecond = 60; kv.clearColor = MTLClearColor(red: 0.05, green: 0, blue: 0.1, alpha: 1)
        let sV = NSView(); self.side = sV; sV.wantsLayer = true; sV.layer?.backgroundColor = NSColor(white: 0.05, alpha: 1.0).cgColor
        let cp = Control(); cp.eng = eng; sV.addSubview(cp.view); sV.translatesAutoresizingMaskIntoConstraints = false; cp.view.translatesAutoresizingMaskIntoConstraints = false; NSLayoutConstraint.activate([cp.view.topAnchor.constraint(equalTo: sV.topAnchor), cp.view.leadingAnchor.constraint(equalTo: sV.leadingAnchor), cp.view.trailingAnchor.constraint(equalTo: sV.trailingAnchor), cp.view.bottomAnchor.constraint(equalTo: sV.bottomAnchor), sV.widthAnchor.constraint(equalToConstant: 250)])
        cp.onUI = { self.side?.isHidden.toggle() }; cp.onFS = { self.w?.toggleFullScreen(nil) }
        let root = NSStackView(views: [sV, kv]); root.orientation = .horizontal; root.spacing = 0; root.alignment = .centerY; root.distribution = .fill; kv.translatesAutoresizingMaskIntoConstraints = false
        w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false); w?.delegate = self; w?.contentView = root; w?.center(); w?.makeKeyAndOrderFront(nil)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in if e.keyCode == 48 { self.side?.isHidden.toggle(); return nil }; if e.charactersIgnoringModifiers == "f" { self.w?.toggleFullScreen(nil); return nil }; return e }
    }
    func setupMenu() { let m = NSMenu(); let am = NSMenu(); am.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")); let mi = NSMenuItem(); mi.submenu = am; m.addItem(mi); NSApp.mainMenu = m }
    func applicationWillTerminate(_ n: Notification) { eng?.run = false; kinect2_shutdown(); _exit(0) }
}
let app = NSApplication.shared; let del = AppDel(); app.delegate = del; app.run()
