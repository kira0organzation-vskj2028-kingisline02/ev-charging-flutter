import 'package:intl/intl.dart';

class BookingModel {
  final int id;
  final int chargerId;
  final int driverId;
  final int startTs;
  final int endTs;
  final String status;
  final int amount; // paise
  final int commission; // paise
  final int hostPayout; // paise
  final String payoutStatus;
  final String createdAt;
  final String? chargerTitle;
  final String? chargerAddress;
  final String? connectorType;
  final double? powerKw;
  final String? driverName;
  final String? orderId;
  final String? keyId;

  const BookingModel({
    required this.id,
    required this.chargerId,
    required this.driverId,
    required this.startTs,
    required this.endTs,
    required this.status,
    required this.amount,
    required this.commission,
    required this.hostPayout,
    required this.payoutStatus,
    required this.createdAt,
    this.chargerTitle,
    this.chargerAddress,
    this.connectorType,
    this.powerKw,
    this.driverName,
    this.orderId,
    this.keyId,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as int,
      chargerId: json['charger_id'] as int,
      driverId: json['driver_id'] as int,
      startTs: json['start_ts'] as int,
      endTs: json['end_ts'] as int,
      status: json['status'] as String,
      amount: json['amount'] as int,
      commission: json['commission'] as int,
      hostPayout: json['host_payout'] as int,
      payoutStatus: json['payout_status'] as String? ?? 'PENDING',
      createdAt: json['created_at'] as String? ?? '',
      chargerTitle: json['charger_title'] as String?,
      chargerAddress: json['charger_address'] as String?,
      connectorType: json['connector_type'] as String?,
      powerKw: (json['power_kw'] as num?)?.toDouble(),
      driverName: json['driver_name'] as String?,
      orderId: json['order_id'] as String?,
      keyId: json['key_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'charger_id': chargerId,
      'driver_id': driverId,
      'start_ts': startTs,
      'end_ts': endTs,
      'status': status,
      'amount': amount,
      'commission': commission,
      'host_payout': hostPayout,
      'payout_status': payoutStatus,
      'created_at': createdAt,
      'charger_title': chargerTitle,
      'charger_address': chargerAddress,
      'connector_type': connectorType,
      'power_kw': powerKw,
      'driver_name': driverName,
      'order_id': orderId,
      'key_id': keyId,
    };
  }

  double get amountRupees => amount / 100.0;
  double get hostPayoutRupees => hostPayout / 100.0;

  DateTime get startDateTime => DateTime.fromMillisecondsSinceEpoch(startTs * 1000, isUtc: true).toLocal();
  DateTime get endDateTime => DateTime.fromMillisecondsSinceEpoch(endTs * 1000, isUtc: true).toLocal();

  String get formattedSlot {
    final df = DateFormat('EEE, d MMM yyyy, hh:mm a');
    final tf = DateFormat('hh:mm a');
    return '${df.format(startDateTime)} - ${tf.format(endDateTime)}';
  }

  bool get isPending => status == 'PENDING_PAYMENT';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isExpired => status == 'EXPIRED';
}

