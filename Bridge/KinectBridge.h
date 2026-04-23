
#ifndef KINECT_BRIDGE_H
#define KINECT_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int kinect2_init();
int kinect2_get_data(float* depthBuffer, uint8_t* colorBuffer, float* cameraParams);
void kinect2_shutdown();

#ifdef __cplusplus
}
#endif

#endif
