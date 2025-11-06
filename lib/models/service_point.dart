class ServicePoint {
  final String id;
  final String name;
  final String code;
  final String fullName;
  final String servicepointtype;
  final String facilityName;
  final bool sales;
  final bool stores;
  final bool production;
  final bool booking;

  ServicePoint({
    required this.id,
    required this.name,
    required this.code,
    required this.fullName,
    required this.servicepointtype,
    required this.facilityName,
    required this.sales,
    required this.stores,
    required this.production,
    required this.booking,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'fullName': fullName,
      'servicepointtype': servicepointtype,
      'facilityName': facilityName,
      'sales': sales ? 1 : 0,
      'stores': stores ? 1 : 0,
      'production': production ? 1 : 0,
      'booking': booking ? 1 : 0,
    };
  }

  factory ServicePoint.fromMap(Map<String, dynamic> map) {
    return ServicePoint(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      fullName: map['fullName'] ?? '',
      servicepointtype: map['servicepointtype'] ?? '',
      facilityName: map['facilityName'] ?? (map['facility']?['name'] ?? ''),
      sales: map['sales'] == 1 || map['sales'] == true,
      stores: map['stores'] == 1 || map['stores'] == true,
      production: map['production'] == 1 || map['production'] == true,
      booking: map['booking'] == 1 || map['booking'] == true,
    );
  }
}
