import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/mock_notifications.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: mockNotifications.isEmpty
          ? const Center(child: Text('No tienes notificaciones.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mockNotifications.length,
              itemBuilder: (context, index) {
                final notification = mockNotifications[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      notification.icon,
                      color: AppColors.primary,
                    ),
                    title: Text(notification.title),
                    subtitle: Text(notification.message),
                  ),
                );
              },
            ),
    );
  }
}
