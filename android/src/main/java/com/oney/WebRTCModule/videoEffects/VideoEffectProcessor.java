package com.oney.WebRTCModule.videoEffects;

import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoFrame;
import org.webrtc.VideoProcessor;
import org.webrtc.VideoSink;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Lightweight abstraction for an object that can receive video frames, process and add effects in
 * them, and pass them on to another object.
 */
public class VideoEffectProcessor implements VideoProcessor {
    private VideoSink mSink;
    final private SurfaceTextureHelper textureHelper;
    private ArrayList<VideoFrameProcessor> videoFrameProcessors;
    public VideoEffectProcessor(SurfaceTextureHelper textureHelper) {
        this.textureHelper = textureHelper;
        this.videoFrameProcessors = new ArrayList<>();
    }

    public int getProcessCount() {return videoFrameProcessors.size();}
    public VideoFrameProcessor getProcess(int index) {return videoFrameProcessors.get(index);}
    public void clearProcess() {videoFrameProcessors.clear();}
    public int addProcess(VideoFrameProcessor pcs) {
        if(pcs!=null)
            videoFrameProcessors.add(pcs);
        return videoFrameProcessors.size();
    }

    public boolean setProperty(String name, String value, int pcsIdx) {
        if (pcsIdx < 0 || pcsIdx >= videoFrameProcessors.size()) {
           for (VideoFrameProcessor pcs : videoFrameProcessors) {
               if (pcs.setProperty(name, value)) {
                   return true;
               }
           }
        }
        else{
            VideoFrameProcessor pcs = videoFrameProcessors.get(pcsIdx);
            if(pcs != null)
                return pcs.setProperty(name, value);
        }
        return false;
    }

    public String getProperty(String name, int pcsIdx) {
        String ret = null;
        if (pcsIdx < 0 || pcsIdx >= videoFrameProcessors.size()) {
            for (VideoFrameProcessor pcs : videoFrameProcessors) {
                ret = pcs.getProperty(name);
                if (ret!=null) {
                    return ret;
                }
            }
        }
        else{
            VideoFrameProcessor pcs = videoFrameProcessors.get(pcsIdx);
            if(pcs != null)
                ret = pcs.getProperty(name);
        }
        return ret;
    }

    @Override
    public void onCapturerStarted(boolean success) {}

    @Override
    public void onCapturerStopped() {}

    @Override
    public void setSink(VideoSink sink) {
        mSink = sink;
    }

    /**
     * Called just after the frame is captured.
     * Will process the VideoFrame with the help of VideoFrameProcessor and send the processed
     * VideoFrame back to webrtc using onFrame method in VideoSink.
     * @param frame raw VideoFrame received from webrtc.
     */
    @Override
    public void onFrameCaptured(VideoFrame frame) {
        frame.retain();
        VideoFrame outputFrame = frame;
        for (VideoFrameProcessor processor : this.videoFrameProcessors) {
            outputFrame = processor.process(outputFrame, textureHelper);

            if (outputFrame == null) {
                mSink.onFrame(frame);
                frame.release();
                return;
            }
        }

        mSink.onFrame(outputFrame);
        if (outputFrame != frame) {
            outputFrame.release();
        }
        frame.release();
    }
}
