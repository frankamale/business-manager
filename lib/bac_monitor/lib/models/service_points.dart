class ServicePoint {
  final String id;
  final String name;
  final String facilityName;
  final String servicePointType;

  ServicePoint({
    required this.id,
    required this.name,
    required this.facilityName,
    required this.servicePointType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'facilityName': facilityName,
      'servicePointType': servicePointType,
    };
  }

  factory ServicePoint.fromMap(Map<String, dynamic> map) {
    return ServicePoint(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      facilityName: map['facilityName'] ?? '',
      servicePointType: map['servicepointtype'] ?? '',
    );
  }
}