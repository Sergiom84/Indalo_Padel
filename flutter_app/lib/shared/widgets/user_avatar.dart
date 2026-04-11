import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final double size;
  final double fontSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const UserAvatar({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.size = 64,
    this.fontSize = 24,
    this.backgroundColor = AppColors.surface2,
    this.foregroundColor = AppColors.primary,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveImageProvider(avatarUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageProvider == null
          ? Center(
              child: Text(
                _initials(displayName),
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image(
              image: imageProvider,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Center(
                  child: Text(
                    _initials(displayName),
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
    );
  }

  ImageProvider<Object>? _resolveImageProvider(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.startsWith('data:image')) {
      final bytes = _decodeDataUri(value);
      if (bytes == null) {
        return null;
      }
      return MemoryImage(bytes);
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return NetworkImage(value);
    }
    return null;
  }

  Uint8List? _decodeDataUri(String value) {
    final commaIndex = value.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= value.length - 1) {
      return null;
    }
    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}
