import 'package:flutter/material.dart';
import '../models/community_post.dart';

class CommunityProvider with ChangeNotifier {
  List<CommunityPost> _posts = [];

  List<CommunityPost> get posts => _posts;

  CommunityProvider() {
    _loadMockPosts();
  }

  void _loadMockPosts() {
    _posts = [
      CommunityPost(
        id: '1',
        content: 'Haze is getting bad near Putrajaya today. Stay safe everyone! 😷',
        location: 'Putrajaya',
        aqiAtTime: 165,
        aqiStatus: 'Unhealthy',
        likes: 24,
        authorName: 'Ahmad R.',
        imageUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb75bb44?auto=format&fit=crop&q=80&w=800',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      CommunityPost(
        id: '2',
        content: 'Beautiful clear sky in Penang today! AQI is only 35 ☀️',
        location: 'Penang',
        aqiAtTime: 35,
        aqiStatus: 'Good',
        likes: 42,
        authorName: 'Siti N.',
        imageUrl: 'https://images.unsplash.com/photo-1596422846543-75c6fc18a5cf?auto=format&fit=crop&q=80&w=800',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      CommunityPost(
        id: '3',
        content: 'AQI in Kuala Lumpur is moderate. Still okay for outdoor activities.',
        location: 'Kuala Lumpur',
        aqiAtTime: 182,
        aqiStatus: 'Unhealthy',
        likes: 15,
        authorName: 'Raj K.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    notifyListeners();
  }

  void addPost(CommunityPost post) {
    _posts.insert(0, post);
    notifyListeners();
  }
}
