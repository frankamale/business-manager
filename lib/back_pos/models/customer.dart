class Customer {
  final String id;
  final String? code;
  final String? firstname;
  final String? lastname;
  final String? othernames;
  final String? remarks;
  final String? status;
  final String? gender;
  final String fullnames;
  final String? dob;
  final String? category;
  final String? designation;
  final String? trackerid1;
  final String? trackerid2;
  final String? trackerid3;
  final String? trackerid4;
  final String? trackerid5;
  final String? trackerid6;
  final String? tracker1;
  final String? tracker2;
  final String? tracker3;
  final String? tracker4;
  final String? tracker5;
  final String? tracker6;
  final String? email;
  final String? phone1;
  final String? address;
  final String? title;
  final String? guarantors;
  final String? pospassword;
  final bool? posenabled;
  final String? posusername;
  final String? pospasswordexpiry;
  final String? statusid;
  final int? subscription;
  final String? logo;
  final int? mode;

  Customer({
    required this.id,
    this.code,
    this.firstname,
    this.lastname,
    this.othernames,
    this.remarks,
    this.status,
    this.gender,
    required this.fullnames,
    this.dob,
    this.category,
    this.designation,
    this.trackerid1,
    this.trackerid2,
    this.trackerid3,
    this.trackerid4,
    this.trackerid5,
    this.trackerid6,
    this.tracker1,
    this.tracker2,
    this.tracker3,
    this.tracker4,
    this.tracker5,
    this.tracker6,
    this.email,
    this.phone1,
    this.address,
    this.title,
    this.guarantors,
    this.pospassword,
    this.posenabled,
    this.posusername,
    this.pospasswordexpiry,
    this.statusid,
    this.subscription,
    this.logo,
    this.mode,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString(),
      firstname: map['firstname']?.toString(),
      lastname: map['lastname']?.toString(),
      othernames: map['othernames']?.toString(),
      remarks: map['remarks']?.toString(),
      status: map['status']?.toString(),
      gender: map['gender']?.toString(),
      fullnames: map['fullnames']?.toString() ?? '',
      dob: map['dob']?.toString(),
      category: map['category']?.toString(),
      designation: map['designation']?.toString(),
      trackerid1: map['trackerid1']?.toString(),
      trackerid2: map['trackerid2']?.toString(),
      trackerid3: map['trackerid3']?.toString(),
      trackerid4: map['trackerid4']?.toString(),
      trackerid5: map['trackerid5']?.toString(),
      trackerid6: map['trackerid6']?.toString(),
      tracker1: map['tracker1']?.toString(),
      tracker2: map['tracker2']?.toString(),
      tracker3: map['tracker3']?.toString(),
      tracker4: map['tracker4']?.toString(),
      tracker5: map['tracker5']?.toString(),
      tracker6: map['tracker6']?.toString(),
      email: map['email']?.toString(),
      phone1: map['phone1']?.toString(),
      address: map['address']?.toString(),
      title: map['title']?.toString(),
      guarantors: map['guarantors']?.toString(),
      pospassword: map['pospassword']?.toString(),
      posenabled: map['posenabled'] == true || map['posenabled'] == 1,
      posusername: map['posusername']?.toString(),
      pospasswordexpiry: map['pospasswordexpiry']?.toString(),
      statusid: map['statusid']?.toString(),
      subscription: map['subscription'] is int ? map['subscription'] : int.tryParse(map['subscription']?.toString() ?? '0') ?? 0,
      logo: map['logo']?.toString(),
      mode: map['mode'] is int ? map['mode'] : int.tryParse(map['mode']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'firstname': firstname,
      'lastname': lastname,
      'othernames': othernames,
      'remarks': remarks,
      'status': status,
      'gender': gender,
      'fullnames': fullnames,
      'dob': dob,
      'category': category,
      'designation': designation,
      'trackerid1': trackerid1,
      'trackerid2': trackerid2,
      'trackerid3': trackerid3,
      'trackerid4': trackerid4,
      'trackerid5': trackerid5,
      'trackerid6': trackerid6,
      'tracker1': tracker1,
      'tracker2': tracker2,
      'tracker3': tracker3,
      'tracker4': tracker4,
      'tracker5': tracker5,
      'tracker6': tracker6,
      'email': email,
      'phone1': phone1,
      'address': address,
      'title': title,
      'guarantors': guarantors,
      'pospassword': pospassword,
      'posenabled': posenabled,
      'posusername': posusername,
      'pospasswordexpiry': pospasswordexpiry,
      'statusid': statusid,
      'subscription': subscription,
      'logo': logo,
      'mode': mode,
    };
  }
}