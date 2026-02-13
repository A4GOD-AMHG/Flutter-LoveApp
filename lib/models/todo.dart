class Todo {
  final int id;
  final String title;
  final String description;
  final int creatorId;
  final String creatorUsername;
  final bool completedAnyel;
  final bool completedAlexis;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Todo({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.creatorUsername,
    required this.completedAnyel,
    required this.completedAlexis,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      creatorId: json['creator_id'],
      creatorUsername: json['creator_username'],
      completedAnyel: json['completed_anyel'] ?? false,
      completedAlexis: json['completed_alexis'] ?? false,
      isCompleted: json['is_completed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'creator_id': creatorId,
      'creator_username': creatorUsername,
      'completed_anyel': completedAnyel,
      'completed_alexis': completedAlexis,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
