import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ya_viene_core/ya_viene_core.dart';

class OfflineBufferRepository {
  static const _dbName = 'yaviene_offline_buffer.db';
  static const _tableName = 'pending_positions';
  static const _maxRecords = 1000;

  Database? _db;

  Future<void> _resetInFlightRows() async {
    await _db!.update(
      _tableName,
      {
        'status': 'pending',
        'lastError': 'Recovered after process restart',
      },
      where: 'status = ?',
      whereArgs: ['sending'],
    );
  }

  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: 2,
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
            isGhostBus INTEGER NOT NULL,
            sequence INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0,
            lastError TEXT,
            lastAttemptAt INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN sequence INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              "ALTER TABLE $_tableName ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'");
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE $_tableName ADD COLUMN lastError TEXT');
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN lastAttemptAt INTEGER');
        }
      },
    );

    await _db!.execute(
        'CREATE INDEX IF NOT EXISTS idx_pending_status_timestamp ON $_tableName(status, timestamp)');
    await _resetInFlightRows();
    await _normalizeLegacySequences();
  }

  Future<int> savePosition(BusPosition position,
      {bool inFlight = false}) async {
    await init();
    final id = await _db!.insert(
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
        'sequence': position.sequence ?? 0,
        'status': inFlight ? 'sending' : 'pending',
      },
    );
    await _trimToLimit();
    return id;
  }

  Future<void> markSending(List<int> ids) async {
    await init();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db!.rawUpdate(
      'UPDATE $_tableName SET status = ?, attempts = attempts + 1, lastAttemptAt = ?, lastError = NULL WHERE id IN ($placeholders)',
      ['sending', DateTime.now().millisecondsSinceEpoch, ...ids],
    );
  }

  Future<void> markPending(List<int> ids, {String? error}) async {
    await init();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db!.rawUpdate(
      'UPDATE $_tableName SET status = ?, lastError = ? WHERE id IN ($placeholders)',
      ['pending', error, ...ids],
    );
  }

  Future<void> deletePositions(List<int> ids) async {
    await init();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db!.delete(
      _tableName,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> nextSequence() async {
    await init();
    final result = await _db!.rawQuery(
      'SELECT COALESCE(MAX(sequence), 0) + 1 AS nextSequence FROM $_tableName',
    );
    return (result.first['nextSequence'] as num).toInt();
  }

  Future<void> _normalizeLegacySequences() async {
    final legacyRows = await _db!.query(
      _tableName,
      columns: ['id'],
      where: 'sequence = 0',
      orderBy: 'id ASC',
    );
    if (legacyRows.isEmpty) return;

    final nextResult = await _db!.rawQuery(
      'SELECT COALESCE(MAX(sequence), 0) + 1 AS nextSequence FROM $_tableName',
    );
    var next = (nextResult.first['nextSequence'] as num).toInt();
    await _db!.transaction((txn) async {
      for (final row in legacyRows) {
        await txn.update(
          _tableName,
          {'sequence': next++},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  }

  Future<void> _trimToLimit() async {
    final count = Sqflite.firstIntValue(
        await _db!.rawQuery('SELECT COUNT(*) FROM $_tableName'))!;
    if (count > _maxRecords) {
      final deleteCount = count - _maxRecords;
      await _db!.delete(
        _tableName,
        where:
            'id IN (SELECT id FROM $_tableName WHERE status = ? ORDER BY timestamp ASC LIMIT ?)',
        whereArgs: ['pending', deleteCount],
      );
    }
  }

  Future<List<PendingPosition>> getPendingPositions() async {
    await init();
    final List<Map<String, dynamic>> maps = await _db!.query(
      _tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'timestamp ASC',
      limit: _maxRecords,
    );

    return List.generate(maps.length, (i) {
      return PendingPosition(
        id: (maps[i]['id'] as num).toInt(),
        position: BusPosition(
          busId: maps[i]['busId'] as String,
          routeId: maps[i]['routeId'] as String,
          lat: (maps[i]['lat'] as num).toDouble(),
          lon: (maps[i]['lon'] as num).toDouble(),
          heading: (maps[i]['heading'] as num).toDouble(),
          speedKmh: (maps[i]['speedKmh'] as num).toDouble(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
              (maps[i]['timestamp'] as num).toInt()),
          isGhostBus: (maps[i]['isGhostBus'] as int) == 1,
          sequence: (maps[i]['sequence'] as num).toInt(),
        ),
      );
    });
  }

  Future<int> pendingCount() async {
    await init();
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) AS count FROM $_tableName WHERE status = ?',
      ['pending'],
    );
    return (result.first['count'] as num).toInt();
  }

  Future<bool> syncPendingPositions(
    Future<Set<int>> Function(List<PendingPosition> batch) onSendBatch,
  ) async {
    final pending = await getPendingPositions();
    if (pending.isEmpty) return true;

    const batchSize = 20;

    for (int i = 0; i < pending.length; i += batchSize) {
      final end =
          (i + batchSize < pending.length) ? i + batchSize : pending.length;
      final batch = pending.sublist(i, end);
      final ids = batch.map((item) => item.id).toList();
      await markSending(ids);

      Set<int> resolved;
      try {
        resolved = await onSendBatch(batch);
      } catch (error) {
        await markPending(ids, error: error.toString());
        return false;
      }

      final confirmed = ids.where(resolved.contains).toList();
      final unresolved = ids.where((id) => !resolved.contains(id)).toList();
      await deletePositions(confirmed);
      await markPending(unresolved, error: 'No ACK received');
      if (unresolved.isNotEmpty) return false;
    }

    return true;
  }
}

class PendingPosition {
  final int id;
  final BusPosition position;

  const PendingPosition({required this.id, required this.position});
}
