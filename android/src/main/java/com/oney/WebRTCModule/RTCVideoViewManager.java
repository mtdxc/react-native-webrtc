package com.oney.WebRTCModule;

import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.common.MapBuilder;
import com.facebook.react.uimanager.NativeViewHierarchyManager;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.UIBlock;
import com.facebook.react.uimanager.UIManagerModule;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.events.RCTEventEmitter;
import org.webrtc.FlvPlayer;
import java.util.Map;

import java.util.HashMap;
import java.util.Map;

public class RTCVideoViewManager extends SimpleViewManager<WebRTCView> {
    private static final String REACT_CLASS = "RTCVideoView";
    private ReactApplicationContext reactContext;
    @Override
    public String getName() {
        return REACT_CLASS;
    }
    public RTCVideoViewManager(ReactApplicationContext context) {
        this.reactContext = context;
    }
    @Override
    public WebRTCView createViewInstance(ThemedReactContext context) {
        return new WebRTCView(context);
    }
    @Override
    public Map getExportedCustomBubblingEventTypeConstants() {
        return MapBuilder.builder()
                .put("onOpen", MapBuilder.of("phasedRegistrationNames", MapBuilder.of("bubbled", "onOpen")))
                .put("onEnd", MapBuilder.of("phasedRegistrationNames", MapBuilder.of("bubbled", "onEnd")))
                .put("onStat", MapBuilder.of("phasedRegistrationNames", MapBuilder.of("bubbled", "onStat")))
                .put("onSeekDone", MapBuilder.of("phasedRegistrationNames", MapBuilder.of("bubbled", "onSeekDone")))
                .put("onDimensionsChange", MapBuilder.of("phasedRegistrationNames", MapBuilder.of("bubbled", "onDimensionsChange")))
        .build();
    }
    /**
     * Sets the indicator which determines whether a specific {@link WebRTCView}
     * is to mirror the video specified by {@code streamURL} during its rendering.
     * For more details, refer to the documentation of the {@code mirror} property
     * of the JavaScript counterpart of {@code WebRTCView} i.e. {@code RTCView}.
     *
     * @param view The {@code WebRTCView} on which the specified {@code mirror} is
     * to be set.
     * @param mirror If the specified {@code WebRTCView} is to mirror the video
     * specified by its associated {@code streamURL} during its rendering,
     * {@code true}; otherwise, {@code false}.
     */
    @ReactProp(name = "mirror")
    public void setMirror(WebRTCView view, boolean mirror) {
        view.setMirror(mirror);
    }

    /**
     * In the fashion of
     * https://www.w3.org/TR/html5/embedded-content-0.html#dom-video-videowidth
     * and https://www.w3.org/TR/html5/rendering.html#video-object-fit, resembles
     * the CSS style {@code object-fit}.
     *
     * @param view The {@code WebRTCView} on which the specified {@code objectFit}
     * is to be set.
     * @param objectFit For details, refer to the documentation of the
     * {@code objectFit} property of the JavaScript counterpart of
     * {@code WebRTCView} i.e. {@code RTCView}.
     */
    @ReactProp(name = "objectFit")
    public void setObjectFit(WebRTCView view, String objectFit) {
        view.setObjectFit(objectFit);
    }

    @ReactProp(name = "streamURL")
    public void setStreamURL(WebRTCView view, String streamURL) {
        view.setStreamURL(streamURL);
    }

    /**
     * Sets the z-order of a specific {@link WebRTCView} in the stacking space of
     * all {@code WebRTCView}s. For more details, refer to the documentation of
     * the {@code zOrder} property of the JavaScript counterpart of
     * {@code WebRTCView} i.e. {@code RTCView}.
     *
     * @param view The {@code WebRTCView} on which the specified {@code zOrder} is
     * to be set.
     * @param zOrder The z-order to set on the specified {@code WebRTCView}.
     */
    @ReactProp(name = "zOrder")
    public void setZOrder(WebRTCView view, int zOrder) {
        view.setZOrder(zOrder);
    }

