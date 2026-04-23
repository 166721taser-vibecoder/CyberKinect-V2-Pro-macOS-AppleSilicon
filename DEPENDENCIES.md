# Project Dependencies

To compile and run CYBER KINECT from source, you need the following:

### Hardware
- Kinect for Xbox One (v2)
- Kinect Adapter for Windows/macOS (USB 3.0)

### Software / Libraries
- **macOS 12.0+** (Apple Silicon recommended)
- **Xcode Command Line Tools**: `xcode-select --install`
- **Homebrew**: `https://brew.sh`
- **libfreenect2**: Open-source driver for Kinect v2.
- **libusb**: Universal USB library.

### Development Tools
- `swiftc` (Swift Compiler)
- `xcrun` (Metal Compiler)
- `install_name_tool` (For binary linking)

All libraries can be installed via Homebrew:
```bash
brew install libfreenect2 libusb
```
