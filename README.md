# 🌀 CyberKinect-V2-Pro (Apple Silicon macOS) v1.0
**Pro-Grade VJ Engine for Kinect v2 (Apple Silicon macOS)**

![Vibe](https://img.shields.io/badge/Style-Vibecoding-blueviolet)
![Platform](https://img.shields.io/badge/Platform-macOS--arm64-black)
![Engine](https://img.shields.io/badge/Engine-Metal-cyan)

CYBER KINECT is a high-performance, point-cloud visualization system designed for professional VJing. It leverages the raw power of Apple's Metal API to process millions of points in real-time with zero latency.

---

## ⚡️ Quick Start (For VJs)
1. **Download**: Grab the latest `CyberKinect_v1.0.zip` from [Releases](../../releases).
2. **Install**: Drag `CyberKinect.app` to your Applications folder.
3. **Connect**: Plug in your Kinect v2 via USB 3.0 (Azure/Xbox One version).
4. **Launch**: Open the app, hit **AUTO** and enjoy.

### 🎮 Controls
- **F**: Toggle Fullscreen Mode.
- **Tab**: Hide/Show the Control Panel.
- **AUTO**: Calibrate depth range automatically.
- **9 Modes**: Press buttons 1-9 to switch visual algorithms.

---

## 🛠 For Developers (Build from Source)

### Dependencies
- **Homebrew**
- **libfreenect2** (Kinect v2 Driver)
- **libusb**

### Automated Build
Simply run the installer script:
```bash
chmod +x INSTALL.sh
./INSTALL.sh
```

### Manual Compilation
If you want to build manually:
1. Compile Shaders: `xcrun -sdk macosx metal -c Shaders.metal -o Shaders.air`
2. Generate Library: `xcrun -sdk macosx metallib Shaders.air -o default.metallib`
3. Compile Swift: Use the provided `INSTALL.sh` logic for linking.

---

## 📡 Credits & Acknowledgements
- **OpenKinect**: For the incredible `libfreenect2` driver. [GitHub](https://github.com/OpenKinect/libfreenect2)
- **Apple Metal**: For the GPU performance.
- **Vibecoding**: For the aesthetic and vision.

---

## ⚖️ License
MIT License. Feel free to use in your live performances and art installations.

*Developed with 💜 for the VJ community.*
