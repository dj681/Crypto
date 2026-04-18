import 'package:flutter/foundation.dart';

import '../models/tx_record.dart';
import '../services/blockchain_service.dart';
import '../services/wallet_service.dart';

enum BlockchainStatus { idle, loading, ready, error }

/// Manages blockchain data: ETH balance and transaction broadcasting.
class BlockchainProvider extends ChangeNotifier {
  BlockchainProvider({
    required BlockchainService blockchainService,
    required WalletService walletService,
  })  : _blockchain = blockchainService,
        _walletService = walletService;

  final BlockchainService _blockchain;
  final WalletService _walletService;

  double? _balance;
  double? _gasPrice;
  BlockchainStatus _status = BlockchainStatus.idle;
  String? _error;

  double? get balance => _balance;
  double? get gasPrice => _gasPrice;
  BlockchainStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _status == BlockchainStatus.loading;
  String get rpcUrl => _blockchain.rpcUrl;

  // ── refresh ───────────────────────────────────────────────────────────────

  /// Fetches the current ETH balance for [address].
  Future<void> refreshBalance(String address) async {
    _status = BlockchainStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _balance = await _blockchain.getBalance(address);
      _gasPrice = await _blockchain.getGasPrice();
      _status = BlockchainStatus.ready;
    } catch (e) {
      _error = 'Impossible de récupérer le solde : $e';
      _status = BlockchainStatus.error;
    }
    notifyListeners();
  }

  // ── send ──────────────────────────────────────────────────────────────────

  /// Signs and sends an ETH transfer.
  /// Saves the transaction to local history.
  /// Returns the tx hash on success.
  Future<String> sendEth({
    required String fromAddress,
    required String toAddress,
    required double amountEth,
    int chainId = 1,
  }) async {
    final credentials = await _walletService.loadCredentials();
    if (credentials == null) throw StateError('Aucun portefeuille chargé.');

    final txHash = await _blockchain.sendEth(
      credentials: credentials,
      toAddress: toAddress,
      amountEth: amountEth,
      chainId: chainId,
    );

    final record = TxRecord(
      txHash: txHash,
      from: fromAddress,
      to: toAddress,
      valueEth: amountEth,
      timestamp: DateTime.now(),
      status: TxStatus.pending,
    );
    await _walletService.appendTransaction(record);

    // Refresh balance after sending.
    await refreshBalance(fromAddress);

    return txHash;
  }

  // ── RPC config ────────────────────────────────────────────────────────────

  void updateRpcUrl(String url) {
    _blockchain.updateRpcUrl(url);
    notifyListeners();
  }
}
