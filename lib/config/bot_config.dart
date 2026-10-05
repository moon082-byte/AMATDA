/// 텔레그램 알림봇 설정.
/// 봇 서버(Cloudflare Worker) 주소와 봇 아이디는 공개되는 값이라 코드에 둔다.
/// 비워 두면 앱의 텔레그램 알림 기능은 '준비 중'으로 표시된다.
/// 빌드할 때 `--dart-define=BOT_API_URL=...`로 덮어쓸 수도 있다.
library;

/// 예: https://amatda-bot.<계정>.workers.dev (끝에 / 없이)
const kBotApiUrl = String.fromEnvironment('BOT_API_URL', defaultValue: '');

/// BotFather에서 만든 봇 아이디 (@ 없이, 예: amatda_alarm_bot)
const kBotUsername = String.fromEnvironment('BOT_USERNAME', defaultValue: '');

/// 텔레그램 메시지에 붙이는 앱 주소
const kAppUrl = 'https://moon082-byte.github.io/AMATDA/';
