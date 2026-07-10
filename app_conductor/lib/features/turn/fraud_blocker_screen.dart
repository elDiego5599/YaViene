import 'package:flutter/material.dart';
import 'package:ya_viene_core/ya_viene_core.dart';
import 'package:ya_viene_pasajero/shared/widgets/primary_button.dart';
import 'login_screen.dart';

class FraudBlockerScreen extends StatelessWidget {
  const FraudBlockerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.error, // Fondo rojo sólido de alerta
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.gpp_bad_rounded,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'TRANSMISIÓN BLOQUEADA',
                style: AppTextStyles.h1.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'El sistema ha detectado el uso de una aplicación de GPS Falso (Mock Location).',
                style: AppTextStyles.body.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Este incidente ha sido reportado al centro de control. Por favor, desactive cualquier alterador de ubicación en las opciones de desarrollador para continuar trabajando.',
                  style: AppTextStyles.label.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'SALIR',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                // Sobrescribimos colores para que el botón se vea bien sobre rojo
                colorOverride: Colors.white,
                textColorOverride: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
