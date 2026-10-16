import assert from 'node:assert/strict';
import { test } from 'node:test';
import { base64url } from '../src/crypto.js';
import { encryptPayload, fromBase64url, vapidAuthorization } from '../src/webpush.js';

const ecdh = { name: 'ECDH', namedCurve: 'P-256' };

/** base64url 공개키(65바이트)·비밀키(32바이트)로 키 쌍을 만든다 */
async function keyPair(publicB64, privateB64) {
  const raw = fromBase64url(publicB64);
  const jwk = {
    kty: 'EC', crv: 'P-256', ext: true,
    x: base64url(raw.slice(1, 33)), y: base64url(raw.slice(33, 65)), d: privateB64,
  };
  return {
    publicKey: await crypto.subtle.importKey('raw', raw, ecdh, true, []),
    privateKey: await crypto.subtle.importKey('jwk', jwk, ecdh, true, ['deriveBits']),
  };
}

test('RFC 8291 부록 A의 예시와 같은 암호문을 만든다', async () => {
  const body = await encryptPayload(
    'When I grow up, I want to be a watermelon',
    'BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4',
    'BTBZMqHH6r4Tts7J_aSIgg',
    {
      senderKeys: await keyPair(
        'BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8',
        'yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw',
      ),
      salt: fromBase64url('DGv6ra1nlYgDCS1FRnbzlw'),
    },
  );
  assert.equal(
    base64url(body),
    'DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Qulcy4a-fN',
  );
});

test('VAPID 인증 헤더: 푸시 서비스 주소 기준 JWT를 서버 키로 서명한다', async () => {
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const publicRaw = new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey));
  const { d } = await crypto.subtle.exportKey('jwk', pair.privateKey);
  const env = { VAPID_PUBLIC_KEY: base64url(publicRaw), VAPID_PRIVATE_KEY: d, VAPID_SUBJECT: 'mailto:a@b.c' };

  const header = await vapidAuthorization('https://fcm.googleapis.com/fcm/send/abc', env, 1000);
  const [, jwt, k] = /^vapid t=([^,]+), k=(.+)$/.exec(header);
  assert.equal(k, env.VAPID_PUBLIC_KEY);
  const [h, p, s] = jwt.split('.');
  const claims = JSON.parse(new TextDecoder().decode(fromBase64url(p)));
  assert.deepEqual(claims, { aud: 'https://fcm.googleapis.com', exp: 1000 + 43200, sub: 'mailto:a@b.c' });
  const ok = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey, fromBase64url(s), new TextEncoder().encode(`${h}.${p}`),
  );
  assert.ok(ok, '서명이 공개키로 검증돼야 한다');
});
