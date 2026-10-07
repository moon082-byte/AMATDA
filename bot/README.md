# 아맞다 서버 (구글 로그인 · 데이터 동기화 · 텔레그램 알림봇)

앱을 닫아 둬도 리마인드 시각이 되면 텔레그램 메시지로 알려 주는 봇 서버입니다.
Cloudflare Workers(무료 플랜)에서 돌아갑니다.

## 동작 방식

1. 앱의 **설정 → 텔레그램 알림 → 연결**을 누르면 앱이 무작위 연결 코드를 만들고 `t.me/<봇>?start=<코드>`를 엽니다.
2. 텔레그램에서 **시작**을 누르면 봇 서버가 코드와 대화방을 묶어 저장합니다.
3. 앱은 할 일·업무방·루틴이 바뀔 때마다 알림 일정(보낼 시각, 문구, 링크 버튼)을 봇 서버에 올립니다.
   루틴처럼 반복되는 알림은 앞으로 7일 치를 미리 올립니다.
4. 봇 서버는 1분마다 시각이 된 알림을 텔레그램으로 보냅니다. 메시지 형식은 아래와 같고, 링크가 없는 줄은 빠집니다.
   ```
   [체크리스트 업무] 보고서 제출
   [마감기한] 10월 7일 (화) 18:00 (1시간 전)
   [텔레그램 업무방] https://t.me/...   ← 설정에서 입력한 계정별 링크
   [업무링크] https://notion.so/...     ← 할 일이 속한 업무방에 등록한 링크
   ```
   업무방 링크가 있으면 메시지 아래에 [💬 텔레그램 업무방] 버튼도 붙습니다(텔레그램이 버튼 주소를 거부하면 글만 보냅니다).

서버에 저장되는 것: 구글 계정(번호·이메일·이름), 로그인 세션(토큰의 해시), 계정별 앱 데이터(업무방·할 일·세부 항목·메모·루틴),
텔레그램 대화방 번호와 이름, 텔레그램 업무방 링크, 알림 일정(할 일 제목·마감 시각 문구).
텔레그램에서 `/stop`을 보내거나 앱에서 **연결 끊기**를 누르면 해당 데이터가 지워집니다.

## 처음 설치 (한 번만)

