import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/inventory_controller.dart';
import '../models/inventory_item.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final InventoryController inventoryController = Get.find();
  bool _isProcessing = false;
  String? _lastScannedCode;
  String? _errorMessage;
  MobileScannerController? _controller;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleBarcodeDetection(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;

    if (code != null && code.isNotEmpty) {
      _processScannedCode(code);
    }
  }

  Future<void> _processScannedCode(String code) async {
    _isProcessing = true;

    setState(() {
      _lastScannedCode = code;
      _errorMessage = null;
    });

    // Search for item by code or externalserial (barcode)
    final matchedItem = _findItemByBarcode(code);

    if (matchedItem != null) {
      if (mounted) {
        Get.back(result: matchedItem);
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Item with barcode "$code" not found';
        });
      }

      // Wait before allowing next scan
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
          _errorMessage = null;
        });
      }
    }
  }

  InventoryItem? _findItemByBarcode(String barcode) {
    try {
      final allItems = inventoryController.filteredItems;

      for (var item in allItems) {
        if (item.code == barcode || item.externalserial == barcode) {
          return item;
        }
      }
    } catch (e) {
      debugPrint('Error finding item by barcode: $e');
    }
    return null;
  }

  void _toggleFlash() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    _controller?.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
            tooltip: 'Toggle Flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcodeDetection,
          ),
          // Overlay with cutout
          _buildOverlay(context),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_lastScannedCode != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '✓ Scanned: $_lastScannedCode',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Text(
                'Position barcode within the red frame',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tap outside frame to cancel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Auto-advances after scan',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        // Dimmed overlay
        Container(color: Colors.black.withOpacity(0.6)),
        // Scanning window cutout area (transparent center)
        Center(
          child: Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Scanning laser line
        Center(
          child: Container(
            width: 280,
            height: 180,
            child: CustomPaint(painter: ScannerLaserPainter()),
          ),
        ),
        // Top-left corner bracket
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          left: 20,
          child: _buildCornerBracket(isTopLeft: true),
        ),
        // Top-right corner bracket
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          right: 20,
          child: _buildCornerBracket(isTopLeft: false),
        ),
        // Bottom-left corner bracket
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.35,
          left: 20,
          child: _buildCornerBracket(isTopLeft: false, isBottom: true),
        ),
        // Bottom-right corner bracket
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.35,
          right: 20,
          child: _buildCornerBracket(isTopLeft: true, isBottom: true),
        ),
      ],
    );
  }

  Widget _buildCornerBracket({required bool isTopLeft, bool isBottom = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTopLeft && !isBottom
              ? const BorderSide(color: Colors.red, width: 4)
              : BorderSide.none,
          bottom: isBottom
              ? const BorderSide(color: Colors.red, width: 4)
              : BorderSide.none,
          left: isTopLeft
              ? const BorderSide(color: Colors.red, width: 4)
              : BorderSide.none,
          right: !isTopLeft
              ? const BorderSide(color: Colors.red, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }
}

class ScannerLaserPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw horizontal laser line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
