package com.waraqawqalam.store;

import android.annotation.SuppressLint;
import android.app.DownloadManager;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.net.http.SslError;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.SslErrorHandler;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import java.util.Locale;

public class MainActivity extends android.app.Activity {
    private static final String HOME = "https://waraqawqalam.com/";
    private static final String CHECKOUT = "https://waraqawqalam.com/checkout.html";
    private static final String LOGIN = "https://waraqawqalam.com/staff-login.html";
    private static final int FILE_CHOOSER_REQUEST = 1001;

    private WebView webView;
    private ProgressBar progressBar;
    private FrameLayout errorLayer;
    private ValueCallback<Uri[]> filePathCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        configureWebView();
        registerPredictiveBackHandler();
        if (savedInstanceState == null) {
            Uri data = getIntent().getData();
            webView.loadUrl(data != null ? data.toString() : HOME);
        } else {
            webView.restoreState(savedInstanceState);
        }
    }

    private void buildUi() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(247, 244, 237));

        LinearLayout vertical = new LinearLayout(this);
        vertical.setOrientation(LinearLayout.VERTICAL);
        vertical.setLayoutDirection(View.LAYOUT_DIRECTION_RTL);

        progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setMax(100);
        progressBar.setProgress(0);
        progressBar.setVisibility(View.GONE);
        vertical.addView(progressBar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(3)));

        webView = new WebView(this);
        vertical.addView(webView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        LinearLayout nav = new LinearLayout(this);
        nav.setOrientation(LinearLayout.HORIZONTAL);
        nav.setGravity(Gravity.CENTER);
        nav.setPadding(dp(6), dp(4), dp(6), dp(6));
        nav.setBackgroundColor(Color.WHITE);
        nav.setElevation(dp(10));
        addNavButton(nav, "الرئيسية", "⌂", v -> webView.loadUrl(HOME));
        addNavButton(nav, "الأقسام", "▦", v -> openCategories());
        addNavButton(nav, "السلة", "🛒", v -> webView.loadUrl(CHECKOUT));
        addNavButton(nav, "الحساب", "◉", v -> webView.loadUrl(LOGIN));
        addNavButton(nav, "مشاركة", "↗", v -> shareCurrentPage());
        vertical.addView(nav, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(62)));

        root.addView(vertical, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        errorLayer = makeErrorLayer();
        errorLayer.setVisibility(View.GONE);
        root.addView(errorLayer, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);
    }

    private void addNavButton(LinearLayout nav, String label, String icon, View.OnClickListener listener) {
        LinearLayout item = new LinearLayout(this);
        item.setOrientation(LinearLayout.VERTICAL);
        item.setGravity(Gravity.CENTER);
        TextView iv = new TextView(this);
        iv.setText(icon);
        iv.setTextSize(20);
        iv.setGravity(Gravity.CENTER);
        iv.setTextColor(Color.rgb(15, 31, 51));
        TextView lv = new TextView(this);
        lv.setText(label);
        lv.setTextSize(11);
        lv.setGravity(Gravity.CENTER);
        lv.setTextColor(Color.rgb(15, 31, 51));
        item.addView(iv, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        item.addView(lv, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        item.setOnClickListener(listener);
        nav.addView(item, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f));
    }

    private FrameLayout makeErrorLayer() {
        FrameLayout layer = new FrameLayout(this);
        layer.setBackgroundColor(Color.rgb(247, 244, 237));
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(Gravity.CENTER);
        box.setPadding(dp(30), dp(30), dp(30), dp(30));
        TextView title = new TextView(this);
        title.setText("تعذر الاتصال بالمتجر");
        title.setTextSize(22);
        title.setTextColor(Color.rgb(15, 31, 51));
        title.setGravity(Gravity.CENTER);
        TextView sub = new TextView(this);
        sub.setText("تأكد من اتصال الإنترنت ثم حاول مرة أخرى");
        sub.setTextSize(14);
        sub.setTextColor(Color.DKGRAY);
        sub.setGravity(Gravity.CENTER);
        sub.setPadding(0, dp(12), 0, dp(18));
        Button retry = new Button(this);
        retry.setText("إعادة المحاولة");
        retry.setOnClickListener(v -> {
            errorLayer.setVisibility(View.GONE);
            webView.reload();
        });
        box.addView(title);
        box.addView(sub);
        box.addView(retry);
        layer.addView(box, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER));
        return layer;
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void configureWebView() {
        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setLoadsImagesAutomatically(true);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(false);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setDisplayZoomControls(false);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);

        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return handleUrl(request.getUrl());
            }

            @Override
            @SuppressWarnings("deprecation")
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                return handleUrl(Uri.parse(url));
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                progressBar.setVisibility(View.GONE);
                errorLayer.setVisibility(View.GONE);
                view.evaluateJavascript("javascript:(function(){var m=document.querySelector('meta[name=viewport]');if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}m.content='width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no';document.documentElement.style.webkitTextSizeAdjust='100%';})()", null);
            }

            @Override
            @SuppressWarnings("deprecation")
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                progressBar.setVisibility(View.GONE);
                if (failingUrl != null && failingUrl.equals(view.getUrl())) errorLayer.setVisibility(View.VISIBLE);
            }

            @Override
            public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                handler.cancel();
                Toast.makeText(MainActivity.this, "تعذر إنشاء اتصال آمن بالمتجر", Toast.LENGTH_LONG).show();
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onProgressChanged(WebView view, int p) {
                progressBar.setProgress(p);
                progressBar.setVisibility(p >= 100 ? View.GONE : View.VISIBLE);
            }

            @Override
            public boolean onShowFileChooser(WebView w, ValueCallback<Uri[]> cb, FileChooserParams params) {
                if (filePathCallback != null) filePathCallback.onReceiveValue(null);
                filePathCallback = cb;
                try {
                    startActivityForResult(params.createIntent(), FILE_CHOOSER_REQUEST);
                } catch (Exception e) {
                    filePathCallback = null;
                    Toast.makeText(MainActivity.this, "لا يوجد مدير ملفات متاح", Toast.LENGTH_SHORT).show();
                    return false;
                }
                return true;
            }
        });

        webView.setDownloadListener((url, ua, cd, mime, len) -> {
            try {
                DownloadManager.Request r = new DownloadManager.Request(Uri.parse(url));
                r.setMimeType(mime);
                r.addRequestHeader("User-Agent", ua);
                r.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                r.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "waraqa_download");
                ((DownloadManager) getSystemService(DOWNLOAD_SERVICE)).enqueue(r);
                Toast.makeText(this, "بدأ التحميل", Toast.LENGTH_SHORT).show();
            } catch (Exception e) {
                openExternal(url);
            }
        });
    }

    private boolean handleUrl(Uri uri) {
        String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
        String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(Locale.ROOT);
        if (scheme.equals("https") && (host.equals("waraqawqalam.com") || host.endsWith(".waraqawqalam.com"))) return false;
        if (scheme.equals("tel") || scheme.equals("mailto") || scheme.equals("sms") || scheme.equals("geo") || scheme.equals("market") || scheme.equals("whatsapp") || scheme.equals("intent")) {
            openExternal(uri.toString());
            return true;
        }
        if (scheme.equals("http") || scheme.equals("https")) {
            openExternal(uri.toString());
            return true;
        }
        return false;
    }

    private void openCategories() {
        if (webView.getUrl() == null || !webView.getUrl().startsWith(HOME)) {
            webView.loadUrl(HOME);
            webView.postDelayed(this::clickCategoriesWithJs, 850);
        } else {
            clickCategoriesWithJs();
        }
    }

    private void clickCategoriesWithJs() {
        webView.evaluateJavascript("(function(){var els=[].slice.call(document.querySelectorAll('a,button'));var el=els.find(function(x){return (x.innerText||'').trim().indexOf('الأقسام')>=0;});if(el){el.click();return 'clicked';}window.scrollTo({top:0,behavior:'smooth'});return 'not-found';})()", null);
    }

    private void shareCurrentPage() {
        String url = webView.getUrl() == null ? HOME : webView.getUrl();
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("text/plain");
        send.putExtra(Intent.EXTRA_SUBJECT, "ورقة وقلم");
        send.putExtra(Intent.EXTRA_TEXT, url);
        startActivity(Intent.createChooser(send, "مشاركة"));
    }

    private void openExternal(String url) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (Exception e) {
            Toast.makeText(this, "لا يوجد تطبيق لفتح هذا الرابط", Toast.LENGTH_SHORT).show();
        }
    }

    private void registerPredictiveBackHandler() {
        if (Build.VERSION.SDK_INT >= 33) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                    android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                    this::handleBackNavigation);
        }
    }

    private void handleBackNavigation() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            finish();
        }
    }

    @Override
    @SuppressLint("GestureBackNavigation")
    public void onBackPressed() {
        if (Build.VERSION.SDK_INT < 33) {
            handleBackNavigation();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        webView.saveState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == FILE_CHOOSER_REQUEST) {
            if (filePathCallback != null) {
                filePathCallback.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data));
                filePathCallback = null;
            }
            return;
        }
        super.onActivityResult(requestCode, resultCode, data);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
