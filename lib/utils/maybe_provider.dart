import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 위쪽에 [T]가 제공되지 않았으면 null (로그인 없이 쓰는 테스트·미리보기용)
T? maybeProvider<T>(BuildContext context, {bool listen = true}) {
  try {
    return Provider.of<T>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}
