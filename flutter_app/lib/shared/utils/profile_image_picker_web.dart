// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Future<String?> pickProfileImageAsDataUrlImpl() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      completer.complete(reader.result as String?);
    });
    reader.onError.first.then((_) {
      completer.completeError(
        Exception('No se pudo leer la imagen seleccionada.'),
      );
    });
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}
