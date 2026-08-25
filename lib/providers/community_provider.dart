import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_post.dart';

class CommunityProvider with ChangeNotifier {
  static const _postsPrefsKey = 'ecoairCommunityPosts';
  static const _demoLatitude = 2.4650;
  static const _demoLongitude = 102.9010;
  static const _malaysiaMinLatitude = 0.5;
  static const _malaysiaMaxLatitude = 7.8;
  static const _malaysiaMinLongitude = 99.0;
  static const _malaysiaMaxLongitude = 120.0;

  final List<CommunityPost> _posts = [];
  double? _userLatitude;
  double? _userLongitude;
  bool _isLocating = false;
  String? _locationError;
  bool _usingDemoLocation = true;

  List<CommunityPost> get posts => List.unmodifiable(_posts);
  double? get userLatitude => _userLatitude;
  double? get userLongitude => _userLongitude;
  bool get isLocating => _isLocating;
  String? get locationError => _locationError;
  bool get usingDemoLocation => _usingDemoLocation;

  bool get hasUserLocation => _userLatitude != null && _userLongitude != null;

  bool isMalaysiaCoordinate(double latitude, double longitude) {
    return _isMalaysiaCoordinate(latitude, longitude);
  }

  CommunityProvider() {
    _userLatitude = _demoLatitude;
    _userLongitude = _demoLongitude;
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_postsPrefsKey);

    if (encoded == null) {
      _posts
        ..clear()
        ..addAll(_buildDemoPosts());
      await _savePosts();
      notifyListeners();
      return;
    }

    try {
      final rows = jsonDecode(encoded) as List<dynamic>;
      _posts
        ..clear()
        ..addAll(
          rows.map(
            (row) =>
                CommunityPost.fromJson(Map<String, dynamic>.from(row as Map)),
          ),
        );
    } catch (e) {
      debugPrint('Community posts cache ignored: $e');
      _posts
        ..clear()
        ..addAll(_buildDemoPosts());
      await _savePosts();
    }

