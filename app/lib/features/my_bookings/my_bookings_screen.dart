import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/bookings_repository.dart';
import '../reviews/add_review_dialog.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookingModel> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(bookingsRepositoryProvider).getMyBookings();
      setState(() => _bookings = list);
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBookingDialog(BookingModel b) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = b.startTs - now;

    int refundPercent = 0;
    if (diff > 7200) {
      refundPercent = 100;
    } else if (diff >= 1800) {
      refundPercent = 50;
    } else {
      refundPercent = 0;
    }
    final refundAmt = (b.amountRupees * (refundPercent / 100.0));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cancel Booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel booking #${b.id}?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Refund Policy: $refundPercent% refund',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Refund Amount: ₹${refundAmt.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ref.read(bookingsRepositoryProvider).cancelBooking(b.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
        _loadBookings();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final upcoming = _bookings
        .where((b) => (b.isConfirmed || b.isPending || b.isActive) && b.endTs >= nowTs)
        .toList();

    final past = _bookings
        .where((b) => b.isCompleted || (b.endTs < nowTs && !b.isCancelled && !b.isExpired))
        .toList();

    final cancelled = _bookings
        .where((b) => b.isCancelled || b.isExpired)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: [
            Tab(text: 'Upcoming (${upcoming.length})'),
            Tab(text: 'Past (${past.length})'),
            Tab(text: 'Cancelled (${cancelled.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(upcoming, isUpcoming: true),
                _buildBookingList(past, isPast: true),
                _buildBookingList(cancelled),
              ],
            ),
    );
  }

  Widget _buildBookingList(List<BookingModel> list, {bool isUpcoming = false, bool isPast = false}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No bookings found in this section', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/map'),
              child: const Text('Explore Chargers'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final b = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        b.chargerTitle ?? 'EV Charging Station',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(b.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  b.chargerAddress ?? '',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.formattedSlot,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ₹${b.amountRupees.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    if (isUpcoming && !b.isCancelled) ...[
                      if (b.isConfirmed || b.status == 'ACTIVE')
                        ElevatedButton.icon(
                          icon: const Icon(Icons.bolt, size: 16),
                          label: const Text('Live Session'),
                          onPressed: () => context.push('/session/${b.id}'),
                        ),
                      TextButton(
                        onPressed: () => _cancelBookingDialog(b),
                        child: const Text('Cancel Booking', style: TextStyle(color: AppTheme.error)),
                      ),
                    ],
                    if (isPast && b.isCompleted)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: const Text('Leave Review'),
                        onPressed: () async {
                          final reviewed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AddReviewDialog(
                              bookingId: b.id,
                              chargerTitle: b.chargerTitle ?? 'Charger',
                            ),
                          );
                          if (reviewed == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thank you for your review!')),
                            );
                          }
                        },
                      ),
                    if (b.isPending)
                      ElevatedButton(
                        onPressed: () => context.push('/payment/${b.id}'),
                        child: const Text('Pay Now'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'CONFIRMED':
        color = AppTheme.primary;
        break;
      case 'ACTIVE':
        color = AppTheme.accent;
        break;
      case 'COMPLETED':
        color = Colors.teal;
        break;
      case 'PENDING_PAYMENT':
        color = Colors.amber;
        break;
      case 'CANCELLED':
      case 'EXPIRED':
      default:
        color = AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

