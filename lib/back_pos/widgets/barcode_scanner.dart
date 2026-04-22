import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/inventory_controller.dart';
import '../models/inventory_item.dart';
import '../../shared/database/unified_db_helper.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with TickerProviderStateMixin {
  final InventoryController inventoryController = Get.find();
  bool _isProcessing = false;
  String? _lastScannedCode;
  String? _errorMessage;
  MobileScannerController? _controller;
  bool _isTorchOn = false;

  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _statusController;
  late Animation<double> _statusFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();

    // Scan line sweeping animation
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Corner bracket pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Status message fade
    _statusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _statusFadeAnimation = CurvedAnimation(
      parent: _statusController,
      curve: Curves.easeOut,
    );
    _statusController.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanLineController.dispose();
    _pulseController.dispose();
    _statusController.dispose();
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
    _statusController.reset();

    setState(() {
      _lastScannedCode = code;
      _errorMessage = null;
    });

    _statusController.forward();

    final matchedItem = await _findItemByBarcode(code);

    if (matchedItem != null) {
      if (mounted) {
        Get.back(result: matchedItem);
      }
    } else {
      if (mounted) {
        _statusController.reset();
        setState(() {
          _errorMessage = 'No item found for "$code"';
        });
        _statusController.forward();
      }

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _statusController.reset();
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
          _errorMessage = null;
        });
        _statusController.forward();
      }
    }
  }

  Future<InventoryItem?> _findItemByBarcode(String barcode) async {
    try {
      final dbHelper = UnifiedDatabaseHelper.instance;
      return await dbHelper.getInventoryByBarcode(barcode);
    } catch (e) {
      debugPrint('Error finding item by barcode: $e');
      return null;
    }
  }

  void _toggleFlash() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    _controller?.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanFrameWidth = size.width * 0.72;
    final scanFrameHeight = scanFrameWidth * 0.6;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Live camera feed ──────────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleBarcodeDetection,
            ),
          ),

          // ── Dark vignette overlay ─────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _VignettePainter(
                frameWidth: scanFrameWidth,
                frameHeight: scanFrameHeight,
              ),
            ),
          ),

          // ── Scan frame ───────────────────────────────────────────────
          Center(
            child: SizedBox(
              width: scanFrameWidth,
              height: scanFrameHeight,
              child: Stack(
                children: [
                  // Animated corner brackets
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => CustomPaint(
                      size: Size(scanFrameWidth, scanFrameHeight),
                      painter: _CornerBracketPainter(
                        opacity: _pulseAnimation.value,
                        isActive: !_isProcessing,
                        isError: _errorMessage != null,
                        isSuccess:
                            _lastScannedCode != null && _errorMessage == null,
                      ),
                    ),
                  ),

                  // Animated scan line
                  if (!_isProcessing)
                    AnimatedBuilder(
                      animation: _scanLineAnimation,
                      builder: (_, __) {
                        final yPos = scanFrameHeight * _scanLineAnimation.value;
                        return Positioned(
                          top: yPos,
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFFE53935).withOpacity(0.9),
                                  const Color(0xFFFF5252),
                                  const Color(0xFFE53935).withOpacity(0.9),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFE53935,
                                  ).withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Processing spinner overlay
                  if (_isProcessing && _errorMessage == null)
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            color: Color(0xFFE53935),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Top bar ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Back button
                  _CircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Get.back(),
                  ),
                  const Spacer(),
                  // Title
                  const Text(
                    'SCAN ITEM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  // Torch button
                  _CircleButton(
                    icon: _isTorchOn
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    onTap: _toggleFlash,
                    isActive: _isTorchOn,
                  ),
                ],
              ),
            ),
          ),

          // ── Hint label above frame ────────────────────────────────────
          Center(
            child: Transform.translate(
              offset: Offset(0, -(scanFrameHeight / 2 + 36)),
              child: Text(
                'Align barcode inside the frame',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

          // ── Status chip below frame ───────────────────────────────────
          Center(
            child: Transform.translate(
              offset: Offset(0, scanFrameHeight / 2 + 24),
              child: FadeTransition(
                opacity: _statusFadeAnimation,
                child: _buildStatusChip(),
              ),
            ),
          ),

          // ── Bottom hint row ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _HintLabel(
                      icon: Icons.touch_app_outlined,
                      label: 'Tap back to cancel',
                    ),
                    _HintLabel(
                      icon: Icons.bolt_rounded,
                      label: 'Auto-advances after scan',
                      alignRight: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    if (_errorMessage != null) {
      return _StatusChip(
        icon: Icons.error_outline_rounded,
        label: _errorMessage!,
        color: const Color(0xFFFF5252),
        bgColor: const Color(0xFFFF5252).withOpacity(0.15),
      );
    }
    if (_lastScannedCode != null) {
      return _StatusChip(
        icon: Icons.check_circle_outline_rounded,
        label: 'Scanned: $_lastScannedCode',
        color: const Color(0xFF69F0AE),
        bgColor: const Color(0xFF69F0AE).withOpacity(0.12),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters & Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Draws a darkened overlay with a clear rectangular hole for the scan area.
class _VignettePainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;

  const _VignettePainter({required this.frameWidth, required this.frameHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final hole = Rect.fromLTWH(
      cx - frameWidth / 2,
      cy - frameHeight / 2,
      frameWidth,
      frameHeight,
    );

    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));

    final combined = Path.combine(
      PathOperation.difference,
      outerPath,
      innerPath,
    );

    canvas.drawPath(combined, Paint()..color = Colors.black.withOpacity(0.72));

    // Subtle inner glow on the hole edge
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(16)),
      Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_VignettePainter old) =>
      old.frameWidth != frameWidth || old.frameHeight != frameHeight;
}

/// Draws four L-shaped corner brackets with colour state.
class _CornerBracketPainter extends CustomPainter {
  final double opacity;
  final bool isActive;
  final bool isError;
  final bool isSuccess;

  const _CornerBracketPainter({
    required this.opacity,
    required this.isActive,
    required this.isError,
    required this.isSuccess,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Color bracketColor = isError
        ? const Color(0xFFFF5252)
        : isSuccess
        ? const Color(0xFF69F0AE)
        : const Color(0xFFE53935);

    final paint = Paint()
      ..color = bracketColor.withOpacity(opacity)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const arm = 28.0;
    const r = 16.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(r + arm, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, r + arm), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, r * 2, r * 2),
      3.14159,
      3.14159 / 2,
      false,
      paint,
    );

    // Top-right
    canvas.drawLine(Offset(w - r - arm, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, r + arm), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2),
      -3.14159 / 2,
      3.14159 / 2,
      false,
      paint,
    );

    // Bottom-left
    canvas.drawLine(Offset(r, h), Offset(r + arm, h), paint);
    canvas.drawLine(Offset(0, h - r), Offset(0, h - r - arm), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, h - r * 2, r * 2, r * 2),
      3.14159 / 2,
      3.14159 / 2,
      false,
      paint,
    );

    // Bottom-right
    canvas.drawLine(Offset(w - r - arm, h), Offset(w - r, h), paint);
    canvas.drawLine(Offset(w, h - r), Offset(w, h - r - arm), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2),
      0,
      3.14159 / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) =>
      old.opacity != opacity ||
      old.isError != isError ||
      old.isSuccess != isSuccess;
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? const Color(0xFFE53935).withOpacity(0.25)
              : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isActive
                ? const Color(0xFFE53935).withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool alignRight;

  const _HintLabel({
    required this.icon,
    required this.label,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, color: Colors.white24, size: 13),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white24, fontSize: 11)),
    ];

    return Row(children: alignRight ? children.reversed.toList() : children);
  }
}
