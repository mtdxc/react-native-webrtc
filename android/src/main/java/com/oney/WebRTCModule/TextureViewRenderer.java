package com.oney.WebRTCModule;

import android.content.Context;
import android.graphics.Matrix;
import android.graphics.SurfaceTexture;
import android.opengl.EGL14;
import android.util.Log;
import android.view.TextureView;

import org.webrtc.EglBase;
import org.webrtc.EglRenderer;
import org.webrtc.GlRectDrawer;
import org.webrtc.RendererCommon;
import org.webrtc.VideoFrame;
import org.webrtc.VideoSink;

import java.util.concurrent.atomic.AtomicBoolean;

public class TextureViewRenderer extends TextureView implements VideoSink {
    private static final String TAG = "TextureViewRenderer";

    private static final int[] EGL_CONFIG_ATTRIBUTES = new int[] {
        EGL14.EGL_RED_SIZE, 8,
        EGL14.EGL_GREEN_SIZE, 8,
        EGL14.EGL_BLUE_SIZE, 8,
        EGL14.EGL_ALPHA_SIZE, 8,
        EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
        EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
        EGL14.EGL_NONE,
    };

    private final EglRenderer eglRenderer;
    private boolean isInitialized;
    private RendererCommon.RendererEvents rendererEvents;

    private int frameWidth;
    private int frameHeight;
    private int frameRotation;

    public TextureViewRenderer(Context context) {
        super(context);
        this.eglRenderer = new EglRenderer("TextureViewRenderer");
        setSurfaceTextureListener(surfaceTextureListener);
    }

    public void init(EglBase.Context sharedContext, RendererCommon.RendererEvents rendererEvents) {
        if (isInitialized) return;
        this.rendererEvents = rendererEvents;
        eglRenderer.init(sharedContext, EGL_CONFIG_ATTRIBUTES, new GlRectDrawer());
        isInitialized = true;
    }

    public void release() {
        if (isInitialized) {
            eglRenderer.release();
            isInitialized = false;
        }
    }

    @Override
    public void onFrame(VideoFrame frame) {
        eglRenderer.onFrame(frame);
        updateFrameDimensions(frame);
    }

    private void updateFrameDimensions(VideoFrame frame) {
        int rotation = frame.getRotation();
        int width = frame.getRotatedWidth();
        int height = frame.getRotatedHeight();

        boolean changed = false;
        if (frameWidth != width || frameHeight != height || frameRotation != rotation) {
            frameWidth = width;
            frameHeight = height;
            frameRotation = rotation;
            changed = true;
        }

        if (changed && rendererEvents != null) {
            rendererEvents.onFrameResolutionChanged(width, height, rotation);
            postUpdateTransform();
        }
    }

    private void postUpdateTransform() {
        if (transformUpdatePending.compareAndSet(false, true)) {
            boolean posted = post(() -> {
                transformUpdatePending.set(false);
                updateTransform();
            });
            if (!posted) {
                transformUpdatePending.set(false);
            }
        }
    }

    private void updateTransform() {
        requestLayout();

        int viewWidth = getWidth();
        int viewHeight = getHeight();
        if (viewWidth <= 0 || viewHeight <= 0 || frameWidth <= 0 || frameHeight <= 0) {
            return;
        }

        float frameAspect = (float) frameWidth / frameHeight;
        float viewAspect = (float) viewWidth / viewHeight;
        transformMatrix.reset();
        Matrix matrix = transformMatrix;
        boolean fill = scalingType == RendererCommon.ScalingType.SCALE_ASPECT_FILL;
        if (fill ? frameAspect > viewAspect : frameAspect < viewAspect) {
            float displayWidth = viewHeight * frameAspect;
            float scaleX = displayWidth / viewWidth;
            float translateX = -(displayWidth - viewWidth) / 2f;
            matrix.setScale(scaleX, 1f);
            matrix.postTranslate(translateX, 0);
        } else {
            float displayHeight = viewWidth / frameAspect;
            float scaleY = displayHeight / viewHeight;
            float translateY = -(displayHeight - viewHeight) / 2f;
            matrix.setScale(1f, scaleY);
            matrix.postTranslate(0, translateY);
        }
        if (mirror) {
            flipMatrix.reset();
            Matrix flip = flipMatrix;
            flip.setScale(-1f, 1f);
            flip.postTranslate(viewWidth, 0f);
            matrix.postConcat(flip);
        }
        setTransform(matrix);
    }

    public void setName(String name) {
        eglRenderer.setName(name);
    }

    public void setMirror(boolean mirror) {
        this.mirror = mirror;
        postUpdateTransform();
    }

    public void setScalingType(RendererCommon.ScalingType scalingType) {
        this.scalingType = scalingType;
        postUpdateTransform();
    }

    @Override
    protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
        super.onSizeChanged(width, height, oldWidth, oldHeight);
        updateTransform();
    }

    private RendererCommon.ScalingType scalingType = RendererCommon.ScalingType.SCALE_ASPECT_FIT;
    private boolean mirror;
    private final Matrix transformMatrix = new Matrix();
    private final Matrix flipMatrix = new Matrix();
    private final AtomicBoolean transformUpdatePending = new AtomicBoolean(false);

    private final SurfaceTextureListener surfaceTextureListener = new SurfaceTextureListener() {
        @Override
        public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
            Log.d(TAG, "Surface texture available: " + width + "x" + height);
            if (isInitialized) {
                eglRenderer.createEglSurface(surface);
            }
        }

        @Override
        public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
            if (!isInitialized) return false;
            Log.d(TAG, "Surface texture destroyed");
            eglRenderer.releaseEglSurface(() -> surface.release());
            return true;
        }

        @Override
        public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
            Log.d(TAG, "Surface texture size changed: " + width + "x" + height);
            if (width > 0 && height > 0 && isInitialized) {
                eglRenderer.releaseEglSurface(new Runnable() {
                    @Override
                    public void run() {
                        // No-op
                    }
                });
                eglRenderer.createEglSurface(surface);
            }
        }

        @Override
        public void onSurfaceTextureUpdated(SurfaceTexture surface) {
            // No-op
        }
    };
}
