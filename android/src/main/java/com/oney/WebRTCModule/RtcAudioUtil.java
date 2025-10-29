package com.oney.WebRTCModule;

import android.util.Base64;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.WritableArray;

import org.webrtc.AudioUtil;
import org.webrtc.Logging;


public class RtcAudioUtil extends ReactContextBaseJavaModule {

    public RtcAudioUtil(ReactApplicationContext reactContext) {
        super(reactContext);
    }
    @Override
    public String getName() {
        return "RtcAudioUtil";
    }

    @ReactMethod
    public void ZipLog(String path, Promise promise)
    {
        promise.resolve(Logging.ZipLog(path));
    }
    @ReactMethod
    public void LogOut(String tag, String msg)
    {
        Logging.d(tag, msg);
    }
    @ReactMethod
    public void GetFormat(String path, Promise promise)
    {
        promise.resolve(AudioUtil.GetFormat(path));
    }
    @ReactMethod
    public void FormatExt(int fmt, Promise promise)
    {
        promise.resolve(AudioUtil.FormatExt(fmt));
    }

    @ReactMethod
    public void WavOpen(String path, int channel, int samplerate, Promise promise)
    {
        promise.resolve(AudioUtil.WavOpen(path, channel, samplerate));
    }
    @ReactMethod
    public void WavSamplerate(int handle, Promise promise) {
        promise.resolve(AudioUtil.WavSamplerate(handle));
    }
    @ReactMethod
    public void WavChannels(int handle, Promise promise) {
        promise.resolve(AudioUtil.WavChannels(handle));
    }
    @ReactMethod
    public void WavTotalSamples(int handle, Promise promise) {
        promise.resolve(AudioUtil.WavTotalSamples(handle));
    }
    @ReactMethod
    public void WavClose(int handle, Promise promise) {
        promise.resolve(AudioUtil.WavClose(handle));
    }
    @ReactMethod
    public void WavWrite(int handle, ReadableArray jpcm, int fmt, Promise promise)
    {
        short[] pcm = new short[jpcm.size()];
        for (int i =0; i<jpcm.size(); i++) {
            if (fmt == 0) {
                pcm[i] = (short)jpcm.getInt(i);
            }
            else{
               pcm[i] = (short)(jpcm.getDouble(i) * 32768);
            }
        }
        promise.resolve(AudioUtil.WavWrite(handle, pcm));
    }
    @ReactMethod
    public void WavRead(int handle, int samples, int fmt, Promise promise)
    {
        short[] pcm = new short[samples];
        int ret = AudioUtil.WavRead(handle, pcm);
        WritableArray array = Arguments.createArray();
        for (int i =0; i < ret; i++) {
            if (fmt == 0) {
                array.pushInt(pcm[i]);
            }
            else{
                array.pushDouble(pcm[i]/32768.0);
            }
        }
        promise.resolve(array);
    }

    @ReactMethod
    public void WavToMp3(String path, String mp3, int bitrate, Promise promise)
    {
        int ret = AudioUtil.WavToMp3(path, mp3, bitrate);
        promise.resolve(ret);
    }
    @ReactMethod
    public void AacToWav(String path, String wav, Promise promise)
    {
        int ret = AudioUtil.AacToWav(path, wav);
        promise.resolve(ret);
    }
    @ReactMethod
    public void WavToAac(String path, String aac, int bitrate, Promise promise)
    {
        int ret = AudioUtil.WavToAac(path, aac, bitrate);
        promise.resolve(ret);
    }
    @ReactMethod
    public void Mp3ToWav(String path, String wav, Promise promise)
    {
        int ret = AudioUtil.Mp3ToWav(path, wav);
        promise.resolve(ret);
    }
    @ReactMethod
    public void FlacToWav(String path, String wav, Promise promise)
    {
        int ret = AudioUtil.FlacToWav(path, wav);
        promise.resolve(ret);
    }

    @ReactMethod
    public void AudioEncOpen(int fmt, int samplerate, int channel, int bitrate, Promise promise) {
        int ret = AudioUtil.AudioEncOpen(fmt, samplerate, channel, bitrate);
        promise.resolve(ret);
    }
    @ReactMethod
    public void AudioEncode(int id, ReadableArray pcm, Promise promise) {
        int samples = AudioUtil.AudioEncFrameSample(id);
        if (pcm.size() < samples) {
            promise.reject("array size error");
            return ;
        }

        boolean isFloat = true;
        short[] p = new short[samples];
        for (int i=0; i<samples; i++) {
            if (pcm.getDouble(i) > 1.0) {
                isFloat = false;
                break;
            }
        }

        for (int i=0; i<samples; i++) {
            p[i] = isFloat ? (short) (pcm.getDouble(i) * 32768) : (short)pcm.getInt(i);
        }
        byte[] ret = AudioUtil.AudioEncode(id, p);
        if (ret!=null)
            promise.resolve(Base64.encodeToString(ret, Base64.DEFAULT));
        else
            promise.resolve("");
    }
    @ReactMethod
    public void AudioEncClose(int id) {
        AudioUtil.AudioEncClose(id);
    }
    @ReactMethod
    public void AudioEncFrameSample(int id, Promise promise) {
        promise.resolve(AudioUtil.AudioEncFrameSample(id));
    }
}
