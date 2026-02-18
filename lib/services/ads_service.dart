import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Manages banner ads for free users.
/// Crash-safe: all operations wrapped in try-catch.
class AdsService {
  // Google test ad unit ID -- replace with real ID for production
  static const _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Whether the Mobile Ads SDK initialized successfully.
  static bool available = false;

  BannerAd? _bannerAd;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Initialize the Mobile Ads SDK (call from post-frame, non-blocking).
  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      available = true;
    } catch (e) {
      available = false;
      debugPrint('[SafeShell] MobileAds init failed: $e');
    }
  }

  /// Load a banner ad. No-op if SDK not available.
  void loadBannerAd({VoidCallback? onLoaded}) {
    if (!available) return;

    try {
      _bannerAd = BannerAd(
        adUnitId: _bannerAdUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isLoaded = true;
            onLoaded?.call();
          },
          onAdFailedToLoad: (ad, error) {
            _isLoaded = false;
            ad.dispose();
            _bannerAd = null;
            debugPrint('[SafeShell] Banner ad failed: $error');
          },
        ),
      );
      _bannerAd?.load();
    } catch (e) {
      debugPrint('[SafeShell] Banner ad load error: $e');
    }
  }

  /// Get the banner ad widget. Returns null if not loaded.
  Widget? getBannerWidget() {
    if (_bannerAd == null || !_isLoaded) return null;
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  /// Dispose of the banner ad.
  void dispose() {
    try {
      _bannerAd?.dispose();
    } catch (_) {}
    _bannerAd = null;
    _isLoaded = false;
  }
}
