import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고 서비스
/// 리워드 광고를 로드하고 표시하는 서비스. 펫 부활 시 리워드 광고를 시청하도록 구현.
///
/// 초기화는 lazy하다 — `MobileAds.instance.initialize()`는 startup에서 1~5초가
/// 소요되는 가장 큰 병목이라 더 이상 main()에서 호출하지 않는다. 대신
/// [showRewardedAd] 첫 호출 시점에 한 번 init되고, 동시 호출이 와도
/// `_initFuture` 캐시로 중복 초기화를 방지한다.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  /// MobileAds SDK 초기화 Future 캐시 — 동시 호출 시 한 번만 실행
  Future<void>? _initFuture;

  /// 테스트 광고 단위 ID (프로덕션에서는 실제 ID로 교체)
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// 외부에서 명시적으로 lazy init을 트리거하고 싶을 때 사용.
  /// 일반 사용 흐름에서는 [showRewardedAd]가 자동으로 호출하므로 직접 호출 불필요.
  Future<void> ensureInitialized() => _ensureInitialized();

  Future<void> _ensureInitialized() {
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      await MobileAds.instance.initialize();
      await _loadRewardedAd();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AdService._doInitialize: $e');
      }
    }
  }

  /// 리워드 광고 로드
  Future<void> _loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: _testRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          if (kDebugMode) {
            debugPrint('AdService: 리워드 광고 로드 완료');
          }
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          if (kDebugMode) {
            debugPrint('AdService: 리워드 광고 로드 실패: ${error.message}');
          }
        },
      ),
    );
  }

  /// 광고 로드 여부
  bool get isAdLoaded => _isAdLoaded;

  /// 리워드 광고 표시
  ///
  /// [onRewarded] 보상 콜백 (광고 시청 완료 시 호출)
  /// [onAdFailed] 광고 로드/표시 실패 콜백 (보상 없이 종료된 경우 호출)
  Future<void> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onAdFailed,
  }) async {
    // 첫 호출이면 여기서 SDK init 후 로드
    await _ensureInitialized();

    if (_rewardedAd == null) {
      await _loadRewardedAd();
      if (_rewardedAd == null) {
        if (kDebugMode) {
          debugPrint('AdService: 광고 로드 실패 - 표시할 광고 없음');
        }
        onAdFailed?.call();
        return;
      }
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        if (kDebugMode) {
          debugPrint('AdService: 광고 표시 실패: ${error.message}');
        }
        onAdFailed?.call();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded();
      },
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
  }
}
