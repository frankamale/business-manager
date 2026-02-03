import 'package:flutter/material.dart';

class ClientHome extends StatelessWidget {
  const ClientHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Welcome Back"), centerTitle: true),
      body: Container(child: Center(child: Text("Code"))),
    );
  }
}