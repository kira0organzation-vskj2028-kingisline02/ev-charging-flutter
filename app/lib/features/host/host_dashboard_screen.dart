import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models/charger_model.dart';
import '../../data/repositories/host_repository.dart';
import '../../data/repositories/bookings_repository.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  ConsumerState<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  HostEarningsData? _earnings;
  List<ChargerModel> _chargers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHostData();
  }

  Future<void> _loadHostData() async {
    setState(() => _isLoading = true);
    try {
      final hostRepo = ref.read(hostRepositoryProvider);
      final earningsData = await hostRepo.getHostEarnings();
      final chargersList = await hostRepo.getHostChargers();
      setState(() {
        _earnings = earningsData;
        _chargers = chargersList;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHostData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('List Charger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/host/add-charger'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHostData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Earnings',
                            '₹${_earnings?.totalEarningsRupees.toStringAsFixed(0) ?? "0"}',
                            Icons.account_balance_wallet,
                            AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Pending Payout',
                            '₹${_earnings?.pendingPayoutRupees.toStringAsFixed(0) ?? "0"}',
                            Icons.pending_actions,
                            Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Completed Sessions',
                            '${_earnings?.completedSessions ?? 0}',
                            Icons.check_circle_outline,
                            AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Active Chargers',
                            '${_earnings?.activeChargers ?? 0}',
                            Icons.ev_station,
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // My Chargers Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Chargers',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Charger'),
                          onPressed: () => context.push('/host/add-charger'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_chargers.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.ev_station, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                const Text('You have not listed any chargers yet.'),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => context.push('/host/add-charger'),
                                  child: const Text('Create First Listing'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ..._chargers.map((c) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withOpacity(0.2),
                                child: const Icon(Icons.bolt, color: AppTheme.primary),
                              ),
                              title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${c.connectorType} • ${c.powerKw} kW • ₹${c.pricePerKwh}/kWh\n${c.address}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    c.isActive ? 'ACTIVE' : 'INACTIVE',
                                    style: TextStyle(
                                      color: c.isActive ? AppTheme.primary : AppTheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (c.avgRating != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        Text(' ${c.avgRating}'),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          )),

                    const SizedBox(height: 28),

                    // Recent Bookings Received
                    const Text(
                      'Recent Sessions Received',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    if (_earnings?.recentBookings.isEmpty ?? true)
                      const Text('No bookings received yet.', style: TextStyle(color: AppTheme.textMuted))
                    else
                      ..._earnings!.recentBookings.map((b) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Driver: ${b.driverName ?? "Driver"}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(b.formattedSlot, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Payout: ₹${(b.hostPayout / 100).toStringAsFixed(2)}  (${b.payoutStatus})',
                                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (b.isConfirmed || b.isActive)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () async {
                                        await ref.read(bookingsRepositoryProvider).completeBooking(b.id);
                                        _loadHostData();
                                      },
                                      child: const Text('Mark Complete', style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            ),
                          )),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

