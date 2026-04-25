import 'dart:convert';

/// The kind of account activity recorded in [AccountEntry].
enum AccountEntryType {
  giftCardRecharge,
  tradeBuy,
  tradeSell,
}

/// A unified account-history record that covers gift-card recharges and trades.
/// ETH blockchain transactions are still handled separately via [TxRecord].
class AccountEntry {
  AccountEntry({
    required this.id,
    required this.type,
    required this.date,
    // ── Gift card fields ────────────────────────────────────────────────────
    this.cardType,
    this.cardCode,
    this.amount,
    this.currency,
    // ── Trade fields ────────────────────────────────────────────────────────
    this.tradeAsset,
    this.tradeMarket,
    this.tradeQuantity,
    this.tradeUnitPrice,
    this.tradeQuoteAsset,
  });

  final String id;
  final AccountEntryType type;
  final DateTime date;

  // Gift card
  final String? cardType;
  final String? cardCode;
  final double? amount;

  /// 'USD' or 'EUR'
  final String? currency;

  // Trade
  final String? tradeAsset;
  final String? tradeMarket;
  final double? tradeQuantity;
  final double? tradeUnitPrice;
  final String? tradeQuoteAsset;

  // ── serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date.toIso8601String(),
        if (cardType != null) 'cardType': cardType,
        if (cardCode != null) 'cardCode': cardCode,
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': currency,
        if (tradeAsset != null) 'tradeAsset': tradeAsset,
        if (tradeMarket != null) 'tradeMarket': tradeMarket,
        if (tradeQuantity != null) 'tradeQuantity': tradeQuantity,
        if (tradeUnitPrice != null) 'tradeUnitPrice': tradeUnitPrice,
        if (tradeQuoteAsset != null) 'tradeQuoteAsset': tradeQuoteAsset,
      };

  factory AccountEntry.fromJson(Map<String, dynamic> json) => AccountEntry(
        id: json['id'] as String,
        type: AccountEntryType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AccountEntryType.giftCardRecharge,
        ),
        date: DateTime.parse(json['date'] as String),
        cardType: json['cardType'] as String?,
        cardCode: json['cardCode'] as String?,
        amount:
            json['amount'] != null ? (json['amount'] as num).toDouble() : null,
        currency: json['currency'] as String?,
        tradeAsset: json['tradeAsset'] as String?,
        tradeMarket: json['tradeMarket'] as String?,
        tradeQuantity: json['tradeQuantity'] != null
            ? (json['tradeQuantity'] as num).toDouble()
            : null,
        tradeUnitPrice: json['tradeUnitPrice'] != null
            ? (json['tradeUnitPrice'] as num).toDouble()
            : null,
        tradeQuoteAsset: json['tradeQuoteAsset'] as String?,
      );

  // ── helpers ───────────────────────────────────────────────────────────────

  static List<AccountEntry> listFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AccountEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<AccountEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());
}
