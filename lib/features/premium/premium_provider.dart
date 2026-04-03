import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/tts_service.dart';

const String _premiumPrefsKey = 'tikbox_premium_state_v1';
const String _premiumMonthlyId = 'tikbox_premium_monthly';
const int _freeDailyTtsLimit = 50;
const int _freeQueueLimit = 10;
const int _premiumQueueLimit = 20;

class PremiumState {
  final bool isPremium;
  final bool isLoading;
  final bool storeAvailable;
  final int dailyTtsCount;
  final String dailyUsageDate;
  final String? promptMessage;
  final String? purchaseMessage;
  final List<ProductDetails> products;
  final bool isInitialized; // [修正済み]

  const PremiumState({
    this.isPremium = false,
    this.isLoading = true,
    this.storeAvailable = false,
    this.dailyTtsCount = 0,
    this.dailyUsageDate = '',
    this.promptMessage,
    this.purchaseMessage,
    this.products = const [],
    this.isInitialized = false, // [修正済み]
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? isLoading,
    bool? storeAvailable,
    int? dailyTtsCount,
    String? dailyUsageDate,
    String? promptMessage,
    String? purchaseMessage,
    List<ProductDetails>? products,
    bool clearPromptMessage = false,
    bool clearPurchaseMessage = false,
    bool? isInitialized, // [修正済み]
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      dailyTtsCount: dailyTtsCount ?? this.dailyTtsCount,
      dailyUsageDate: dailyUsageDate ?? this.dailyUsageDate,
      promptMessage:
          clearPromptMessage ? null : (promptMessage ?? this.promptMessage),
      purchaseMessage: clearPurchaseMessage
          ? null
          : (purchaseMessage ?? this.purchaseMessage),
      products: products ?? this.products,
      isInitialized: isInitialized ?? this.isInitialized, // [修正済み]
    );
  }

  int get freeRemainingReads {
    if (isPremium) {
      return -1;
    }
    final remaining = _freeDailyTtsLimit - dailyTtsCount;
    return remaining < 0 ? 0 : remaining;
  }
}

