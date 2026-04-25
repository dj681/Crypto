import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_entry.dart';

/// Persists and exposes the unified account history (gift-card recharges,
/// trades).  ETH blockchain transactions are managed separately by
/// [WalletProvider] and [TxRecord].
class AccountHistoryProvider extends ChangeNotifier {
  static const _key = 'account_history';

  List<AccountEntry> _entries = [];

  /// Chronological list, newest first.
  List<AccountEntry> get entries => List.unmodifiable(_entries);

  // ── persistence ────────────────────────────────────────────────────────────

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _entries = AccountEntry.listFromJson(raw);
    }
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, AccountEntry.listToJson(_entries));
  }

  // ── mutations ──────────────────────────────────────────────────────────────

  /// Prepends [entry] and persists.
  void addEntry(AccountEntry entry) {
    _entries = [entry, ..._entries];
    notifyListeners();
    unawaited(_saveState());
  }
}
