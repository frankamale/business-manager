import 'package:flutter/material.dart';

class DailySummary extends StatelessWidget {
  const DailySummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Daily summary"),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(vertical: 10, horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.grey),
                    child: Text("REVIEW DATE"),
                  ),
                  Text(new DateTime(2025, 1, 1).toString()),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Total Cash Amount"), Text("0")],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Card Amount"), Text("0")],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Mobile Money"), Text("0")],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Credit Amount"), Text("0")],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Total Drinks Amount"), Text("0")],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Total Menu Amount"), Text("0")],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text("Complementary Items"), Text("0")],
              ),
              SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      TextButton(onPressed: () => {}, child: Text("Print")),
                      TextButton(onPressed: () => {}, child: Text("Commit")),
                    ],
                  ),
                  TextButton(onPressed: () => {}, child: Text("Cancel")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
