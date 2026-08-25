import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/weather_provider.dart';
import '../../widgets/ecoair_ui.dart';

class CreatePostScreen extends StatefulWidget {
  final CommunityPost? initialPost;

  const CreatePostScreen({super.key, this.initialPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  File? _imageFile;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  bool _isSaving = false;

  bool get _isEditing => widget.initialPost != null;

  @override
  void initState() {
    super.initState();
    final post = widget.initialPost;
    if (post == null) return;

    _contentController.text = post.content;
    _locationController.text = post.location;
    _latitude = post.latitude;
    _longitude = post.longitude;
    if (post.imageUrl != null && !post.imageUrl!.startsWith('http')) {
      _imageFile = File(post.imageUrl!);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _getGpsLocation() async {
    setState(() => _isLocating = true);
    final communityProvider = context.read<CommunityProvider>();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable location services.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final position = await Geolocator.getCurrentPosition();
      if (!communityProvider.isMalaysiaCoordinate(
        position.latitude,
        position.longitude,
      )) {
        communityProvider.setUserLocation(
          position.latitude,
          position.longitude,
        );
        if (!mounted) return;
        setState(() {
          _latitude = communityProvider.userLatitude;
          _longitude = communityProvider.userLongitude;
          _locationController.text = 'Segamat, Johor, Malaysia';
        });
        _showSnack('GPS is outside Malaysia, using Segamat demo location.');
        return;
      }

      final address = await _addressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text = address;
      });
      communityProvider.setUserLocation(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      _showSnack(friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<String> _addressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return _coordinateLabel(latitude, longitude);

      final placemark = placemarks.first;
      final parts =
          <String>[
                placemark.subLocality ?? '',
                placemark.locality ?? '',
                placemark.administrativeArea ?? '',
                placemark.country ?? '',
              ]
              .where((part) => part.trim().isNotEmpty)
              .map((part) => part.trim())
              .toSet()
              .toList();

      if (parts.isEmpty) return _coordinateLabel(latitude, longitude);
      return parts.join(', ');
    } catch (_) {
      return _coordinateLabel(latitude, longitude);
    }
  }

  String _coordinateLabel(double latitude, double longitude) {
    return 'Lat ${latitude.toStringAsFixed(5)}, Lng ${longitude.toStringAsFixed(5)}';
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnack('Please describe what you see.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final weatherProvider = context.read<WeatherProvider>();
      final authProvider = context.read<AuthProvider>();
      final communityProvider = context.read<CommunityProvider>();
      final currentCity = weatherProvider.currentCity;
      final authorName = authProvider.userName ?? 'sk';
      final authorId = authProvider.userEmail ?? authorName;
      final location = _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : _latitude != null && _longitude != null
          ? _coordinateLabel(_latitude!, _longitude!)
          : currentCity?.name ?? 'Current location';

      final post = CommunityPost(
        id: widget.initialPost?.id ?? const Uuid().v4(),
        content: content,
        location: location,
        latitude: _latitude,
        longitude: _longitude,
        aqiAtTime: currentCity?.aqi ?? widget.initialPost?.aqiAtTime ?? 72,
        aqiStatus:
            currentCity?.status ?? widget.initialPost?.aqiStatus ?? 'Moderate',
        likes: widget.initialPost?.likes ?? 0,
        authorName: widget.initialPost?.authorName ?? authorName,
        authorId: widget.initialPost?.authorId ?? authorId,
        timestamp: widget.initialPost?.timestamp ?? DateTime.now(),
        imageUrl: _imageFile?.path ?? widget.initialPost?.imageUrl,
      );

      if (_isEditing) {
        await communityProvider.updatePost(post);
      } else {
        await communityProvider.addPost(post);
      }

      if (!mounted) return;
      showEcoAirSnackBar(
        context,
        _isEditing ? 'Contribution updated.' : 'Post shared.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not save the post. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 28),
              TextField(
                controller: _contentController,
                maxLines: 5,
                style: const TextStyle(fontSize: 16),
                decoration: _inputDecoration(
                  'Describe what you see... (e.g., open burning, haze, unusual smell)',
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Location',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      decoration: _inputDecoration('Add location or use GPS'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _isLocating ? null : _getGpsLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Get GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: CustomPaint(
                  painter: DashedBorderPainter(),
                  child: Container(
                    width: double.infinity,
                    height: 190,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageFile == null
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                color: Color(0xFFCBD5E1),
                                size: 34,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Take or upload a photo',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Optional · adds visual context to your post',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  onPressed: () =>
                                      setState(() => _imageFile = null),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _isSaving ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7CCDB7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Post' : 'Share Post',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Post' : 'Create Post',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            const Text(
              'Share an air quality observation or hazard',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF10B981)),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    showEcoAirSnackBar(context, message, isError: isError);
  }
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dashWidth = 7.0;
    const dashGap = 5.0;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final path = Path()..addRRect(rect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
