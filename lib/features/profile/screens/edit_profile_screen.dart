import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';

/// Edición del perfil lector (RF-02) y de la contraseña (RF-01, RNF-04).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _name = TextEditingController(text: user?.name ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await context.read<AuthProvider>().updateProfile(name: _name.text, bio: _bio.text);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await context
        .read<AuthProvider>()
        .changePassword(_currentPassword.text, _newPassword.text);
    if (!mounted) return;
    setState(() => _passwordError = error);
    if (error == null) {
      _currentPassword.clear();
      _newPassword.clear();
      messenger.showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmAction(
      context,
      title: 'Eliminar cuenta',
      message:
          'Se borrarán tu cuenta, tu biblioteca, tus comentarios y tu historial de este dispositivo. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar cuenta',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().deleteAccount();
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bio,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Biografía lectora',
                      hintText: '¿Qué tipo de lector eres?',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saveProfile,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Guardar cambios'),
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Cambiar contraseña'),
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña actual'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      helperText: 'Mínimo 8 caracteres',
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Debe tener al menos 8 caracteres.'
                        : null,
                  ),
                  if (_passwordError != null) ...[
                    const SizedBox(height: 8),
                    Text(_passwordError!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _changePassword,
                    child: const Text('Actualizar contraseña'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Eliminar mi cuenta y mis datos'),
            ),
          ],
        ),
      ),
    );
  }
}
