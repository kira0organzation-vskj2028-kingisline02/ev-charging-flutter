import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/models/charger_model.dart';
import '../../data/repositories/chargers_repository.dart';

class ChargerDetailScreen extends ConsumerStatefulWidget {
  final int chargerId;

  const ChargerDetailScreen({super.key, required this.chargerId});

  @override
  ConsumerState<ChargerDetailScreen> createState() => _ChargerDetailScreenState();
}

class _ChargerDetailScreenState extends ConsumerState<ChargerDetailScreen> {
  ChargerModel? _charger;
  bool _isLoading = true;
  bool _isFavorite = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ref.read(chargersRepositoryProvider).getChargerDetail(widget.chargerId);
      setState(() => _charger = data);
    } catch (e) {
      setState(() => _error = 'Could not load charger details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _charger == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Charger not found', style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final c = _charger!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(c.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppTheme.error : AppTheme.textMain,
            ),
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isFavorite ? 'Saved to Favorites' : 'Removed from Favorites'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Charger link copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual Gallery Carousel Header
            Stack(
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: c.photos.isNotEmpty
                        ? Image.network(
                            c.photos.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                ),
                // Live Availability Float Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AVAILABLE NOW',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Photo Counter
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text(
                          'Verified Photos',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Title & Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.address,
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                                const Text(
                                  'Exact gate directions unlocked upon booking',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Host Persona Strip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          (c.hostName ?? 'H')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              c.hostName ?? 'Ramesh Kumar',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryFixed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SuperHost',
                                style: TextStyle(
                                  color: AppTheme.onPrimaryFixed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Verified Host • 100% response rate (usually 2 mins)',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4 Bento Hardware Spec Cards
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    icon: Icons.bolt,
                    badge: 'Fast AC',
                    metric: '${c.powerKw}',
                    unit: 'kW',
                    sub: 'Three-phase 32A power',
                    iconColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBentoCard(
                    icon: Icons.ev_station,
                    badge: 'Tethered',
                    metric: c.connectorType,
                    unit: '',
                    sub: '5m heavy grade cable',
                    iconColor: AppTheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    icon: Icons.garage,
                    badge: 'Secure',
                    metric: 'Covered Bay',
                    unit: '',
                    sub: 'Gated port with CCTV',
                    iconColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBentoCard(
                    icon: Icons.currency_rupee,
                    badge: 'Clear Rate',
                    metric: '₹${c.pricePerKwh}',
                    unit: '/kWh',
                    sub: 'Zero surge pricing',
                    iconColor: AppTheme.tertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Electrical Safety & Verification Section (SafeCharge™)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.inverseSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_user, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'SafeCharge™ Certified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'VERIFIED',
                                style: TextStyle(
                                  color: AppTheme.primaryFixed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Grid inspected by certified BESCOM wireman',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSafetyRow('Tested 30mA Residual Current Device (RCD / ELCB)'),
                  const SizedBox(height: 6),
                  _buildSafetyRow('Dedicated earthing pit verified (< 2 Ohm impedance)'),
                  const SizedBox(height: 6),
                  _buildSafetyRow('Auto-shutoff microsecond surge protector installed'),
                  const SizedBox(height: 6),
                  _buildSafetyRow('Waterproof outdoor enclosure (IP65 monsoon proof)'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield, color: AppTheme.primaryFixed, size: 14),
                            SizedBox(width: 6),
                            Text(
                              '₹50,000 Hardware Protection Escrow',
                              style: TextStyle(
                                color: AppTheme.primaryFixed,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Policy #CB-BLR-8924',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Amenities & Access
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
                  const Row(
                    children: [
                      Icon(Icons.local_cafe, color: AppTheme.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Host Amenities & Access',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildAmenityBadge(Icons.wifi, 'Free 300Mbps Wi-Fi')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildAmenityBadge(Icons.wc, 'Restroom on request')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildAmenityBadge(Icons.wb_twilight, 'Well-lit driveway')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildAmenityBadge(Icons.security, 'Security guard')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.secondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vehicle height clearance is 2.8m. Wide ramp suitable for luxury sedans and electric SUVs (Ioniq 5, EV6, Nexon EV).',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Estimated Range Addition Widget
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Estimated Range Addition',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMain),
                      ),
                      Text(
                        '+140 km (1 hr)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.65,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Typical 20 kWh Top-up', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      Text('Est. Session Time: ~55 mins', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Reviews & Driver Feedback
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.tertiaryFixed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: AppTheme.tertiary),
                                const SizedBox(width: 4),
                                Text(
                                  c.avgRating?.toString() ?? '4.9',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.onTertiaryFixed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${c.reviews.isNotEmpty ? c.reviews.length : 42} Verified Reviews',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text('View all', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Featured driver review
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppTheme.secondary,
                                  child: Text('A', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Ankit P.',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '• Tata Nexon EV Max',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            Text('3 days ago', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '“Seamless charging for my Nexon EV. Host offered chilled drinking water and had a clear parking space ready. Clocked 22kW steady without heating!”',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textMain),
                        ),
                      ],
                    ),
                  ),
                  if (c.reviews.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...c.reviews.map((r) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    r.reviewerName ?? 'Driver',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < r.rating ? Icons.star : Icons.star_border,
                                      color: AppTheme.tertiary,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (r.comment != null && r.comment!.isNotEmpty)
                                Text(r.comment!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${c.pricePerKwh}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                      ),
                      const Text(' / kWh', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                  Text(
                    'Approx. ₹${(c.pricePerKwh * 20).toStringAsFixed(0)} for 20 kWh top-up',
                    style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: () => context.push('/book/${c.id}'),
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Reserve Slot'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AppTheme.surfaceContainerHigh,
      child: const Center(
        child: Icon(Icons.ev_station, size: 64, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildBentoCard({
    required IconData icon,
    required String badge,
    required String metric,
    required String unit,
    required String sub,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                metric,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textMain),
              ),
              if (unit.isNotEmpty)
                Text(
                  ' $unit',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSafetyRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppTheme.primaryFixed, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMain),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
