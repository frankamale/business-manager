import 'package:flutter/material.dart';
import '../../../back_pos/utils/network_helper.dart';

/// Offline banner widget that shows in the top-left corner when offline
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await NetworkHelper.hasConnection();
    if (mounted) {
      setState(() {
        _isOffline = !isOnline;
      });
    }
  }

  void _setupConnectivityListener() {
    NetworkHelper.connectivityStream.listen((status) {
      if (mounted) {
        // Check if the status indicates disconnection
        final statusString = status.toString().toLowerCase();
        setState(() {
          _isOffline = statusString.contains('disconnect') || !statusString.contains('connect');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            child: Banner(
              message: 'OFFLINE',
              location: BannerLocation.topStart,
              color: Colors.red,
              textStyle: const TextStyle(
                fontSize: 12 * 0.85,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}