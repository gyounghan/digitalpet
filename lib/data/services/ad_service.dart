import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고 서비스
/// 리워드 광고를 로드하고 표시하는 서비스
/// 펫 부활 시 리워드 광고를 시청하도록 구현
class AdService {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  /// 테스트 광고 단위 ID (프로덕션에서는 실제 ID로 교체)
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// 광고 서비스 초기화
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      await _loadRewardedAd();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AdService.initialize: $e');
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
  Future<void> showRewardedAd({
    required void Function() onRewarded,
  }) async {
    if (_rewardedAd == null) {
      await _loadRewardedAd();
      if (_rewardedAd == null) return;
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
