import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

class UserAccount {
  final String id;
  final String username;
  final String system; // 'monitor' or 'pos'
  final Map<String, dynamic> userData;
  final DateTime lastLogin;

  UserAccount({
    required this.id,
    required this.username,
    required this.system,
    required this.userData,
    required this.lastLogin,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'system': system,
    'userData': userData,
    'lastLogin': lastLogin.toIso8601String(),
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'],
    username: json['username'],
    system: json['system'],
    userData: json['userData'],
    lastLogin: DateTime.parse(json['lastLogin']),
  );
}

class AccountManager extends GetxService {
  static const String _accountsKey = 'user_accounts';
  static const String _currentAccountKey = 'current_account_id';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  var accounts = <UserAccount>[].obs;
  var currentAccount = Rx<UserAccount?>(null);

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
    loadCurrentAccount();
  }

  Future<void> loadAccounts() async {
    try {
      final accountsJson = await _secureStorage.read(key: _accountsKey);
      if (accountsJson != null) {
        final List<dynamic> accountsList = jsonDecode(accountsJson);
        accounts.value = accountsList
            .map((accountJson) => UserAccount.fromJson(accountJson))
            .toList();
      }
    } catch (e) {
      print('Error loading accounts: $e');
    }
  }

  Future<void> saveAccounts() async {
    try {
      final accountsJson = jsonEncode(accounts.map((account) => account.toJson()).toList());
      await _secureStorage.write(key: _accountsKey, value: accountsJson);
    } catch (e) {
      print('Error saving accounts: $e');
    }
  }

  Future<void> addAccount(UserAccount account) async {
    // Remove existing account with same id if exists
    accounts.removeWhere((a) => a.id == account.id);
    accounts.add(account);
    await saveAccounts();
  }

  Future<void> removeAccount(String accountId) async {
    accounts.removeWhere((account) => account.id == accountId);
    await saveAccounts();

    // If current account was removed, clear it
    if (currentAccount.value?.id == accountId) {
      await setCurrentAccount(null);
    }
  }

  Future<void> setCurrentAccount(UserAccount? account) async {
    currentAccount.value = account;
    if (account != null) {
      await _secureStorage.write(key: _currentAccountKey, value: account.id);
      // Update last login time
      final updatedAccount = UserAccount(
        id: account.id,
        username: account.username,
        system: account.system,
        userData: account.userData,
        lastLogin: DateTime.now(),
      );
      await addAccount(updatedAccount);
    } else {
      await _secureStorage.delete(key: _currentAccountKey);
    }
  }

  Future<void> loadCurrentAccount() async {
    try {
      final currentAccountId = await _secureStorage.read(key: _currentAccountKey);
      if (currentAccountId != null) {
        currentAccount.value = accounts.firstWhereOrNull((account) => account.id == currentAccountId);
      }
    } catch (e) {
      print('Error loading current account: $e');
    }
  }

  List<UserAccount> getAccountsForSystem(String system) {
    return accounts.where((account) => account.system == system).toList()
      ..sort((a, b) => b.lastLogin.compareTo(a.lastLogin));
  }

  Future<void> switchToAccount(UserAccount account) async {
    await setCurrentAccount(account);
    // Here we would trigger system/database switching logic
    // This will be handled by the ProfileController
  }

  Future<void> clearAllAccounts() async {
    accounts.clear();
    currentAccount.value = null;
    await _secureStorage.delete(key: _accountsKey);
    await _secureStorage.delete(key: _currentAccountKey);
  }
}