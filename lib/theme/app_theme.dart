import 'package:flutter/material.dart';

final lightTheme = ThemeData.light().copyWith(
  primaryColor: Colors.red[600],
  scaffoldBackgroundColor: Colors.white,
  cardColor: Colors.grey[100],
  textTheme: const TextTheme(
    headlineSmall: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.black87, fontSize: 15),
    bodySmall: TextStyle(color: Colors.grey, fontSize: 12),
  ),
  iconTheme: IconThemeData(color: Colors.red[600]),
);

final darkTheme = ThemeData.dark().copyWith(
  primaryColor: Colors.red[900],
  scaffoldBackgroundColor: const Color(0xFF212121),
  cardColor: const Color(0xFF424242),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white, fontSize: 15),
    bodySmall: TextStyle(color: Colors.grey, fontSize: 12),
  ),
  iconTheme: IconThemeData(color: Colors.red[700]),
);