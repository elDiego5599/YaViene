import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'turn_assignment_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cedulaController = TextEditingController();
  final _pinController = TextEditingController();
  void _login() {
    final phoneNumber = _cedulaController.text.trim();
    final pin = _pinController.text.trim();
    if (phoneNumber.isEmpty || !RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cédula y un PIN válido.')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TurnAssignmentScreen(
          phoneNumber: phoneNumber,
          pin: pin,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.directions_bus_rounded,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Acceso Conductores',
                style: AppTextStyles.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _cedulaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cédula',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'PIN de 4 dígitos',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'INICIAR SESIÓN',
                isLoading: false,
                onPressed: _login,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
