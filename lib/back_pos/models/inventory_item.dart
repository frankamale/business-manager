class InventoryItem {
  final String ipdid;
  final String id;  // UUID string from API
  final String code;
  final String externalserial;
  final String name;
  final String category;
  final double price;
  final double? costprice;
  final double packsize;
  final String packaging;
  final String packagingid;  // UUID string from API
  final String soldfrom;
  final String shortform;
  final String packagingcode;
  final bool efris;
  final String efrisid;
  final String measurmentunitidefris;
  final String measurmentunit;
  final String measurmentunitid;  // UUID string from API
  final String vatcategoryid;  // UUID string from API
  final String branchid;  // UUID string from API
  final String companyid;  // UUID string from API
  final String? downloadlink;

  InventoryItem({
    required this.ipdid,
    required this.id,
    required this.code,
    required this.externalserial,
    required this.name,
    required this.category,
    required this.price,
    this.costprice,
    required this.packsize,
    required this.packaging,
    required this.packagingid,
    required this.soldfrom,
    required this.shortform,
    required this.packagingcode,
    required this.efris,
    required this.efrisid,
    required this.measurmentunitidefris,
    required this.measurmentunit,
    required this.measurmentunitid,
    required this.vatcategoryid,
    required this.branchid,
    required this.companyid,
    this.downloadlink,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      ipdid: map['ipdid']?.toString() ?? '',
      id: map['id']?.toString() ?? '',  // UUID string from API
      code: map['code']?.toString() ?? '',
      externalserial: map['externalserial']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      price: _toDouble(map['price']),
      costprice: map['costprice'] != null ? _toDouble(map['costprice']) : null,
      packsize: _toDouble(map['packsize']),
      packaging: map['packaging']?.toString() ?? '',
      packagingid: map['packagingid']?.toString() ?? '',  // UUID string from API
      soldfrom: map['soldfrom']?.toString() ?? '',
      shortform: map['shortform']?.toString() ?? '',
      packagingcode: map['packagingcode']?.toString() ?? '',
      efris: map['efris'] == true || map['efris'] == 1,
      efrisid: map['efrisid']?.toString() ?? '',
      measurmentunitidefris: map['measurmentunitidefris']?.toString() ?? '',
      measurmentunit: map['measurmentunit']?.toString() ?? '',
      measurmentunitid: map['measurmentunitid']?.toString() ?? '',  // UUID string from API
      vatcategoryid: map['vatcategoryid']?.toString() ?? '',  // UUID string from API
      branchid: map['branchid']?.toString() ?? '',  // UUID string from API
      companyid: map['companyid']?.toString() ?? '',  // UUID string from API
      downloadlink: map['downloadlink']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ipdid': ipdid,
      'id': id,
      'code': code,
      'externalserial': externalserial,
      'name': name,
      'category': category,
      'price': price,
      'costprice': costprice,
      'packsize': packsize,
      'packaging': packaging,
      'packagingid': packagingid,
      'soldfrom': soldfrom,
      'shortform': shortform,
      'packagingcode': packagingcode,
      'efris': efris ? 1 : 0,
      'efrisid': efrisid,
      'measurmentunitidefris': measurmentunitidefris,
      'measurmentunit': measurmentunit,
      'measurmentunitid': measurmentunitid,
      'vatcategoryid': vatcategoryid,
      'branchid': branchid,
      'companyid': companyid,
      'downloadlink': downloadlink,
    };
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
