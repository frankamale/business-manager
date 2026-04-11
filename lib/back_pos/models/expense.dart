class Expense {
  final String id;
  final String title;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? servicePointId;
  final String? subject;
  final String uploadStatus;
  final int? createdAt;

  Expense({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.servicePointId,
    this.subject,
    this.uploadStatus = 'pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'date': date.millisecondsSinceEpoch,
      'servicePointId': servicePointId,
      'subject': subject,
      'upload_status': uploadStatus,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      servicePointId: map['servicePointId'],
      subject: map['subject'],
      uploadStatus: map['upload_status'] ?? 'pending',
      createdAt: map['created_at'],
    );
  }
}

// Predefined expense categories
class ExpenseCategory {
  static const String food = 'Food';
  static const String transport = 'Transport';
  static const String supplies = 'Supplies';
  static const String utilities = 'Utilities';
  static const String rent = 'Rent';
  static const String maintenance = 'Maintenance';
  static const String salaries = 'Salaries';
  static const String marketing = 'Marketing';
  static const String other = 'Other';

  static List<String> get all => [
        food,
        transport,
        supplies,
        utilities,
        rent,
        maintenance,
        salaries,
        marketing,
        other,
      ];
}