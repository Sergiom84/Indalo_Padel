import 'package:image_picker/image_picker.dart';

import 'chat_image_picker_stub.dart'
    if (dart.library.io) 'chat_image_picker_io.dart'
    if (dart.library.html) 'chat_image_picker_web.dart';

Future<String?> pickChatImageAsDataUrl(ImageSource source) {
  return pickChatImageAsDataUrlImpl(source);
}
