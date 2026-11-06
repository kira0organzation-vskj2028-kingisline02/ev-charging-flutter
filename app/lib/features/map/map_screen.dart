import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/models/charger_model.dart';
import '../../data/repositories/chargers_repository.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(12.9352, 77.6245); // Default: Koramangala, Bengaluru
  List<ChargerModel> _chargers = [];
  ChargerModel? _selectedCharger;
  String _selectedFilter = 'All';
  bool _isLoading = false;
  bool _showFullMap = false;
  int _navIndex = 0;

  late AnimationController _pulseController;

  final List<String> _filterChips = [
    'All',
    'CCS2',
    'Available Now',
    'Type 2',
    'Power > 22 kW',
    '≤ ₹18/kWh',
    'Host Verified',
    '3-Pin Socket',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fetchChargers();
    _determinePosition();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        final userLoc = LatLng(pos.latitude, pos.longitude);
        setState(() => _currentCenter = userLoc);
        _mapController.move(userLoc, 13.0);
        _fetchChargers();
      }
    } catch (_) {}
  }

  Future<void> _fetchChargers() async {
    setState(() => _isLoading = true);
    try {
      String? connector;
      if (_selectedFilter == 'CCS2') connector = 'CCS2';
      if (_selectedFilter == 'Type 2') connector = 'Type2';
      if (_selectedFilter == '3-Pin Socket') connector = '3-pin';

      final results = await ref.read(chargersRepositoryProvider).searchChargers(
            lat: _currentCenter.latitude,
            lng: _currentCenter.longitude,
            radiusKm: 50.0,
            connectorType: connector,
          );
      setState(() => _chargers = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chargers: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Koramangala, BLR',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Wallet Balance Pill (Electric Purple)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_balance_wallet, size: 14, color: AppTheme.secondary),
                SizedBox(width: 4),
                Text(
                  '₹1,420',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Notification Bell
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          // User Avatar (Forest Green)
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primary,
                child: Text(
                  user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Horizontal Bar
          Container(
            color: AppTheme.background,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filterChips.map((chip) {
                  final isSelected = _selectedFilter == chip;
                  final isAvailableNow = chip == 'Available Now';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      showCheckmark: false,
                      avatar: isAvailableNow
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                      label: Text(chip),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: isSelected ? AppTheme.primary : AppTheme.surfaceContainerLow,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : AppTheme.border,
                      ),
                      onSelected: (val) {
                        setState(() => _selectedFilter = chip);
                        _fetchChargers();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Main View (Mini Map Preview + Peer Chargers List)
          Expanded(
            child: _showFullMap ? _buildFullMapView() : _buildSplitView(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (index) {
          setState(() => _navIndex = index);
          if (index == 0) {
            // Already on Explore
          } else if (index == 1) {
            context.push('/my-bookings');
          } else if (index == 2) {
            if (user == null) {
              context.push('/auth/login');
            } else if (user.isHost) {
              context.push('/host');
            } else {
              context.push('/host/add-charger');
            }
          } else if (index == 3) {
            context.push('/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt_outlined),
            activeIcon: Icon(Icons.bolt),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.ev_station_outlined),
            activeIcon: Icon(Icons.ev_station),
            label: 'Host',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSplitView() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Mini Interactive Map Preview Strip
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 12.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.chargebridge.app',
                    ),
                    MarkerLayer(
                      markers: _chargers.map((c) {
                        return Marker(
                          point: LatLng(c.lat, c.lng),
                          width: 32,
                          height: 32,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      elevation: 2,
                    ),
                    onPressed: () => setState(() => _showFullMap = true),
                    icon: const Icon(Icons.map, size: 14),
                    label: const Text('Expand Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Peer Chargers (${_chargers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
              ),
              IconButton(
                icon: const Icon(Icons.my_location, size: 20, color: AppTheme.primary),
                tooltip: 'My Location',
                onPressed: _determinePosition,
              ),
            ],
          ),
        ),

        // Charger Cards
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_chargers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.ev_station_outlined, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  const Text('No chargers found matching this filter.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _selectedFilter = 'All');
                      _fetchChargers();
                    },
                    child: const Text('Reset Filter'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._chargers.map((c) => _buildStitchChargerCard(c)),

        const SizedBox(height: 16),

        // 100% Hardware Safe & Verified Trust Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.inverseSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '100% Hardware Safe & Verified',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Every host socket is inspected with 30mA RCD earth-leakage protection and ₹50,000 escrow insurance guarantee.',
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullMapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: 13.0,
            onTap: (_, __) => setState(() => _selectedCharger = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.chargebridge.app',
            ),
            MarkerLayer(
              markers: _chargers.map((c) {
                final isSelected = _selectedCharger?.id == c.id;
                return Marker(
                  point: LatLng(c.lat, c.lng),
                  width: isSelected ? 50 : 40,
                  height: isSelected ? 50 : 40,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCharger = c),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.secondary : AppTheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt, color: Colors.white, size: 22),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Collapse map button
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textMain,
            onPressed: () => setState(() => _showFullMap = false),
            child: const Icon(Icons.close),
          ),
        ),

        // Selected Charger Preview
        if (_selectedCharger != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildStitchChargerCard(_selectedCharger!),
          ),
      ],
    );
  }

  Widget _buildStitchChargerCard(ChargerModel c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Host & Distance & Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primaryFixed,
                    child: Text(
                      (c.hostName ?? 'H')[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.onPrimaryFixed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.hostName ?? 'Verified Host',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryFixed.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SuperHost',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (c.avgRating != null)
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppTheme.tertiary),
                    const SizedBox(width: 2),
                    Text(
                      '${c.avgRating} (${c.reviewCount})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Title & Address
          Text(
            c.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
          ),
          const SizedBox(height: 2),
          Text(
            c.address,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Connector & Hardware Spec Tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryContainer.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${c.connectorType} • ${c.powerKw} kW Fast AC',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 12, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text(
                      'ELCB Breaker Protected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Price & Book Direct Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${c.pricePerKwh}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const Text(
                        ' / kWh',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const Text(
                    'Free Dedicated Parking',
                    style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => context.push('/charger/${c.id}'),
                    child: const Text('Details'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () => context.push('/book/${c.id}'),
                    child: const Text('Book Slot'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
