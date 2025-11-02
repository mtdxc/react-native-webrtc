package com.oney.WebRTCModule.videoEffects;

public class GpuPixelProcessorFactory implements VideoFrameProcessorFactoryInterface {
    private boolean lite;
    public GpuPixelProcessorFactory(boolean val){
        lite = val;
    }
    public VideoFrameProcessor build(){
        return new GpuPixelVideoProcessor(lite);
    }
}
