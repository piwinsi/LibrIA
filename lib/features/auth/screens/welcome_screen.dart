import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loadingDemo = false;

  Future<void> _enterDemo() async {
    setState(() => _loadingDemo = true);
    await context.read<AuthProvider>().loginDemo();
    if (mounted) setState(() => _loadingDemo = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 140,
                    height: 140,
                    semanticsLabel: 'Logo de LibrIA',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'LibrIA',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Registra tus lecturas, sigue tu avance, guarda tus '
                    'reflexiones y descubre qué leer después.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Crear cuenta'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadingDemo ? null : _enterDemo,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(
                      _loadingDemo
                          ? 'Preparando demostración...'
                          : 'Explorar con la cuenta de demostración',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tus datos se guardan solo en este dispositivo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
