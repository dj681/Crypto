import 'package:flutter/foundation.dart';

import '../models/tx_record.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';

enum WalletStatus { idle, loading, ready, error }

/// Global wallet state: holds the loaded wallet model and transaction history.
class WalletProvider extends ChangeNotifier {
  WalletProvider(this._service);

  final WalletService _service;

  WalletModel? _wallet;
  List<TxRecord> _history = [];
  WalletStatus _status = WalletStatus.idle;
  String? _error;

  WalletModel? get wallet => _wallet;
  List<TxRecord> get history => List.unmodifiable(_history);
  WalletStatus get status => _status;
  String? get error => _error;
  bool get hasWallet => _wallet != null;
  bool get isLoading => _status == WalletStatus.loading;

  // ── load ──────────────────────────────────────────────────────────────────

  /// Loads the persisted wallet (if any) from secure storage.
  Future<void> loadWallet() async {
    _setLoading();
    try {
      _wallet = await _service.loadWallet();
      if (_wallet != null) {
        _history = await _service.loadHistory();
      }
      _status = WalletStatus.ready;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── create ────────────────────────────────────────────────────────────────

  /// Generates a new mnemonic and returns it (not yet persisted).
  String generateMnemonic() => _service.generateMnemonic();

  /// Creates a wallet from a verified mnemonic, persists it, and updates state.
  Future<void> createWallet(String mnemonic) async {
    _setLoading();
    try {
      _wallet = await _service.createWallet(mnemonic);
      _history = [];
      _status = WalletStatus.ready;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  // ── import ────────────────────────────────────────────────────────────────

  /// Imports a wallet from a user-supplied mnemonic phrase.
  /// Throws [ArgumentError] if the mnemonic is invalid.
  Future<void> importWallet(String mnemonic) async {
    _setLoading();
    try {
      _wallet = await _service.importWallet(mnemonic);
      _history = await _service.loadHistory();
      _status = WalletStatus.ready;
      notifyListeners();
    } on ArgumentError catch (e) {
      _setError(e.message as String? ?? 'La phrase de récupération fournie n\'est pas valide.');
      rethrow;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  // ── history ───────────────────────────────────────────────────────────────

  Future<void> appendTransaction(TxRecord record) async {
    await _service.appendTransaction(record);
    _history = await _service.loadHistory();
    notifyListeners();
  }

  // ── security flags ────────────────────────────────────────────────────────

  Future<void> setPinEnabled({required bool enabled}) async {
    if (_wallet == null) return;
    await _service.setPinEnabled(enabled: enabled);
    _wallet = _wallet!.copyWith(hasPinEnabled: enabled);
    notifyListeners();
  }

  Future<void> setBiometricsEnabled({required bool enabled}) async {
    if (_wallet == null) return;
    await _service.setBiometricsEnabled(enabled: enabled);
    _wallet = _wallet!.copyWith(hasBiometricsEnabled: enabled);
    notifyListeners();
  }

  // ── clear ─────────────────────────────────────────────────────────────────

  Future<void> clearWallet() async {
    await _service.clearWallet();
    _wallet = null;
    _history = [];
    _status = WalletStatus.idle;
    notifyListeners();
  }

  // ── internals ─────────────────────────────────────────────────────────────

  void _setLoading() {
    _status = WalletStatus.loading;
    _error = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = WalletStatus.error;
    _error = message;
    notifyListeners();
  }
}
