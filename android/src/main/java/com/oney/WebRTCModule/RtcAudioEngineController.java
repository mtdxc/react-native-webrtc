package com.oney.WebRTCModule;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;

import org.webrtc.Logging;
import org.webrtc.RTCAudioEngine;
import org.webrtc.AudioUtil;

import android.media.AudioManager;
import android.util.Base64;

import java.io.File;

/**
 * Created by cqm on 2017/4/18.
 */

public class RtcAudioEngineController extends ReactContextBaseJavaModule {
    ReactApplicationContext context;
    public RtcAudioEngineController(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;
    }
    @Override
    public String getName() {
        return "RtcAudioEngineController";
    }

    @ReactMethod
    void setSpeakerOn(boolean speaker) {
        AudioManager audioManager = (AudioManager)this.context.getSystemService(this.context.AUDIO_SERVICE);
        /* use in RnSound
        if (speaker)
            audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);
        else
            audioManager.setMode(AudioManager.MODE_NORMAL);
        */
        audioManager.setSpeakerphoneOn(speaker);
    }
    @ReactMethod
    public void play(String path, int loop, float vol,Promise promise)
    {
        int ret = RTCAudioEngine.play(path, loop!=0, vol);
        promise.resolve(ret);
    }
    @ReactMethod
    public void play2d(String path, int loop, float vol,Promise promise)
    {
        int ret = RTCAudioEngine.play2d(path, loop!=0, vol);
        promise.resolve(ret);
    }
    @ReactMethod
    public void playMem(int samplerate, int channel, int fmt, float vol, Promise promise)
    {
        int ret = RTCAudioEngine.playMem(samplerate, channel, fmt, vol);
        promise.resolve(ret);
    }
    @ReactMethod
    public void getMemCache(int audioId, Promise promise)
    {
        promise.resolve(RTCAudioEngine.getMemCache(audioId));
    }
    @ReactMethod
    public void fillMem(int audioId, String base64Mem, Promise promise)
    {
        byte[] buff = Base64.decode(base64Mem, Base64.DEFAULT);
        promise.resolve(RTCAudioEngine.fillMem(audioId, buff));
    }
    @ReactMethod
    public void clearMem(int audioId, Promise promise)
    {
        promise.resolve(RTCAudioEngine.clearMem(audioId));
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
    public void getCacheDir(Promise promise)
    {
        promise.resolve(RTCAudioEngine.GetCacheDir());
    }
    @ReactMethod
    public void setCacheDir(String path)
    {
        RTCAudioEngine.SetCacheDir(path);
    }
    @ReactMethod
    public void isFileExist(String path, Promise promise) {
        File file = new File(path);
        promise.resolve(file.exists());
    }
    @ReactMethod
    public void clearCache()
    {
        RTCAudioEngine.ClearCache();
    }

    @ReactMethod
    public void setFinishCallback(int audioId, Promise promise){
        final Promise pms = promise;
        RTCAudioEngine.setFinishCallback(audioId, new RTCAudioEngine.AudioCallback(){
            public void call(int audioID, String path){
                pms.resolve(audioID);
            }
        });
    }
    @ReactMethod
    public void setStartCallback(int audioId, Promise promise){
        final Promise pms = promise;
        RTCAudioEngine.setStartCallback(audioId, new RTCAudioEngine.AudioCallback(){
            public void call(int audioID, String path){
                pms.resolve(audioID);
            }
        });
    }
    @ReactMethod
    public void setCachedCallback(String path, Promise promise){
        final Promise pms = promise;
        RTCAudioEngine.setCachedCallback(path, new RTCAudioEngine.AudioCallback(){
            public void call(int audioID, String path){
                pms.resolve(path);
            }
        });
    }
    @ReactMethod
    public void getFileDuration(String path,Promise promise)
    {
        float ret = RTCAudioEngine.getFileDuration(path);
        promise.resolve(ret);
    }
    @ReactMethod
    public void cache(String path, Promise promise)
    {
        boolean ret = RTCAudioEngine.cache(path);
        promise.resolve(ret);
    }
    @ReactMethod
    public void uncache(String path, Promise promise)
    {
        boolean ret = RTCAudioEngine.uncache(path);
        promise.resolve(ret);
    }
    @ReactMethod
    public void isCached(String path,Promise promise)
    {
        boolean ret = RTCAudioEngine.isCached(path);
        promise.resolve(ret);
    }
    @ReactMethod
    public void uncacheAll(Promise promise)
    {
        int ret = RTCAudioEngine.uncacheAll();
        promise.resolve(ret);
    }

    @ReactMethod
    public void setVolume(int audioId, float vol){
        RTCAudioEngine.setVolume(audioId, vol);
    }
    @ReactMethod
    public void setLoop(int audioId, boolean loop){
        RTCAudioEngine.setLoop(audioId, loop);
    }
    @ReactMethod
    public void pause(int audioId){
        RTCAudioEngine.pause(audioId);
    }
    @ReactMethod
    public void resume(int audioId){
        RTCAudioEngine.resume(audioId);
    }
    @ReactMethod
    public void paused(int audioId, Promise promise){
        promise.resolve(RTCAudioEngine.paused(audioId));
    }
    @ReactMethod
    public void speed(int audioId, Promise promise){
        float ret = RTCAudioEngine.speed(audioId);
        promise.resolve(ret);
    }
    @ReactMethod
    public void setSpeed(int audioId, float val, Promise promise){
        boolean ret = RTCAudioEngine.setSpeed(audioId, val);
        promise.resolve(ret);
    }
    @ReactMethod
    public void stop(int audioId){
        RTCAudioEngine.stop(audioId);
    }
    @ReactMethod
    public void stopAll(){
        RTCAudioEngine.stopAll();
    }
    @ReactMethod
    public void getDuration(int audioId, Promise promise){
        float ret = RTCAudioEngine.getDuration(audioId);
        promise.resolve(ret);
    }
    @ReactMethod
    public void getState(int audioId, Promise promise){
        int ret = RTCAudioEngine.getState(audioId);
        promise.resolve(ret);
    }
    @ReactMethod
    public void getCurrentTime(int audioId, Promise promise){
        float ret = RTCAudioEngine.getCurrentTime(audioId);
        promise.resolve(ret);
    }
    @ReactMethod
    public void setCurrentTime(int audioId, float pos_ms, Promise promise){
        float ret = RTCAudioEngine.setCurrentTime(audioId, pos_ms);
        promise.resolve(ret);
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
    public void fillMem2(int id, ReadableArray pcm, int type, Promise promise) {
        int samples = pcm.size();
        byte[] p = new byte[samples * (type!=0?2:1)];
        for (int i=0; i<samples; i++) {
            if (type ==0) {
                p[i] = (byte)pcm.getInt(i);
            } else {
                short val = type == 3 ? (short) (pcm.getDouble(i) * 32768) : (short)pcm.getInt(i);
                p[2*i] = (byte)(val & 0xFF);
                p[2*i+1] = (byte)(val >> 8 & 0xFF);
            }
        }
        promise.resolve(RTCAudioEngine.fillMem(id, p));
    }
}
