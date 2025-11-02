package com.oney.WebRTCModule;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;
import java.util.Arrays;
import java.util.List;
import java.util.ArrayList;

public class WebRTCModulePackage implements ReactPackage {
    @Override
    public List<NativeModule> createNativeModules(ReactApplicationContext reactContext) {
        List<NativeModule> modules = new ArrayList<>();
        modules.add(new WebRTCModule(reactContext));
        modules.add(new RtcAudioEngineController(reactContext));
        modules.add(new RtcAudioUtil(reactContext));
        modules.add(new RTCVideoViewManager(reactContext));
        return modules;
    }

    @Override
    public List<ViewManager> createViewManagers(ReactApplicationContext reactContext) {
        return Arrays.<ViewManager>asList(new RTCVideoViewManager(reactContext));
    }
}
