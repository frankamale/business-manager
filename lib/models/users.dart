class User {
  final String id;
  final String name;
  final String branch;
  final String company;
  final String role;
  final String branchname;
  final String companyName;
  final String username;
  final String staff;
  final String staffid;
  final String salespersonid;
  final String companyid;
  final int pospassword;

  User({
    required this.id,
    required this.name,
    required this.branch,
    required this.company,
    required this.role,
    required this.branchname,
    required this.companyName,
    required this.username,
    required this.staff,
    required this.staffid,
    required this.salespersonid,
    required this.companyid,
    required this.pospassword,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'branch': branch,
      'company': company,
      'role': role,
      'branchname': branchname,
      'companyName': companyName,
      'username': username,
      'staff': staff,
      'staffid': staffid,
      'salespersonid': salespersonid,
      'companyid': companyid,
      'pospassword': pospassword,
    };
  }
  factory User.fromMap(Map<String, dynamic> map){
    return User(
      id: map['id'] ?? '',
      name: map['staff'] ?? map['name'] ?? '',  // API uses 'staff' field for name
      branch: map['branch'] ?? '',
      company: map['company'] ?? '',
      role: map['role'] ?? '',
      branchname: map['branchname'] ?? '',
      companyName: map['companyname'] ?? map['companyName'] ?? '',  // API uses 'companyname'
      username: map['username'] ?? '',
      staff: map['staff'] ?? '',
      staffid: map['staffid'] ?? '',
      salespersonid: map['salespersonid'] ?? '',
      companyid: map['companyid'] ?? '',
      pospassword: map['pospassword'] ?? 0,
    );
  }
}
