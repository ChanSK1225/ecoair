import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/weather_provider.dart';
import '../../models/community_post.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Share your local air quality observation...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Add location (e.g., Kuala Lumpur)',
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey[200]!,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _imageFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.grey[300],
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Upload a photo',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'AQI watermark will be added automatically',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned(
                            right: 8,
                            top: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    setState(() => _imageFile = null),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                final content = _contentController.text.trim();
                if (content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please write an air quality observation.'),
                    ),
                  );
                  return;
                }

                final weatherProvider = Provider.of<WeatherProvider>(
                  context,
                  listen: false,
                );
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                final currentCity = weatherProvider.currentCity;
                final newPost = CommunityPost(
                  id: const Uuid().v4(),
                  content: content,
                  location: _locationController.text.isNotEmpty
                      ? _locationController.text
                      : currentCity?.name ?? 'Kuala Lumpur',
                  aqiAtTime: currentCity?.aqi ?? 72,
                  aqiStatus: currentCity?.status ?? 'Moderate',
                  likes: 0,
                  authorName: authProvider.userName ?? 'sk',
                  timestamp: DateTime.now(),
                  // In a real app we'd upload the file and get a URL
                  imageUrl: _imageFile?.path,
                );
                Provider.of<CommunityProvider>(
                  context,
                  listen: false,
                ).addPost(newPost);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF86EFAC).withValues(alpha: 0.8),
                foregroundColor: const Color(0xFF0F9D58),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Share to Community',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
