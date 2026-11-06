import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/data/models/user_model.dart';
import 'package:app/data/models/charger_model.dart';
import 'package:app/data/models/booking_model.dart';
import 'package:app/data/repositories/bookings_repository.dart';
import 'package:app/features/auth/login_screen.dart';
import 'package:app/features/booking/live_session_screen.dart';
import 'package:app/core/theme.dart';

class FakeBookingsRepository extends Fake implements BookingsRepository {
  @override
  Future<BookingModel> getBooking(int id) async {
    return BookingModel(
      id: id,
      chargerId: 10,
      driverId: 1,
      startTs: 1730000000,
      endTs: 1730007200,
      status: 'CONFIRMED',
      amount: 35000,
      commission: 3500,
      hostPayout: 31500,
      payoutStatus: 'PENDING',
      createdAt: '2026-11-04 12:00:00',
    );
  }
}

void main() {
  group('ChargeBridge Data Models Unit Tests', () {
    test('UserModel serialization and role checks', () {
      final user = UserModel(
        id: 1,
        name: 'John Doe',
        email: 'john@example.com',
        role: 'host',
        phone: '9876543210',
        isVerified: true,
      );

      final json = user.toJson();
      final parsed = UserModel.fromJson(json);

      expect(parsed.id, 1);
      expect(parsed.name, 'John Doe');
      expect(parsed.email, 'john@example.com');
      expect(parsed.isHost, true);
      expect(parsed.isAdmin, false);
    });

    test('ChargerModel price calculations', () {
      final charger = ChargerModel(
        id: 10,
        hostId: 2,
        title: 'Super Charger',
        lat: 28.6139,
        lng: 77.2090,
        address: 'Delhi NCR',
        connectorType: 'CCS2',
        powerKw: 22.0,
        pricePerKwh: 16.0,
        pricePerHour: 250.0,
      );

      expect(charger.displayHourlyRate, 250.0);
      expect(charger.connectorType, 'CCS2');
      expect(charger.powerKw, 22.0);
    });

    test('BookingModel rupee conversion and formatting', () {
      final booking = BookingModel(
        id: 101,
        chargerId: 10,
        driverId: 1,
        startTs: 1730000000,
        endTs: 1730007200,
        status: 'CONFIRMED',
        amount: 25000, // 250.00 INR
        commission: 3000,
        hostPayout: 22000,
        payoutStatus: 'PENDING',
        createdAt: '2026-11-04 12:00:00',
      );

      expect(booking.amountRupees, 250.0);
      expect(booking.hostPayoutRupees, 220.0);
      expect(booking.isConfirmed, true);
      expect(booking.isCancelled, false);
    });
  });

  group('ChargeBridge Widget Smoke Tests', () {
    testWidgets('LoginScreen renders fields and login button', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('Welcome to ChargeBridge'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('LiveSessionScreen renders telemetry and safety indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingsRepositoryProvider.overrideWithValue(FakeBookingsRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LiveSessionScreen(bookingId: 101),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Active Charging Session'), findsOneWidget);
      expect(find.text('₹350 Escrow Locked'), findsOneWidget);
      expect(find.text('Hardware Access PIN'), findsOneWidget);
      expect(find.text('4892'), findsOneWidget);
      expect(find.text('+30m Extend'), findsOneWidget);
      expect(find.text('Stop & Unlock'), findsOneWidget);
    });
  });
}
