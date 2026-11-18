import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static Database? _db;

  static Future<Database> open() async {
    final existing = _db;
    if (existing != null) return existing;

    final directory = await getDatabasesPath();
    final db = await openDatabase(
      p.join(directory, 'esok.db'),
      version: 7,
      onCreate: (db, version) async {
        await _createTasks(db);
        await _createMoney(db);
        await seedDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createMoney(db);
        }
        if (oldVersion == 2) {
          await db.execute('ALTER TABLE categories ADD COLUMN icon_id TEXT');
        }
        if (oldVersion >= 2 && oldVersion < 4) {
          await db.execute(
            'ALTER TABLE accounts ADD COLUMN opening_balance INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await seedDefaults(db);
        }
        if (oldVersion >= 2 && oldVersion < 5) {
          await db.execute('ALTER TABLE transactions ADD COLUMN detail TEXT');
        }
        if (oldVersion >= 2 && oldVersion < 6) {
          await db.execute('ALTER TABLE accounts ADD COLUMN icon_key TEXT');
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE tasks ADD COLUMN repeat_weekdays TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN series_id TEXT');
          await db.execute('ALTER TABLE tasks ADD COLUMN repeat_until TEXT');
          await db.execute(
            'ALTER TABLE tasks ADD COLUMN is_skipped INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );

    _db = db;
    return db;
  }

  static Future<void> _createTasks(Database db) async {
    await db.execute('''
CREATE TABLE tasks (
  id             TEXT PRIMARY KEY,
  title          TEXT NOT NULL,
  scheduled_date TEXT NOT NULL,
  scheduled_time TEXT,
  notes          TEXT,
  is_done        INTEGER NOT NULL DEFAULT 0,
  created_at     INTEGER NOT NULL,
  repeat_weekdays TEXT,
  series_id       TEXT,
  repeat_until    TEXT,
  is_skipped      INTEGER NOT NULL DEFAULT 0
)
''');
    await db.execute('CREATE INDEX idx_tasks_date ON tasks(scheduled_date)');
  }

  static Future<void> _createMoney(Database db) async {
    await db.execute('''
CREATE TABLE categories (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  kind       TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  archived   INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  icon_id    TEXT
)
''');
    await db.execute('''
CREATE TABLE accounts (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  type       TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  archived   INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  opening_balance INTEGER NOT NULL DEFAULT 0,
  icon_key   TEXT
)
''');
    await db.execute('''
CREATE TABLE transactions (
  id            TEXT PRIMARY KEY,
  amount        INTEGER NOT NULL,
  kind          TEXT NOT NULL,
  category_id   TEXT,
  account_id    TEXT NOT NULL,
  to_account_id TEXT,
  date          TEXT NOT NULL,
  time          TEXT,
  note          TEXT,
  detail        TEXT,
  created_at    INTEGER NOT NULL
)
''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_tx_cat ON transactions(category_id)');
  }

  static Future<void> seedDefaults(
    DatabaseExecutor db, {
    bool categories = true,
    bool accounts = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    const expense = [
      ('cat-exp-makan', 'Makan', 'makan'),
      ('cat-exp-minuman', 'Minuman', 'minuman'),
      ('cat-exp-transport', 'Transport', 'transport'),
      ('cat-exp-belanja', 'Belanja', 'belanja'),
      ('cat-exp-tagihan', 'Tagihan', 'tagihan'),
      ('cat-exp-kesehatan', 'Kesehatan', 'kesehatan'),
      ('cat-exp-hiburan', 'Hiburan', 'hiburan'),
      ('cat-exp-lain', 'Lain-lain', 'lainnya'),
    ];
    const income = [
      ('cat-inc-gaji', 'Gaji', 'gaji'),
      ('cat-inc-bonus', 'Bonus', 'bonus'),
      ('cat-inc-jual', 'Jual', 'jual'),
      ('cat-inc-lain', 'Lain-lain', 'lainnya'),
    ];

    for (var i = 0; categories && i < expense.length; i++) {
      batch.insert('categories', {
        'id': expense[i].$1,
        'name': expense[i].$2,
        'kind': 'expense',
        'sort_order': i,
        'archived': 0,
        'created_at': now,
        'icon_id': expense[i].$3,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.update(
        'categories',
        {'icon_id': expense[i].$3},
        where: "id = ? AND (icon_id IS NULL OR icon_id = '')",
        whereArgs: [expense[i].$1],
      );
    }
    for (var i = 0; categories && i < income.length; i++) {
      batch.insert('categories', {
        'id': income[i].$1,
        'name': income[i].$2,
        'kind': 'income',
        'sort_order': i,
        'archived': 0,
        'created_at': now,
        'icon_id': income[i].$3,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.update(
        'categories',
        {'icon_id': income[i].$3},
        where: "id = ? AND (icon_id IS NULL OR icon_id = '')",
        whereArgs: [income[i].$1],
      );
    }
    if (accounts) {
      batch.insert('accounts', {
        'id': 'acc-tunai',
        'name': 'Tunai',
        'type': 'cash',
        'sort_order': 0,
        'archived': 0,
        'created_at': now,
        'opening_balance': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
