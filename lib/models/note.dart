class Note {
  final int timestamp;
  final dynamic data;
  final String service;
  final String overview;
  final String? image;
  final String id; // Internal ID for UI

  Note({
    required this.timestamp,
    required this.data,
    required this.service,
    required this.overview,
    this.image,
    String? id,
  }) : id = id ?? '${timestamp}_$service';

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      timestamp: json['timestamp'] ?? 0,
      data: json['data'],
      service: json['service'] ?? 'Unknown Service',
      overview: json['overview'] ?? '',
      image: json['image'],
      id: json['_id']?.toString() ?? json['_local_note_id']?.toString(),
    );
  }
}
