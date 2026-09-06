import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/contribution_export.dart';
import '../../models/community_post.dart';
import '../../widgets/ecoair_ui.dart';

class ContributionExportSheet extends StatefulWidget {
  const ContributionExportSheet({
    super.key,
    required this.userId,
    required this.posts,
  });
  final String userId;
  final List<CommunityPost> posts;
  @override
  State<ContributionExportSheet> createState() =>
      _ContributionExportSheetState();
}

class _ContributionExportSheetState extends State<ContributionExportSheet> {
  File? _file;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _save();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ContributionExport.save(widget.userId, widget.posts);
      if (mounted) setState(() => _file = file);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not save the CSV. Check free storage and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    setState(() => _busy = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_file!.path, mimeType: 'text/csv')],
          subject: 'EcoAir contribution log',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        showEcoAirSnackBar(
          context,
          'Sharing is unavailable. Your CSV is still saved.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Export & Share', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            '${widget.posts.length} ${widget.posts.length == 1 ? 'contribution' : 'contributions'}',
          ),
          const SizedBox(height: 12),
          if (_file != null)
            const Text(
              'CSV saved on this device. The file includes report text and location coordinates.',
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_file == null)
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          else
            FilledButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share),
              label: const Text('Share CSV'),
            ),
        ],
      ),
    ),
  );
}
