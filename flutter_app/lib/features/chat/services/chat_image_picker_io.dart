import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const int _maxChatImageDimension = 1600;
const int _chatImageQuality = 76;

Future<String?> pickChatImageAsDataUrlImpl(ImageSource source) async {
  final picker = ImagePicker();
  try {
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: _chatImageQuality,
      maxWidth: _maxChatImageDimension.toDouble(),
      maxHeight: _maxChatImageDimension.toDouble(),
    );
    if (pickedFile == null) {
      return null;
    }

    final bytes = await pickedFile.readAsBytes();
    return 'data:${_mimeTypeFromPath(pickedFile.path)};base64,${base64Encode(bytes)}';
  } on MissingPluginException {
    throw Exception(
      'El selector de imagenes necesita reiniciar la app completamente.',
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
  return 'image/jpeg';
}
