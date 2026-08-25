package com.oney.WebRTCModule.videoEffects;

import android.util.Log;

import com.pixpark.gpupixel.FaceDetector;
import com.pixpark.gpupixel.GPUPixel;
import com.pixpark.gpupixel.GPUPixelFilter;
import com.pixpark.gpupixel.GPUPixelSinkRawData;
import com.pixpark.gpupixel.GPUPixelSourceRawData;

import org.webrtc.JavaI420Buffer;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoFrame;
import java.util.ArrayList;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.util.concurrent.atomic.AtomicInteger;

public class GpuPixelVideoProcessor implements VideoFrameProcessor {
    private GPUPixelSourceRawData input;
    private GPUPixelFilter beautyFaceFilter = null;
    private GPUPixelFilter faceReshapFilter = null;
    private GPUPixelFilter lipstickFilter = null;
    private ArrayList<GPUPixelFilter> filterList = new ArrayList<>();
    private FaceDetector faceDetector = null;
    private GPUPixelSinkRawData output;
    public AtomicInteger frame_count;
    public static String TAG = GpuPixelVideoProcessor.class.getName();
    private float[] faceLandmarks;
    public float[] getFaceLandmarks() {
        if (faceDetector == null) {
            faceDetector = FaceDetector.Create();
        }
        return faceLandmarks;
    }

    private boolean liteMode;
    static VideoFrame.I420Buffer wrapI420(int width, int height, byte[] data) {
        final int posY = 0;
        final int posU = width * height;
        final int posV = posU + width * height / 4;
        final int endV = posV + width * height / 4;

        ByteBuffer buffer = ByteBuffer.allocateDirect(data.length);
        buffer.put(data);

        buffer.limit(posU);
        buffer.position(posY);
        ByteBuffer dataY = buffer.slice();

        buffer.limit(posV);
        buffer.position(posU);
        ByteBuffer dataU = buffer.slice();

        buffer.limit(endV);
        buffer.position(posV);
        ByteBuffer dataV = buffer.slice();

        return JavaI420Buffer.wrap(width, height, dataY, width, dataU, width / 2, dataV, width / 2,
                /* releaseCallback= */ null);
    }

    public GpuPixelVideoProcessor(boolean lite) {
        liteMode = lite;
        frame_count = new AtomicInteger(0);
        initFilter();
    }

    public void initFilter() {
        Log.i(TAG, "initFilter");
        input = GPUPixelSourceRawData.Create();
        output = GPUPixelSinkRawData.Create();
        beautyFaceFilter = GPUPixelFilter.Create(GPUPixelFilter.BEAUTY_FACE_FILTER);
        filterList.clear();
        filterList.add(beautyFaceFilter);
        beautyFaceFilter.AddSink(output);
        if (!liteMode) {
            faceReshapFilter = GPUPixelFilter.Create(GPUPixelFilter.FACE_RESHAPE_FILTER);
            lipstickFilter = GPUPixelFilter.Create(GPUPixelFilter.LIPSTICK_FILTER);
            filterList.add(faceReshapFilter);
            filterList.add(lipstickFilter);
            getFaceLandmarks();
            input.AddSink(lipstickFilter);
            lipstickFilter.AddSink(faceReshapFilter);
            faceReshapFilter.AddSink(beautyFaceFilter);
        } else {
            input.AddSink(beautyFaceFilter);
        }
    }

    public VideoFrame process(VideoFrame frame, SurfaceTextureHelper textureHelper){
        if (input==null ||frame_count.get()>10) {
            frame_count.decrementAndGet();
            return null;
        }
        frame_count.getAndAdd(1);
        int rotation = frame.getRotation();
        VideoFrame.I420Buffer buff = frame.getBuffer().toI420();
        byte[] rgba = new byte[buff.getWidth() * buff.getHeight() * 4];
        GPUPixel.nativeYUV420ToRGBA(buff.getDataY(), buff.getDataV(), buff.getDataU(),
                buff.getWidth(), buff.getHeight(),
                buff.getStrideY(), buff.getStrideV(), buff.getStrideU(),
                1, 1, 1, rgba);
        byte[] rotRgba = GPUPixel.rotateRgbaImage(rgba, buff.getWidth(), buff.getHeight(), rotation);
        int width = frame.getRotatedWidth();
        int height = frame.getRotatedHeight();
        if (faceDetector!=null) {
            float[] landmarks = faceDetector.detect(rotRgba, width, height, width * 4,
                    FaceDetector.GPUPIXEL_MODE_FMT_VIDEO,
                    FaceDetector.GPUPIXEL_FRAME_TYPE_RGBA);
            if (landmarks != null && landmarks.length > 0) {
                this.faceLandmarks = landmarks;
                Log.d(TAG, "Face landmarks detected: " + landmarks.length);
                if (faceReshapFilter!=null) {
                    faceReshapFilter.SetProperty("face_landmark", landmarks);
                }
                if (lipstickFilter!=null) {
                    lipstickFilter.SetProperty("face_landmark", landmarks);
                }
            }
        }
        // Process the rotated RGBA data with GPUPixelSourceRawData
        input.ProcessData(rotRgba, width, height, width * 4,
                GPUPixelSourceRawData.FRAME_TYPE_RGBA);
        // Get processed RGBA data
        byte[] outYuv = output.GetI420Buffer();
        // Set texture data and request redraw
        if (outYuv != null) {
            frame_count.decrementAndGet();
            VideoFrame.I420Buffer i420 = wrapI420(output.GetWidth(), output.GetHeight(), outYuv);
            return new VideoFrame(i420, 0, frame.getTimestampNs());
        }
        return null;
    }

    public boolean setProperty(String name, String val) {
        return setProperty(name, Float.parseFloat(val));
    }

    public boolean setProperty(String name, float val) {
        for(int i = 0; i < filterList.size(); i++) {
            GPUPixelFilter filter = filterList.get(i);
            if (filter != null && filter.SetProperty(name, val)) {
                return true;
            }
        }
        return false;
    }

    public String getProperty(String name) {
        return Float.toString(getPropertyFloat(name));
    }

    public float getPropertyFloat(String name) {
        float ret = 0;
        for(int i = 0; i < filterList.size(); i++) {
            GPUPixelFilter filter = filterList.get(i);
            if (filter != null && filter.HasProperty(name, "")) {
                ret = filter.GetPropertyFloat(name);
                break;
            }
        }
        return ret;
    }
}