class PremiumNotifier extends Notifier<PremiumState> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  SharedPreferences? _prefs;

  @override
  PremiumState build() {
    unawaited(_initialize());
    ref.onDispose(() => _purchaseSub?.cancel());
    return const PremiumState();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPersistedState();
    await _setupStore();
    try {
      state = state.copyWith(isInitialized: true); // [修正済み]
    } catch (_) {
      return;
    }
  }

  Future<void> _loadPersistedState() async {
    final raw = _prefs?.getString(_premiumPrefsKey);
    if (raw == null) {
      final today = _todayKey();
      try {
        state = state.copyWith(
          dailyUsageDate: today,
          isLoading: false,
        ); // [修正済み]
      } catch (_) {
        return;
      }
      _applyTierConfig();
      return;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedDate = json['dailyUsageDate']?.toString() ?? _todayKey();
      final today = _todayKey();
      final isSameDay = savedDate == today;
      try {
        state = state.copyWith(
          isPremium: json['isPremium'] as bool? ?? false,
          dailyTtsCount: isSameDay ? (json['dailyTtsCount'] as int? ?? 0) : 0,
          dailyUsageDate: today,
          isLoading: false,
        ); // [修正済み]
      } catch (_) {
        return;
      }
      _applyTierConfig();
    } catch (_) {
      try {
        state = state.copyWith(
          dailyUsageDate: _todayKey(),
          isLoading: false,
        ); // [修正済み]
      } catch (_) {
        return;
      }
      _applyTierConfig();
    }
  }

  Future<void> _setupStore() async {
    final available = await _iap.isAvailable();
    try {
      state = state.copyWith(storeAvailable: available); // [修正済み]
    } catch (_) {
      return;
    }

    _purchaseSub ??= _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        try {
          state = state.copyWith(
            purchaseMessage: '購入処理でエラーが発生しました: $error',
          ); // [修正済み]
        } catch (_) {}
      },
    );

    if (!available) {
      await _persist();
      return;
    }

    final response = await _iap.queryProductDetails({_premiumMonthlyId});
    if (response.error != null) {
      try {
        state = state.copyWith(
          purchaseMessage: response.error!.message,
        ); // [修正済み]
      } catch (_) {}
    }

    try {
      state = state.copyWith(products: response.productDetails); // [修正済み]
    } catch (_) {
      return;
    }
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      _premiumPrefsKey,
      jsonEncode({
        'isPremium': state.isPremium,
        'dailyTtsCount': state.dailyTtsCount,
        'dailyUsageDate': state.dailyUsageDate,
      }),
    );
  }

  Future<void> buyPremium() async {
    if (!state.storeAvailable) {
      state = state.copyWith(
        purchaseMessage: 'ストアに接続できませんでした',
      );
      return;
    }

    final product = state.products.isEmpty ? null : state.products.first;
    if (product == null) {
      state = state.copyWith(
        purchaseMessage: '購入商品が見つかりません',
      );
      return;
    }

    state = state.copyWith(
      purchaseMessage: '購入処理を開始しています...',
      clearPromptMessage: true,
    );

    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(
      purchaseMessage: '購入情報を復元しています...',
      clearPromptMessage: true,
    );
    await _iap.restorePurchases();
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          state = state.copyWith(
            isPremium: true,
            purchaseMessage: 'プレミアムが有効になりました',
            clearPromptMessage: true,
          );
          _applyTierConfig();
          unawaited(_persist());
          break;
        case PurchaseStatus.error:
          state = state.copyWith(
            purchaseMessage: purchase.error?.message ?? '購入に失敗しました',
          );
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(
            purchaseMessage: '購入はキャンセルされました',
          );
          break;
        case PurchaseStatus.pending:
          state = state.copyWith(
            purchaseMessage: '購入確認を待っています...',
          );
          break;
      }

      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
    }
  }

  Future<bool> consumeTtsAllowance() async {
    if (!state.isInitialized) return false; // [修正済み]

    _rolloverDailyCountIfNeeded();

    if (state.isPremium) {
      return true;
    }

    if (state.dailyTtsCount >= _freeDailyTtsLimit) {
      state = state.copyWith(
        promptMessage: 'もっと快適に使うにはプレミアムへ。無料枠は1日50回までです。',
      );
      return false;
    }

    state = state.copyWith(
      dailyTtsCount: state.dailyTtsCount + 1,
      clearPromptMessage: true,
    );
    await _persist();
    return true;
  }

  bool canUseVoice(Map<String, String>? voice) {
    if (voice == null || state.isPremium) {
      return true;
    }
    return !_isPremiumVoice(voice);
  }

  void showUpgradePrompt(String message) {
    state = state.copyWith(promptMessage: message);
  }

  void clearUpgradePrompt() {
    state = state.copyWith(clearPromptMessage: true);
  }

  void clearPurchaseMessage() {
    state = state.copyWith(clearPurchaseMessage: true);
  }

  int get queueLimit => state.isPremium ? _premiumQueueLimit : _freeQueueLimit;

  int giftPriorityBoost() => state.isPremium ? 300 : 120;

  bool get hasPremiumGiftEffects => state.isPremium;

  void _applyTierConfig() {
    ttsService.setQueueLimit(queueLimit);
  }

  void _rolloverDailyCountIfNeeded() {
    final today = _todayKey();
    if (state.dailyUsageDate == today) {
      return;
    }

    state = state.copyWith(
      dailyUsageDate: today,
      dailyTtsCount: 0,
    );
    unawaited(_persist());
  }

  bool _isPremiumVoice(Map<String, String> voice) {
    final name = (voice['name'] ?? '').toLowerCase();
    final quality = (voice['quality'] ?? '').toLowerCase();
    final identifier = (voice['identifier'] ?? '').toLowerCase();
    return name.contains('enhanced') ||
        name.contains('premium') ||
        name.contains('neural') ||
        quality.contains('premium') ||
        quality.contains('enhanced') ||
        identifier.contains('neural');
  }

  String _todayKey() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }
}

final premiumProvider =
    NotifierProvider<PremiumNotifier, PremiumState>(PremiumNotifier.new);
