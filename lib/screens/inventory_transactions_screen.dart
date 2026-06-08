import 'package:flutter/material.dart';

class InventoryTransactionsScreen extends StatelessWidget {
  const InventoryTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حركات المخزون'),
        ),
        body: const Center(
          child: Text(
            'شاشة حركات المخزون',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}