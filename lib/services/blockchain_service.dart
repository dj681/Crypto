import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import '../models/tx_record.dart';

/// Manages the web3dart RPC client and all blockchain read/write operations.
class BlockchainService {
  BlockchainService({String? rpcUrl})
      : _rpcUrl = rpcUrl ?? _defaultRpcUrl,
        _httpClient = http.Client() {
    _initClient();
  }

  static const String _defaultRpcUrl = 'https://rpc.ankr.com/eth';

  String _rpcUrl;
  final http.Client _httpClient;
  late Web3Client _client;

  String get rpcUrl => _rpcUrl;

  void _initClient() {
    _client = Web3Client(_rpcUrl, _httpClient);
  }

  /// Reconfigures the RPC endpoint (e.g. when the user changes it in Settings).
  void updateRpcUrl(String url) {
    if (url == _rpcUrl) return;
    _rpcUrl = url;
    _client.dispose();
    _initClient();
  }

  // ── balance ───────────────────────────────────────────────────────────────

  /// Returns the ETH balance for [address] in ether units.
  /// Throws on network / RPC errors — callers should catch and handle.
  Future<double> getBalance(String address) async {
    final ethAddress = EthereumAddress.fromHex(address);
    final amount = await _client
        .getEtherBalance(ethAddress)
        .timeout(const Duration(seconds: 20));
    return amount.getValueInUnit(EtherUnit.ether).toDouble();
  }

  // ── gas price ─────────────────────────────────────────────────────────────

  /// Returns the current gas price in gwei.
  Future<double> getGasPrice() async {
    final price = await _client
        .getGasPrice()
        .timeout(const Duration(seconds: 10));
    return price.getValueInUnit(EtherUnit.gwei).toDouble();
  }

  // ── nonce ─────────────────────────────────────────────────────────────────

  Future<int> getNonce(String address) async {
    final ethAddress = EthereumAddress.fromHex(address);
    return _client
        .getTransactionCount(ethAddress)
        .timeout(const Duration(seconds: 10));
  }

  // ── send transaction ──────────────────────────────────────────────────────

  /// Signs and broadcasts an ETH transfer.
  ///
  /// [credentials] — the sender's private key.
  /// [toAddress]   — recipient (0x-prefixed).
  /// [amountEth]   — amount in ether.
  /// [chainId]     — 1 for mainnet, 11155111 for Sepolia, etc.
  ///
  /// Returns the transaction hash.
  Future<String> sendEth({
    required EthPrivateKey credentials,
    required String toAddress,
    required double amountEth,
    int chainId = 1,
  }) async {
    final amountWei =
        BigInt.from((amountEth * 1e18).toInt());

    final txHash = await _client.sendTransaction(
      credentials,
      Transaction(
        to: EthereumAddress.fromHex(toAddress),
        value: EtherAmount.inWei(amountWei),
        maxGas: 21000,
      ),
      chainId: chainId,
    );
    return txHash;
  }

  // ── transaction receipt ───────────────────────────────────────────────────

  /// Polls for a transaction receipt and returns its status.
  /// Returns [TxStatus.pending] if the receipt is not yet available.
  Future<TxStatus> getTransactionStatus(String txHash) async {
    try {
      final receipt = await _client
          .getTransactionReceipt(txHash)
          .timeout(const Duration(seconds: 10));
      if (receipt == null) return TxStatus.pending;
      return receipt.status == true ? TxStatus.confirmed : TxStatus.failed;
    } catch (_) {
      return TxStatus.pending;
    }
  }

  // ── cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _client.dispose();
    _httpClient.close();
  }
}
