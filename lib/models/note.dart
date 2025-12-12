class Note {
  final NotificationInfo notification;
  final Map<String, dynamic> data;
  final bool starred;
  final int trashed;
  final bool archived;
  final int time;
  final String priority;
  final Map<String, dynamic>? rawJson;

  Note({
    required this.notification,
    required this.data,
    required this.starred,
    required this.trashed,
    required this.archived,
    required this.time,
    required this.priority,
    this.rawJson,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      notification: NotificationInfo.fromJson(json['notification']),
      data: json['data'] ?? {},
      starred: json['starred'] ?? false,
      trashed: json['trashed'] is bool
          ? (json['trashed']
                ? DateTime.now().millisecondsSinceEpoch ~/ 1000
                : 0)
          : (json['trashed'] ?? 0),
      archived: json['archived'] ?? false,
      time: json['time'] ?? 0,
      priority: json['priority'] ?? 'normal',
      rawJson: json,
    );
  }

  Note copyWith({
    NotificationInfo? notification,
    Map<String, dynamic>? data,
    bool? starred,
    int? trashed,
    bool? archived,
    int? time,
    String? priority,
    Map<String, dynamic>? rawJson,
  }) {
    return Note(
      notification: notification ?? this.notification,
      data: data ?? this.data,
      starred: starred ?? this.starred,
      trashed: trashed ?? this.trashed,
      archived: archived ?? this.archived,
      time: time ?? this.time,
      priority: priority ?? this.priority,
      rawJson: rawJson ?? this.rawJson,
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
