package com.oney.WebRTCModule.videoEffects;

import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoFrame;

public class RotateVideoProcessor implements  VideoFrameProcessor {
    public int rotate = 0;
    public VideoFrame process(VideoFrame frame, SurfaceTextureHelper textureHelper) {
        if (frame == null || rotate == 0) return frame;
        int newRotate = (frame.getRotation() + rotate) % 360;
        VideoFrame out = new VideoFrame(frame.getBuffer(), newRotate, frame.getTimestampNs());
        out.retain();
        return out;
    }

    public boolean setProperty(String name, String value) {
        boolean ret = false;
        if (name.equalsIgnoreCase("rotate")) {
            rotate = Integer.valueOf(value) / 90 * 90;
            ret = true;
        }
        return false;
    }

    public String getProperty(String name) {
        String ret = null;
        if (name.equalsIgnoreCase("rotate")) {
            ret = String.format("%d", rotate);
        }
        return ret;
    }
}

