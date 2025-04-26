import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          '', // You can put 'Welcome' or leave it empty
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
