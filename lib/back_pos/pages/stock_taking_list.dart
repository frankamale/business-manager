import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/stock_take_controller.dart';
import '../models/service_point.dart';
import '../models/stock_take_session.dart';
import 'stock_take_session_detail.dart';
import '../../flavors/flavor_colors.dart';

/// Lists stock-take sessions. Each session bundles many counted items; tap a
/// session to view/manage its items. The FAB starts a new session.
class StockTakingList extends StatefulWidget {
  final ServicePoint? servicePoint;

  const StockTakingList({super.key, this.servicePoint});

  @override
  State<StockTakingList> createState() => _StockTakingListState();
}

class _StockTakingListState extends State<StockTakingList> {
  final StockTakeController _controller = Get.put(StockTakeController());
  final NumberFormat _money = NumberFormat('#,##0.##', 'en_US');

  String? get _spId => widget.servicePoint?.id;

  @override
  void initState() {
    super.initState();
    _controller.loadSessions(servicePointId: _spId);
  }

  Future<void> _newSession() async {
    final ctrl = TextEditingController();
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Stock Take'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Reference / name ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (create != true || !mounted) return;

    final session = await _controller.createSession(
      reference: ctrl.text.trim(),
      servicePointId: _spId,
    );
    await _openSession(session);
  }

  Future<void> _openSession(StockTakeSession session) async {
    await Get.to(
      () => StockTakeSessionDetail(
        session: session,
        servicePoint: widget.servicePoint,
      ),
    );
    await _controller.loadSessions(servicePointId: _spId);
  }

  Future<void> _uploadAll() async {
    final pending =
        _controller.sessions.where((s) => s.uploadStatus == 'pending').length;
    if (pending == 0) {
      Get.snackbar(
        'Nothing to upload',
        'All stock takes are already uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: FlavorColors.current.primaryDark,
        colorText: Colors.white,
      );
      return;
    }
    Get.dialog(
      Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Uploading $pending stock take(s)...'),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    try {
      await _controller.uploadAll(servicePointId: _spId);
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Success',
        '$pending stock take(s) uploaded',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade900,
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error',
        'Upload failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Taking'),
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'upload_all') _uploadAll();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'upload_all',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload,
                        size: 20, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    const Text('Upload All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSession,
        backgroundColor: FlavorColors.current.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Stock Take'),
      ),
      body: SafeArea(
        child: Obx(() {
          if (_controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = _controller.sessions;
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No stock takes yet',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text('Tap "New Stock Take" to start one',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildTile(sessions[index]),
          );
        }),
      ),
    );
  }

  Widget _buildTile(StockTakeSession session) {
    final color = _uploadColor(session.uploadStatus);
    final title =
        session.reference.isNotEmpty ? session.reference : 'Stock Take';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openSession(session),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Item-count chip
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${session.itemCount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color,
                      ),
                    ),
                    Text(
                      'ITEMS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(
                          _money.format(session.totalAmount),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            DateFormat('dd MMM yyyy • HH:mm')
                                .format(session.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              _fiscalIcon(session.uploadStatus),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// Upload status, conveyed through the title (and count) colour:
  /// orange = pending, red = failed, dark blue = uploaded/fiscalised.
  Color _uploadColor(String status) {
    switch (status) {
      case 'failed':
        return const Color(0xFFD32F2F);
      case 'uploaded':
      case 'fiscalised':
        return const Color(0xFF0D47A1);
      case 'pending':
      default:
        return const Color(0xFFEF6C00);
    }
  }

  /// Fiscalisation status icon:
  /// check = fiscalised, hourglass = awaiting fiscalisation, "?" = error.
  Widget _fiscalIcon(String status) {
    late final IconData icon;
    late final MaterialColor color;
    late final String tip;
    switch (status) {
      case 'fiscalised':
        icon = Icons.check_circle_rounded;
        color = Colors.green;
        tip = 'Fiscalised';
        break;
      case 'failed':
        icon = Icons.help_rounded;
        color = Colors.red;
        tip = 'Fiscalisation error';
        break;
      case 'uploaded':
      case 'pending':
      default:
        icon = Icons.hourglass_bottom_rounded;
        color = Colors.blueGrey;
        tip = 'Awaiting fiscalisation';
    }
    return Tooltip(
      message: tip,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: color.shade700),
      ),
    );
  }
}
