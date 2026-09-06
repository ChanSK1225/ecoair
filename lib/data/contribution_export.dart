import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/community_post.dart';

class ContributionExport {
  static String _safe(String value) =>
      RegExp(r'^[\s]*[=+@\-\t\r\n]').hasMatch(value) ? "'$value" : value;

  static String csv(String userId, List<CommunityPost> posts) {
    final own = posts.where((post) => post.authorId == userId);
    return '\uFEFF${const ListToCsvConverter().convert([
      ['Post ID', 'Author', 'Posted at (ISO 8601)', 'Location', 'Latitude', 'Longitude', 'Report', 'AQI (reference)', 'Status', 'Likes'],
      for (final post in own) [_safe(post.id), _safe(post.authorName), post.timestamp.toIso8601String(), _safe(post.location), post.latitude, post.longitude, _safe(post.content), post.aqiAtTime, _safe(post.aqiStatus), post.likes],
    ])}';
  }

  static Future<File> save(
    String userId,
    List<CommunityPost> posts, {
    Directory? directory,
  }) async {
    final root = directory ?? await getApplicationDocumentsDirectory();
    final folder = Directory(path.join(root.path, 'exports', userId));
    await folder.create(recursive: true);
    final file = File(
      path.join(
        folder.path,
        'ecoair_contributions_${DateTime.now().microsecondsSinceEpoch}.csv',
      ),
    );
    await file.writeAsBytes(utf8.encode(csv(userId, posts)), flush: true);
    return file;
  }
}
