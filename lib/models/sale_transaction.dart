class SaleTransaction {
  final String id;
  final String? purchaseordernumber;
  final int internalrefno;
  final String issuedby;
  final String? receiptnumber;
  final String? receivedby;
  final String remarks;
  final int transactiondate;
  final String? costcentre;
  final String destinationbp;
  final String paymentmode;
  final String sourcefacility;
  final String genno;
  final String paymenttype;
  final int validtill;
  final String currency;
  final double quantity;
  final double unitquantity;
  final double amount;
  final double amountpaid;
  final double balance;
  final double sellingprice;
  final double costprice;
  final double sellingpriceOriginal;
  final String inventoryname;
  final String category;
  final String subcategory;
  final int gnrtd;
  final int printed;
  final int redeemed;
  final int cancelled;
  final String patron;
  final String department;
  final int packsize;
  final String packaging;
  final int complimentaryid;
  final String salesId;
  final String? uploadStatus;
  final int? uploadedAt;
  final String? uploadError;
  final String? inventoryid;
  final String? ipdid;
  final String? clientid;
  final String? companyid;
  final String? branchid;
  final String? servicepointid;
  final String? salespersonid;

  SaleTransaction({
    required this.id,
    this.purchaseordernumber,
    required this.internalrefno,
    required this.issuedby,
    this.receiptnumber,
    this.receivedby,
    required this.remarks,
    required this.transactiondate,
    this.costcentre,
    required this.destinationbp,
    required this.paymentmode,
    required this.sourcefacility,
    required this.genno,
    required this.paymenttype,
    required this.validtill,
    required this.currency,
    required this.quantity,
    required this.unitquantity,
    required this.amount,
    required this.amountpaid,
    required this.balance,
    required this.sellingprice,
    required this.costprice,
    required this.sellingpriceOriginal,
    required this.inventoryname,
    required this.category,
    required this.subcategory,
    required this.gnrtd,
    required this.printed,
    required this.redeemed,
    required this.cancelled,
    required this.patron,
    required this.department,
    required this.packsize,
    required this.packaging,
    required this.complimentaryid,
    required this.salesId,
    this.uploadStatus,
    this.uploadedAt,
    this.uploadError,
    this.inventoryid,
    this.ipdid,
    this.clientid,
    this.companyid,
    this.branchid,
    this.servicepointid,
    this.salespersonid,
  });

  factory SaleTransaction.fromJson(Map<String, dynamic> json) {
    return SaleTransaction(
      id: json['id'] as String,
      purchaseordernumber: json['purchaseordernumber'] as String?,
      internalrefno: json['internalrefno'] as int,
      issuedby: json['issuedby'] as String,
      receiptnumber: json['receiptnumber'] as String?,
      receivedby: json['receivedby'] as String?,
      remarks: json['remarks'] as String,
      transactiondate: json['transactiondate'] as int,
      costcentre: json['costcentre'] as String?,
      destinationbp: json['destinationbp'] as String,
      paymentmode: json['paymentmode'] as String,
      sourcefacility: json['sourcefacility'] as String,
      genno: json['genno'] as String,
      paymenttype: json['paymenttype'] as String,
      validtill: json['validtill'] as int,
      currency: json['currency'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitquantity: (json['unitquantity'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      amountpaid: (json['amountpaid'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      sellingprice: (json['sellingprice'] as num).toDouble(),
      costprice: (json['costprice'] as num).toDouble(),
      sellingpriceOriginal: (json['sellingprice_original'] as num).toDouble(),
      inventoryname: json['inventoryname'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String,
      gnrtd: json['gnrtd'] as int,
      printed: json['printed'] as int,
      redeemed: json['redeemed'] as int,
      cancelled: json['cancelled'] as int,
      patron: json['patron'] as String,
      department: json['department'] as String,
      packsize: json['packsize'] as int,
      packaging: json['packaging'] as String,
      complimentaryid: json['complimentaryid'] as int,
      salesId: json['salesId'] as String,
      uploadStatus: json['upload_status'] as String?,
      uploadedAt: json['uploaded_at'] as int?,
      uploadError: json['upload_error'] as String?,
      inventoryid: json['inventoryid'] as String?,
      ipdid: json['ipdid'] as String?,
      clientid: json['clientid'] as String?,
      companyid: json['companyid'] as String?,
      branchid: json['branchid'] as String?,
      servicepointid: json['servicepointid'] as String?,
      salespersonid: json['salespersonid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseordernumber': purchaseordernumber,
      'internalrefno': internalrefno,
      'issuedby': issuedby,
      'receiptnumber': receiptnumber,
      'receivedby': receivedby,
      'remarks': remarks,
      'transactiondate': transactiondate,
      'costcentre': costcentre,
      'destinationbp': destinationbp,
      'paymentmode': paymentmode,
      'sourcefacility': sourcefacility,
      'genno': genno,
      'paymenttype': paymenttype,
      'validtill': validtill,
      'currency': currency,
      'quantity': quantity,
      'unitquantity': unitquantity,
      'amount': amount,
      'amountpaid': amountpaid,
      'balance': balance,
      'sellingprice': sellingprice,
      'costprice': costprice,
      'sellingprice_original': sellingpriceOriginal,
      'inventoryname': inventoryname,
      'category': category,
      'subcategory': subcategory,
      'gnrtd': gnrtd,
      'printed': printed,
      'redeemed': redeemed,
      'cancelled': cancelled,
      'patron': patron,
      'department': department,
      'packsize': packsize,
      'packaging': packaging,
      'complimentaryid': complimentaryid,
      'salesId': salesId,
      'upload_status': uploadStatus,
      'uploaded_at': uploadedAt,
      'upload_error': uploadError,
      'inventoryid': inventoryid,
      'ipdid': ipdid,
      'clientid': clientid,
      'companyid': companyid,
      'branchid': branchid,
      'servicepointid': servicepointid,
      'salespersonid': salespersonid,
    };
  }

  factory SaleTransaction.fromMap(Map<String, dynamic> map) {
    return SaleTransaction(
      id: map['id'] as String,
      purchaseordernumber: map['purchaseordernumber'] as String?,
      internalrefno: map['internalrefno'] as int,
      issuedby: map['issuedby'] as String,
      receiptnumber: map['receiptnumber'] as String?,
      receivedby: map['receivedby'] as String?,
      remarks: map['remarks'] as String,
      transactiondate: map['transactiondate'] as int,
      costcentre: map['costcentre'] as String?,
      destinationbp: map['destinationbp'] as String,
      paymentmode: map['paymentmode'] as String,
      sourcefacility: map['sourcefacility'] as String,
      genno: map['genno'] as String,
      paymenttype: map['paymenttype'] as String,
      validtill: map['validtill'] as int,
      currency: map['currency'] as String,
      quantity: map['quantity'] as double,
      unitquantity: map['unitquantity'] as double,
      amount: map['amount'] as double,
      amountpaid: map['amountpaid'] as double,
      balance: map['balance'] as double,
      sellingprice: map['sellingprice'] as double,
      costprice: map['costprice'] as double,
      sellingpriceOriginal: map['sellingprice_original'] as double,
      inventoryname: map['inventoryname'] as String,
      category: map['category'] as String,
      subcategory: map['subcategory'] as String,
      gnrtd: map['gnrtd'] as int,
      printed: map['printed'] as int,
      redeemed: map['redeemed'] as int,
      cancelled: map['cancelled'] as int,
      patron: map['patron'] as String,
      department: map['department'] as String,
      packsize: map['packsize'] as int,
      packaging: map['packaging'] as String,
      complimentaryid: map['complimentaryid'] as int,
      salesId: map['salesId'] as String,
      uploadStatus: map['upload_status'] as String?,
      uploadedAt: map['uploaded_at'] as int?,
      uploadError: map['upload_error'] as String?,
      inventoryid: map['inventoryid'] as String?,
      ipdid: map['ipdid'] as String?,
      clientid: map['clientid'] as String?,
      companyid: map['companyid'] as String?,
      branchid: map['branchid'] as String?,
      servicepointid: map['servicepointid'] as String?,
      salespersonid: map['salespersonid'] as String?,
    );
  }
}
