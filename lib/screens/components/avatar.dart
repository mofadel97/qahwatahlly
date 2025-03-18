import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

class Avatar extends StatefulWidget {
  const Avatar({
    super.key,
    required this.imageUrl,
    required this.onUpload,
  });

  final String? imageUrl;
  final void Function(String imageUrl) onUpload;

  @override
  _AvatarState createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;
  bool _isUploading = false;

  Future<bool> _requestStoragePermission() async {
    print('Checking storage permission status...');
    PermissionStatus status = await Permission.photos.status;
    print('Photos permission status: $status');

    if (status.isGranted) {
      print('Photos permission already granted');
      return true;
    }
    if (status.isPermanentlyDenied) {
      print('Photos permission permanently denied');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء السماح بالوصول إلى الصور من الإعدادات'),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: openAppSettings,
          ),
        ),
      );
      return false;
    }

    status = await Permission.photos.request();
    print('Photos permission request result: $status');

    if (status.isGranted) {
      print('Permission granted');
      return true;
    } else if (status.isPermanentlyDenied) {
      print('Permission permanently denied');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء السماح بالوصول إلى الصور من الإعدادات'),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: openAppSettings,
          ),
        ),
      );
      return false;
    } else {
      print('Permission denied');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب السماح بالوصول إلى الصور لاختيار الصورة'),
        ),
      );
      return false;
    }
  }

  Future<void> _pickAndUploadImage() async {
    print('Starting image picking process...');
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      print('Permission denied, aborting');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      print('Opening gallery...');
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        print('No image selected');
        setState(() {
          _isUploading = false;
        });
        return;
      }

      print('Image picked: ${image.path}');
      final imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();
      final imageExtension = path.extension(image.path).toLowerCase().replaceFirst('.', '');

      final userId = _supabase.auth.currentUser?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final imagePath = '$userId-profile.png';

      print('Uploading image to Supabase Storage...');
      await _supabase.storage
          .from('avatar-url')
          .uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$imageExtension',
            ),
          );

      print('Getting public URL...');
      String imageUrl = _supabase.storage.from('avatar-url').getPublicUrl(imagePath);
      imageUrl = Uri.parse(imageUrl)
          .replace(queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()})
          .toString();

      print('Image uploaded successfully: $imageUrl');
      widget.onUpload(imageUrl);
    } catch (e) {
      print('Error during image upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في رفع الصورة: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _pickAndUploadImage,
          child: SizedBox(
            width: 150,
            height: 150,
            child: _isUploading
                ? const Center(child: CircularProgressIndicator())
                : widget.imageUrl != null
                    ? Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                      )
                    : Container(
                        color: Colors.grey,
                        child: const Center(
                          child: Text('No Image'),
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isUploading ? null : _pickAndUploadImage,
          child: const Text('رفع الصورة'),
        ),
      ],
    );
  }
}