import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models/charger_model.dart';
import 'models/booking_model.dart';

class LocalDb {
  Database? _db;

  Future<Database?> get db async {
    if (kIsWeb) return null; // Web uses in-memory or secure storage
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chargebridge_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE cached_chargers (
            id INTEGER PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_bookings (
            id INTEGER PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> cacheChargers(List<ChargerModel> chargers) async {
    final database = await db;
    if (database == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();
    for (var c in chargers) {
      batch.insert(
        'cached_chargers',
        {'id': c.id, 'data': jsonEncode(c.toJson()), 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ChargerModel>> getCachedChargers() async {
    final database = await db;
    if (database == null) return [];
    try {
      final List<Map<String, dynamic>> maps =
          await database.query('cached_chargers', orderBy: 'updated_at DESC', limit: 50);
      return maps.map((m) {
        final data = jsonDecode(m['data'] as String) as Map<String, dynamic>;
        return ChargerModel.fromJson(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheBookings(List<BookingModel> bookings) async {
    final database = await db;
    if (database == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();
    for (var b in bookings) {
      batch.insert(
        'cached_bookings',
        {'id': b.id, 'data': jsonEncode(b.toJson()), 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<BookingModel>> getCachedBookings() async {
    final database = await db;
    if (database == null) return [];
    try {
      final List<Map<String, dynamic>> maps =
          await database.query('cached_bookings', orderBy: 'updated_at DESC');
      return maps.map((m) {
        final data = jsonDecode(m['data'] as String) as Map<String, dynamic>;
        return BookingModel.fromJson(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

final localDb = LocalDb();