### 1. 텔레그램 봇 만들기
1. 텔레그램에서 [@BotFather](https://t.me/BotFather)와 대화를 시작하고 `/newbot`을 보냅니다.
2. 봇 이름(예: `아맞다 알림`)과 아이디(예: `amatda_alarm_bot`, `bot`으로 끝나야 함)를 정합니다.
3. BotFather가 알려 주는 **토큰**(`123456:ABC...`)을 복사해 둡니다. 토큰은 비밀번호와 같으니 다른 사람에게 보여 주지 마세요.

### 2. Cloudflare 준비
1. [Cloudflare](https://dash.cloudflare.com/sign-up)에 무료로 가입합니다.
2. 이 폴더에서 아래를 실행해 로그인합니다(브라우저가 열립니다).
   ```bash
   cd bot
   npm install
   npx wrangler login
   ```

### 3. 데이터베이스 만들기
```bash
npx wrangler d1 create amatda-bot
```
출력된 `database_id`를 `wrangler.toml`의 `database_id`에 넣고(다른 계정에 새로 설치할 때만), 표를 만듭니다.
```bash
npm run db:init
```

### 4. workers.dev 하위 도메인 등록 (계정당 한 번)
[Cloudflare 대시보드 → Workers](https://dash.cloudflare.com/?to=/:account/workers/onboarding)에서 하위 도메인(예: `amatda`)을 등록합니다.
봇 서버 주소가 `https://amatda-bot.<하위 도메인>.workers.dev`가 됩니다. 처음 등록하면 인증서 발급에 몇 분 걸립니다.

### 5. 봇 토큰 등록 후 배포
```bash
npx wrangler secret put BOT_TOKEN   # 1단계의 토큰을 붙여 넣기
npm run deploy
```
배포가 끝나면 `https://amatda-bot.<하위 도메인>.workers.dev` 주소가 나옵니다.

### 6. 텔레그램 웹훅 등록
브라우저로 `https://amatda-bot.<하위 도메인>.workers.dev/setup`을 엽니다. "✅ 텔레그램 웹훅 등록 완료"가 나오면 끝입니다.
`/api/info`를 열면 봇 아이디를 확인할 수 있습니다.

### 7. 구글 로그인 설정
1. [Google Cloud Console → API 및 서비스 → 사용자 인증 정보](https://console.cloud.google.com/apis/credentials)에서
   **OAuth 클라이언트 ID**(유형: 웹 애플리케이션)를 만듭니다.
2. **승인된 리디렉션 URI**에 `https://amatda-bot.<하위 도메인>.workers.dev/auth/google/callback`을 추가합니다.
   (자바스크립트 원본은 필요 없습니다. 로그인은 서버가 처리합니다.)
3. OAuth 동의 화면이 '테스트' 상태면 **테스트 사용자**에 로그인할 구글 계정을 추가합니다.
4. 비밀값을 등록합니다. 클라이언트 보안 비밀번호는 비밀번호와 같으니 다른 사람에게 보여 주지 마세요.
   ```bash
   npx wrangler secret put GOOGLE_CLIENT_ID       # ...apps.googleusercontent.com
   npx wrangler secret put GOOGLE_CLIENT_SECRET
   npx wrangler secret put ALLOWED_EMAILS         # 로그인을 허용할 이메일, 쉼표로 구분
   npx wrangler secret put OWNER_EMAIL            # 로그인 도입 전 기기 데이터·텔레그램 연결을 넘겨받을 계정
   ```
   `ALLOWED_EMAILS`에 없는 계정은 로그인할 수 없고, 목록에서 빼면 이미 로그인한 기기도 바로 막힙니다.
5. 2차 비밀번호(PIN) 해시용 서버 비밀키를 무작위로 만들어 등록합니다(값을 따로 적어 둘 필요는 없습니다).
   ```bash
   node -e "process.stdout.write(require('crypto').randomBytes(32).toString('base64url'))" | npx wrangler secret put PIN_PEPPER
   ```
   이 값을 바꾸면 모든 사용자의 PIN이 맞지 않게 되니 한 번 등록한 뒤에는 바꾸지 마세요.

### 8. 앱에 서버 연결
`lib/config/bot_config.dart`에 배포 주소와 봇 아이디를 넣고 앱을 다시 배포합니다.
```dart
const kBotApiUrl = String.fromEnvironment('BOT_API_URL', defaultValue: 'https://amatda-bot.<하위 도메인>.workers.dev');
const kBotUsername = String.fromEnvironment('BOT_USERNAME', defaultValue: 'amatda_alarm_bot');
```

## 개발

```bash
npm test                     # 로직 단위 테스트
npx wrangler dev --local --test-scheduled   # 내 PC에서 서버 실행 (.dev.vars에 위 비밀값들의 테스트 값 필요)
npm run logs                 # 배포된 봇 서버 로그 보기
```

### 데이터베이스 변경 반영
표 구조가 바뀐 버전을 배포할 때는 **배포 전에** 변경분을 한 번 실행합니다.
(처음 설치하는 경우에는 `npm run db:init`에 이미 포함돼 있어 필요 없습니다.)
```bash
npm run db:migrate           # migrations/0001_reminder_buttons.sql: 링크 버튼 칸 추가
npm run db:migrate:accounts  # migrations/0002_accounts.sql: 사용자·세션·동기화 표, 계정별 텔레그램 연결
npm run db:migrate:pin       # migrations/0003_pin.sql: 2차 비밀번호(PIN) 칸
npm run db:migrate:tgroom    # migrations/0004_tg_room_url.sql: 계정별 텔레그램 업무방 링크 칸
npm run deploy
```

## 주소 목록

| 주소 | 설명 |
|---|---|
| `GET /auth/google/start?return=<앱 주소>` | 구글 로그인 시작 |
| `GET /auth/google/callback` | 구글이 돌려보내는 주소 → `<앱 주소>?login=<일회용 코드>` |
| `POST /auth/exchange` | 일회용 코드 → 로그인 토큰 |
| `GET /auth/me`, `POST /auth/logout` | 내 정보, 로그아웃 🔒 |
| `GET` / `PUT` / `DELETE /auth/pin` | PIN 상태 / 켜기·바꾸기 / 끄기 🔒 |
| `POST /auth/pin/verify` | PIN 확인 (5번 틀리면 1분, 다시 5번 틀리면 30분 잠금) 🔒 |
| `POST /auth/pin/reset/send`, `POST /auth/pin/reset` | 텔레그램 재설정 코드 보내기, 코드로 새 PIN 정하기 🔒 |
| `POST /api/sync` | 바뀐 데이터 올리기·받기 (업무방·할 일·세부 항목·메모·루틴) 🔒 |
| `POST /api/telegram/code` | 텔레그램 연결 코드 만들기 🔒 |
| `GET` / `DELETE /api/telegram` | 텔레그램 연결 확인(업무방 링크 포함) / 끊기 🔒 |
| `PUT /api/telegram/room` | 텔레그램 업무방 링크 저장 (`{"url": ""}`이면 지움) 🔒 |
| `PUT /api/reminders` | 알림 일정 전체 올리기 🔒 |
| `POST /telegram/webhook` | 텔레그램이 보내는 메시지 (`/start <코드>`, `/stop`, `/status`) |
| `GET /setup` | 텔레그램 웹훅·명령어 등록 (여러 번 호출해도 안전) |
| `GET /api/info` | 봇 아이디·이름 확인 |
| `GET/DELETE /api/link/:code`, `PUT /api/reminders/:code` | 로그인 전 앱 호환용 (전환이 끝나면 삭제) |

🔒 `Authorization: Bearer <로그인 토큰>`이 필요합니다. PIN을 켠 계정은 그 로그인에서 PIN을 확인하기 전까지
`/api/...` 요청이 `423`(`pinRequired: true`)으로 거부됩니다.
