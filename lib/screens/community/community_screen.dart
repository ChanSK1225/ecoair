import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/community_post.dart';
import '../../providers/community_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/ecoair_theme.dart';
import '../../widgets/ecoair_ui.dart';
import 'create_post_screen.dart';
import 'my_contributions_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoAirColors.background,
      body: SafeArea(
        child: Consumer<CommunityProvider>(
          builder: (context, communityProvider, child) {
            final posts = communityProvider.postsSortedByDistance();

            return RefreshIndicator(
              onRefresh: communityProvider.refreshLocation,
              color: EcoAirColors.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 164),
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 6),
                  const Text(
                    'On-device reports - AQI badges use reference readings',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (communityProvider.loadError case final String error)
                    Text(error, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  _buildLocationBanner(context, communityProvider),
                  if (communityProvider.locationError != null) ...[
                    const SizedBox(height: 12),
                    EcoAirInlineMessage(
                      icon: Icons.location_off_outlined,
                      title: 'GPS fallback',
                      message: communityProvider.locationError!,
                      color: EcoAirColors.warning,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (posts.isEmpty)
                    EcoAirEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No nearby reports',
                      message:
                          'Create the first air quality or open burning report near you.',
                      action: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreatePostScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create Post'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...posts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPostCard(context, communityProvider, post),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Nearby hazards and air quality reports',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'My Contributions',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MyContributionsScreen(),
              ),
            );
          },
          icon: const Icon(Icons.article_outlined),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreatePostScreen()),
            );
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Post'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationBanner(
    BuildContext context,
    CommunityProvider communityProvider,
  ) {
    final statusText = communityProvider.isLocating
        ? 'Locating...'
        : communityProvider.usingDemoLocation
        ? 'Segamat fallback location · tap Refresh for GPS'
        : 'Located · posts sorted by distance';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation_outlined, color: Color(0xFF059669)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                color: Color(0xFF047857),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: communityProvider.isLocating
                ? null
                : communityProvider.refreshLocation,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
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
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF14B8A6),
                child: Text(
                  post.authorName.isEmpty
                      ? '?'
                      : post.authorName[0].toLowerCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  post.authorName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildPill(
                Icons.navigation_outlined,
                communityProvider.distanceLabel(post),
                const Color(0xFFD1FAE5),
                const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              _buildPill(
                null,
                'AQI ${post.aqiAtTime}',
                const Color(0xFFFEF3C7),
                const Color(0xFFD97706),
              ),
            ],
          ),
          if (post.location.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.location,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            post.content,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Builder(
                builder: (context) {
                  final userId = context.watch<AuthProvider>().userId ?? '';
                  final liked = communityProvider.isPostLiked(post.id, userId);
                  return TextButton.icon(
                    key: ValueKey('like-${post.id}'),
                    style: TextButton.styleFrom(
                      foregroundColor: liked
                          ? Colors.red
                          : const Color(0xFF64748B),
                    ),
                    onPressed: communityProvider.isLikePending(post.id)
                        ? null
                        : () async {
                            try {
                              await communityProvider.likePost(post.id, userId);
                            } catch (_) {
                              if (context.mounted) {
                                showEcoAirSnackBar(
                                  context,
                                  'Could not save your like. Please try again.',
                                  isError: true,
                                );
                              }
                            }
                          },
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      semanticLabel: liked ? 'Unlike post' : 'Like post',
                    ),
                    label: Text('${post.likes}'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(
    IconData? icon,
    String label,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
