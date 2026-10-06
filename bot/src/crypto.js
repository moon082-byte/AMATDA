// 무작위 값·해시 (Workers와 Node 모두 Web Crypto를 쓴다)

/** URL에 써도 안전한 base64 */
export function base64url(bytes) {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** 추측할 수 없는 무작위 문자열 ([bytes]바이트 → 약 1.33배 길이) */
export function randomToken(bytes = 32) {
  return base64url(crypto.getRandomValues(new Uint8Array(bytes)));
}

export async function sha256Hex(text) {
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
  return [...hash].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** PKCE: verifier → S256 challenge */
export async function pkceChallenge(verifier) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return base64url(new Uint8Array(hash));
}

/** HMAC-SHA256 (16진수) */
export async function hmacHex(secret, text) {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(text)));
  return [...sig].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** 길이가 같은 문자열을 걸리는 시간이 내용과 무관하게 비교한다 */
export function safeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** 000000~999999 무작위 숫자 코드 */
export function randomDigits(length = 6) {
  const values = crypto.getRandomValues(new Uint32Array(length));
  return [...values].map((v) => String(v % 10)).join('');
}
