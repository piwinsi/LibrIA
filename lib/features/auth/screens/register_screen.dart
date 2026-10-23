import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final error = await context.read<AuthProvider>().register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _errorMessage = error;
      });
      return;
    }
    // La raíz de la app muestra ahora la selección de géneros.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('register_name'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ingresa tu nombre.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('register_email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final valid =
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                    return valid ? null : 'Ingresa un correo válido.';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('register_password'),
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo 8 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) => (value == null || value.length < 8)
                      ? 'La contraseña debe tener al menos 8 caracteres.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('register_confirm'),
                  controller: _confirmController,
                  obscureText: _obscure,
                  onFieldSubmitted: (_) => _handleRegister(),
                  decoration: const InputDecoration(
                    labelText: 'Repite la contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Las contraseñas no coinciden.'
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('register_submit'),
                  onPressed: _loading ? null : _handleRegister,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_loading ? 'Creando cuenta...' : 'Crear cuenta'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tu cuenta y tu actividad lectora se guardan solo en este '
                  'dispositivo. La contraseña se almacena cifrada (hash).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
