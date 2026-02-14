import 'user.dart';

class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final User sender;
  final User receiver;
  final String content;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.sender,
    required this.receiver,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int? ?? 0,
      senderId: json['sender_id'] as int? ?? 0,
      receiverId: json['receiver_id'] as int? ?? 0,
      sender: User.fromJson(json['sender'] as Map<String, dynamic>? ?? {}),
      receiver: User.fromJson(json['receiver'] as Map<String, dynamic>? ?? {}),
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender': sender.toJson(),
      'receiver': receiver.toJson(),
      'content': content,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
