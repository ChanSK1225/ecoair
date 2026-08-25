class CommunityPost {
  final String id;
  final String content;
  final String? imageUrl;
  final String location;
  final double? latitude;
  final double? longitude;
  final int aqiAtTime;
  final String aqiStatus;
  final int likes;
  final String authorName;
  final String authorId;
  final DateTime timestamp;

  CommunityPost({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.location,
    this.latitude,
    this.longitude,
    required this.aqiAtTime,
    required this.aqiStatus,
    required this.likes,
    required this.authorName,
    required this.authorId,
    required this.timestamp,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  CommunityPost copyWith({
    String? id,
    String? content,
    String? imageUrl,
    String? location,
    double? latitude,
    double? longitude,
    int? aqiAtTime,
    String? aqiStatus,
    int? likes,
    String? authorName,
    String? authorId,
    DateTime? timestamp,
    bool clearImage = false,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      content: content ?? this.content,
      imageUrl: clearImage ? null : imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      aqiAtTime: aqiAtTime ?? this.aqiAtTime,
      aqiStatus: aqiStatus ?? this.aqiStatus,
      likes: likes ?? this.likes,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'imageUrl': imageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'aqiAtTime': aqiAtTime,
      'aqiStatus': aqiStatus,
      'likes': likes,
      'authorName': authorName,
      'authorId': authorId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      location: json['location'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      aqiAtTime: json['aqiAtTime'] as int? ?? 72,
      aqiStatus: json['aqiStatus'] as String? ?? 'Moderate',
      likes: json['likes'] as int? ?? 0,
      authorName: json['authorName'] as String? ?? 'sk',
      authorId: json['authorId'] as String? ?? 'sk',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
