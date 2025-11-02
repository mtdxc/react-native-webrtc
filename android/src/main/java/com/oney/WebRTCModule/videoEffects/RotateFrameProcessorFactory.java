package com.oney.WebRTCModule.videoEffects;

public class RotateFrameProcessorFactory implements VideoFrameProcessorFactoryInterface {
    /**
     * Dynamically allocates a VideoFrameProcessor instance and returns a pointer to it.
     * The caller takes ownership of the object.
     */
    public VideoFrameProcessor build() {
        return new RotateVideoProcessor();
    }
}
