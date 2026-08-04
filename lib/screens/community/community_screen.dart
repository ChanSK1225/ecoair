import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/community_provider.dart';
import 'create_post_screen.dart';
import '../qr_scanner/qr_scanner_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final communityProvider = Provider.of<CommunityProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Share your local air quality reports',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'QR scanner',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRScannerScreen(),
                ),
              );
            },
            icon: const Icon(Icons.qr_code_scanner_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D58),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: communityProvider.posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final post = communityProvider.posts[index];
          return _buildPostCard(context, post);
        },
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, dynamic post) {
    final communityProvider = Provider.of<CommunityProvider>(
      context,
      listen: false,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0F9D58),
                  child: Text(
                    post.authorName[0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        post.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AQI ${post.aqiAtTime}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (post.imageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildPostImage(post.imageUrl!),
              ),
            ),
          Padding(padding: const EdgeInsets.all(16), child: Text(post.content)),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                _buildAction(
                  Icons.favorite_border,
                  '${post.likes}',
                  () => communityProvider.likePost(post.id),
                ),
                const SizedBox(width: 24),
                _buildAction(
                  Icons.chat_bubble_outline,
                  'Reply',
                  () => _showSnack(context, 'Reply feature is ready for demo.'),
                ),
                const SizedBox(width: 24),
                _buildAction(
                  Icons.share_outlined,
                  'Share',
                  () => _showSnack(context, 'Post share preview prepared.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage(String imageUrl) {
    final isNetworkImage =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (isNetworkImage) {
      return Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _imageFallback(),
      );
    }

    final file = File(imageUrl);
    if (!file.existsSync()) {
      return _imageFallback();
    }

    return Image.file(
      file,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Widget _imageFallback() {
    return Container(
      height: 200,
      width: double.infinity,
      color: const Color(0xFFE8F5E9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF0F9D58),
        size: 36,
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
