/// Represents a locally recorded transaction (sent or received).
class TxRecord {
  const TxRecord({
    required this.txHash,
    required this.from,
    required this.to,
    required this.valueEth,
    required this.timestamp,
    this.status = TxStatus.pending,
    this.gasUsed,
  });

  final String txHash;
  final String from;
  final String to;

  /// Value expressed in ETH (not wei).
  final double valueEth;
  final DateTime timestamp;
  final TxStatus status;
  final BigInt? gasUsed;

  bool get isSent => from.toLowerCase() == from.toLowerCase();

  TxRecord copyWith({TxStatus? status, BigInt? gasUsed}) {
    return TxRecord(
      txHash: txHash,
      from: from,
      to: to,
      valueEth: valueEth,
      timestamp: timestamp,
      status: status ?? this.status,
      gasUsed: gasUsed ?? this.gasUsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'txHash': txHash,
        'from': from,
        'to': to,
        'valueEth': valueEth,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'gasUsed': gasUsed?.toString(),
      };

  factory TxRecord.fromJson(Map<String, dynamic> json) => TxRecord(
        txHash: json['txHash'] as String,
        from: json['from'] as String,
        to: json['to'] as String,
        valueEth: (json['valueEth'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        status: TxStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => TxStatus.pending,
        ),
        gasUsed: json['gasUsed'] != null
            ? BigInt.tryParse(json['gasUsed'] as String)
            : null,
      );

  @override
  String toString() =>
      'TxRecord(hash: ${txHash.substring(0, 10)}…, value: $valueEth ETH, status: $status)';
}

enum TxStatus { pending, confirmed, failed }
