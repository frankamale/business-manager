class CompanyDetails {
  final String branchId;
  final String companyName;
  final String currentBranchName;

  CompanyDetails({
    required this.branchId,
    required this.companyName,
    required this.currentBranchName,
  });

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'companyName': companyName,
      'currentBranchName': currentBranchName,
    };
  }

  factory CompanyDetails.fromMap(Map<String, dynamic> map) {
    return CompanyDetails(
      branchId: map['branchId'] ?? '',
      companyName: map['companyName'] ?? '',
      currentBranchName: map['currentBranchName'] ?? '',
    );
  }
}