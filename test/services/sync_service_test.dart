import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:love_app/services/sync_service.dart';
import 'package:love_app/services/api_service.dart';
import 'package:love_app/models/pending_operation.dart';
import 'package:love_app/models/message.dart';
import 'package:love_app/models/todo.dart';
import '../helpers/mock_classes.dart';

void main() {
  late MockApiService mockApi;
  late MockDatabaseService mockDb;
  late SyncService sync;

  setUpAll(() {
    registerFallbackValue(PendingOperation(
      type: PendingOperation.typeCreateTodo,
      payload: '{}',
      createdAt: DateTime(2024),
    ));
  });

  setUp(() {
    mockApi = MockApiService();
    mockDb = MockDatabaseService();
    sync = SyncService(db: mockDb, api: mockApi);
    SyncService.overrideInstance(sync);
  });

  tearDown(() {
    SyncService.resetInstance();
  });

  group('enqueueOperation', () {
    test('guarda operación en la base de datos', () async {
      when(() => mockDb.savePendingOperation(any())).thenAnswer((_) async {});

      await sync.enqueueOperation(PendingOperation.typeCreateTodo, {
        'title': 'Mi tarea',
        'description': 'descripción',
      });

      verify(() => mockDb.savePendingOperation(any())).called(1);
    });

    test('enqueueTodoCreation guarda tipo correcto', () async {
      when(() => mockDb.savePendingOperation(any())).thenAnswer((_) async {});

      await sync.enqueueTodoCreation('Tarea', 'Desc', 'alexis');

      final captured = verify(() => mockDb.savePendingOperation(captureAny()))
          .captured
          .first as PendingOperation;
      expect(captured.type, PendingOperation.typeCreateTodo);
    });

    test('enqueueMessageSend guarda tipo correcto', () async {
      when(() => mockDb.savePendingOperation(any())).thenAnswer((_) async {});

      await sync.enqueueMessageSend('Hola amor');

      final captured = verify(() => mockDb.savePendingOperation(captureAny()))
          .captured
          .first as PendingOperation;
      expect(captured.type, PendingOperation.typeSendMessage);
    });

    test('enqueueTodoStatusUpdate guarda tipo correcto', () async {
      when(() => mockDb.savePendingOperation(any())).thenAnswer((_) async {});

      await sync.enqueueTodoStatusUpdate(42, true);

      final captured = verify(() => mockDb.savePendingOperation(captureAny()))
          .captured
          .first as PendingOperation;
      expect(captured.type, PendingOperation.typeUpdateTodoStatus);
    });

    test('enqueueTodoDeletion guarda tipo correcto', () async {
      when(() => mockDb.savePendingOperation(any())).thenAnswer((_) async {});

      await sync.enqueueTodoDeletion(5);

      final captured = verify(() => mockDb.savePendingOperation(captureAny()))
          .captured
          .first as PendingOperation;
      expect(captured.type, PendingOperation.typeDeleteTodo);
    });
  });

  group('processQueue — cola vacía', () {
    test('no llama a la API si no hay operaciones pendientes', () async {
      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => []);

      await sync.processQueue();

      verifyNever(() => mockApi.createTodo(any(), any()));
      verifyNever(() => mockApi.sendMessage(any()));
    });

    test('no emite evento si cola vacía', () async {
      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => []);
      bool emitted = false;
      final sub = sync.onSyncComplete.listen((_) => emitted = true);

      await sync.processQueue();

      await Future.delayed(Duration.zero);
      expect(emitted, isFalse);
      await sub.cancel();
    });
  });

  group('processQueue — con operaciones', () {
    test('ejecuta create_todo y elimina la operación de la cola', () async {
      final op = makeOp(
        id: 1,
        type: PendingOperation.typeCreateTodo,
        payload: '{"title":"Nueva","description":"desc"}',
      );

      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => [op]);
      when(() => mockDb.deletePendingOperation(1)).thenAnswer((_) async {});
      when(() => mockApi.createTodo(any(), any()))
          .thenAnswer((_) async => makeTodo());

      await sync.processQueue();

      verify(() => mockApi.createTodo('Nueva', 'desc')).called(1);
      verify(() => mockDb.deletePendingOperation(1)).called(1);
    });

    test('ejecuta send_message correctamente', () async {
      final op = makeOp(
        id: 2,
        type: PendingOperation.typeSendMessage,
        payload: '{"content":"Hola amor"}',
      );

      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => [op]);
      when(() => mockDb.deletePendingOperation(2)).thenAnswer((_) async {});
      when(() => mockApi.sendMessage('Hola amor'))
          .thenAnswer((_) async => MockMessage());

      await sync.processQueue();

      verify(() => mockApi.sendMessage('Hola amor')).called(1);
      verify(() => mockDb.deletePendingOperation(2)).called(1);
    });

    test('ejecuta update_todo_status correctamente', () async {
      final op = makeOp(
        id: 3,
        type: PendingOperation.typeUpdateTodoStatus,
        payload: '{"id":10,"completed":true}',
      );

      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => [op]);
      when(() => mockDb.deletePendingOperation(3)).thenAnswer((_) async {});
      when(() => mockApi.updateTodoStatus(any(), any()))
          .thenAnswer((_) async => makeTodo());

      await sync.processQueue();

      verify(() => mockApi.updateTodoStatus(10, true)).called(1);
      verify(() => mockDb.deletePendingOperation(3)).called(1);
    });

    test('ejecuta delete_todo correctamente', () async {
      final op = makeOp(
        id: 4,
        type: PendingOperation.typeDeleteTodo,
        payload: '{"id":7}',
      );

      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => [op]);
      when(() => mockDb.deletePendingOperation(4)).thenAnswer((_) async {});
      when(() => mockApi.deleteTodo(any())).thenAnswer((_) async {});

      await sync.processQueue();

      verify(() => mockApi.deleteTodo(7)).called(1);
      verify(() => mockDb.deletePendingOperation(4)).called(1);
    });

    test('emite onSyncComplete después de procesar operaciones', () async {
      final op = makeOp(id: 1);

      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => [op]);
      when(() => mockDb.deletePendingOperation(1)).thenAnswer((_) async {});
      when(() => mockApi.createTodo(any(), any()))
          .thenAnswer((_) async => makeTodo());

      bool emitted = false;
      final sub = sync.onSyncComplete.listen((_) => emitted = true);

      await sync.processQueue();

      await Future.delayed(Duration.zero);
      expect(emitted, isTrue);
      await sub.cancel();
    });

    test('procesa múltiples operaciones en orden', () async {
      final ops = [
        makeOp(
            id: 1,
            type: PendingOperation.typeCreateTodo,
            payload: '{"title":"A","description":""}'),
        makeOp(
            id: 2,
            type: PendingOperation.typeCreateTodo,
            payload: '{"title":"B","description":""}'),
      ];

      final created = <String>[];
      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => ops);
      when(() => mockDb.deletePendingOperation(any())).thenAnswer((_) async {});
      when(() => mockApi.createTodo(any(), any())).thenAnswer((inv) async {
        created.add(inv.positionalArguments[0] as String);
        return makeTodo();
      });

      await sync.processQueue();

      expect(created, ['A', 'B']);
    });

    test('se detiene en OfflineException y no elimina la operación', () async {
      final op = makeOp(id: 1);

      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => [op]);
      when(() => mockApi.createTodo(any(), any()))
          .thenThrow(OfflineException());

      await sync.processQueue();

      verifyNever(() => mockDb.deletePendingOperation(any()));
    });

    test('elimina operación con error genérico y continúa', () async {
      final ops = [
        makeOp(
            id: 1,
            type: PendingOperation.typeCreateTodo,
            payload: '{"title":"A","description":""}'),
        makeOp(
            id: 2,
            type: PendingOperation.typeCreateTodo,
            payload: '{"title":"B","description":""}'),
      ];

      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => ops);
      when(() => mockDb.deletePendingOperation(any())).thenAnswer((_) async {});
      when(() => mockApi.createTodo('A', any()))
          .thenThrow(Exception('server error'));
      when(() => mockApi.createTodo('B', any()))
          .thenAnswer((_) async => makeTodo());

      await sync.processQueue();

      verify(() => mockDb.deletePendingOperation(1)).called(1);
      verify(() => mockDb.deletePendingOperation(2)).called(1);
    });
  });

  group('getPendingCount', () {
    test('retorna conteo del db', () async {
      when(() => mockDb.getPendingOperationsCount()).thenAnswer((_) async => 3);

      final count = await sync.getPendingCount();

      expect(count, 3);
    });
  });

  group('syncOnAppLaunch', () {
    test('no sincroniza si el backend no responde al health check', () async {
      when(() => mockApi.isOnline()).thenAnswer((_) async => false);

      await sync.syncOnAppLaunch();

      verify(() => mockApi.isOnline()).called(1);
      verifyNever(() => mockDb.getPendingOperations());
      verifyNever(() => mockApi.getTodos(
            status: any(named: 'status'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
          ));
    });

    test('sincroniza al iniciar si el backend está realmente online', () async {
      when(() => mockApi.isOnline()).thenAnswer((_) async => true);
      when(() => mockDb.getPendingOperations()).thenAnswer((_) async => []);
      when(() => mockApi.getTodos(
            status: any(named: 'status'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => {
            'todos': <Todo>[],
            'page': 1,
            'per_page': 100,
            'total': 0,
            'last_page': 1,
          });
      when(() => mockApi.getConversation(
            page: any(named: 'page'),
            perPage: any(named: 'perPage'),
          )).thenAnswer((_) async => <Message>[]);
      when(() => mockApi.getUnreadCount()).thenAnswer((_) async => 2);

      await sync.syncOnAppLaunch();

      verify(() => mockApi.isOnline()).called(1);
      verify(() => mockApi.getTodos(
            status: 'all',
            sortOrder: 'desc',
            limit: 100,
          )).called(1);
      verify(() => mockApi.getConversation(page: 1, perPage: 100)).called(1);
      verify(() => mockApi.getUnreadCount()).called(1);
    });
  });

  group('buildTempTodo / tempId', () {
    test('buildTempTodo retorna Todo con datos correctos', () {
      final todo = SyncService.buildTempTodo(
        tempId: -1,
        title: 'Mi tarea',
        description: 'desc',
        creatorId: 2,
        creatorUsername: 'alexis',
      );

      expect(todo.id, -1);
      expect(todo.title, 'Mi tarea');
      expect(todo.description, 'desc');
      expect(todo.creatorId, 2);
      expect(todo.completedAnyel, false);
      expect(todo.completedAlexis, false);
      expect(todo.isCompleted, false);
    });

    test('tempId retorna un valor negativo', () {
      final id = SyncService.tempId();
      expect(id, isNegative);
    });

    test('dos llamadas a tempId generan IDs distintos', () async {
      final id1 = SyncService.tempId();
      await Future.delayed(const Duration(milliseconds: 2));
      final id2 = SyncService.tempId();
      expect(id1, isNot(equals(id2)));
    });
  });
}

class MockMessage extends Mock implements Message {}
