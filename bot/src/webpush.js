// Web Push 보내기 (외부 라이브러리 없이 Web Crypto로 구현, Workers와 Node 모두 동작)
// - 메시지 암호화: RFC 8291 (aes128gcm, RFC 8188)
// - 서버 인증: RFC 8292 VAPID (ES256 JWT)
//
// 필요한 설정: VAPID_PUBLIC_KEY(65바이트 공개키), VAPID_PRIVATE_KEY(32바이트 비밀키) — 둘 다 base64url,
//            VAPID_SUBJECT(연락처, 예: mailto:me@example.com). `npm run vapid:keys`로 만든다.

import { base64url } from './crypto.js';

const enc = new TextEncoder();

export function fromBase64url(text) {
  const b64 = String(text).replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64 + '='.repeat((4 - (b64.length % 4)) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

const concat = (...parts) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
};

async function hmac(key, data) {
  const k = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, data));
}

/** 65바이트 공개키(0x04‖x‖y)와 32바이트 비밀키로 P-256 JWK를 만든다 */
function p256Jwk(publicRaw, privateRaw) {
  return {
    kty: 'EC',
    crv: 'P-256',
    x: base64url(publicRaw.slice(1, 33)),
    y: base64url(publicRaw.slice(33, 65)),
    ...(privateRaw ? { d: base64url(privateRaw) } : {}),
  };
}

/** 받는 기기의 키([p256dh], [auth])로 [plaintext]를 암호화한 본문 (RFC 8291). 시험용으로 임시 키·salt를 넣을 수 있다 */
export async function encryptPayload(plaintext, p256dh, auth, { senderKeys, salt } = {}) {
  const uaPublic = fromBase64url(p256dh);
  const authSecret = fromBase64url(auth);
  const ecdh = { name: 'ECDH', namedCurve: 'P-256' };
  const keys = senderKeys ?? (await crypto.subtle.generateKey(ecdh, true, ['deriveBits']));
  const asPublic = new Uint8Array(await crypto.subtle.exportKey('raw', keys.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', uaPublic, ecdh, false, []);
  const shared = new Uint8Array(
    await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, keys.privateKey, 256),
  );

  // IKM = HKDF(auth, ecdh_secret, "WebPush: info\0" ‖ ua_public ‖ as_public, 32)
  const prkKey = await hmac(authSecret, shared);
  const ikm = await hmac(prkKey, concat(enc.encode('WebPush: info\0'), uaPublic, asPublic, [1]));
  const saltBytes = salt ?? crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(saltBytes, ikm);
  const cek = (await hmac(prk, concat(enc.encode('Content-Encoding: aes128gcm\0'), [1]))).slice(0, 16);
  const nonce = (await hmac(prk, concat(enc.encode('Content-Encoding: nonce\0'), [1]))).slice(0, 12);

  const aesKey = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const record = concat(enc.encode(plaintext), [2]); // 마지막(유일한) 레코드 구분자
  const cipher = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, aesKey, record));
  const header = concat(saltBytes, [0, 0, 16, 0], [asPublic.length], asPublic); // rs = 4096
  return concat(header, cipher);
}

/** 푸시 서비스에 보낼 VAPID 인증 헤더 값: "vapid t=<JWT>, k=<공개키>" */
export async function vapidAuthorization(endpoint, env, nowSec = Math.floor(Date.now() / 1000)) {
  const publicRaw = fromBase64url(env.VAPID_PUBLIC_KEY);
  const key = await crypto.subtle.importKey(
    'jwk',
    p256Jwk(publicRaw, fromBase64url(env.VAPID_PRIVATE_KEY)),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const part = (obj) => base64url(enc.encode(JSON.stringify(obj)));
  const unsigned = `${part({ typ: 'JWT', alg: 'ES256' })}.${part({
    aud: new URL(endpoint).origin,
    exp: nowSec + 12 * 60 * 60,
    sub: env.VAPID_SUBJECT || 'mailto:admin@example.com',
  })}`;
  const signature = new Uint8Array(
    await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(unsigned)),
  );
  return `vapid t=${unsigned}.${base64url(signature)}, k=${env.VAPID_PUBLIC_KEY}`;
}

export const pushConfigured = (env) => !!(env.VAPID_PUBLIC_KEY && env.VAPID_PRIVATE_KEY);

/**
 * 구독 하나에 푸시를 보내고 HTTP 상태 코드를 돌려준다 (201이면 성공, 404·410이면 만료된 구독).
 * [ttlSec] 동안 기기가 꺼져 있어도 푸시 서비스가 보관했다가 전달한다.
 */
export async function sendWebPush(sub, payload, env, ttlSec = 12 * 60 * 60) {
  const body = await encryptPayload(JSON.stringify(payload), sub.p256dh, sub.auth);
  const res = await fetch(sub.endpoint, {
    method: 'POST',
    headers: {
      Authorization: await vapidAuthorization(sub.endpoint, env),
      'Content-Encoding': 'aes128gcm',
      'Content-Type': 'application/octet-stream',
      TTL: String(ttlSec),
      Urgency: 'high',
    },
    body,
  });
  return res.status;
}
