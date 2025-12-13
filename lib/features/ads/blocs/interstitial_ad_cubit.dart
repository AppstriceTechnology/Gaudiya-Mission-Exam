import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ironsource_mediation/ironsource_mediation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

sealed class InterstitialAdState {
  const InterstitialAdState();
}

final class InterstitialAdInitial extends InterstitialAdState {
  const InterstitialAdInitial();
}

final class InterstitialAdLoaded extends InterstitialAdState {
  const InterstitialAdLoaded();
}

final class InterstitialAdLoadInProgress extends InterstitialAdState {
  const InterstitialAdLoadInProgress();
}

final class InterstitialAdFailToLoad extends InterstitialAdState {
  const InterstitialAdFailToLoad();
}

class InterstitialAdCubit extends Cubit<InterstitialAdState>
    with LevelPlayInterstitialAdListener {
  InterstitialAdCubit() : super(const InterstitialAdInitial());

  InterstitialAd? _interstitialAd;
  late LevelPlayInterstitialAd _ironSourceAd;

  InterstitialAd? get interstitialAd => _interstitialAd;

  final unityPlacementName = Platform.isIOS
      ? 'Interstitial_iOS'
      : 'Interstitial_Android';

  void _createGoogleInterstitialAd(BuildContext context) {
    InterstitialAd.load(
      adUnitId: context.read<SystemConfigCubit>().googleInterstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          emit(const InterstitialAdLoaded());
        },
        onAdFailedToLoad: (err) {
          emit(const InterstitialAdFailToLoad());
        },
      ),
    );
  }

  void _createUnityAds() {
    UnityAds.load(
      placementId: unityPlacementName,
      onComplete: (placementId) => emit(const InterstitialAdLoaded()),
      onFailed: (placementId, err, msg) =>
          emit(const InterstitialAdFailToLoad()),
    );
  }

  Future<void> _createIronSourceAd(String adUnitId) async {
    _ironSourceAd = LevelPlayInterstitialAd(adUnitId: adUnitId);
    _ironSourceAd.setListener(this);
    await _ironSourceAd.loadAd();
  }

  void createInterstitialAd(BuildContext context) {
    // Ads disabled - no ads will be shown
    emit(const InterstitialAdFailToLoad());
  }

  Future<void> showAd(BuildContext context) async {
    // Ads disabled - no ads will be shown
    log('Ad display disabled', name: 'InterstitialAdCubit');
  }

  @override
  Future<void> close() async {
    await _interstitialAd?.dispose();
    await _ironSourceAd.dispose();

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
    log('onAdDisplayFailed $adInfo', name: 'LevelPlay', error: error);
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
    emit(const InterstitialAdFailToLoad());
    log('onAdLoadFailed', name: 'LevelPlay', error: error);
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    emit(const InterstitialAdLoaded());
    log('onAdLoaded $adInfo', name: 'LevelPlay');
  }
}
