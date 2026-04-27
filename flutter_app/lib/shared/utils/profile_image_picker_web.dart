// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

const int _maxImageDimension = 512;
const double _jpegQuality = 0.72;
const String _outputMimeType = 'image/jpeg';

Future<String?> pickProfileImageAsDataUrlImpl() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';

  input.onChange.first.then((_) async {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
      return;
    }

    try {
      final dataUrl = await _readOptimizedImageAsDataUrl(file);
      completer.complete(dataUrl);
    } catch (_) {
      completer.completeError(
        Exception('No se pudo leer la imagen seleccionada.'),
      );
    }
  });

  input.click();
  return completer.future;
}

Future<String> _readOptimizedImageAsDataUrl(html.File file) async {
  final originalDataUrl = await _readFileAsDataUrl(file);
  final image = await _loadImage(originalDataUrl);

  final width = image.width ?? 0;
  final height = image.height ?? 0;
  if (width <= 0 || height <= 0) {
    return originalDataUrl;
  }

  final targetSize = _scaledDimensions(width, height);
  const mimeType = _outputMimeType;

  final canvas = html.CanvasElement(
    width: targetSize.$1,
    height: targetSize.$2,
  );

  canvas.context2D.drawImageScaled(
    image,
    0,
    0,
    targetSize.$1.toDouble(),
    targetSize.$2.toDouble(),
  );

  return canvas.toDataUrl(mimeType, _jpegQuality);
}

Future<String> _readFileAsDataUrl(html.File file) {
  final completer = Completer<String>();
  final reader = html.FileReader();

  reader.onLoad.first.then((_) {
    completer.complete(reader.result as String);
  });
  reader.onError.first.then((_) {
    completer.completeError(Exception('No se pudo leer el archivo.'));
  });

  reader.readAsDataUrl(file);
  return completer.future;
}

Future<html.ImageElement> _loadImage(String dataUrl) {
  final completer = Completer<html.ImageElement>();
  final image = html.ImageElement();

  image.onLoad.first.then((_) => completer.complete(image));
  image.onError.first.then((_) {
    completer.completeError(Exception('No se pudo procesar la imagen.'));
  });

  image.src = dataUrl;
  return completer.future;
}

(int, int) _scaledDimensions(int width, int height) {
  final largestSide = width > height ? width : height;
  if (largestSide <= _maxImageDimension) {
    return (width, height);
  }

  final scale = _maxImageDimension / largestSide;
  return (
    (width * scale).round(),
    (height * scale).round(),
  );
}
