
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class OfflineBufferRepository {
  static const _dbName = 'yaviene_offline_buffer.db';
  static const _tableName = 'pending_positions';
  static const _maxRecords = 1000;

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            busId TEXT NOT NULL,
            routeId TEXT NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            heading REAL NOT NULL,
            speedKmh REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            isGhostBus INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> savePosition(BusPosition position) async {
    await init();
    await _db!.insert(
      _tableName,
      {
        'busId': position.busId,
        'routeId': position.routeId,
        'lat': position.lat,
        'lon': position.lon,
        'heading': position.heading,
        'speedKmh': position.speedKmh,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
        'isGhostBus': position.isGhostBus ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _trimToLimit();
  }

  Future<void> _trimToLimit() async {
    final count = Sqflite.firstIntValue(
        await _db!.rawQuery('SELECT COUNT(*) FROM $_tableName'))!;
    if (count > _maxRecords) {
      final deleteCount = count - _maxRecords;
      await _db!.delete(
        _tableName,
        where: 'id IN (SELECT id FROM $_tableName ORDER BY timestamp ASC LIMIT ?)',
        whereArgs: [deleteCount],
      );
    }
  }

  Future<List<BusPosition>> getPendingPositions() async {
    await init();
    final List<Map<String, dynamic>> maps = await _db!.query(
      _tableName,
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return BusPosition(
        busId: maps[i]['busId'] as String,
        routeId: maps[i]['routeId'] as String,
        lat: maps[i]['lat'] as double,
        lon: maps[i]['lon'] as double,
        heading: maps[i]['heading'] as double,
        speedKmh: maps[i]['speedKmh'] as double,
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp'] as int),
        isGhostBus: (maps[i]['isGhostBus'] as int) == 1,
      );
    });
  }

  Future<void> clearPendingPositions() async {
    await init();
    await _db!.delete(_tableName);
  }

  Future<bool> syncPendingPositions(
    Future<bool> Function(List<BusPosition> batch) onSendBatch,
  ) async {
    final pending = await getPendingPositions();
    if (pending.isEmpty) return true;

    const batchSize = 20;
    
    for (int i = 0; i < pending.length; i += batchSize) {
      final end = (i + batchSize < pending.length) ? i + batchSize : pending.length;
      final batch = pending.sublist(i, end);
      
      final success = await onSendBatch(batch);
      if (!success) {
        return false;
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    await clearPendingPositions();
    return true;
  }
}
