import 'dart:developer';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ironsource_mediation/ironsource_mediation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

sealed class RewardedAdState {
  const RewardedAdState();
}

final class RewardedAdInitial extends RewardedAdState {
  const RewardedAdInitial();
}

final class RewardedAdLoaded extends RewardedAdState {
  const RewardedAdLoaded();
}

final class RewardedAdLoadInProgress extends RewardedAdState {
  const RewardedAdLoadInProgress();
}

final class RewardedAdFailure extends RewardedAdState {
  const RewardedAdFailure();
}

class RewardedAdCubit extends Cubit<RewardedAdState>
    with LevelPlayRewardedAdListener {
  RewardedAdCubit() : super(const RewardedAdInitial());

  RewardedAd? _rewardedAd;
  late LevelPlayRewardedAd _ironSourceAd;

  RewardedAd? get rewardedAd => _rewardedAd;

  final unityPlacementName = Platform.isIOS
      ? 'Rewarded_iOS'
      : 'Rewarded_Android';

  Future<void> _createGoogleRewardedAd(BuildContext context) async {
    await _rewardedAd?.dispose();
    await RewardedAd.load(
      adUnitId: context.read<SystemConfigCubit>().googleRewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdFailedToLoad: (error) {
          log(error.message, name: 'Create Google Ads');
          emit(const RewardedAdFailure());
        },
        onAdLoaded: (ad) {
          _rewardedAd = ad;

          emit(const RewardedAdLoaded());
        },
      ),
    );
  }

  Future<void> createUnityRewardsAd() async {
    await UnityAds.load(
      placementId: unityPlacementName,
      onComplete: (placementId) => emit(const RewardedAdLoaded()),
      onFailed: (p, e, m) => emit(const RewardedAdFailure()),
    );
  }

  Future<void> _createIronSourceAd(String adUnitId) async {
    _ironSourceAd = LevelPlayRewardedAd(adUnitId: adUnitId);
    _ironSourceAd.setListener(this);
    await _ironSourceAd.loadAd();
  }

  Future<void> createRewardedAd(BuildContext context) async {
    // Ads disabled - no ads will be shown
    emit(const RewardedAdFailure());
  }

  Future<void> createDailyRewardAd(BuildContext context) async {
    // Ads disabled - no ads will be shown
    emit(const RewardedAdFailure());
  }

  Future<void> showDailyAd({required BuildContext context}) async {
    // Ads disabled - no ads will be shown
    log('Daily ad display disabled', name: 'RewardedAdCubit');
  }

  Future<void> showAd({
    required VoidCallback onAdDismissedCallback,
    required BuildContext context,
  }) async {
    // Ads disabled - no ads will be shown
    // Still execute the callback to maintain app flow
    onAdDismissedCallback();
    log('Ad display disabled', name: 'RewardedAdCubit');
  }

  @override
  Future<void> close() async {
    await _rewardedAd?.dispose();
    return super.close();
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    log('onAdClicked $adInfo', name: 'LevelPlay');
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    log('onAdClosed $adInfo', name: 'LevelPlay');
  }

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    log('onAdDisplayFailed $adInfo', name: 'LevelPlay');
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    log('onAdDisplayed $adInfo', name: 'LevelPlay');
  }

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {
    log('onAdInfoChanged $adInfo', name: 'LevelPlay');
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    emit(const RewardedAdFailure());
    log('onAdLoadFailed', name: 'LevelPlay', error: error);
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    emit(const RewardedAdLoaded());
    log('onAdLoaded $adInfo', name: 'LevelPlay');
  }

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    log('onAdRewarded $adInfo', name: 'LevelPlay');
  }
}
