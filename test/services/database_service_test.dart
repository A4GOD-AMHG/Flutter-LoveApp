import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:love_app/services/database_service.dart';
import 'package:love_app/models/pending_operation.dart';
import 'package:love_app/models/todo.dart';
import 'package:love_app/models/message.dart';
import 'package:love_app/models/user.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.resetForTest();
    DatabaseService.setOverridePath(inMemoryDatabasePath);
  });

  tearDown(() async {
    await DatabaseService.resetForTest();
  });

  final db = DatabaseService();

  group('PendingOperations — CRUD', () {
    test('guarda y recupera una operación pendiente', () async {
      final op = PendingOperation(
        type: PendingOperation.typeCreateTodo,
        payload: '{"title":"T","description":""}',
        createdAt: DateTime(2024, 1, 27),
      );

      await db.savePendingOperation(op);
      final ops = await db.getPendingOperations();

      expect(ops.length, 1);
      expect(ops.first.type, PendingOperation.typeCreateTodo);
      expect(ops.first.id, isNotNull);
    });

    test('recupera múltiples operaciones en orden (FIFO)', () async {
      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeCreateTodo,
        payload: '{"title":"A"}',
        createdAt: DateTime(2024, 1, 27, 10),
      ));
      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeSendMessage,
        payload: '{"content":"Hola"}',
        createdAt: DateTime(2024, 1, 27, 11),
      ));

      final ops = await db.getPendingOperations();

      expect(ops.length, 2);
      expect(ops[0].type, PendingOperation.typeCreateTodo);
      expect(ops[1].type, PendingOperation.typeSendMessage);
    });

    test('elimina una operación por id', () async {
      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeDeleteTodo,
        payload: '{"id":5}',
        createdAt: DateTime.now(),
      ));

      final ops = await db.getPendingOperations();
      final id = ops.first.id!;

      await db.deletePendingOperation(id);
      final remaining = await db.getPendingOperations();

      expect(remaining, isEmpty);
    });

    test('getPendingOperationsCount retorna el conteo correcto', () async {
      expect(await db.getPendingOperationsCount(), 0);

      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeCreateTodo,
        payload: '{}',
        createdAt: DateTime.now(),
      ));
      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeSendMessage,
        payload: '{}',
        createdAt: DateTime.now(),
      ));

      expect(await db.getPendingOperationsCount(), 2);
    });

    test('eliminar operación inexistente no lanza error', () async {
      await expectLater(
        db.deletePendingOperation(9999),
        completes,
      );
    });
  });

  group('Todos — caché', () {
    test('guarda y recupera todos', () async {
      final todos = [_makeTodo(1, 'Tarea uno'), _makeTodo(2, 'Tarea dos')];

      await db.saveTodos(todos);
      final cached = await db.getCachedTodos();

      expect(cached.length, 2);
      expect(
          cached.map((t) => t.title), containsAll(['Tarea uno', 'Tarea dos']));
    });

    test('sobrescribe todo existente con mismo id (upsert)', () async {
      await db.saveTodos([_makeTodo(1, 'Original')]);
      await db.saveTodos([_makeTodo(1, 'Actualizado')]);

      final cached = await db.getCachedTodos();

      expect(cached.length, 1);
      expect(cached.first.title, 'Actualizado');
    });

    test('retorna lista vacía si no hay todos', () async {
      final cached = await db.getCachedTodos();
      expect(cached, isEmpty);
    });

    test('preserva todos los campos del todo', () async {
      final now = DateTime(2024, 6, 15, 12, 30);
      final todo = Todo(
        id: 42,
        title: 'Visitar cafetería',
        description: 'Con Anyel',
        creatorId: 2,
        creatorUsername: 'alexis',
        completedAnyel: true,
        completedAlexis: false,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      await db.saveTodos([todo]);
      final cached = await db.getCachedTodos();
      final result = cached.first;

      expect(result.id, 42);
      expect(result.title, 'Visitar cafetería');
      expect(result.description, 'Con Anyel');
      expect(result.creatorId, 2);
      expect(result.creatorUsername, 'alexis');
      expect(result.completedAnyel, true);
      expect(result.completedAlexis, false);
      expect(result.isCompleted, false);
    });
  });

  group('Messages — caché', () {
    test('guarda y recupera mensajes', () async {
      final messages = [
        _makeMessage(1, 'Hola amor'),
        _makeMessage(2, 'Te quiero mucho'),
      ];

      await db.saveMessages(messages);
      final cached = await db.getCachedMessages();

      expect(cached.length, 2);
      expect(cached.map((m) => m.content),
          containsAll(['Hola amor', 'Te quiero mucho']));
    });

    test('insertMessage agrega un mensaje individual', () async {
      final msg = _makeMessage(10, 'Mensaje individual');

      await db.insertMessage(msg);
      final cached = await db.getCachedMessages();

      expect(cached.length, 1);
      expect(cached.first.content, 'Mensaje individual');
    });

    test('mensajes se ordenan por fecha ascendente', () async {
      final earlier = _makeMessageWithDate(1, 'Primero', DateTime(2024, 1, 1));
      final later = _makeMessageWithDate(2, 'Segundo', DateTime(2024, 1, 2));

      await db.saveMessages([later, earlier]);
      final cached = await db.getCachedMessages();

      expect(cached[0].content, 'Primero');
      expect(cached[1].content, 'Segundo');
    });

    test('retorna lista vacía si no hay mensajes', () async {
      final cached = await db.getCachedMessages();
      expect(cached, isEmpty);
    });

    test('upsert en mensajes (mismo id se sobrescribe)', () async {
      await db.insertMessage(_makeMessage(5, 'Original'));
      await db.insertMessage(_makeMessage(5, 'Actualizado'));

      final cached = await db.getCachedMessages();

      expect(cached.length, 1);
      expect(cached.first.content, 'Actualizado');
    });
  });

  group('Flujo offline completo — todos', () {
    test(
        'guarda todo en caché, agrega operación pendiente y se puede recuperar',
        () async {
      final todos = [_makeTodo(1, 'Tarea offline')];
      await db.saveTodos(todos);

      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeCreateTodo,
        payload: '{"title":"Tarea offline","description":""}',
        createdAt: DateTime.now(),
      ));

      final cached = await db.getCachedTodos();
      final pending = await db.getPendingOperations();

      expect(cached.any((t) => t.title == 'Tarea offline'), isTrue);
      expect(pending.length, 1);
      expect(pending.first.type, PendingOperation.typeCreateTodo);
    });
  });

  group('Flujo offline completo — mensajes', () {
    test('guarda mensaje en caché y operación pendiente', () async {
      await db.insertMessage(_makeMessage(1, 'Mensaje offline'));

      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeSendMessage,
        payload: '{"content":"Mensaje offline"}',
        createdAt: DateTime.now(),
      ));

      final cached = await db.getCachedMessages();
      final pending = await db.getPendingOperations();

      expect(cached.any((m) => m.content == 'Mensaje offline'), isTrue);
      expect(pending.any((p) => p.type == PendingOperation.typeSendMessage),
          isTrue);
    });

    test('después de sync se pueden eliminar operaciones pendientes', () async {
      await db.savePendingOperation(PendingOperation(
        type: PendingOperation.typeSendMessage,
        payload: '{"content":"Sync test"}',
        createdAt: DateTime.now(),
      ));

      var ops = await db.getPendingOperations();
      expect(ops.length, 1);

      await db.deletePendingOperation(ops.first.id!);

      ops = await db.getPendingOperations();
      expect(ops, isEmpty);
    });
  });

  group('Auth cache — offline login', () {
    test('guarda credenciales y valida contraseña correcta', () async {
      final user = User(
        id: 1,
        username: 'anyel',
        name: 'Anyel',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      await db.cacheAuthCredentials(
        username: 'anyel',
        password: '1234',
        userJson: user.toJson(),
      );

      final valid = await db.validateCachedPassword('anyel', '1234');
      final invalid = await db.validateCachedPassword('anyel', 'xxxx');
      final cachedUser = await db.getCachedUserJson('anyel');

      expect(valid, isTrue);
      expect(invalid, isFalse);
      expect(cachedUser, isNotNull);
      expect(cachedUser!['username'], 'anyel');
    });

    test('updateCachedPassword actualiza la contraseña en caché', () async {
      final user = User(
        id: 2,
        username: 'alexis',
        name: 'Alexis',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      await db.cacheAuthCredentials(
        username: 'alexis',
        password: 'old-pass',
        userJson: user.toJson(),
      );

      await db.updateCachedPassword('alexis', 'new-pass');

      final oldValid = await db.validateCachedPassword('alexis', 'old-pass');
      final newValid = await db.validateCachedPassword('alexis', 'new-pass');

      expect(oldValid, isFalse);
      expect(newValid, isTrue);
    });
  });
}

Todo _makeTodo(int id, String title) => Todo(
      id: id,
      title: title,
      description: 'desc',
      creatorId: 2,
      creatorUsername: 'alexis',
      completedAnyel: false,
      completedAlexis: false,
      isCompleted: false,
      createdAt: DateTime(2024, 1, 27),
      updatedAt: DateTime(2024, 1, 27),
    );

Message _makeMessage(int id, String content) =>
    _makeMessageWithDate(id, content, DateTime(2024, 1, 27, id));

Message _makeMessageWithDate(int id, String content, DateTime date) {
  final user = User(
    id: 2,
    username: 'alexis',
    name: 'Alexis',
    createdAt: date,
    updatedAt: date,
  );
  return Message(
    id: id,
    senderId: 2,
    receiverId: 1,
    sender: user,
    receiver: user,
    content: content,
    status: 'sent',
    createdAt: date,
    updatedAt: date,
  );
}
