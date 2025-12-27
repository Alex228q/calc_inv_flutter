import 'package:flutter/material.dart';
import 'screens/stock_price_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Равномерное распределение',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const StockPriceScreen(),
    );
  }
}
