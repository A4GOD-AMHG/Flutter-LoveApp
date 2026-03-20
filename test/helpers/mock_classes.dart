import 'package:mocktail/mocktail.dart';
import 'package:love_app/services/api_service.dart';
import 'package:love_app/services/database_service.dart';
import 'package:love_app/models/todo.dart';
import 'package:love_app/models/pending_operation.dart';

class MockApiService extends Mock implements ApiService {}

class MockDatabaseService extends Mock implements DatabaseService {}

Todo makeTodo({int id = 1, String title = 'Test Todo'}) => Todo(
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

PendingOperation makeOp({
  int? id,
  String type = PendingOperation.typeCreateTodo,
  String payload = '{"title":"T","description":""}',
}) =>
    PendingOperation(
      id: id ?? 1,
      type: type,
      payload: payload,
      createdAt: DateTime(2024, 1, 27),
    );
