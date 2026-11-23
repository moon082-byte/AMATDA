// 텔레그램 봇 설정: /setup 웹훅·명령 메뉴 등록, 봇 정보

import { tg, webhookSecret } from './telegram.js';

/** 봇 아이디·이름 (공개 정보). 앱 설정에 넣을 봇 아이디를 확인할 때 쓴다. */
export async function botInfo(env) {
  const me = await tg(env, 'getMe', {});
  return me.ok ? { username: me.result.username, name: me.result.first_name } : { error: me.description };
}

export async function setup(url, env) {
  const hook = await tg(env, 'setWebhook', {
    url: `${url.origin}/telegram/webhook`,
    secret_token: await webhookSecret(env),
    allowed_updates: ['message', 'channel_post', 'callback_query'],
  });
  await tg(env, 'setMyCommands', {
    commands: [
      { command: 'today', description: '오늘 일정' },
      { command: 'week', description: '이번 주 일정' },
      { command: 'month', description: '이번 달 일정' },
      { command: 'all', description: '전체 일정' },
      { command: 'add', description: '할 일 추가 (예: /add 내일 3시 보고서)' },
      { command: 'status', description: '연결 상태와 예정된 알림 수' },
      { command: 'stop', description: '알림 연결 끊기' },
    ],
  });
  // 배포 직후에는 옛 버전이 응답할 수 있으므로, 실제로 등록된 내용을 다시 확인해 보여준다
  const info = await tg(env, 'getWebhookInfo', {});
  const buttons = (info.result?.allowed_updates ?? []).includes('callback_query');
  const body = !hook.ok
    ? `❌ 등록 실패: ${hook.description}`
    : `✅ 텔레그램 웹훅 등록 완료\n버튼 누름 받기: ${buttons ? '켜짐' : '꺼짐 - 잠시 뒤 이 주소를 다시 열어 주세요'}`;
  return new Response(body, {
    status: hook.ok ? 200 : 500,
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
