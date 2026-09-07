import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/ecoair_database.dart';
import '../models/community_post.dart';

class CommunityProvider with ChangeNotifier {
  static const _postsPrefsKey = 'ecoairCommunityPosts';
  static const _postsInitializedKey = 'community.postsInitialized';
  static const _demoLatitude = 2.4650;
  static const _demoLongitude = 102.9010;
  static const _malaysiaMinLatitude = 0.5;
  static const _malaysiaMaxLatitude = 7.8;
  static const _malaysiaMinLongitude = 99.0;
  static const _malaysiaMaxLongitude = 120.0;

  final List<CommunityPost> _posts = [];
  final Map<String, Set<String>> _likedPosts = {};
  final Set<String> _pendingLikes = {};
  late final Future<void> ready;
  double? _userLatitude;
  double? _userLongitude;
  bool _isLocating = false;
  String? _locationError;
  bool _usingDemoLocation = true;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

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

  final EcoAirDatabase _database;
  String? loadError;

  CommunityProvider({String? userId, bool initialize = true})
    : _database = userId == null
          ? EcoAirDatabase.instance
          : EcoAirDatabase.forUser(userId) {
    _userLatitude = _demoLatitude;
    _userLongitude = _demoLongitude;
    ready = initialize ? _loadSavedPosts() : Future.value();
  }

  Future<void> _loadSavedPosts() async {
    final database = EcoAirDatabase.instance;
    try {
      await database.removeRetiredCommunitySeed();
      if (_database.userId != null) {
        await database.ensureRegionalCommunitySeed();
      }
      _likedPosts.addAll(await database.loadCommunityLikes());
      final savedPosts = await database.loadCommunityPosts();
      final initialized =
          await database.getBoolSetting(_postsInitializedKey) ?? false;
      if (_database.userId != null || savedPosts.isNotEmpty || initialized) {
        _posts
          ..clear()
          ..addAll(savedPosts);
        notifyListeners();
        return;
      }
    } catch (e) {
      loadError = 'Reports could not be loaded. Please restart to retry.';
      if (_database.userId != null) {
        notifyListeners();
        return;
      }
      debugPrint('Community database cache ignored: $e');
    }

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
          rows
              .map(
                (row) => CommunityPost.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .where(
                (post) => post.id != 'demo-hazard-1' || post.authorId != 'aina',
              ),
        );
    } catch (e) {
      debugPrint('Community posts cache ignored: $e');
      _posts
        ..clear()
        ..addAll(_buildDemoPosts());
    }
    await _savePosts();
    notifyListeners();
  }

  Future<void> restoreDemoPosts() async {
    await ready;
    if (_database.userId != null) {
      throw StateError(
        'Seed report replacement is disabled for local accounts.',
      );
    }
    _posts
      ..clear()
      ..addAll(_buildDemoPosts());
    await _savePosts();
    _likedPosts.clear();
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
        aqiAtTime: 155,
        aqiStatus: 'Unhealthy',
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
        aqiAtTime: 155,
        aqiStatus: 'Unhealthy',
        likes: 0,
        authorName: 'sk',
        authorId: 'sk',
        timestamp: now.subtract(const Duration(hours: 6)),
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

      final position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 20),
      );
      if (!_isMalaysiaCoordinate(position.latitude, position.longitude)) {
        _useDemoLocation(
          'Using Segamat fallback location because emulator GPS is outside Malaysia.',
        );
        return;
      }

      _userLatitude = position.latitude;
      _userLongitude = position.longitude;
      _usingDemoLocation = false;
    } catch (e) {
      _useDemoLocation(
        'Using Segamat fallback location because GPS is unavailable.',
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
        'Using Segamat fallback location because GPS returned a non-Malaysia coordinate.',
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

  List<CommunityPost> postsByAuthor(String authorId) {
    final normalized = authorId.trim().toLowerCase();
    return _posts
        .where((post) => post.authorId.trim().toLowerCase() == normalized)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addPost(CommunityPost post) async {
    await ready;
    await _database.upsertCommunityPost(post);
    await EcoAirDatabase.instance.setBoolSetting(_postsInitializedKey, true);
    _posts.insert(0, post);
    notifyListeners();
  }

  Future<void> updatePost(CommunityPost updatedPost) async {
    await ready;
    final index = _posts.indexWhere((post) => post.id == updatedPost.id);
    if (index < 0) return;
    updatedPost = updatedPost.copyWith(likes: _posts[index].likes);
    await _database.upsertCommunityPost(updatedPost);
    await EcoAirDatabase.instance.setBoolSetting(_postsInitializedKey, true);
    _posts[index] = updatedPost;
    notifyListeners();
  }

  Future<void> deletePost(String postId) async {
    await ready;
    await _database.deleteCommunityPost(postId);
    await EcoAirDatabase.instance.setBoolSetting(_postsInitializedKey, true);
    _posts.removeWhere((post) => post.id == postId);
    for (final liked in _likedPosts.values) {
      liked.remove(postId);
    }
    notifyListeners();
  }

  bool isPostLiked(String postId, String userId) =>
      _likedPosts[userId.trim().toLowerCase()]?.contains(postId) ?? false;

  bool isLikePending(String postId) => _pendingLikes.contains(postId);

  Future<void> likePost(String postId, String userId) async {
    if (_pendingLikes.contains(postId) || userId.trim().isEmpty) return;
    await ready;
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0 || _pendingLikes.contains(postId)) return;
    _pendingLikes.add(postId);
    notifyListeners();
    try {
      final normalized = userId.trim().toLowerCase();
      final result = await _database.toggleCommunityLike(postId, normalized);
      final currentIndex = _posts.indexWhere((post) => post.id == postId);
      if (currentIndex >= 0) {
        _posts[currentIndex] = _posts[currentIndex].copyWith(
          likes: result.likes,
        );
      }
      final liked = _likedPosts.putIfAbsent(normalized, () => <String>{});
      result.liked ? liked.add(postId) : liked.remove(postId);
    } finally {
      _pendingLikes.remove(postId);
      notifyListeners();
    }
  }

  Future<void> _savePosts() async {
    try {
      await EcoAirDatabase.instance.replaceCommunityPosts(_posts);
      await EcoAirDatabase.instance.setBoolSetting(_postsInitializedKey, true);
    } catch (e) {
      debugPrint('Community database save failed: $e');
    }
  }
}
