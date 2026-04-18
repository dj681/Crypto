import 'package:flutter_test/flutter_test.dart';
import 'package:my_crypto_safe/services/blockchain_service.dart';

void main() {
  group('BlockchainService - RPC URL normalization', () {
    test('uses default public RPC when url is null', () async {
      final service = BlockchainService();
      expect(service.rpcUrl, 'https://ethereum.publicnode.com');
      await service.dispose();
    });

    test('uses default public RPC when url is empty', () async {
      final service = BlockchainService(rpcUrl: '   ');
      expect(service.rpcUrl, 'https://ethereum.publicnode.com');
      await service.dispose();
    });

    test('replaces legacy Ankr RPC URL on init', () async {
      final service = BlockchainService(rpcUrl: 'https://rpc.ankr.com/eth');
      expect(service.rpcUrl, 'https://ethereum.publicnode.com');
      await service.dispose();
    });

    test('removes trailing slash on init for custom URL', () async {
      final service = BlockchainService(rpcUrl: 'https://example.com/rpc/');
      expect(service.rpcUrl, 'https://example.com/rpc');
      await service.dispose();
    });

    test('normalizes URL when updating RPC endpoint', () async {
      final service = BlockchainService(rpcUrl: 'https://example.com/rpc');
      service.updateRpcUrl('https://rpc.ankr.com/eth/');
      expect(service.rpcUrl, 'https://ethereum.publicnode.com');
      await service.dispose();
    });
  });
}
