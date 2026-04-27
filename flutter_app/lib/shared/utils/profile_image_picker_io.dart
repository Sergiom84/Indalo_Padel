import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const int _maxAvatarDimension = 512;
const int _avatarImageQuality = 72;

Future<String?> pickProfileImageAsDataUrlImpl() async {
  final picker = ImagePicker();
  try {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: _avatarImageQuality,
      maxWidth: _maxAvatarDimension.toDouble(),
      maxHeight: _maxAvatarDimension.toDouble(),
    );
    if (pickedFile == null) {
      return null;
    }
    final bytes = await pickedFile.readAsBytes();
    return 'data:${_mimeTypeFromPath(pickedFile.path)};base64,${base64Encode(bytes)}';
  } on MissingPluginException {
    throw Exception(
      'El selector de imágenes necesita reiniciar la app completamente para activarse.',
    );
  }
}

String _mimeTypeFromPath(String path) {
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerPath.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lowerPath.endsWith('.gif')) {
    return 'image/gif';
  }
  return 'image/jpeg';
}
