
#include "KinectBridge.h"
#include <libfreenect2/libfreenect2.hpp>
#include <libfreenect2/packet_pipeline.h>
#include <libfreenect2/frame_listener_impl.h>
#include <iostream>
#include <vector>
#include <string.h>

static libfreenect2::Freenect2 freenect2;
static libfreenect2::Freenect2Device *dev = nullptr;
static libfreenect2::SyncMultiFrameListener *listener = nullptr;
static libfreenect2::FrameMap frames;

extern "C" int kinect2_init() {
    std::cout << "[CPP] Initializing Freenect2..." << std::endl;
    if (freenect2.enumerateDevices() == 0) {
        std::cout << "[CPP] No devices found." << std::endl;
        return -1;
    }
    std::string serial = freenect2.getDefaultDeviceSerialNumber();
    std::cout << "[CPP] Opening device: " << serial << std::endl;
    
    // BACK TO CPU FOR MAXIMUM STABILITY - AVOID METAL PIPELINE CRASHES
    dev = freenect2.openDevice(serial, new libfreenect2::CpuPacketPipeline());
    if (!dev) {
        std::cout << "[CPP] Failed to open device." << std::endl;
        return -2;
    }

    listener = new libfreenect2::SyncMultiFrameListener(libfreenect2::Frame::Depth);
    dev->setIrAndDepthFrameListener(listener);

    if (!dev->start()) {
        std::cout << "[CPP] Failed to start device." << std::endl;
        return -3;
    }
    std::cout << "[CPP] Kinect Ready." << std::endl;
    return 0;
}

extern "C" int kinect2_get_data(float* depthBuffer, uint8_t* colorBuffer, float* cameraParams) {
    if (!listener->waitForNewFrame(frames, 500)) return -1;
    
    libfreenect2::Frame *depth = frames[libfreenect2::Frame::Depth];
    if (depth) memcpy(depthBuffer, depth->data, 512 * 424 * 4);
    
    libfreenect2::Freenect2Device::IrCameraParams ir = dev->getIrCameraParams();
    cameraParams[0] = ir.fx; cameraParams[1] = ir.fy;
    cameraParams[2] = ir.cx; cameraParams[3] = ir.cy;

    listener->release(frames);
    return 0;
}

extern "C" void kinect2_shutdown() {
    std::cout << "[CPP] Shutdown." << std::endl;
    if (dev) { dev->stop(); dev->close(); }
    if (listener) delete listener;
}
