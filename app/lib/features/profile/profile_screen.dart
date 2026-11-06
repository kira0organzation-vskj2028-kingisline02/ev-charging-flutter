import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../data/repositories/auth_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of ChargeBridge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await ref.read(authRepositoryProvider).logout();
      ref.read(authStateProvider.notifier).state = null;
      if (mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, size: 72, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text('Not logged in', style: TextStyle(fontSize: 18, color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/auth/login'),
                child: const Text('Log In or Register'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // User card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(user.email, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions list
            Card(
              child: Column(
                children: [
                  if (!user.isHost)
                    ListTile(
                      leading: const Icon(Icons.ev_station, color: AppTheme.primary),
                      title: const Text('Become a Charger Host'),
                      subtitle: const Text('Earn income by renting out your home charger'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/host/add-charger'),
                    ),
                  if (user.isHost)
                    ListTile(
                      leading: const Icon(Icons.dashboard_outlined, color: AppTheme.primary),
                      title: const Text('Host Management Dashboard'),
                      subtitle: const Text('View earnings, chargers and received sessions'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/host'),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history, color: AppTheme.accent),
                    title: const Text('Booking History'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my-bookings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security, color: Colors.amber),
                    title: const Text('Electrical Safety Standards'),
                    subtitle: const Text('Guidelines for safe EV charging'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: const Text('Host Safety Guidelines'),
                          content: const Text(
                            'All ChargeBridge hosts must ensure their charger is installed with certified RCCB/MCB protection and proper grounding/earthing according to national electrical standards.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                onPressed: _isLoading ? null : _logout,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ChargeBridge v1.0.0 • Made with Flutter & FastAPI',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
