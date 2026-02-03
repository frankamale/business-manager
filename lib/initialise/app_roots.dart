import 'package:flutter/material.dart';
import 'package:bac_pos/back_pos/auth/splash_screen.dart';
import 'package:bac_pos/bac_monitor/lib/pages/auth/splash_page.dart';
import 'package:bac_pos/back_pos/pages/homepage.dart';
import 'package:bac_pos/bac_monitor/lib/pages/bottom_nav.dart';
import 'package:bac_pos/client/pages/client_home.dart';

/// Root widget for the POS app
class PosAppRoot extends StatelessWidget {
  const PosAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

/// Root widget for the Monitor app
class MonitorAppRoot extends StatelessWidget {
  const MonitorAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }
}

/// Root widget for the Client app (customers)
class ClientAppRoot extends StatelessWidget {
  const ClientAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClientHome();
  }
}