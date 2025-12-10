class Note {
  final NotificationInfo notification;
  final Map<String, dynamic> data;
  final bool starred;
  final bool trashed;
  final bool archived;
  final int time;
  final String priority;

  Note({
    required this.notification,
    required this.data,
    required this.starred,
    required this.trashed,
    required this.archived,
    required this.time,
    required this.priority,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      notification: NotificationInfo.fromJson(json['notification']),
      data: json['data'] ?? {},
      starred: json['starred'] ?? false,
      trashed: json['trashed'] ?? false,
      archived: json['archived'] ?? false,
      time: json['time'] ?? 0,
      priority: json['priority'] ?? 'normal',
    );
  }

  Note copyWith({
    NotificationInfo? notification,
    Map<String, dynamic>? data,
    bool? starred,
    bool? trashed,
    bool? archived,
    int? time,
    String? priority,
  }) {
    return Note(
      notification: notification ?? this.notification,
      data: data ?? this.data,
      starred: starred ?? this.starred,
      trashed: trashed ?? this.trashed,
      archived: archived ?? this.archived,
      time: time ?? this.time,
      priority: priority ?? this.priority,
    );
  }
}

class NotificationInfo {
  final String title;
  final String body;

  NotificationInfo({required this.title, required this.body});

  factory NotificationInfo.fromJson(Map<String, dynamic> json) {
    return NotificationInfo(
      title: json['title'] ?? '',
      body: json['body'] ?? '',
    );
  }
}
