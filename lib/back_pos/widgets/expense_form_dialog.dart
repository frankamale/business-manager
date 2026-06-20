import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:bac_pos/back_pos/models/expense.dart';
import 'package:bac_pos/back_pos/controllers/expenses_controller.dart';
import 'package:bac_pos/back_pos/controllers/user_controller.dart';
import 'package:bac_pos/back_pos/controllers/service_point_controller.dart';
import 'package:bac_pos/back_pos/controllers/auth_controller.dart';

import '../../bac_monitor/lib/additions/colors.dart';

class ExpenseFormDialog extends StatefulWidget {
  final ExpensesController expensesController;
  final String? servicePointId;
  final Color color;
  final String expenseType;

  const ExpenseFormDialog({
    super.key,
    required this.expensesController,
    required this.color,
    this.servicePointId,
    this.expenseType = 'non-stock',
  });

  static Future<void> show({
    required BuildContext context,
    required ExpensesController expensesController,
    required Color color,
    String? servicePointId,
    String expenseType = 'non-stock',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpenseFormDialog(
        expensesController: expensesController,
        servicePointId: servicePointId,
        color: color,
        expenseType: expenseType,
      ),
    );
  }

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  late final UserController _userController;
  late final ServicePointController _servicePointController;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = ExpenseCategory.other;
  String? _selectedSubject;
  String? _selectedServicePointId;
  // Defaults to the day of entry; the user can pick a different date.
  DateTime _selectedDate = DateTime.now();

  String? _titleError;
  String? _descriptionError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _userController = Get.find<UserController>();
    _servicePointController = Get.find<ServicePointController>();
    _servicePointController.loadServicePointsFromCache();
    if (_userController.users.isEmpty) {
      if (Get.isRegistered<AuthController>()) {
        Get.find<AuthController>().syncUsersFromAPI(showMessage: false).then((_) => _userController.fetchUsers());
      }
    }
    if (_servicePointController.servicePoints.isEmpty) {
      _servicePointController.syncServicePointsFromAPI(showMessage: false).then((_) => _servicePointController.loadServicePointsFromCache());
    }
    if (widget.servicePointId != null) {
      _selectedServicePointId = widget.servicePointId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _servicePointError;

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0 &&
      _selectedServicePointId != null &&
          _selectedSubject != null;

  void _submitForm() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    bool hasError = false;
    if (title.isEmpty) {
      setState(() => _titleError = 'Please enter a title');
      hasError = true;
    }
    if (description.isEmpty) {
      setState(() => _descriptionError = 'Please enter a description');
      hasError = true;
    }
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Please enter a valid amount');
      hasError = true;
    }
    if (_selectedServicePointId == null || _selectedServicePointId == '---all-stores-id---') {
      setState(() => _servicePointError = 'Please select a service point');
      hasError = true;
    }
    if (hasError) return;

    widget.expensesController.addExpense(
      title: title,
      description: description,
      subject: _selectedSubject,
      staffId: _selectedSubject,
      amount: amount!,
      category: _selectedCategory,
      servicePointId: _selectedServicePointId ?? widget.servicePointId,
      expenseType: widget.expenseType,
      date: _selectedDate,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration:  BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getTextPrimaryColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.add_card_outlined,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'New Expense',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey.shade500),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Amount — hero field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'UGX',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: color.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: color.withOpacity(0.3),
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setState(() => _amountError = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_amountError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 4),
                    child: Text(
                      _amountError!,
                      style:  TextStyle(color:AppColors.getWarningColor(context), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                Divider(height: 1, color: AppColors.getTextPrimaryColor(context)),
                const SizedBox(height: 16),
                // Fields
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildField(
                        controller: _titleController,
                        icon: Icons.label_outline,
                        label: 'Title',
                        errorText: _titleError,
                        color: color,
                        onChanged: (_) => setState(() => _titleError = null),
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _descriptionController,
                        icon: Icons.notes_outlined,
                        label: 'Description',
                        errorText: _descriptionError,
                        color: color,
                        onChanged: (_) =>
                            setState(() => _descriptionError = null),
                      ),
                      const SizedBox(height: 12),
                      Obx(
                        () => _buildDropdown<String>(
                          icon: Icons.person_outline,
                          label: 'Staff (Subject)',
                          value: _selectedSubject,
                          color: color,
                          items: _userController.users
                              .map(
                                (user) => DropdownMenuItem(
                                  value: user.id,
                                  child: Text(user.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedSubject = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(() {
                        final servicePoints = _servicePointController.servicePoints;
                        final validServicePoints = servicePoints
                            .where((sp) => sp.id != '---all-stores-id---')
                            .toList();
                        
                        // Get unique service points
                        final uniqueServicePoints = <String, dynamic>{};
                        for (final sp in validServicePoints) {
                          uniqueServicePoints[sp.id] = sp;
                        }
                        final uniqueSpList = uniqueServicePoints.values.toList();
                        
                        // Auto-select a valid service point if current selection is invalid
                        String? validServicePointId;
                        if (_selectedServicePointId != null && 
                            _selectedServicePointId != '---all-stores-id---' &&
                            uniqueSpList.any((sp) => sp.id == _selectedServicePointId)) {
                          validServicePointId = _selectedServicePointId;
                        } else if (uniqueSpList.isNotEmpty) {
                          validServicePointId = uniqueSpList.first.id;
                        }
                        
                        return _buildDropdown<String>(
                          icon: Icons.store_outlined,
                          label: 'Service Point',
                          value: validServicePointId,
                          color: color,
                          errorText: _servicePointError,
                          items: uniqueSpList
                              .map<DropdownMenuItem<String>>(
                                (sp) => DropdownMenuItem<String>(
                                  value: sp.id,
                                  child: Text(sp.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() {
                                _selectedServicePointId = value;
                                _servicePointError = null;
                              }),
                        );
                      }),
                      const SizedBox(height: 12),
                      _buildDropdown<String>(
                        icon: Icons.category_outlined,
                        label: 'Category (Payref)',
                        value: _selectedCategory,
                        color: color,
                        items: ExpenseCategory.all
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDateField(color: color),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Save button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _isValid ? AppColors.getSecondaryColor(context) : AppColors.getCardColor(context),
                      foregroundColor: _isValid
                          ? AppColors.getTextPrimaryColor(context)
                          : AppColors.getSurfaceColor(context),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isValid ? _submitForm : null,
                    child: const Text(
                      'Save Expense',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required Color color,
    String? errorText,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.getTextPrimaryColor(context)),
        errorText: errorText,
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getTextPrimaryColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> _pickDate(Color color) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: color),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildDateField({required Color color}) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final label = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickDate(color),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_today_outlined,
              size: 18, color: AppColors.getTextPrimaryColor(context)),
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.getBorderColor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.getTextPrimaryColor(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isToday ? '$label  (Today)' : label,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            Icon(Icons.edit_calendar_outlined,
                size: 18, color: color.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required IconData icon,
    required String label,
    required T? value,
    required Color color,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? errorText,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.getTextPrimaryColor(context)),
        errorText: errorText,
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color:AppColors.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.getTextPrimaryColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
