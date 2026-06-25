class StockTakeSession {
  final String id;
  final String reference;
  final String note;
  final String? servicePointId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String uploadStatus;

  final int itemCount;
  final double totalAmount;

  StockTakeSession({
    required this.id,
    required this.reference,
    required this.note,
    required this.servicePointId,
    required this.createdAt,
    required this.updatedAt,
    this.uploadStatus = 'pending',
    this.itemCount = 0,
    this.totalAmount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'note': note,
      'servicepointid': servicePointId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'upload_status': uploadStatus,
    };
  }

  factory StockTakeSession.fromMap(Map<String, dynamic> map) {
    return StockTakeSession(
      id: map['id']?.toString() ?? '',
      reference: map['reference']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      servicePointId: map['servicepointid']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
      uploadStatus: map['upload_status']?.toString() ?? 'pending',
      itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  StockTakeSession copyWith({
    String? reference,
    String? note,
    DateTime? updatedAt,
    String? uploadStatus,
  }) {
    return StockTakeSession(
      id: id,
      reference: reference ?? this.reference,
      note: note ?? this.note,
      servicePointId: servicePointId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      itemCount: itemCount,
      totalAmount: totalAmount,
    );
  }
}
