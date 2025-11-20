class InventoryItem {
  final String ipdid;
  final String id;
  final String code;
  final String externalserial;
  final String name;
  final String category;
  final double price;
  final double? costprice;
  final double packsize;
  final String packaging;
  final String packagingid;
  final String soldfrom;
  final String shortform;
  final String packagingcode;
  final bool efris;
  final String efrisid;
  final String measurmentunitidefris;
  final String measurmentunit;
  final String measurmentunitid;
  final String vatcategoryid;
  final String branchid;
  final String companyid;
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
      ipdid: map['ipdid'] ?? '',
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      externalserial: map['externalserial'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      price: _toDouble(map['price']),
      costprice: map['costprice'] != null ? _toDouble(map['costprice']) : null,
      packsize: _toDouble(map['packsize']),
      packaging: map['packaging'] ?? '',
      packagingid: map['packagingid'] ?? '',
      soldfrom: map['soldfrom'] ?? '',
      shortform: map['shortform'] ?? '',
      packagingcode: map['packagingcode'] ?? '',
      efris: map['efris'] == true || map['efris'] == 1,
      efrisid: map['efrisid'] ?? '',
      measurmentunitidefris: map['measurmentunitidefris'] ?? '',
      measurmentunit: map['measurmentunit'] ?? '',
      measurmentunitid: map['measurmentunitid'] ?? '',
      vatcategoryid: map['vatcategoryid'] ?? '',
      branchid: map['branchid'] ?? '',
      companyid: map['companyid'] ?? '',
      downloadlink: map['downloadlink'],
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
}
