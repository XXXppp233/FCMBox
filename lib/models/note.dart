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
  }) : id = id ?? '${timestamp}_${service}';

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      timestamp: json['timestamp'] ?? 0,
      data: json['data'],
      service: json['service'] ?? 'Unknown Service',
      overview: json['overview'] ?? '',
      image: json['image'],
      id: json['_id']?.toString() ?? json['_local_note_id']?.toString() 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'data': data,
      'service': service,
      'overview': overview,
      'image': image,
      '_id': id,
    };
  }

  Note copyWith({
    int? timestamp,
    dynamic data,
    String? service,
    String? overview,
    String? image,
    String? id,
  }) {
    return Note(
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      service: service ?? this.service,
      overview: overview ?? this.overview,
      image: image ?? this.image,
      id: id ?? this.id,
    );
  }
}
