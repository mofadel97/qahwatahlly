import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class Avatar extends StatefulWidget {
  const Avatar({
    super.key,
    required this.imageUrl,
    required this.onImageSelected, // تغيير إلى تمرير File بدلاً من URL
  });

  final String? imageUrl;
  final void Function(File? imageFile) onImageSelected;

  @override
  _AvatarState createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  final _picker = ImagePicker();
  File? _selectedImage;

  Future<bool> _requestGalleryPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى السماح بالوصول إلى المعرض من الإعدادات'),
          action: SnackBarAction(label: 'الإعدادات', onPressed: openAppSettings),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى السماح بالوصول إلى المعرض')),
      );
    }
    return false;
  }

  Future<void> _pickImage() async {
    if (!(await _requestGalleryPermission())) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
      widget.onImageSelected(_selectedImage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.brown, width: 2),
            ),
            child: ClipOval(
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.cover, width: 150, height: 150)
                  : widget.imageUrl != null
                      ? Image.network(widget.imageUrl!, fit: BoxFit.cover, width: 150, height: 150)
                      : const Icon(Icons.camera_alt, size: 50, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _pickImage,
          child: const Text('اختيار صورة الملف الشخصي'),
        ),
      ],
    );
  }
}