import 'profile_image_picker_stub.dart'
    if (dart.library.io) 'profile_image_picker_io.dart'
    if (dart.library.html) 'profile_image_picker_web.dart';

Future<String?> pickProfileImageAsDataUrl() => pickProfileImageAsDataUrlImpl();
