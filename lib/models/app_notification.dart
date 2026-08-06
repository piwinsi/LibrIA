import 'package:flutter/material.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String id;
  final String title;
  final String message;
  final IconData icon;
}
