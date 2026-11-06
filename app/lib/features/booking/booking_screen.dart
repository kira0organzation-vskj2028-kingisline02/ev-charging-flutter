import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/charger_model.dart';
import '../../data/repositories/chargers_repository.dart';
import '../../data/repositories/bookings_repository.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final int chargerId;

  const BookingScreen({super.key, required this.chargerId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  ChargerModel? _charger;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  int _durationHours = 2;
  double _energyTargetKwh = 20.0;
  String _selectedPaymentMethod = 'upi'; // 'upi', 'wallet', 'card'
  int _selectedSlotIndex = 1; // 0: Reserved, 1: Selected, 2: Open

  PricePreviewResult? _pricePreview;
  bool _isLoading = true;
  bool _isBooking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChargerAndPreview();
  }

  Future<void> _loadChargerAndPreview() async {
    setState(() => _isLoading = true);
    try {
      final c = await ref.read(chargersRepositoryProvider).getChargerDetail(widget.chargerId);
      setState(() => _charger = c);
      await _updatePricePreview();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _startUnix {
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  int get _endUnix => _startUnix + (_durationHours * 3600);

  Future<void> _updatePricePreview() async {
    try {
      final preview = await ref.read(bookingsRepositoryProvider).previewPrice(
            chargerId: widget.chargerId,
            startTs: _startUnix,
            endTs: _endUnix,
          );
      if (mounted) setState(() => _pricePreview = preview);
    } catch (e) {
      // preview error fallback
    }
  }

  Future<void> _handleConfirmBooking() async {
    setState(() {
      _isBooking = true;
      _errorMessage = null;
    });

    try {
      final booking = await ref.read(bookingsRepositoryProvider).createBooking(
            chargerId: widget.chargerId,
            startTs: _startUnix,
            endTs: _endUnix,
          );
      if (mounted) {
        context.pushReplacement('/payment/${booking.id}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().contains('409')
            ? 'This time slot is already reserved. Please choose a different slot.'
            : 'Booking failed: $e';
      });
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Booking & Breakdown')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final c = _charger;
    final ratePerKwh = c?.pricePerKwh.toDouble() ?? 16.0;
    final baseEnergyCost = _energyTargetKwh * ratePerKwh;
    final platformFee = 28.0;
    final gst = platformFee * 0.18;
    final totalDeposit = baseEnergyCost + platformFee + gst;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Booking & Breakdown'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station Snapshot Card
            if (c != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.ev_station, color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (c.avgRating != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tertiaryFixed,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, size: 12, color: AppTheme.tertiary),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${c.avgRating}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onTertiaryFixed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.address,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Host: ${c.hostName ?? "Verified Host"} • ${c.connectorType} ${c.powerKw} kW Fast AC',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Vehicle Selector Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: AppTheme.secondary, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tata Nexon EV Max (KA 01 MR 8920)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
                        ),
                        Text(
                          'Compatible with CCS2 / Type 2 • 40.5 kWh Pack',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    child: const Text('Change', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Slot Scheduling Section
            const Text(
              'Select Slot & Start Time',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
            const SizedBox(height: 10),

            // Date picker & Quick slots
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: const BorderSide(color: AppTheme.border),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('EEE, d MMM').format(_selectedDate), style: const TextStyle(fontSize: 13)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _updatePricePreview();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: const BorderSide(color: AppTheme.border),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 13)),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                        _updatePricePreview();
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Pre-defined slot pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSlotChip(0, '02:30 PM - 03:30 PM', 'Reserved', isBooked: true),
                  const SizedBox(width: 8),
                  _buildSlotChip(1, '04:00 PM - 06:00 PM', 'Open (Fast Bay)'),
                  const SizedBox(width: 8),
                  _buildSlotChip(2, '06:30 PM - 08:30 PM', 'Open'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Energy Goal Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Target Energy Top-up',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryFixed.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_energyTargetKwh.toStringAsFixed(0)} kWh (~${((_energyTargetKwh / 40.5) * 100).toInt()}% Battery)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '+${(_energyTargetKwh * 7.0).toStringAsFixed(0)} km Estimated Range Addition',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      Text(
                        'Est. Time: ~${((_energyTargetKwh / (c?.powerKw ?? 22.0)) * 60).toInt()} mins',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  Slider(
                    value: _energyTargetKwh,
                    min: 5.0,
                    max: 35.0,
                    divisions: 6,
                    label: '${_energyTargetKwh.toStringAsFixed(0)} kWh',
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.surfaceContainerHigh,
                    onChanged: (val) {
                      setState(() {
                        _energyTargetKwh = val;
                        _durationHours = (val / 10).ceil().clamp(1, 4);
                      });
                      _updatePricePreview();
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('5 kWh (Quick +35 km)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      Text('20 kWh (Standard)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      Text('35 kWh (Full Top-up)', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Transparent Price Breakdown Bill
            const Text(
              'Zero-Surge Fare Transparency',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildBillRow(
                    'Base Energy Tariff (${_energyTargetKwh.toStringAsFixed(0)} kWh @ ₹${ratePerKwh.toStringAsFixed(0)}/kWh)',
                    '₹${baseEnergyCost.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _buildBillRow('Platform Technology & Escrow Fee', '₹${platformFee.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _buildBillRow('GST (18% on technology fee)', '₹${gst.toStringAsFixed(2)}'),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Escrow Hold',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                          ),
                          Text(
                            'Unused units refunded automatically',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      Text(
                        '₹${totalDeposit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // P2P Refund Guarantee Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '100% P2P Refund Guarantee — Any unconsumed kWh is instantly credited back to your wallet the moment you unplug.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMain, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Method Selector
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
            const SizedBox(height: 10),

            _buildPaymentOption(
              id: 'upi',
              title: 'Instant UPI (Google Pay, PhonePe, Paytm)',
              subtitle: 'Zero fee • Instant escrow lock',
              icon: Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 8),
            _buildPaymentOption(
              id: 'wallet',
              title: 'ChargeBridge EV Wallet',
              subtitle: 'Available Balance: ₹1,420.00',
              icon: Icons.electric_bolt,
            ),
            const SizedBox(height: 8),
            _buildPaymentOption(
              id: 'card',
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard, RuPay',
              icon: Icons.credit_card,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),

      // Sticky Bottom Bar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${totalDeposit.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                  ),
                  const Text('Hold in Escrow', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: _isBooking ? null : _handleConfirmBooking,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: _isBooking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Lock Slot & Pay'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotChip(int index, String time, String label, {bool isBooked = false}) {
    final isSelected = _selectedSlotIndex == index;
    return GestureDetector(
      onTap: isBooked ? null : () => setState(() => _selectedSlotIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isBooked
              ? AppTheme.surfaceContainer
              : isSelected
                  ? AppTheme.primaryFixed.withOpacity(0.3)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isBooked ? AppTheme.textMuted : AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isBooked
                    ? AppTheme.error
                    : isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.secondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
                  ),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Radio<String>(
              value: id,
              groupValue: _selectedPaymentMethod,
              activeColor: AppTheme.primary,
              onChanged: (val) {
                if (val != null) setState(() => _selectedPaymentMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
