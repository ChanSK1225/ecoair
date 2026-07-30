class CommunityPost {
  final String id;
  final String content;
  final String? imageUrl;
  final String location;
  final int aqiAtTime;
  final String aqiStatus;
  final int likes;
  final String authorName;
  final DateTime timestamp;

  CommunityPost({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.location,
    required this.aqiAtTime,
    required this.aqiStatus,
    required this.likes,
    required this.authorName,
    required this.timestamp,
  });
}
