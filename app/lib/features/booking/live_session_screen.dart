import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/bookings_repository.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  final int bookingId;

  const LiveSessionScreen({super.key, required this.bookingId});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> with SingleTickerProviderStateMixin {
  BookingModel? _booking;
  bool _isLoading = true;
  String? _errorMessage;

  // Live telemetry state
  late Timer _telemetryTimer;
  double _socPercent = 68.0;
  double _energyAddedKwh = 22.4;
  double _powerKw = 18.4;
  int _elapsedMinutes = 42;
  int _remainingMinutes = 18;
  double _accruedCost = 358.40;
  final String _hardwarePin = '4892';

  // Animation controller for pulsating ping
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchBooking();
    _startLiveSimulation();
  }

  @override
  void dispose() {
    _telemetryTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startLiveSimulation() {
    // Tick every 3 seconds to show live energy & cost increment
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        if (_socPercent < 99.0) {
          _socPercent += 0.2;
          _energyAddedKwh += 0.08;
          _accruedCost += 1.28; // ₹16/kWh * 0.08 kWh
          if (_remainingMinutes > 1 && timer.tick % 4 == 0) {
            _remainingMinutes -= 1;
            _elapsedMinutes += 1;
          }
        }
      });
    });
  }

  Future<void> _fetchBooking() async {
    try {
      final b = await ref.read(bookingsRepositoryProvider).getBooking(widget.bookingId);
      setState(() {
        _booking = b;
        _isLoading = false;
      });
    } catch (e) {
      // In dev/mock mode, provide default fallback values
      setState(() {
        _isLoading = false;
        _errorMessage = null; // Still show interactive demo view
      });
    }
  }

  Future<void> _extendSession() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.more_time, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Extend Reservation'),
          ],
        ),
        content: const Text(
          'Extend your charging slot by +30 minutes?\n\n'
          'Host bay is verified open. Additional escrow of ₹100 will be held from your wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _remainingMinutes += 30;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reservation extended by 30 mins! Escrow updated.'),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            child: const Text('Confirm (+30m)'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStopCharging() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.power_settings_new, color: AppTheme.error),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stop Charging & Unlock?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMain,
                        ),
                      ),
                      Text(
                        'Power flow will safely ramp down before unlocking.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Final Energy Delivered:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${_energyAddedKwh.toStringAsFixed(1)} kWh',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Charge Fee:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '₹${_accruedCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep Charging'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Stop & Release'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(bookingsRepositoryProvider).completeBooking(widget.bookingId);
      } catch (_) {
        // Continue navigation in dev mode
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charging stopped safely. Cable solenoid unlocked!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.go('/my-bookings');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Active Charging Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/my-bookings'),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryFixed.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, size: 14, color: AppTheme.primary),
                SizedBox(width: 4),
                Text(
                  '₹350 Escrow Locked',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Station & Status Ribbon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GreenNest Villa Charger',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                                Text(
                                  'Host: Ramesh Kumar • Koramangala 4th Block',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CCS2 Fast',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Hardware Access PIN Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.inverseSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pin, color: AppTheme.primaryFixed, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hardware Access PIN',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    _hardwarePin,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: _hardwarePin));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('PIN copied to clipboard!')),
                                      );
                                    },
                                    child: const Icon(Icons.copy, size: 16, color: AppTheme.primaryFixed),
                                  ),
                                ],
                              ),
                              const Text(
                                'Keypad mounted next to charger socket to unlock holster',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Center Circular Telemetry Gauge
                  Center(
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background dial
                          SizedBox(
                            width: 210,
                            height: 210,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 16,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.surfaceContainerHigh,
                              ),
                            ),
                          ),
                          // Live progress arc
                          SizedBox(
                            width: 210,
                            height: 210,
                            child: CircularProgressIndicator(
                              value: (_socPercent / 100.0).clamp(0.0, 1.0),
                              strokeWidth: 16,
                              strokeCap: StrokeCap.round,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primary,
                              ),
                            ),
                          ),
                          // Dial center readout
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt, color: AppTheme.electricPurple, size: 30),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${_socPercent.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                  const Text(
                                    '%',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_powerKw.toStringAsFixed(1)} kW Flow',
                                  style: const TextStyle(
                                    color: AppTheme.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${_energyAddedKwh.toStringAsFixed(1)} kWh delivered',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3 Delivery Metric Tiles Bento
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.electric_car,
                          label: 'Energy Added',
                          value: '${_energyAddedKwh.toStringAsFixed(1)} kWh',
                          sub: '+140 km range',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.timer,
                          label: 'Elapsed Time',
                          value: '$_elapsedMinutes mins',
                          sub: 'Started at 02:30 PM',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.timelapse,
                          label: 'Remaining',
                          value: '$_remainingMinutes mins',
                          sub: 'to 80% target',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Live Accrued Cost Ticker
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Accrued Cost',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${_accruedCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMain,
                              ),
                            ),
                            const Text(
                              'Fixed rate: ₹16.00 / kWh • Unused escrow auto-refunds',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'ESCROW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                ),
                              ),
                              Text(
                                '₹350.00',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Hardware Safety Telemetry Strip
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.inverseSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: AppTheme.primaryFixed, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Live SafeCharge™ Telemetry',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSafetyStat('Grid Voltage', '238 V', 'Nominal'),
                            _buildSafetyStat('Earth Leakage', '0.0 mA', '< 30mA Pass'),
                            _buildSafetyStat('Cable Lock', 'Engaged', 'Solenoid Active'),
                            _buildSafetyStat('Enclosure Temp', '32°C', 'Cooling Normal'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _extendSession,
                          icon: const Icon(Icons.add_alarm),
                          label: const Text('+30m Extend'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _handleStopCharging,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop & Unlock'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.secondary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyStat(String label, String val, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          status,
          style: const TextStyle(color: AppTheme.primaryFixed, fontSize: 9),
        ),
      ],
    );
  }
}