    /**
     * Sets whether this RTCVideoView should use a TextureView instead of
     * the default SurfaceView for rendering on Android.
     *
     * TextureView is a regular view in the view hierarchy and respects
     * overflow:hidden + borderRadius from parent views. SurfaceView renders
     * on a separate hardware layer and cannot be clipped.
     *
     * @param view The WebRTCView on which the setting is applied.
     * @param useTextureView {@code true} to use TextureView, {@code false}
     *                       to use SurfaceView (default).
     */
    @ReactProp(name = "useTextureView")
    public void setUseTextureView(WebRTCView view, boolean useTextureView) {
        view.setUseTextureView(useTextureView);
    }

    /**
     * Sets the callback for when video dimensions change.
     *
     * @param view The {@code WebRTCView} on which the callback is to be set.
     * @param onDimensionsChange The callback to be called when video dimensions change.
     */
    @ReactProp(name = "onDimensionsChange")
    public void setOnDimensionsChange(WebRTCView view, boolean onDimensionsChange) {
        view.setOnDimensionsChange(onDimensionsChange);
    }

    @ReactProp(name = "stop")
    public void setStop(WebRTCView view, int wait) {
        if(view.player != null)
            view.player.stop(wait!=0);
    }

    @ReactProp(name = "rate", defaultFloat = 1.0f)
    public void setSpeed(WebRTCView view, float v) {
        view.rate = v;
        if (view.player != null)
            view.player.setSpeed(v);
    }
    @ReactProp(name = "volume", defaultFloat = 1.0f)
    public void setVolume(WebRTCView view, float v) {
        view.volume = v;
        if (view.player != null)
            view.player.setVolume(v);
    }
    @ReactProp(name = "pid")
    public void setId(WebRTCView view, String v) {
        view.setPid(v);
    }
    @ReactProp(name = "jitter")
    public void setJitter(WebRTCView view, int v) {
        view.jitter = v;
        if (view.player != null)
            view.player.setJitter(v);
    }
    @ReactProp(name = "playMode")
    public void setPlayMode(WebRTCView view, int v) {
        view.playMode = v;
        if (view.player != null)
            view.player.setPlayMode(v);
    }
    @ReactProp(name = "statInterval")
    public void setStatInterval(WebRTCView view, int v) {
        view.statInterval = v;
        if (view.player != null)
            view.player.setStatInterval(v);
    }

    @ReactProp(name = "cacheSize")
    public void setCacheSize(WebRTCView view, int v) {
        view.cacheSize = v;
        if (view.player != null)
            view.player.setCacheSize(v);
    }
    @ReactProp(name = "paused")
    public void setPaused(WebRTCView view, boolean v) {
        view.paused = v;
        if (view.player != null)
            view.player.setPaused(v);
    }
    @ReactProp(name = "muted")
    public void setMuted(WebRTCView view, boolean v) {
        view.muted = v;
        if (view.player != null)
            view.player.setMuted(v);
    }
    @ReactProp(name = "mutedVideo")
    public void setMutedVideo(WebRTCView view, boolean v) {
        view.mutedVideo = v;
        if (view.player != null)
            view.player.setMutedVideo(v);
    }
    @ReactProp(name = "seek")
    public void setSeek(WebRTCView view, int v) {
        if (view.player != null)
            view.player.seek(v);
    }

    public static interface UICall {
        public void call(FlvPlayer player);
    }
    private void uiCall(int vid, boolean callnil, UICall call) {
        reactContext.getNativeModule(UIManagerModule.class).addUIBlock(new UIBlock() {
            @Override
            public void execute(NativeViewHierarchyManager uiManager) {
                WebRTCView view = (WebRTCView)uiManager.resolveView(vid);
                if (view!=null && view.player != null) {
                    call.call(view.player);
                } else if(callnil) {
                    call.call(null);
                }
            }
        });
    }

    @ReactMethod
    public void seek(int viewTag, int pos) {
        uiCall(viewTag, false, new UICall() {
            @Override
            public void call(FlvPlayer p) {
                p.seek(pos);
            }
        });
    }

    @ReactMethod
    public void stop(int viewTag, int wait) {
        uiCall(viewTag, false, new UICall() {
            @Override
            public void call(FlvPlayer p) {
                p.stop(wait!=0);
            }
        });
    }

    @ReactMethod
    public void position(int viewTag, Promise promise) {
        uiCall(viewTag, true, new UICall() {
            @Override
            public void call(FlvPlayer p) {
                promise.resolve(p!=null?p.position():0);
            }
        });
    }
}
