import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/bookings_repository.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int bookingId;

  const PaymentScreen({super.key, required this.bookingId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  BookingModel? _booking;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isConfirmed = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchBooking();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBooking() async {
    try {
      final b = await ref.read(bookingsRepositoryProvider).getBooking(widget.bookingId);
      setState(() {
        _booking = b;
        _isLoading = false;
        if (b.isConfirmed) {
          _isConfirmed = true;
          _isProcessing = false;
        }
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final b = await ref.read(bookingsRepositoryProvider).getBooking(widget.bookingId);
        if (b.isConfirmed) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _booking = b;
              _isConfirmed = true;
              _isProcessing = false;
            });
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _payWithRazorpay() async {
    setState(() => _isProcessing = true);
    _startPolling();

    // In test environment, automatically trigger test payment confirmation
    try {
      await Future.delayed(const Duration(seconds: 2));
      await ref.read(bookingsRepositoryProvider).testConfirm(widget.bookingId);
      await _fetchBooking();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment initiation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final b = _booking;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Booking details not found')),
      );
    }

    if (_isConfirmed) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle_rounded, size: 80, color: AppTheme.primary),
                const SizedBox(height: 20),
                const Text(
                  'Booking Confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your charging slot for #${b.id} has been secured.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildRow('Location', b.chargerTitle ?? 'EV Charger'),
                        const Divider(height: 20),
                        _buildRow('Slot', b.formattedSlot),
                        const Divider(height: 20),
                        _buildRow('Amount Paid', '₹${b.amountRupees.toStringAsFixed(2)}'),
                        const Divider(height: 20),
                        _buildRow('Status', 'CONFIRMED', textColor: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.push('/session/${widget.bookingId}'),
                  icon: const Icon(Icons.bolt),
                  label: const Text('Start Live Charging Session'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/my-bookings'),
                  child: const Text('View in My Bookings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/map'),
                  child: const Text('Back to Map'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Razorpay Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Amount Due', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '₹${b.amountRupees.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order Ref: ${b.orderId ?? "N/A"}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Payment Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildRow('Booking ID', '#${b.id}'),
                    const Divider(height: 20),
                    _buildRow('Station', b.chargerTitle ?? 'EV Station'),
                    const Divider(height: 20),
                    _buildRow('Time Window', b.formattedSlot),
                    const Divider(height: 20),
                    _buildRow('Platform Fee (12%)', '₹${(b.commission / 100).toStringAsFixed(2)}'),
                    const Divider(height: 20),
                    _buildRow('Host Payout (88%)', '₹${(b.hostPayout / 100).toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (_isProcessing)
              Column(
                children: const [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text(
                    'Confirming payment with gateway webhook...',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.payment),
                label: Text('Pay ₹${b.amountRupees.toStringAsFixed(2)} with Razorpay'),
                onPressed: _payWithRazorpay,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: textColor ?? AppTheme.textMain,
          ),
        ),
      ],
    );
  }
}

