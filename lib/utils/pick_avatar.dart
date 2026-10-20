import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// 프로필 사진 최대 크기 (서버 제한과 같음)
const kMaxAvatarBytes = 200 * 1024;
const kAvatarSize = 512;

/// 사진을 고르게 하고, 512px 이하 JPEG(200KB 이하)로 줄여 돌려준다. 고르지 않으면 둘 다 null.
Future<({Uint8List? jpeg, String? error})> pickAvatar() async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kAvatarSize.toDouble(),
      maxHeight: kAvatarSize.toDouble(),
    );
  } catch (e) {
    return (jpeg: null, error: '사진을 열지 못했어요');
  }
  if (file == null) return (jpeg: null, error: null);
  final jpeg = shrinkAvatar(await file.readAsBytes());
  return jpeg == null
      ? (jpeg: null, error: '이 사진은 쓸 수 없어요. 다른 사진(JPG·PNG)을 골라 주세요')
      : (jpeg: jpeg, error: null);
}

/// 정사각형으로 가운데를 잘라 [kAvatarSize] 이하로 줄이고, 200KB 이하가 될 때까지 화질을 낮춰 JPEG로 만든다.
/// 읽을 수 없는 형식이면 null.
Uint8List? shrinkAvatar(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  var square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  if (side > kAvatarSize) {
    square = img.copyResize(square, width: kAvatarSize, height: kAvatarSize);
  }
  for (final quality in [85, 70, 55, 40]) {
    final jpeg = img.encodeJpg(square, quality: quality);
    if (jpeg.length <= kMaxAvatarBytes) return jpeg;
  }
  return null;
}