    notifyListeners();
  }

  List<CommunityPost> _buildDemoPosts() {
    final now = DateTime.now();
    return [
      CommunityPost(
        id: 'demo-sk-1',
        content: 'The weather is excellent today!!!',
        location: 'Segamat, Johor, Malaysia',
        latitude: 2.46518,
        longitude: 102.90118,
        aqiAtTime: 72,
        aqiStatus: 'Moderate',
        likes: 0,
        authorName: 'sk',
        authorId: 'sk',
        timestamp: now.subtract(const Duration(hours: 3)),
      ),
      CommunityPost(
        id: 'demo-sk-2',
        content: 'hi',
        location: 'Segamat, Johor, Malaysia',
        latitude: 2.46536,
        longitude: 102.90065,
        aqiAtTime: 72,
        aqiStatus: 'Moderate',
        likes: 0,
        authorName: 'sk',
        authorId: 'sk',
        timestamp: now.subtract(const Duration(hours: 6)),
      ),
      CommunityPost(
        id: 'demo-hazard-1',
        content:
            'Open burning reported behind the workshop. The smell is strong near the residential area.',
        location: 'Bandar Segamat, Johor, Malaysia',
        latitude: 2.4738,
        longitude: 102.8956,
        aqiAtTime: 118,
        aqiStatus: 'Unhealthy',
        likes: 7,
        authorName: 'Aina',
        authorId: 'aina',
        timestamp: now.subtract(const Duration(hours: 1)),
      ),
    ];
  }

  Future<void> refreshLocation() async {
    _isLocating = true;
    _locationError = null;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is denied.');
      }

      final position = await Geolocator.getCurrentPosition();
      if (!_isMalaysiaCoordinate(position.latitude, position.longitude)) {
        _useDemoLocation(
          'Using Segamat demo location because emulator GPS is outside Malaysia.',
        );
        return;
      }

      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
      _usingDemoLocation = false;
    } catch (e) {
      _useDemoLocation(
        'Using Segamat demo location because GPS is unavailable.',
      );
      debugPrint('Community location fallback used: $e');
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  void setUserLocation(double latitude, double longitude) {
    if (!_isMalaysiaCoordinate(latitude, longitude)) {
      _useDemoLocation(
        'Using Segamat demo location because GPS returned a non-Malaysia coordinate.',
      );
      notifyListeners();
      return;
    }

    _userLatitude = latitude;
    _userLongitude = longitude;
    _usingDemoLocation = false;
    _locationError = null;
    notifyListeners();
  }

  bool _isMalaysiaCoordinate(double latitude, double longitude) {
    return latitude >= _malaysiaMinLatitude &&
        latitude <= _malaysiaMaxLatitude &&
        longitude >= _malaysiaMinLongitude &&
        longitude <= _malaysiaMaxLongitude;
  }

  void _useDemoLocation(String message) {
    _userLatitude = _demoLatitude;
    _userLongitude = _demoLongitude;
    _usingDemoLocation = true;
    _locationError = message;
  }

  List<CommunityPost> postsSortedByDistance() {
    final sorted = [..._posts];
    sorted.sort((a, b) {
      final distanceA = distanceInMeters(a);
      final distanceB = distanceInMeters(b);

      if (distanceA == null && distanceB == null) {
        return b.timestamp.compareTo(a.timestamp);
      }
      if (distanceA == null) return 1;
      if (distanceB == null) return -1;
      return distanceA.compareTo(distanceB);
    });
    return sorted;
  }

  double? distanceInMeters(CommunityPost post) {
    if (!hasUserLocation || !post.hasCoordinates) return null;
    return Geolocator.distanceBetween(
      _userLatitude!,
      _userLongitude!,
      post.latitude!,
      post.longitude!,
    );
  }

  String distanceLabel(CommunityPost post) {
    final meters = distanceInMeters(post);
    if (meters == null) return 'Nearby';
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  List<CommunityPost> postsByAuthor(String authorName) {
    final normalized = authorName.trim().toLowerCase();
    return _posts
        .where((post) => post.authorName.trim().toLowerCase() == normalized)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addPost(CommunityPost post) async {
    _posts.insert(0, post);
    await _savePosts();
    notifyListeners();
  }

  Future<void> updatePost(CommunityPost updatedPost) async {
    final index = _posts.indexWhere((post) => post.id == updatedPost.id);
    if (index < 0) return;
    _posts[index] = updatedPost;
    await _savePosts();
    notifyListeners();
  }

  Future<void> deletePost(String postId) async {
    _posts.removeWhere((post) => post.id == postId);
    await _savePosts();
    notifyListeners();
  }

  Future<void> likePost(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;

    final post = _posts[index];
    _posts[index] = post.copyWith(likes: post.likes + 1);
    await _savePosts();
    notifyListeners();
  }

  Future<File> exportPostsToCsv(List<CommunityPost> posts) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${directory.path}/ecoair_contributions_$timestamp.csv');
    final buffer = StringBuffer()
      ..writeln(
        [
          'id',
          'date',
          'author',
          'location',
          'latitude',
          'longitude',
          'distance',
          'aqi',
          'status',
          'likes',
          'content',
        ].join(','),
      );

    for (final post in posts) {
      buffer.writeln(
        [
          post.id,
          post.timestamp.toIso8601String(),
          post.authorName,
          post.location,
          post.latitude?.toStringAsFixed(6) ?? '',
          post.longitude?.toStringAsFixed(6) ?? '',
          distanceLabel(post),
          post.aqiAtTime,
          post.aqiStatus,
          post.likes,
          post.content,
        ].map(_csvEscape).join(','),
      );
    }

    return file.writeAsString(buffer.toString(), flush: true);
  }

  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _postsPrefsKey,
      jsonEncode(_posts.map((post) => post.toJson()).toList()),
    );
  }

  String _csvEscape(Object? value) {
    final text = (value ?? '').toString().replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (text.contains(',') || text.contains('"')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
