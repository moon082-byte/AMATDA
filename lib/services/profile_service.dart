import 'package:flutter/foundation.dart';
import '../data/local_store.dart';
import '../models/profile.dart';
import 'api_client.dart';

/// unavailable: 로그인 안 함(테스트) · loading: 처음 받는 중 · offline: 서버에 못 닿았고 저장된 것도 없음
enum ProfileStatus { unavailable, loading, offline, ready }

/// 내 프로필(닉네임#태그·사진·자기소개). 마지막으로 받은 값을 기기에 저장해 두고 바로 보여준다.
class ProfileService extends ChangeNotifier {
  final ApiClient? _api;
  final LocalStore? _store;
  Profile _profile;
  ProfileStatus _status;
  bool _busy = false;
  bool _disposed = false;

  ProfileService({this._api, LocalStore? store})
      : _store = store,
        _profile = Profile.fromJson(store?.loadProfile() ?? const {}),
        _status = _api == null
            ? ProfileStatus.unavailable
            : store?.loadProfile() == null
                ? ProfileStatus.loading
                : ProfileStatus.ready {
    if (_api != null) refresh();
  }

  Profile get profile => _profile;
  ProfileStatus get status => _status;
  bool get available => _api != null;
  bool get busy => _busy;

  /// 처음 로그인해 아직 닉네임이 없다 (서버에서 확인한 뒤에만 true)
  bool get needsNickname =>
      _status == ProfileStatus.ready && !_profile.hasNickname;

  Future<void> refresh() async {
    try {
      final res = await _api!.get('/api/profile');
      _apply(Profile.fromJson(res));
    } on ApiException catch (e) {
      debugPrint('프로필 받기 실패: $e');
      if (_status == ProfileStatus.loading) _set(ProfileStatus.offline);
    }
  }

  /// 닉네임·자기소개를 저장한다. 실패하면 error, 태그가 바뀌었으면 notice로 안내 문구를 돌려준다.
  Future<({String? error, String? notice})> save(
      {String? nickname, String? bio}) async {
    final res = await _put({'nickname': ?nickname, 'bio': ?bio});
    if (res.error != null) return (error: res.error, notice: null);
    final changed = res.body?['tagChanged'] == true;
    return (
      error: null,
      notice: changed ? '같은 닉네임#태그가 있어서 태그가 #${_profile.tag}로 바뀌었어요' : null,
    );
  }

  /// 줄인 사진(JPEG)을 프로필 사진으로. null이면 사진을 지운다(첫 글자 아바타).
  Future<String?> setAvatar(Uint8List? jpeg) async => (await _put({
        'avatar': jpeg == null ? null : Profile.avatarDataUrl(jpeg),
      }))
          .error;

  Future<({String? error, Map<String, dynamic>? body})> _put(
      Map<String, Object?> change) async {
    final api = _api;
    if (api == null) return (error: '로그인이 필요해요', body: null);
    _busy = true;
    _notify();
    try {
      final res = await api.put('/api/profile', change);
      _apply(Profile.fromJson(res));
      return (error: null, body: res);
    } on ApiException catch (e) {
      return (
        error: e.isOffline ? '인터넷 연결 후 다시 시도해 주세요' : e.message,
        body: null,
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _apply(Profile p) {
    _profile = p;
    _store?.saveProfile(p.toJson());
    _set(ProfileStatus.ready);
  }

  void _set(ProfileStatus s) {
    _status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
