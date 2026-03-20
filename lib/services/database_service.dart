import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../models/todo.dart';
import '../models/message.dart';
import '../models/pending_operation.dart';
import 'dart:convert';

class DatabaseService {
  static Database? _db;
  static String? _overridePath;

  static void setOverridePath(String p) {
    _overridePath = p;
    _db = null;
  }

  static Future<void> resetForTest() async {
    await _db?.close();
    _db = null;
    _overridePath = null;
  }

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final fullPath = _overridePath ??
        path.join(await getDatabasesPath(), 'love_app.db');

    return openDatabase(
      fullPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        creator_id INTEGER,
        creator_username TEXT,
        completed_anyel INTEGER,
        completed_alexis INTEGER,
        is_completed INTEGER,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY,
        sender_id INTEGER,
        receiver_id INTEGER,
        sender_json TEXT,
        receiver_json TEXT,
        content TEXT,
        status TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> saveTodos(List<Todo> todos) async {
    final db = await database;
    final batch = db.batch();
    for (final todo in todos) {
      batch.insert('todos', {
        'id': todo.id,
        'title': todo.title,
        'description': todo.description,
        'creator_id': todo.creatorId,
        'creator_username': todo.creatorUsername,
        'completed_anyel': todo.completedAnyel ? 1 : 0,
        'completed_alexis': todo.completedAlexis ? 1 : 0,
        'is_completed': todo.isCompleted ? 1 : 0,
        'created_at': todo.createdAt.toIso8601String(),
        'updated_at': todo.updatedAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Todo>> getCachedTodos() async {
    final db = await database;
    final rows = await db.query('todos', orderBy: 'created_at DESC');
    return rows.map((row) => Todo(
      id: row['id'] as int,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      creatorId: row['creator_id'] as int,
      creatorUsername: row['creator_username'] as String,
      completedAnyel: (row['completed_anyel'] as int) == 1,
      completedAlexis: (row['completed_alexis'] as int) == 1,
      isCompleted: (row['is_completed'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    )).toList();
  }

  Future<void> saveMessages(List<Message> messages) async {
    final db = await database;
    final batch = db.batch();
    for (final msg in messages) {
      batch.insert('messages', {
        'id': msg.id,
        'sender_id': msg.senderId,
        'receiver_id': msg.receiverId,
        'sender_json': jsonEncode(msg.sender.toJson()),
        'receiver_json': jsonEncode(msg.receiver.toJson()),
        'content': msg.content,
        'status': msg.status,
        'created_at': msg.createdAt.toIso8601String(),
        'updated_at': msg.updatedAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Message>> getCachedMessages() async {
    final db = await database;
    final rows = await db.query('messages', orderBy: 'created_at ASC');
    return rows.map((row) {
      final senderJson = jsonDecode(row['sender_json'] as String) as Map<String, dynamic>;
      final receiverJson = jsonDecode(row['receiver_json'] as String) as Map<String, dynamic>;
      return Message.fromJson({
        'id': row['id'],
        'sender_id': row['sender_id'],
        'receiver_id': row['receiver_id'],
        'sender': senderJson,
        'receiver': receiverJson,
        'content': row['content'],
        'status': row['status'],
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
      });
    }).toList();
  }

  Future<void> insertMessage(Message msg) async {
    final db = await database;
    await db.insert('messages', {
      'id': msg.id,
      'sender_id': msg.senderId,
      'receiver_id': msg.receiverId,
      'sender_json': jsonEncode(msg.sender.toJson()),
      'receiver_json': jsonEncode(msg.receiver.toJson()),
      'content': msg.content,
      'status': msg.status,
      'created_at': msg.createdAt.toIso8601String(),
      'updated_at': msg.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePendingOperation(PendingOperation op) async {
    final db = await database;
    await db.insert('pending_operations', {
      'type': op.type,
      'payload': op.payload,
      'created_at': op.createdAt.toIso8601String(),
    });
  }

  Future<List<PendingOperation>> getPendingOperations() async {
    final db = await database;
    final rows = await db.query('pending_operations', orderBy: 'id ASC');
    return rows.map((r) => PendingOperation.fromMap(r)).toList();
  }

  Future<void> deletePendingOperation(int id) async {
    final db = await database;
    await db.delete('pending_operations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingOperationsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM pending_operations');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
