import 'package:flutter/material.dart';

import '../models/app_notification.dart';

final List<AppNotification> mockNotifications = [
  const AppNotification(
    id: 'notif_001',
    title: 'Continúa tu lectura',
    message: 'Llevas varios días sin avanzar en "Hábitos atómicos".',
    icon: Icons.menu_book,
  ),
  const AppNotification(
    id: 'notif_002',
    title: 'Nueva recomendación',
    message: 'Encontramos un libro de ciencia ficción que podría gustarte.',
    icon: Icons.auto_awesome,
  ),
  const AppNotification(
    id: 'notif_003',
    title: 'Actividad social',
    message: 'Camila Rojas terminó de leer "1984".',
    icon: Icons.people,
  ),
];
