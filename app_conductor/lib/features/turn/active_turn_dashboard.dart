import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

import '../tracking/gps_manager.dart';
import 'fraud_blocker_screen.dart';

class ActiveTurnDashboard extends ConsumerStatefulWidget {
  final String empresaId;
  final String busId;
  final String routeId;

  const ActiveTurnDashboard({
    super.key,
    required this.empresaId,
    required this.busId,
    required this.routeId,
  });

  @override
  ConsumerState<ActiveTurnDashboard> createState() => _ActiveTurnDashboardState();
}

class _ActiveTurnDashboardState extends ConsumerState<ActiveTurnDashboard> {
  DateTime _startTime = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(gpsManagerProvider).startTracking(
      empresaId: widget.empresaId,
      busId: widget.busId,
      routeId: widget.routeId,
    ));

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _closeTurn() {
    ref.read(gpsManagerProvider).stopTracking();
    Navigator.of(context).pop();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingStateProvider);

    if (trackingState == TrackingState.fraudDetected) {
      return const FraudBlockerScreen();
    }

    final duration = DateTime.now().difference(_startTime);
    final isTracking = trackingState == TrackingState.tracking;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Turno en Curso'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              // ── Panel de Tiempo Principal ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  children: [
                    Text('Tiempo Transcurrido', style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _formatDuration(duration),
                      style: AppTextStyles.etaNumber.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_bus_rounded, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text(widget.busId, style: AppTextStyles.bodyLarge),
                        const SizedBox(width: AppSpacing.lg),
                        const Icon(Icons.route_rounded, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text(widget.routeId, style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // ── Estado de Transmisión (Verde Pastel) ────────────────────────
              _StatusCard(
                title: 'Transmisión GPS',
                subtitle: isTracking ? 'Emitiendo en alta precisión' : 'Esperando señal...',
                icon: Icons.radar_rounded,
                isActive: isTracking,
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              // ── Sincronización Offline ───────────────────────────────────────
              const _StatusCard(
                title: 'Sincronización',
                subtitle: 'Conectado al servidor central',
                icon: Icons.cloud_done_rounded,
                isActive: true,
                isSecondary: true,
              ),

              const Spacer(),
              
              // ── Botón de Cerrar Turno ───────────────────────────────────────
              ElevatedButton(
                onPressed: _closeTurn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorLight,
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.power_settings_new_rounded, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Text('CERRAR TURNO', style: AppTextStyles.labelLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isSecondary;

  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isActive = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? (isSecondary ? AppColors.surface : AppColors.successLight)
        : AppColors.surface;
    final iconColor = isActive ? AppColors.success : AppColors.textDisabled;
    final titleColor = isActive ? AppColors.textPrimary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isSecondary ? AppShadows.soft : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.5) : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge.copyWith(color: titleColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
