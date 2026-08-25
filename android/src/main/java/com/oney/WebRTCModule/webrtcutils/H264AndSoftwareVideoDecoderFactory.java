package com.oney.WebRTCModule.webrtcutils;

import androidx.annotation.Nullable;

import org.webrtc.EglBase;
import org.webrtc.HardwareVideoDecoderFactory;
import org.webrtc.VideoCodecInfo;
import org.webrtc.VideoDecoder;
import org.webrtc.VideoDecoderFactory;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * This is a custom video decoder factory for WebRTC which behaves similarly
 * to the default one in iOS. It supports the following codecs:
 *
 * - In hardware: H.264 (high, baseline)
 * - In software: VP8, VP9, AV1
 */
public class H264AndSoftwareVideoDecoderFactory implements VideoDecoderFactory {
    private final VideoDecoderFactory hardwareVideoDecoderFactory;
    private final VideoDecoderFactory softwareVideoDecoderFactory;
    public static boolean enabled = true;
    public H264AndSoftwareVideoDecoderFactory(@Nullable EglBase.Context eglContext) {
        this.hardwareVideoDecoderFactory = new HardwareVideoDecoderFactory(null);
        this.softwareVideoDecoderFactory = new SoftwareVideoDecoderFactoryProxy();
    }

    @Nullable
    @Override
    public VideoDecoder createDecoder(VideoCodecInfo codecInfo) {
        VideoDecoder ret = null;
        if (enabled && (codecInfo.name.equalsIgnoreCase("H264") || codecInfo.name.equalsIgnoreCase("H265"))) {
            ret = this.hardwareVideoDecoderFactory.createDecoder(codecInfo);
        }
        if (ret == null)
            ret = this.softwareVideoDecoderFactory.createDecoder(codecInfo);
        return ret;
    }

    @Override
    public VideoCodecInfo[] getSupportedCodecs() {
        List<VideoCodecInfo> codecs = new ArrayList<>();

        VideoCodecInfo h264Baseline = null;
        VideoCodecInfo h264High = null;
        if (enabled) {
            VideoCodecInfo[] hwCodecs = this.hardwareVideoDecoderFactory.getSupportedCodecs();
            for (VideoCodecInfo hwCodec : hwCodecs) {
                if (hwCodec.name.equalsIgnoreCase("H264")) {
                    String profileLevel = hwCodec.params.get(VideoCodecInfo.H264_FMTP_PROFILE_LEVEL_ID);
                    if (profileLevel == null) {
                        continue;
                    }
                    if (profileLevel.equalsIgnoreCase(VideoCodecInfo.H264_CONSTRAINED_HIGH_3_1)) {
                        h264High = hwCodec;
                    } else if (profileLevel.equalsIgnoreCase(VideoCodecInfo.H264_CONSTRAINED_BASELINE_3_1)) {
                        h264Baseline = hwCodec;
                    }
                }
            }
        }

        if (h264High != null) {
            codecs.add(h264High);
        }
        if (h264Baseline != null) {
            codecs.add(h264Baseline);
        }
        codecs.addAll(Arrays.asList(this.softwareVideoDecoderFactory.getSupportedCodecs()));

        return codecs.toArray(new VideoCodecInfo[codecs.size()]);
    }
}
