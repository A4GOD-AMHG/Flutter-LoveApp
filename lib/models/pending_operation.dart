class PendingOperation {
  final int? id;
  final String type;
  final String payload;
  final DateTime createdAt;

  static const typeCreateTodo = 'create_todo';
  static const typeSendMessage = 'send_message';
  static const typeUpdateTodoStatus = 'update_todo_status';
  static const typeDeleteTodo = 'delete_todo';
  static const typeChangePassword = 'change_password';

  PendingOperation({
    this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  factory PendingOperation.fromMap(Map<String, dynamic> map) =>
      PendingOperation(
        id: map['id'] as int?,
        type: map['type'] as String,
        payload: map['payload'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
