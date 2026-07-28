import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// Central ad manager using Google Mobile Ads SDK with AdMob Mediation support.
/// Features:
/// 1. Google UMP (User Messaging Platform) GDPR/Consent Flow.
/// 2. Exponential backoff retry strategy (prevents infinite loops and micro-stutters).
/// 3. Memory leak protection (proper disposal of failed/timed-out ad instances).
/// 4. Seamless rewarded ad fallback.
class AdManager {
  // ── AdMob State ─────────────────────────────────────────────────────────────
  InterstitialAd? _admobInterstitial;
  bool _isAdmobInterstitialLoaded = false;
  int _interstitialRetryCount = 0;

  RewardedAd? _admobRewarded;
  bool _isAdmobRewardedLoaded = false;
  int _rewardedRetryCount = 0;

  int _levelsSinceLastInterstitial = 0;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // ── Initialization & UMP Consent ───────────────────────────────────────────
  Future<void> initialize() async {
    if (!AppConstants.enableAdMob) return;

    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
            if (formError != null) {
              debugPrint('AdMob UMP Form Error: ${formError.message}');
            }
            await _initMobileAds();
          });
        } else {
          await _initMobileAds();
        }
      },
      (error) async {
        debugPrint('AdMob UMP Request Error: ${error.message}');
        await _initMobileAds();
      },
    );
  }

  Future<void> _initMobileAds() async {
    await MobileAds.instance.initialize();
    _isInitialized = true;
    _loadAdmobInterstitial();
    _loadAdmobRewarded();
  }

  // ── Interstitial Ad Management ─────────────────────────────────────────────
  void _loadAdmobInterstitial() {
    if (!AppConstants.enableAdMob || _isAdmobInterstitialLoaded) return;

    InterstitialAd.load(
      adUnitId: AppConstants.admobInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _admobInterstitial = ad;
          _isAdmobInterstitialLoaded = true;
          _interstitialRetryCount = 0; // Reset backoff counter on success
          ad.setImmersiveMode(true);
          debugPrint('AdMob: Interstitial loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _isAdmobInterstitialLoaded = false;
          _admobInterstitial = null;
          debugPrint('AdMob: Interstitial failed to load ($error). Retry count: $_interstitialRetryCount');

          // Exponential backoff: 5s, 15s, 45s (max 3 retries)
          if (_interstitialRetryCount < 3) {
            _interstitialRetryCount++;
            final delay = Duration(seconds: 5 * _interstitialRetryCount * _interstitialRetryCount);
            Future.delayed(delay, () => _loadAdmobInterstitial());
          }
        },
      ),
    );
  }

  // ── Rewarded Ad Management ──────────────────────────────────────────────────
  void _loadAdmobRewarded() {
    if (!AppConstants.enableAdMob || _isAdmobRewardedLoaded) return;

    RewardedAd.load(
      adUnitId: AppConstants.admobRewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _admobRewarded = ad;
          _isAdmobRewardedLoaded = true;
          _rewardedRetryCount = 0; // Reset backoff counter on success
          debugPrint('AdMob: Rewarded ad loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _isAdmobRewardedLoaded = false;
          _admobRewarded = null;
          debugPrint('AdMob: Rewarded ad failed to load ($error). Retry count: $_rewardedRetryCount');

          // Exponential backoff: 5s, 15s, 45s (max 3 retries)
          if (_rewardedRetryCount < 3) {
            _rewardedRetryCount++;
            final delay = Duration(seconds: 5 * _rewardedRetryCount * _rewardedRetryCount);
            Future.delayed(delay, () => _loadAdmobRewarded());
          }
        },
      ),
    );
  }

  // ── Interstitial Flow ──────────────────────────────────────────────────────
  Future<void> onLevelComplete(int levelNumber, bool isSpecialLevel) async {
    if (isSpecialLevel) return; // No interstitial ads on boss/god levels
    _levelsSinceLastInterstitial++;
    if (_levelsSinceLastInterstitial >= AppConstants.interstitialEveryNLevels) {
      await showInterstitial();
    }
  }

  Future<void> showInterstitial() async {
    if (!AppConstants.enableAdMob) return;

    if (_isAdmobInterstitialLoaded && _admobInterstitial != null) {
      final completer = Completer<void>();
      final ad = _admobInterstitial!;
      _admobInterstitial = null;
      _isAdmobInterstitialLoaded = false;
      _levelsSinceLastInterstitial = 0;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAdmobInterstitial(); // Pre-load next ad
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadAdmobInterstitial();
          if (!completer.isCompleted) completer.complete();
        },
      );

      await ad.show();
      return completer.future;
    } else {
      // Ad not ready: trigger background load without blocking game flow
      _loadAdmobInterstitial();
    }
  }

  // ── Rewarded Flow ──────────────────────────────────────────────────────────
  bool get isRewardedAvailable => AppConstants.enableAdMob;

  Future<void> showRewarded({
    required void Function() onRewarded,
    void Function()? onDismissed,
  }) async {
    bool rewardEarned = false;

    void handleSuccess() {
      if (!rewardEarned) {
        rewardEarned = true;
        onRewarded();
      }
    }

    void handleFinish() {
      onDismissed?.call();
    }

    // 1. Try pre-loaded rewarded ad
    if (_isAdmobRewardedLoaded && _admobRewarded != null) {
      final ad = _admobRewarded!;
      _admobRewarded = null;
      _isAdmobRewardedLoaded = false;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAdmobRewarded();
          handleFinish();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadAdmobRewarded();
          // Fallback reward on show failure so player isn't stuck
          handleSuccess();
          handleFinish();
        },
      );

      await ad.show(
        onUserEarnedReward: (ad, rewardItem) {
          debugPrint('AdMob: Rewarded ad completed! Granted: ${rewardItem.amount} ${rewardItem.type}');
          handleSuccess();
        },
      );
      return;
    }

    // 2. Try fast 3-second on-demand load
    final onDemandAd = await _loadAdmobRewardedOnDemand(const Duration(seconds: 3));
    if (onDemandAd != null) {
      onDemandAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAdmobRewarded();
          handleFinish();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadAdmobRewarded();
          handleSuccess();
          handleFinish();
        },
      );

      await onDemandAd.show(
        onUserEarnedReward: (ad, rewardItem) {
          debugPrint('AdMob: Rewarded ad completed! Granted: ${rewardItem.amount} ${rewardItem.type}');
          handleSuccess();
        },
      );
      return;
    }

    // 3. Fallback: If ad network has no inventory, grant reward so player feature works
    debugPrint('AdMob ad inventory unavailable. Granting fallback reward.');
    handleSuccess();
    handleFinish();
    _loadAdmobRewarded();
  }

  Future<RewardedAd?> _loadAdmobRewardedOnDemand(Duration timeout) {
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: AppConstants.admobRewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) {
            completer.complete(ad);
          } else {
            // Received after timeout expired: dispose immediately to avoid memory leaks
            ad.dispose();
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(null);
        return null;
      },
    );
  }

  void dispose() {
    _admobInterstitial?.dispose();
    _admobRewarded?.dispose();
    _admobInterstitial = null;
    _admobRewarded = null;
  }
}
