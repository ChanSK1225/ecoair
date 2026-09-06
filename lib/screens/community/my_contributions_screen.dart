import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../widgets/ecoair_ui.dart';
import 'create_post_screen.dart';
import 'contribution_export_sheet.dart';

class MyContributionsScreen extends StatelessWidget {
  const MyContributionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final communityProvider = context.watch<CommunityProvider>();
    final authorName = authProvider.userId ?? '';
    final posts = communityProvider.postsByAuthor(authorName);

    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: FilledButton.icon(
          onPressed: posts.isEmpty
              ? null
              : () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) => ContributionExportSheet(
                    userId: authorName,
                    posts: List.of(posts),
                  ),
                ),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export to CSV'),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, posts.length),
              const SizedBox(height: 28),
              Expanded(
                child: posts.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: posts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _buildContributionCard(
                            context,
                            communityProvider,
                            posts[index],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int postCount) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Contributions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$postCount ${postCount == 1 ? 'post' : 'posts'} contributed',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContributionCard(
    BuildContext context,
    CommunityProvider communityProvider,
    CommunityPost post,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('d MMM').format(post.timestamp),
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'AQI ${post.aqiAtTime}',
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePostScreen(initialPost: post),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8)),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () =>
                    _confirmDelete(context, communityProvider, post),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          if (post.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.hasCoordinates
                        ? '${post.location}  ${post.latitude!.toStringAsFixed(3)}, ${post.longitude!.toStringAsFixed(3)}'
                        : post.location,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(post.content, style: const TextStyle(fontSize: 16, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFE11D48), size: 16),
              const SizedBox(width: 4),
              Text(
                '${post.likes} likes',
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'No contributions yet.',
        style: TextStyle(color: Color(0xFF94A3B8)),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CommunityProvider communityProvider,
    CommunityPost post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contribution?'),
        content: const Text('This report post will be removed from the feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await communityProvider.deletePost(post.id);
    } catch (_) {
      if (context.mounted) {
        showEcoAirSnackBar(
          context,
          'Could not delete the post. Please retry.',
          isError: true,
        );
      }
    }
  }
}
